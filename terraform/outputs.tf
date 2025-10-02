output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.goldenshell.id
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