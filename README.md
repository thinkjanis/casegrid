# CaseGrid - Capstone Project

**CaseGrid** is a capstone project demonstrating infrastructure automation. It provisions an AWS environment and deploys an IIS web server on Windows Server that is managed by an Ansible control node.

## Technologies Used
- **Terraform**: Provisions AWS resources (EC2, VPC, etc.).
- **PowerShell & Bash**: Automates Windows and cross-platform tasks.
- **AWS**: Hosts the infrastructure (EC2, networking).
- **Windows Server**: Runs the IIS web server.
- **Ansible**: Configures IIS and manages the server.
- **IIS**: Serves web content.

## Project Structure
CaseGrid/
├── terraform/                  # Terraform configuration files
│   ├── backend.hcl            # Terraform backend configuration
│   ├── backend.hcl.example    # Example backend configuration
│   ├── iam.tf                 # IAM resource definitions
│   ├── main.tf                # Main Terraform configuration
│   ├── network.tf             # Network resource definitions
│   ├── outputs.tf             # Terraform outputs
│   ├── providers.tf           # Provider configuration
│   ├── terraform.lock.hcl     # Terraform lock file
│   ├── terraform.tfstate      # Terraform state file
│   ├── terraform.tfstate.backup # Terraform state backup
│   ├── variables.tf           # Variable definitions
├── scripts/                    # Automation scripts
│   ├── ansible_setup.sh       # Bash script for Ansible setup
│   ├── tf-troubleshooting.sh  # Bash script for Terraform troubleshooting
│   └── windows.ps1            # PowerShell script for Windows
├── ansible.cfg                # Ansible configuration file
├── install_iis.yml            # Ansible playbook for IIS installation
├── inventory.ini              # Ansible inventory file
├── validate_connection.yml    # Ansible playbook for connection validation
├── .gitignore                 # Git ignore file
└── README.md                  # This file