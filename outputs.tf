# Output the public IP of the Windows VM
output "windows_server_public_ip" {
  value       = aws_instance.windows_server.public_ip
  description = "Public IP address of the Windows server"
}

# Output the private IP of the Ansible Control Node
output "ansible_control_private_ip" {
  value       = aws_instance.ansible_control.private_ip
  description = "Private IP address of the Ansible control node"
}