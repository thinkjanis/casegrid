#!/bin/bash

# Exit on any error
set -e

# Install AWS CLI first
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    apt-get update && apt-get install -y unzip
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
else
    echo "AWS CLI already installed: $(aws --version)"
fi

# CloudWatch Log configuration
LOG_GROUP="/${project_name}/${environment}/ansible-setup"
LOG_STREAM="ansible-$(date +%Y-%m-%d-%H-%M-%S)"

# Simple logging function
log_message() {
    local message="$1"
    aws logs put-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$LOG_STREAM" \
        --log-events timestamp=$(date +%s000),message="$message" 2>/dev/null || echo "Failed to log to CloudWatch: $message"
    echo "$message"
}

# Setup CloudWatch logs
aws logs create-log-group --log-group-name "$LOG_GROUP" 2>/dev/null || true
aws logs create-log-stream --log-group-name "$LOG_GROUP" --log-stream-name "$LOG_STREAM" 2>/dev/null || true

# Redirect stdout to logging function
exec > >(while read -r line; do log_message "$line"; done) 2>&1

# Wait for cloud-init to complete
log_message "Waiting for cloud-init to complete..."
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done

# Install required packages
log_message "Installing required packages..."
apt-get update && apt-get install -y python3-pip ansible snapd

# Install AWS Session Manager plugin if not present
if ! command -v session-manager-plugin &> /dev/null; then
    log_message "Installing Session Manager plugin..."
    snap install amazon-ssm-agent --classic
    snap enable amazon-ssm-agent
    snap start amazon-ssm-agent
else
    log_message "Session Manager plugin already installed"
fi

# Install Python packages
log_message "Installing Python packages..."
pip3 install boto3 botocore

# Setup Ansible configuration
log_message "Setting up Ansible..."
mkdir -p /etc/ansible /home/ubuntu/ansible
echo "${ansible_config}" > /etc/ansible/ansible.cfg
echo "${ansible_inventory}" > /etc/ansible/hosts
echo "${validation_playbook}" > /home/ubuntu/ansible/validate_connection.yml
echo "${ansible_playbook}" > /home/ubuntu/ansible/install_iis.yml

# Create and schedule playbook execution script
log_message "Creating playbook execution script..."
cat > /home/ubuntu/ansible/run_playbook.sh <<'EOL'
#!/bin/bash
set -e
log_message() {
    local msg="$1"
    aws logs put-log-events --log-group-name "$LOG_GROUP" --log-stream-name "$LOG_STREAM" --log-events timestamp=$(date +%s000),message="$msg" 2>/dev/null || echo "Failed to log: $msg"
    echo "$msg"
}
cd /home/ubuntu/ansible
ANSIBLE_HOST_KEY_CHECKING=False
log_message "Validating connection..."
ansible-playbook validate_connection.yml -v || { log_message "Validation failed"; exit 1; }
log_message "Installing IIS..."
ansible-playbook install_iis.yml -v || { log_message "IIS installation failed"; exit 1; }
log_message "Setup completed successfully"
EOL

chmod +x /home/ubuntu/ansible/run_playbook.sh
log_message "Scheduling playbook execution in 3 minutes..."
(sleep 180 && /home/ubuntu/ansible/run_playbook.sh) &

log_message "Setup completed successfully"