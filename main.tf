# Provider
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

# Subnet
resource "aws_subnet" "casegrid_subnet" {
    vpc_id = aws_vpc.casegrid_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-2a"
    tags = {
      Name = "casegrid_subnet"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "casegrid_igw" {
  vpc_id = aws_vpc.casegrid_vpc.id
  tags = {
    Name = "casegrid_igw"
  }
}

# Route Table
resource "aws_route_table" "casegrid_rt" {
  vpc_id = aws_vpc.casegrid_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.casegrid_igw.id
  }
  tags = {
    Name = "casegrid_rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "casegrid_rt_association" {
  subnet_id = aws_subnet.casegrid_subnet.id
  route_table_id = aws_route_table.casegrid_rt.id
}

# Security Group
resource "aws_security_group" "casegrid_sg" {
  name        = "casegrid_sg"
  description = "Security group for CaseGrid EC2 instance"
  vpc_id      = aws_vpc.casegrid_vpc.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RDP from internet"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "casegrid_sg"
  }
}

# Key Pair
resource "tls_private_key" "casegrid_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "casegrid_key" {
  key_name   = "casegrid_key"
  public_key = tls_private_key.casegrid_private_key.public_key_openssh
}

# EC2 Instance
resource "aws_instance" "casegrid_ec2" {
  ami = "ami-03dad44b0cd6f43d1"
  instance_type = "t3.large"
  subnet_id = aws_subnet.casegrid_subnet.id
  vpc_security_group_ids = [aws_security_group.casegrid_sg.id]
  associate_public_ip_address = true
  key_name = aws_key_pair.casegrid_key.key_name
  
  tags = {
    Name = "casegrid_ec2"
  }
}

# Output
output "ec2_public_ip" {
  value = aws_instance.casegrid_ec2.public_ip
}

output "private_key_pem" {
  value     = tls_private_key.casegrid_private_key.private_key_pem
  sensitive = true
}