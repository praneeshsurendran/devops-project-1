terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "praneesh-devops-tfstate-sydney-2026"
    key            = "prod/terraform.tfstate"
    region         = "ap-southeast-2"
    use_lockfile = true
    encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-2"
}