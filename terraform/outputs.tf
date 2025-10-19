output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.goldenshell.id
}

output "instance_name" {
  description = "Name tag of the EC2 instance"
  value       = aws_instance.goldenshell.tags["Name"]
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.goldenshell.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.goldenshell.private_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.goldenshell.id
}

output "tailscale_connection_info" {
  description = "Connection information via Tailscale (recommended)"
  value       = "Once instance is running, connect via Tailscale SSH. Check 'tailscale status' on the instance for the hostname."
}

output "start_instance_command" {
  description = "Command to start the instance if stopped"
  value       = "aws ec2 start-instances --instance-ids ${aws_instance.goldenshell.id} --region ${var.aws_region}"
}

output "stop_instance_command" {
  description = "Command to stop the instance"
  value       = "aws ec2 stop-instances --instance-ids ${aws_instance.goldenshell.id} --region ${var.aws_region}"
}

output "view_logs_command" {
  description = "Command to view user-data logs after SSH"
  value       = "sudo tail -f /var/log/user-data.log"
}

output "ssm_parameter_name" {
  description = "SSM Parameter Store path for Tailscale auth key"
  value       = aws_ssm_parameter.tailscale_auth_key.name
}

output "backup_policy_id" {
  description = "DLM backup policy ID (if backups enabled)"
  value       = var.enable_backups ? aws_dlm_lifecycle_policy.goldenshell_backups[0].id : "Backups not enabled"
}

output "web_terminal_url" {
  description = "Web terminal URL (HTTP)"
  value       = "http://${aws_instance.goldenshell.public_ip}:7681"
}

output "web_terminal_password_command" {
  description = "Command to retrieve web terminal password"
  value       = "aws ssm get-parameter --name /goldenshell/ttyd-password --with-decryption --query Parameter.Value --output text --region ${var.aws_region}"
}