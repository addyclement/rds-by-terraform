
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region     = var.region
  access_key = "XXXXX"
  secret_key = "XXXXXX"
}

#looking up secrets manager creds
data "aws_secretsmanager_secret_version" "credentials" {
  # Fill in the name you gave to your secret
  secret_id = "terraform-rds-secret"
}

locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.credentials.secret_string
  )
}


# Setting up the primary VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc

resource "aws_vpc" "shopping_vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "Shopping VPC"
  }
}

#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet

#Configure Private Subnet 1

resource "aws_subnet" "priv_subnet_1" {
  vpc_id     = aws_vpc.shopping_vpc.id
  cidr_block = var.priv_subnet_1
  #map_public_ip_on_launch = true
  availability_zone = var.var-az["zone-1"]

  tags = {
    Name        = "Private Subnet 1"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"
  }
}

#Private Subnet2
resource "aws_subnet" "priv_subnet_2" {
  vpc_id     = aws_vpc.shopping_vpc.id
  cidr_block = var.priv_subnet_2
  #map_public_ip_on_launch = true
  availability_zone = var.var-az["zone-2"]

  tags = {
    Name        = "Private Subnet 2"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"
  }
}

#Public Subnet1
resource "aws_subnet" "pub_subnet_1" {
  vpc_id                  = aws_vpc.shopping_vpc.id
  cidr_block              = var.pub_subnet_1
  map_public_ip_on_launch = true
  availability_zone       = var.var-az["zone-1"]

  tags = {
    Name        = "Public Subnet 1"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"
  }
}

#Public Subnet2 
resource "aws_subnet" "pub_subnet_2" {
  vpc_id                  = aws_vpc.shopping_vpc.id
  cidr_block              = var.pub_subnet_2
  map_public_ip_on_launch = true
  availability_zone       = var.var-az["zone-2"]

  tags = {
    Name        = "Public Subnet 2"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"
  }
}

#Create an IGW
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.shopping_vpc.id

  tags = {
    Name        = "Internet Gateway-01"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"
  }
}

#resource "aws_instance" "foo" {
# ... other arguments ...

# depends_on = [aws_internet_gateway.gw]
#}

# Create a custom route for public subnets
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_table

resource "aws_route_table" "pub_subnet_route" {
  vpc_id = aws_vpc.shopping_vpc.id

  route {
    # route to the internet
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "Custom Public Route"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"
  }
}



#Associate the public subnets with the custom public route
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association

resource "aws_route_table_association" "rtassoc-pub-subnet-1" {
  subnet_id      = aws_subnet.pub_subnet_1.id
  route_table_id = aws_route_table.pub_subnet_route.id
}

resource "aws_route_table_association" "rtassoc-pub-subnet-2" {
  subnet_id      = aws_subnet.pub_subnet_2.id
  route_table_id = aws_route_table.pub_subnet_route.id
}

#Create web server(s) security group

resource "aws_security_group" "web_server_sg" {
  name        = "web_server_sg"
  description = "Allow http(s) inbound traffic"
  vpc_id      = aws_vpc.shopping_vpc.id

  ingress {
    description = "https traffic from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    description = "http traffic from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web server access"
  }
}


#Create SG and rules for public facing load balancer

resource "aws_security_group" "elb_sg" {
  name        = "Load balancer SG"
  description = "Public Access from LB"
  vpc_id      = aws_vpc.shopping_vpc.id

  tags = {

    name        = "SG-ELB-Public-Access"
    project     = "Baxley"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"

  }

}

#allow mysql traffic http/https traffic from public
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule

resource "aws_security_group_rule" "http_access" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.elb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https_access" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.elb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}


#Create web server(s) security group
#https://cloudcasts.io/course/terraform/security-groups
#we wont declare the sg rules inline in this alternate format
#https://dev.to/aws-builders/how-to-terraform-multiple-security-group-with-varying-configuration-1638

resource "aws_security_group" "db_sg" {
  #  name = "cloudcasts-${var.infra_env}-public-sg"
  name        = "DB Servers SG"
  description = "VPC Access to DB Servers"
  vpc_id      = aws_vpc.shopping_vpc.id

  tags = {

    name        = "SG-DB-VPC-Access"
    project     = "Baxley"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"

  }

}

#  Name = "cloudcasts-${var.infra_env}-public-sg"
#  Environment = var.infra_env

#allow mysql traffic from web server SG
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule

resource "aws_security_group_rule" "mysql_access" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = aws_security_group.web_server_sg.id
}

#create DB Subnet Group to span accross AZ-1 and AZ-2
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group

resource "aws_db_subnet_group" "shopping_subnet_grp" {
  name        = "shopping subnet group"
  subnet_ids  = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id]
  description = "Subnet Group for RDS/Aurora Instances"
  tags = {
    Name        = "My DB Subnet Group"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"
  }
}

#https://developer.hashicorp.com/terraform/tutorials/aws/aws-rds
#Create custom DB Parameter Group
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group

resource "aws_db_parameter_group" "shoppingdb-mysql8-pg" {
  name   = "shdb-mysql8-pg"
  family = "mysql8.0"

  dynamic "parameter" {
    for_each = var.cstm_db_params
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", null)
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "ShoppingDB Parameter Group"
  }
}

#Create primary DB instance specifying cstm DB parameterand security grp

resource "aws_db_instance" "rds-pry-instance" {
  allocated_storage                     = 20
  max_allocated_storage                 = var.var-dbconf["max_storage"]
  identifier                            = "shopping-db-source"
  storage_type                          = "gp2"
  engine                                = "mysql"
  engine_version                        = "8.0.31"
  instance_class                        = var.db-instance-class-types[terraform.workspace]
  db_name                               = "shoppingdb"
  username                              = local.db_creds.username
  password                              = local.db_creds.password
  parameter_group_name                  = aws_db_parameter_group.shoppingdb-mysql8-pg.name
  performance_insights_enabled          = true
  performance_insights_retention_period = 31
  multi_az                              = true
  publicly_accessible                   = false
  skip_final_snapshot                   = true
  port                                  = var.var-dbconf["db_port"]
  vpc_security_group_ids                = ["${aws_security_group.db_sg.id}"]
  monitoring_role_arn                   = aws_iam_role.iam-role-rds-monitoring.arn
  monitoring_interval                   = 5
  maintenance_window                    = "Sun:01:00-Sun:02:30"
  backup_window                         = "03:00-05:00"
  backup_retention_period               = var.var-dbconf["backup_retention_period"]
  iam_database_authentication_enabled   = true
  auto_minor_version_upgrade            = false
  db_subnet_group_name                  = aws_db_subnet_group.shopping_subnet_grp.name
  enabled_cloudwatch_logs_exports       = ["error", "slowquery"]
  tags = {
    Name        = "ShoppingDB_01"
    Environment = "baxley-${terraform.workspace}"
    managed_by  = "Terraform"
  }
}

#Create Hosted Zone, CNAME record etc for RDS, ELB
#resource "aws_route53_record" "database" {
#  zone_id = "${aws_route53_zone.primary.zone_id}"
#  name = "database.example.com"
#  type = "CNAME"
#  ttl = "300"
#  records = ["${aws_db_instance.mydb.address}"]
#}
