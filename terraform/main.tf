terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get VPC - either use specified vpc_id or find default
data "aws_vpc" "selected" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id == "" ? true : null
}

# Get subnet - either use specified subnet_id or find default in the VPC
data "aws_subnet" "selected" {
  count             = var.subnet_id != "" ? 1 : 0
  id                = var.subnet_id
}

data "aws_subnets" "available" {
  count = var.subnet_id == "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "goldenshell" {
  name        = "goldenshell-sg"
  description = "Security group for GoldenShell development instance"
  vpc_id      = data.aws_vpc.selected.id

  # Tailscale UDP - only port needed since Tailscale handles SSH
  ingress {
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Tailscale"
  }

  # Mosh UDP ports (for mobile shell connections)
  ingress {
    from_port   = 60000
    to_port     = 61000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Mosh (mobile shell)"
  }

  # SSH access for emergency access (can be restricted to specific IPs via variable)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
    description = "SSH access"
  }

  # Web terminal (ttyd) - HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for web terminal"
  }

  # Web terminal (ttyd) - HTTP (development/testing)
  ingress {
    from_port   = 7681
    to_port     = 7681
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for web terminal (ttyd)"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "goldenshell-sg"
    Project     = "GoldenShell"
    ManagedBy   = "Terraform"
  }
}

# IAM Role for EC2 instance (for CloudWatch and auto-shutdown)
resource "aws_iam_role" "goldenshell" {
  name = "goldenshell-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "goldenshell-instance-role"
  }
}

# IAM Policy for CloudWatch metrics and EC2 operations
resource "aws_iam_role_policy" "goldenshell_cloudwatch" {
  name = "goldenshell-cloudwatch-policy"
  role = aws_iam_role.goldenshell.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "GoldenShell"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:StopInstances"
        ]
        Resource = "arn:aws:ec2:${var.aws_region}:*:instance/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Project" = "GoldenShell"
          }
        }
      }
    ]
  })
}

# IAM Policy for SSM Parameter Store (Tailscale key)
resource "aws_iam_role_policy" "goldenshell_ssm" {
  name = "goldenshell-ssm-policy"
  role = aws_iam_role.goldenshell.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/goldenshell/*"
      }
    ]
  })
}

# Attach AWS managed policy for Systems Manager access
resource "aws_iam_role_policy_attachment" "goldenshell_ssm_managed" {
  role       = aws_iam_role.goldenshell.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "goldenshell" {
  name = "goldenshell-instance-profile"
  role = aws_iam_role.goldenshell.name
}

# SSM Parameter for Tailscale Auth Key (secure storage)
resource "aws_ssm_parameter" "tailscale_auth_key" {
  name        = "/goldenshell/tailscale-auth-key"
  description = "Tailscale authentication key for GoldenShell instances"
  type        = "SecureString"
  value       = var.tailscale_auth_key

  tags = {
    Name      = "goldenshell-tailscale-key"
    Project   = "GoldenShell"
    ManagedBy = "Terraform"
  }
}

# EC2 Instance
resource "aws_instance" "goldenshell" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = var.key_name
  subnet_id             = var.subnet_id != "" ? var.subnet_id : (length(data.aws_subnets.available) > 0 ? data.aws_subnets.available[0].ids[0] : null)
  vpc_security_group_ids = [aws_security_group.goldenshell.id]
  iam_instance_profile   = aws_iam_instance_profile.goldenshell.name
  associate_public_ip_address = true

  # Enforce IMDSv2 for improved security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    aws_region             = var.aws_region
    auto_shutdown_minutes  = var.auto_shutdown_minutes
  })

  root_block_device {
    volume_size           = var.ebs_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name      = "${var.instance_name}-root"
      Project   = "GoldenShell"
      ManagedBy = "Terraform"
    }
  }

  tags = {
    Name      = var.instance_name
    Project   = "GoldenShell"
    ManagedBy = "Terraform"
    AutoShutdown = "enabled"
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Data Lifecycle Manager (DLM) for automated EBS snapshots
resource "aws_dlm_lifecycle_policy" "goldenshell_backups" {
  count              = var.enable_backups ? 1 : 0
  description        = "GoldenShell EBS snapshot policy"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "Daily snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }

      retain_rule {
        count = var.backup_retention_days
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        Project         = "GoldenShell"
      }

      copy_tags = true
    }

    target_tags = {
      Project = "GoldenShell"
    }
  }

  tags = {
    Name      = "goldenshell-backup-policy"
    Project   = "GoldenShell"
    ManagedBy = "Terraform"
  }
}

# IAM role for DLM
resource "aws_iam_role" "dlm_lifecycle_role" {
  count = var.enable_backups ? 1 : 0
  name  = "goldenshell-dlm-lifecycle-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "goldenshell-dlm-role"
    Project   = "GoldenShell"
    ManagedBy = "Terraform"
  }
}

# IAM policy for DLM
resource "aws_iam_role_policy" "dlm_lifecycle" {
  count = var.enable_backups ? 1 : 0
  name  = "goldenshell-dlm-lifecycle-policy"
  role  = aws_iam_role.dlm_lifecycle_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*::snapshot/*"
      }
    ]
  })
}

# CloudWatch Alarm for high CPU usage
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "goldenshell-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when CPU exceeds 80%"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = aws_instance.goldenshell.id
  }

  tags = {
    Name      = "goldenshell-high-cpu-alarm"
    Project   = "GoldenShell"
    ManagedBy = "Terraform"
  }
}

# CloudWatch Alarm for instance status check failures
resource "aws_cloudwatch_metric_alarm" "instance_health" {
  alarm_name          = "goldenshell-instance-health"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alert when instance status checks fail"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = aws_instance.goldenshell.id
  }

  tags = {
    Name      = "goldenshell-health-alarm"
    Project   = "GoldenShell"
    ManagedBy = "Terraform"
  }
}

# AWS Budget for cost monitoring
resource "aws_budgets_budget" "goldenshell_monthly" {
  name              = "goldenshell-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2025-10-01_00:00"

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Project$GoldenShell"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.budget_email_addresses
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.budget_email_addresses
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_email_addresses = var.budget_email_addresses
  }
}