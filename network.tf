# ---------------------------------------------------------------------------------------------------------------------
# VPC AND SUBNET CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

# Create VPC - Main network container for all resources
resource "aws_vpc" "casegrid_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Public Subnet - Hosts Windows server with internet access
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.casegrid_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
  }
}

# Private Subnet - Hosts Ansible control node with no direct internet access
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.casegrid_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name        = "${var.project_name}-private-subnet"
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORK GATEWAYS AND ROUTING
# ---------------------------------------------------------------------------------------------------------------------

# Internet Gateway - Enables internet access for public subnet resources
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.casegrid_vpc.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# Elastic IP for NAT Gateway - Static IP for outbound internet access from private subnet
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
  }
}

# NAT Gateway - Enables outbound internet access for private subnet resources
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name        = "${var.project_name}-nat-gateway"
    Environment = var.environment
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}

# Public Route Table - Routes traffic from public subnet to internet via IGW
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.casegrid_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# Private Route Table - Routes traffic from private subnet to internet via NAT Gateway
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.casegrid_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

# Route Table Associations - Links subnets with their respective route tables
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC ENDPOINTS FOR AWS SERVICES
# ---------------------------------------------------------------------------------------------------------------------

# Security Group for VPC Endpoints - Controls access to AWS service endpoints
resource "aws_security_group" "vpce_sg" {
  name        = "${var.project_name}-vpce-sg"
  description = "Security group for VPC Endpoints"
  vpc_id      = aws_vpc.casegrid_vpc.id

  ingress {
    description = "HTTPS from private and public subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr, var.public_subnet_cidr]
  }

  tags = {
    Name        = "${var.project_name}-vpce-sg"
    Environment = var.environment
  }
}

# SSM Endpoint - Enables Systems Manager access for instance management
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = aws_vpc.casegrid_vpc.id
  service_name       = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private_subnet.id]
  security_group_ids = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-ssm-endpoint"
    Environment = var.environment
  }
}

# SSM Messages Endpoint - Enables session management for SSM
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id             = aws_vpc.casegrid_vpc.id
  service_name       = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private_subnet.id]
  security_group_ids = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-ssmmessages-endpoint"
    Environment = var.environment
  }
}

# EC2 Messages Endpoint - Enables EC2 instance communication with SSM
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id             = aws_vpc.casegrid_vpc.id
  service_name       = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private_subnet.id]
  security_group_ids = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-ec2messages-endpoint"
    Environment = var.environment
  }
}

# S3 Gateway Endpoint - Enables access to S3 for SSM patches and resources
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.casegrid_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]

  tags = {
    Name        = "${var.project_name}-s3-endpoint"
    Environment = var.environment
  }
}