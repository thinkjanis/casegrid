variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "eu-west-2a"
}

variable "windows_instance_type" {
  description = "Instance type for Windows server"
  type        = string
  default     = "m5.large"
}

variable "windows_ami" {
  description = "AMI ID for Windows server"
  type        = string
  default     = "ami-03dad44b0cd6f43d1"
}

variable "ansible_instance_type" {
  description = "Instance type for Ubuntu server"
  type        = string
  default     = "t2.micro"
}

variable "ansible_ami" {
  description = "AMI ID for Ubuntu server"
  type        = string
  default     = "ami-091f18e98bc129c4e"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "casegrid"
}

variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "prod"
}