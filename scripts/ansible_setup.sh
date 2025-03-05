#!/bin/bash

# =====================================================
# Enhanced AWS SSM Ansible Automation Script
# =====================================================
# This script configures an Ansible control node to manage
# Windows servers via AWS SSM, with improved diagnostics
# and error handling for troubleshooting connections.
# =====================================================

# CloudWatch Log configuration
LOG_GROUP="/${project_name}/${environment}/ansible-setup"
LOG_STREAM="ansible-$(date +%Y-%m-%d-%H-%M-%S)"

# Simple logging function that writes to both CloudWatch and stdout
log_message() {
    message="$1"
    
    # Attempt to log the message to CloudWatch
    aws logs put-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$LOG_STREAM" \
        --log-events timestamp=$(date +%s000),message="$message" \
        2>/dev/null || {
            # Log error if writing to CloudWatch fails
            echo "Failed to log message to CloudWatch: $message"
        }
    
    # Also print the message to stdout
    echo "$message"
}

# Create log group and stream if they do not exist
aws logs create-log-group --log-group-name "$LOG_GROUP" 2>/dev/null || true
aws logs create-log-stream --log-group-name "$LOG_GROUP" --log-stream-name "$LOG_STREAM" 2>/dev/null || true

# Redirect stdout and stderr to both syslog and our logging function
exec 1> >(tee >(logger -s -t $(basename $0)) >(while read line; do log_message "$line"; done))
exec 2>&1

# Exit on any error
set -e

# Function to handle errors
handle_error() {
    echo "Error occurred in script at line: $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Wait for cloud-init to complete
echo "Waiting for cloud-init to complete..."
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
  sleep 1
done

# Install required packages
echo "Installing required packages..."
if ! sudo apt-get update; then
    echo "Failed to update package list"
    exit 1
fi

if ! sudo apt-get install -y software-properties-common python3-pip; then
    echo "Failed to install software-properties-common and python3-pip"
    exit 1
fi

if ! sudo add-apt-repository --yes --update ppa:ansible/ansible; then
    echo "Failed to add Ansible repository"
    exit 1
fi

if ! sudo apt-get install -y ansible; then
    echo "Failed to install Ansible"
    exit 1
fi

# Install AWS CLI
# echo "Installing AWS CLI..."
# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
# sudo apt-get install -y unzip
# unzip awscliv2.zip
# sudo ./aws/install
# rm -rf aws awscliv2.zip

# Install AWS Session Manager plugin
# echo "Installing Session Manager plugin..."
# curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
# sudo dpkg -i session-manager-plugin.deb
# rm session-manager-plugin.deb

# ------- Check AWS CLI installation
if aws --version > /dev/null 2>&1; then
    log_message "AWS CLI is installed successfully"
else
    log_message "AWS CLI is not installed"
    exit 1
fi

# Check Session Manager plugin installation
if session-manager-plugin --version > /dev/null 2>&1; then
    log_message "Session Manager plugin is installed successfully"
else
    log_message "Session Manager plugin is not installed"
    exit 1
fi

# -------

# Install required Python packages and Ansible collections
echo "Installing Python packages..."
if ! pip3 install boto3 botocore ansible[aws]; then
    echo "Failed to install Python packages"
    exit 1
fi

echo "Installing Ansible collections..."
if ! ansible-galaxy collection install ansible.windows; then
    echo "Failed to install Ansible Windows collection"
    exit 1
fi

# Install AWS SSM agent
echo "Installing AWS SSM agent..."
if ! sudo snap install amazon-ssm-agent --classic; then
    echo "Failed to install AWS SSM agent"
    exit 1
fi

# Enable and start SSM agent with verification
# echo "Configuring SSM agent..."
# sudo systemctl enable amazon-ssm-agent
# sudo systemctl start amazon-ssm-agent

# Verify SSM agent is running
echo "Verifying SSM agent status..."
if ! sudo systemctl is-active --quiet amazon-ssm-agent; then
    echo "AWS SSM agent is not running"
    exit 1
fi

# Setup Ansible configuration
echo "Setting up Ansible configuration..."
sudo mkdir -p /etc/ansible
sudo tee /etc/ansible/ansible.cfg > /dev/null <<'EOL'
${ansible_config}
EOL

# Create inventory file
sudo tee /etc/ansible/hosts > /dev/null <<EOL
${ansible_inventory}
EOL

# Copy playbooks
sudo mkdir -p /home/ubuntu/ansible

# Copy the validation playbook
sudo tee /home/ubuntu/ansible/validate_connection.yml > /dev/null <<EOL
${validation_playbook}
EOL

# Copy the IIS installation playbook
sudo tee /home/ubuntu/ansible/install_iis.yml > /dev/null <<EOL
${ansible_playbook}
EOL

# Create playbook execution script with improved error handling and validation first
sudo tee /home/ubuntu/ansible/run_playbook.sh > /dev/null <<'EOL'
#!/bin/bash

# Exit on error
set -e

# Function to log to CloudWatch
log_message() {
    message="$1"
    aws logs put-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$LOG_STREAM" \
        --log-events timestamp=$(date +%s000),message="$message" \
        2>/dev/null || echo "Failed to log to CloudWatch: $message"
    echo "$message"
}

cd /home/ubuntu/ansible
ANSIBLE_HOST_KEY_CHECKING=False 

# STEP 1: Run the validation playbook first
log_message "Running connection validation playbook..."
ansible-playbook validate_connection.yml -v
if [ $? -ne 0 ]; then
    log_message "ERROR: Connection validation failed. Cannot proceed with IIS installation."
    log_message "Please check the Windows server configuration and AWS SSM connectivity."
    exit 1
else
    log_message "SUCCESS: Connection validation completed successfully."
fi

# STEP 2: If validation succeeds, proceed with IIS installation
log_message "Proceeding with IIS installation playbook..."
ansible-playbook install_iis.yml -v
if [ $? -ne 0 ]; then
    log_message "ERROR: IIS installation failed."
    exit 1
fi

log_message "SUCCESS: IIS installation completed successfully."
log_message "All playbooks executed successfully."
EOL

sudo chmod +x /home/ubuntu/ansible/run_playbook.sh

# Schedule the playbook execution for after a short delay
log_message "Scheduling Ansible playbook execution..."
# Wait for 3 minutes before running playbooks to allow systems to fully initialize
(sleep 180 && /home/ubuntu/ansible/run_playbook.sh 2>&1 | logger -t ansible-playbook) &
log_message "Playbook execution scheduled. It will run in 3 minutes."
log_message "The validate_connection.yml playbook will first verify connectivity before attempting IIS installation."

# Get all EC2 instance IDs with appropriate tag
WINDOWS_INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${project_name}-windows" --query "Reservations[].Instances[].InstanceId" --output text)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

echo "Setup completed successfully"