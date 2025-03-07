# ---------------------------------------------------------------------------------------------------------------------
# PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.0"
    }
  }

  backend "remote" {}
}

provider "aws" {
  region = var.aws_region
}