# ---------------------------------------------------------------------------------------------------------------------
# AWS CONFIGURATION VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where resources will be created (e.g., eu-west-2 for London)"
  type        = string
  default     = "eu-west-2"
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORK CONFIGURATION VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC network space (e.g., 10.0.0.0/16 provides 65,536 addresses)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet where Windows server will be deployed"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet where Ansible control node will be deployed"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "AWS availability zone for subnet placement (must be within aws_region)"
  type        = string
  default     = "eu-west-2a"
}

# ---------------------------------------------------------------------------------------------------------------------
# INSTANCE CONFIGURATION VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "windows_instance_type" {
  description = "EC2 instance type for Windows server (m5.large recommended for production workloads)"
  type        = string
  default     = "m5.large"
}

variable "windows_ami" {
  description = "AMI ID for Windows Server (must be a Windows Server AMI in the specified region)"
  type        = string
  default     = "ami-03dad44b0cd6f43d1"
}

variable "ansible_instance_type" {
  description = "EC2 instance type for Ansible control node (t2.micro is sufficient for basic management)"
  type        = string
  default     = "t2.micro"
}

variable "ansible_ami" {
  description = "AMI ID for Ubuntu server (must be an Ubuntu AMI in the specified region)"
  type        = string
  default     = "ami-091f18e98bc129c4e"
}

# ---------------------------------------------------------------------------------------------------------------------
# TAGGING VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming and tagging (lowercase, no spaces)"
  type        = string
  default     = "casegrid"
}

variable "environment" {
  description = "Environment name (e.g., prod, dev, staging) for resource tagging and naming"
  type        = string
  default     = "prod"
}