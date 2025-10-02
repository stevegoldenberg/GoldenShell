variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
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