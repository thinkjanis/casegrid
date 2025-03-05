# ---------------------------------------------------------------------------------------------------------------------
# IAM ROLES AND POLICIES
# ---------------------------------------------------------------------------------------------------------------------

# Windows Server Role
resource "aws_iam_role" "windows_server_role" {
  name = "${var.project_name}-windows-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-windows-server-role"
    Environment = var.environment
  }
}

# Windows Server SSM Policy
resource "aws_iam_role_policy_attachment" "windows_ssm_policy" {
  role       = aws_iam_role.windows_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Windows Server CloudWatch Policy
resource "aws_iam_role_policy" "windows_cloudwatch_policy" {
  name = "${var.project_name}-windows-cloudwatch-policy"
  role = aws_iam_role.windows_server_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

# Windows Server Instance Profile
resource "aws_iam_instance_profile" "windows_server_profile" {
  name = "${var.project_name}-windows-server-profile"
  role = aws_iam_role.windows_server_role.name
}

# Ansible Control Node Role
resource "aws_iam_role" "ansible_control_role" {
  name = "${var.project_name}-ansible-control-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ansible-control-role"
    Environment = var.environment
  }
}

# Ansible Control Node Custom Policy for Secrets Manager
resource "aws_iam_role_policy" "ansible_secrets_policy" {
  name = "${var.project_name}-ansible-secrets-policy"
  role = aws_iam_role.ansible_control_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.windows_password.arn
        ]
      }
    ]
  })
}

# Ansible Control Node SSM Policy
resource "aws_iam_role_policy_attachment" "ansible_ssm_policy" {
  role       = aws_iam_role.ansible_control_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Ansible Control Node CloudWatch Policy
resource "aws_iam_role_policy" "ansible_cloudwatch_policy" {
  name = "${var.project_name}-ansible-cloudwatch-policy"
  role = aws_iam_role.ansible_control_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

# Ansible Control Node SSM Control Policy
resource "aws_iam_role_policy" "ansible_ssm_control_policy" {
  name = "${var.project_name}-ansible-ssm-control-policy"
  role = aws_iam_role.ansible_control_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # EC2 instance discovery permissions - needed to find Windows hosts
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = ["*"]
      },
      {
        # SSM information and connection status permissions
        # These are required for basic SSM functionality and don't need specific resources
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetConnectionStatus",
          "ssm:DescribeInstanceProperties",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations"
        ]
        Resource = ["*"]
      },
      {
        # SSM session management permissions for connecting to Windows hosts
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:ResumeSession",
          "ssm:TerminateSession"
        ]
        # Restrict to Windows instances in the account
        Resource = [
          "arn:aws:ec2:*:*:instance/*"
        ]
        Condition = {
          StringLike = {
            "ssm:resourceTag/Role": "web-server"
          }
        }
      },
      {
        # SSM command and automation permissions for Windows management
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:StartAutomationExecution",
          "ssm:GetAutomationExecution",
          "ssm:StopAutomationExecution"
        ]
        # Restrict to Windows instances in the account 
        Resource = [
          "arn:aws:ec2:*:*:instance/*"
        ]
        Condition = {
          StringLike = {
            "ssm:resourceTag/Role": "web-server"
          }
        }
      },
      {
        # Permission to use SSM Documents for command execution
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetDocument"
        ]
        # Restrict to AWS managed documents and our account's custom documents
        Resource = [
          "arn:aws:ssm:*:*:document/AWS-*",
          "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:document/*"
        ]
      }
    ]
  })
}

# Add this data source at the top of the file (after provider block)
data "aws_caller_identity" "current" {}

# Ansible Control Node Instance Profile
resource "aws_iam_instance_profile" "ansible_control_profile" {
  name = "${var.project_name}-ansible-control-profile"
  role = aws_iam_role.ansible_control_role.name
}

# ---------------------------------------------------------------------------------------------------------------------
# SECRETS MANAGER
# ---------------------------------------------------------------------------------------------------------------------

# Windows Server Administrator Password
resource "aws_secretsmanager_secret" "windows_password" {
  name = "${var.project_name}/${var.environment}/windows-admin-password"
  force_overwrite_replica_secret = true
  recovery_window_in_days = 0
  
  tags = {
    Name        = "${var.project_name}-windows-password"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "windows_password" {
  secret_id     = aws_secretsmanager_secret.windows_password.id
  secret_string = random_password.windows_password.result
}

resource "random_password" "windows_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()_+"
}