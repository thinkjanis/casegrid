# Provider
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "remote" {}
}

# AWS
provider "aws" {
    region = "eu-west-2"
}

# VPC
resource "aws_vpc" "casegrid_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "casegrid_vpc"
  }
}

