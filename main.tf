# ---------------------------------------------------------------------------------------------------------------------
# CLOUD WATCH LOG GROUPS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "windows_setup_logs" {
  name              = "/${var.project_name}/${var.environment}/windows-setup"
  retention_in_days = 30
  
  tags = {
    Name        = "${var.project_name}-windows-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "ansible_setup_logs" {
  name              = "/${var.project_name}/${var.environment}/ansible-setup"
  retention_in_days = 30
  
  tags = {
    Name        = "${var.project_name}-ansible-logs"
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SECURITY CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

# Security Group for Windows Server
resource "aws_security_group" "windows_sg" {
  name        = "${var.project_name}-windows-sg"
  description = "Security group for Windows Server"
  vpc_id      = aws_vpc.casegrid_vpc.id

  # HTTP access from anywhere for website
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere for website
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Explicit rule for SSM VPC endpoints
  egress {
    description = "HTTPS to VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]  # VPC endpoints are in private subnet
  }

  # Allow all other outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-windows-sg"
    Environment = var.environment
  }
}

# Security Group for Ansible Control Node
resource "aws_security_group" "ansible_sg" {
  name        = "${var.project_name}-ansible-sg"
  description = "Security group for Ansible control node"
  vpc_id      = aws_vpc.casegrid_vpc.id

  # Allow all outbound traffic to VPC endpoints and internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ansible-sg"
    Environment = var.environment
  }
}

# Generate SSH key for the Ubuntu instance
resource "tls_private_key" "ubuntu_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Add the public key to AWS
resource "aws_key_pair" "ubuntu_key" {
  key_name   = "${var.project_name}-ubuntu-key"
  public_key = tls_private_key.ubuntu_ssh_key.public_key_openssh
}

data "template_file" "windows_script" {
  template = file("${path.module}/scripts/windows.ps1")
  vars = {
    admin_password = random_password.windows_password.result
    project_name   = var.project_name
    environment    = var.environment
  }
}

data "template_file" "ansible_inventory" {
  template = file("${path.module}/scripts/inventory.ini")
  vars = {
    windows_dns = aws_instance.windows_server.private_dns
    aws_region  = var.aws_region
  }
}

data "template_file" "ansible_setup" {
  template = file("${path.module}/scripts/ansible_setup.sh")
  vars = {
    ansible_config      = file("${path.module}/scripts/ansible.cfg")
    ansible_inventory   = data.template_file.ansible_inventory.rendered
    ansible_playbook    = file("${path.module}/scripts/install_iis.yml")
    validation_playbook = file("${path.module}/scripts/validate_connection.yml")
    project_name        = var.project_name
    environment         = var.environment
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 INSTANCES
# ---------------------------------------------------------------------------------------------------------------------

# Windows Server Instance
resource "aws_instance" "windows_server" {
  ami                  = var.windows_ami
  instance_type        = var.windows_instance_type
  subnet_id            = aws_subnet.public_subnet.id
  iam_instance_profile = aws_iam_instance_profile.windows_server_profile.name
  vpc_security_group_ids = [aws_security_group.windows_sg.id]

  user_data = <<-EOF
              <powershell>
              ${data.template_file.windows_script.rendered}
              </powershell>
              EOF

  # Ensure the log group exists before the instance starts
  # This prevents loss of early logs during instance initialization
  depends_on = [aws_cloudwatch_log_group.windows_setup_logs]

  tags = {
    Name        = "${var.project_name}-windows"
    Environment = var.environment
    Role        = "web-server"
  }
}

# Ansible Control Node Instance (Ubuntu)
resource "aws_instance" "ansible_control" {
  ami                    = var.ansible_ami
  instance_type          = var.ansible_instance_type
  subnet_id              = aws_subnet.private_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.ansible_control_profile.name
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  key_name               = aws_key_pair.ubuntu_key.key_name

  user_data = data.template_file.ansible_setup.rendered

  tags = {
    Name        = "${var.project_name}-ansible-control"
    Environment = var.environment
    Role        = "ansible-controller"
  }

  depends_on = [
    aws_nat_gateway.nat_gateway,
    aws_instance.windows_server,
    aws_secretsmanager_secret_version.windows_password,
    aws_cloudwatch_log_group.ansible_setup_logs
  ]
}
