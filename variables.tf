#define custom RDS configurations

#include PI/EM, enable IAM auth, setup RR

variable "var-dbconf" {
  type = map(any)
  default = {
    "backup_retention_period" = 2
    "max_storage"             = 35
    "db_port"                 = 3306
    "instance_type"           = "t3.micro"
  }
}

variable "db-instance-class-types" {
  type = map(any)
  default = {
    "dev"     = "t3.medium"
    "staging" = "t3.medium"
    "prod"    = "db.m6g.large"
  }
}

# Defaulting to london region
variable "region" {
  default = "eu-west-2"
}

# Defining CIDR Block for Shopping VPC
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

# Defining CIDR Block for Private Subnet 1
variable "priv_subnet_1" {
  default = "10.0.1.0/24"
}

# Defining CIDR Block for Private Subnet 2
variable "priv_subnet_2" {
  default = "10.0.2.0/24"
}


# Defining CIDR Block for Public Subnet 1
variable "pub_subnet_1" {
  default = "10.0.3.0/24"
}

# Defining CIDR Block for Private Subnet 2
variable "pub_subnet_2" {
  default = "10.0.4.0/24"
}

variable "var-az" {
  type = map(any)
  default = {
    "zone-1" = "eu-west-2a"
    "zone-2" = "eu-west-2b"
    "zone-3" = "eu-west-2c"
  }
}


#specify custom DB paramters

variable "cstm_db_params" {
  type = list(map(string))
  default = [
    {
      name  = "character_set_connection"
      value = "utf8mb4"
    },
    { name  = "character_set_server"
      value = "utf8mb4"
    },
    {
      name  = "log_bin_trust_function_creators"
      value = 1
    },
    {
      name  = "slow_query_log"
      value = 1
    },
    {
      name  = "long_query_time"
      value = 2
    },
    {
      name  = "log_output"
      value = "FILE"
    },
    {
      name  = "max_allowed_packet"
      value = 268435456
    }
  ]
}
