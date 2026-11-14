variable "subnet_id" {
  description = "The subnet ID where the EC2 instance will live"
  type        = string
}

variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID passed from the networking module"
  type        = string
}

variable "public_key" {
  description = "Public SSH key for the EC2 instance"
  type        = string
}

