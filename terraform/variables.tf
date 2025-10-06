variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID to deploy resources into (leave empty to use default VPC)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID to launch instance in (leave empty to use default subnet)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "AWS SSH key pair name"
  type        = string
}

variable "tailscale_auth_key" {
  description = "Tailscale authentication key"
  type        = string
  sensitive   = true
}

variable "instance_name" {
  description = "Name tag for the instance"
  type        = string
  default     = "goldenshell-dev"
}

variable "auto_shutdown_minutes" {
  description = "Minutes of inactivity before auto-shutdown"
  type        = number
  default     = 30
}

variable "ebs_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 30
}

variable "enable_backups" {
  description = "Enable automated EBS snapshots"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain EBS snapshots"
  type        = number
  default     = 7
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms (optional)"
  type        = string
  default     = ""
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD for cost alerts"
  type        = number
  default     = 50
}

variable "budget_email_addresses" {
  description = "Email addresses to receive budget alerts"
  type        = list(string)
  default     = []
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to the instance (use [\"0.0.0.0/0\"] for anywhere or restrict to your IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ttyd_password" {
  description = "Password for web terminal (ttyd) access"
  type        = string
  sensitive   = true
  default     = ""
}