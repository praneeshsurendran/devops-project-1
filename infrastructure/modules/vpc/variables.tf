variable "vpc_cidr"{
    description = "CIDR block for the VPC"
    type = string
}

variable "env_name"{
    description = "Dev, Staging or Prod environment?"
    type = string
}