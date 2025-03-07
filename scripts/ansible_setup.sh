#!/bin/bash

# Exit on any error
set -e

# Simple logging function
log_message() {
    local message="$1"
    echo "$message"
    # Single logging method that works with both console and EC2 system log
    logger -t "ansible-setup" "$message"
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_message "Error on line $line_number: Command exited with status $exit_code"
    exit $exit_code
}

# Set up trap for error handling
trap 'handle_error $LINENO' ERR

# Install AWS CLI first
if ! command -v aws &> /dev/null; then
    log_message "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    apt-get update && apt-get install -y unzip
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
else
    log_message "AWS CLI already installed: $(aws --version)"
fi

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
    
    # Verify SSM Agent is running properly
    log_message "Verifying SSM Agent status..."
    sleep 5
    SSM_STATUS=$(snap services amazon-ssm-agent | grep amazon-ssm-agent | awk '{print $2}')
    
    if [ "$SSM_STATUS" != "active" ]; then
        log_message "SSM Agent is not running! Attempting to restart..."
        snap restart amazon-ssm-agent
        sleep 5
        SSM_STATUS=$(snap services amazon-ssm-agent | grep amazon-ssm-agent | awk '{print $2}')
        
        if [ "$SSM_STATUS" != "active" ]; then
            log_message "Failed to start SSM Agent. Installation may have issues."
            # Not exiting with error as the instance might still be usable
        fi
    else
        log_message "SSM Agent is running properly"
    fi
    
    # Check SSM Agent registration status
    log_message "Checking SSM Agent registration status..."
    if [ -f /var/log/amazon/ssm/amazon-ssm-agent.log ]; then
        if grep -q "Successfully registered the instance" /var/log/amazon/ssm/amazon-ssm-agent.log; then
            log_message "SSM Agent successfully registered with AWS SSM service"
        else
            log_message "Warning: Could not confirm SSM Agent registration in logs. This might be normal for a new instance."
        fi
    else
        log_message "Warning: SSM Agent log file not found. Cannot verify registration status."
    fi
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
echo "${ansible_playbook}" > /home/ubuntu/ansible/install_iis.yml

# Create and schedule playbook execution script
log_message "Creating playbook execution script..."
cat > /home/ubuntu/ansible/run_playbook.sh <<'EOL'
#!/bin/bash
set -e

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    echo "Error on line $line_number: Command exited with status $exit_code" | logger -t "ansible-playbook"
    exit $exit_code
}

# Set up trap for error handling
trap 'handle_error $LINENO' ERR

# Simple logging function
log_message() {
    local msg="$1"
    echo "$msg"
    logger -t "ansible-playbook" "$msg"
}

cd /home/ubuntu/ansible
ANSIBLE_HOST_KEY_CHECKING=False
log_message "Installing IIS..."
ansible-playbook install_iis.yml -v || { log_message "IIS installation failed"; exit 1; }
log_message "Setup completed successfully"
EOL

chmod +x /home/ubuntu/ansible/run_playbook.sh
log_message "Scheduling playbook execution in 3 minutes..."
(sleep 180 && /home/ubuntu/ansible/run_playbook.sh) &

log_message "Setup completed successfully"