#!/bin/bash

# Exit on any error
set -e

# Simple logging function
log_message() {
    local message="$1"
    # Write to console
    echo "$message"
    # Write to system log
    logger -t "ansible-setup" "$message"
    # Additionally write to console device directly
    echo "[ansible-setup] $message" > /dev/console
    # Also write to a separate log file that you can check later
    echo "$(date): [ansible-setup] $message" >> /var/log/ansible-setup.log
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_message "Error on line $line_number: Command exited with status $exit_code"
    exit $exit_code
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Set up trap for error handling
trap 'handle_error $LINENO' ERR

# Install Ansible
log_message "Starting Ansible installation..."

# Check if apt exists
if ! command_exists apt; then
    log_message "Error: apt command not found. This script requires a Debian-based system."
    exit 1
fi

# Update package lists with retry mechanism
max_retries=3
retry_count=0
update_success=false

while [ $retry_count -lt $max_retries ] && [ "$update_success" != "true" ]; do
    log_message "Updating package lists (attempt $(($retry_count + 1))/$max_retries)..."
    if sudo apt update -y; then
        update_success=true
        log_message "Package lists updated successfully."
    else
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            log_message "Package update failed. Retrying in 5 seconds..."
            sleep 5
        else
            log_message "Error: Failed to update package lists after $max_retries attempts."
            exit 1
        fi
    fi
done

# Install Ansible with retry mechanism
retry_count=0
install_success=false

while [ $retry_count -lt $max_retries ] && [ "$install_success" != "true" ]; do
    log_message "Installing Ansible (attempt $(($retry_count + 1))/$max_retries)..."
    if sudo apt install -y ansible; then
        install_success=true
        log_message "Ansible installed successfully."
    else
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            log_message "Ansible installation failed. Retrying in 5 seconds..."
            sleep 5
        else
            log_message "Error: Failed to install Ansible after $max_retries attempts."
            exit 1
        fi
    fi
done

# Verify Ansible installation
if ! command_exists ansible; then
    log_message "Error: Ansible was not installed correctly."
    exit 1
fi

# Check Ansible version to confirm installation
ansible_version=$(ansible --version | head -n 1)
log_message "Installed $ansible_version"

# Setup Ansible configuration
log_message "Setting up Ansible..."
if ! mkdir -p /etc/ansible /home/ubuntu/ansible; then
    log_message "Error: Failed to create Ansible directories."
    exit 1
fi

# Write configuration files with error checking
if ! echo "${ansible_config}" > /etc/ansible/ansible.cfg; then
    log_message "Error: Failed to write Ansible configuration."
    exit 1
fi

if ! echo "${ansible_inventory}" > /etc/ansible/hosts; then
    log_message "Error: Failed to write Ansible inventory."
    exit 1
fi

if ! echo "${ansible_playbook}" > /home/ubuntu/ansible/install_iis.yml; then
    log_message "Error: Failed to write Ansible playbook."
    exit 1
fi

# Indicate script completion for troubleshooting
touch /tmp/ansible_setup_completed
log_message "Setup completed successfully"