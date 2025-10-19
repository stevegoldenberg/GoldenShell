# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GoldenShell is a Python CLI tool for deploying ephemeral Linux development environments in AWS EC2. It automates the setup of a fully-configured Ubuntu instance with Claude Code CLI, GitHub CLI, Warp Terminal, and Tailscale VPN, complete with auto-shutdown after inactivity.

## Core Commands

### Installation & Setup
```bash
# Install dependencies
pip install -r requirements.txt

# Make CLI executable
chmod +x goldenshell.py
```

### Interactive Mode (Default)
Running goldenshell.py without any command launches an interactive menu:
```bash
./goldenshell.py
```

This displays a numbered menu with options for:
1. Initialize configuration (first-time setup)
2. View configuration
3. Deploy new instance (prompts for instance type)
4. Check instance status
5. Start instance
6. Stop instance
7. Resize instance
8. SSH to instance
9. Destroy environment
0. Exit

The menu shows configuration status and last deployment info, and loops until you choose to exit.

### Direct Command Mode
All commands can still be run directly without the interactive menu:

```bash
# Initialize configuration (required before first use)
./goldenshell.py init

# View current configuration (with masked credentials)
./goldenshell.py config

# Deploy instance (default: t3.medium)
./goldenshell.py deploy
./goldenshell.py deploy --instance-type t3.large

# Check instance status (includes connection details and web terminal password)
./goldenshell.py status

# Start stopped instance
./goldenshell.py start

# Stop running instance
./goldenshell.py stop

# Resize instance type
./goldenshell.py resize

# SSH into instance (via Tailscale or public IP)
./goldenshell.py ssh
./goldenshell.py ssh --use-public-ip
./goldenshell.py ssh --tailscale-hostname <hostname>

# Destroy environment
./goldenshell.py destroy
```

## Architecture

### Python CLI Layer (`goldenshell.py`)
- Built with Click framework for command-line interface
- Configuration stored in `~/.goldenshell/config.yaml`
- Uses `python-terraform` library to orchestrate Terraform operations
- Manages AWS credentials via environment variables for Terraform
- Interactive menu system as default behavior (lines 63-122)

### Key Components

**Config Class (lines 19-61)**
- Handles YAML configuration persistence
- Masks sensitive values (AWS keys, Tailscale auth key) in display output
- Stores: AWS credentials, region, SSH key name, Tailscale auth key, last deployment info

**Interactive Menu (lines 63-122)**
- Default behavior when no command specified
- Shows configuration status and last deployment info
- Loops continuously until user exits
- Invokes Click commands programmatically via Context
- Prompts for instance type when deploying

**CLI Commands**
- `init`: Prompts for and saves AWS/Tailscale credentials
- `config`: Displays current configuration with masked sensitive values
- `deploy`: Runs Terraform apply with configured variables
- `status`: Uses boto3 to query EC2 instance state and retrieves web terminal password from SSM
- `start`: Starts a stopped EC2 instance
- `stop`: Stops a running EC2 instance
- `resize`: Changes instance type (requires instance restart)
- `ssh`: Connects to instance via SSH (Tailscale or public IP)
- `destroy`: Runs Terraform destroy with auto-approval (requires confirmation)

### Terraform Infrastructure (`terraform/`)

**main.tf**
- Uses latest Ubuntu 22.04 AMI (Canonical owner ID: 099720109477)
- Security group: SSH (port 22) and Tailscale UDP (port 41641)
- IAM role with permissions for CloudWatch metrics and EC2 stop operations
- Instance profile attached to EC2 instance for auto-shutdown capability
- User data templating for Tailscale auth key and shutdown timeout

**variables.tf**
- `aws_region`: Default us-east-1
- `instance_type`: Default t3.medium
- `key_name`: Required - AWS SSH key pair name
- `tailscale_auth_key`: Sensitive - for Tailscale VPN authentication
- `instance_name`: Default "goldenshell-dev"
- `auto_shutdown_minutes`: Default 30 minutes

**user-data.sh**
- Bootstrap script that runs on instance first boot
- Installs: GitHub CLI, Claude Code CLI, Warp Terminal, Tailscale, AWS CLI
- Creates systemd service + timer for idle monitoring (checks every 5 minutes)
- Idle detection logic: checks active SSH sessions and network connections
- Auto-shutdown script at `/usr/local/bin/check-idle-shutdown.sh`

## Configuration Flow

1. User runs `./goldenshell.py init` → credentials saved to `~/.goldenshell/config.yaml`
2. User runs `./goldenshell.py deploy` → Python reads config, sets AWS env vars, calls Terraform
3. Terraform reads variables from Python CLI, applies infrastructure
4. Terraform outputs (instance_id, public_ip) returned to Python CLI
5. Python saves deployment info back to config.yaml for status/connect commands

## Auto-Shutdown Mechanism

The instance monitors itself for inactivity:
- Systemd timer runs `/usr/local/bin/check-idle-shutdown.sh` every 5 minutes
- Script checks for active SSH sessions and established network connections (excluding SSH)
- Tracks last activity timestamp in `/tmp/last-activity`
- If idle for > `auto_shutdown_minutes`, calls `aws ec2 stop-instances` on itself
- Instance IAM role grants permission to stop itself via policy in main.tf:92-118

## Dependencies

**Python packages (requirements.txt)**
- `click>=8.1.0` - CLI framework
- `boto3>=1.28.0` - AWS SDK (for status command)
- `pyyaml>=6.0.0` - Configuration file handling
- `python-terraform>=0.10.1` - Terraform wrapper

**External requirements**
- Terraform 1.0+ (must be installed and in PATH)
- AWS CLI (installed on remote instance, not required locally)
- Valid AWS credentials with EC2/IAM permissions
- Tailscale account with auth key

## Security Considerations

- Configuration file (`~/.goldenshell/config.yaml`) contains plaintext AWS credentials and Tailscale auth key
  - File permissions automatically set to 600 (owner read/write only) for security
- Web terminal password is randomly generated and stored in AWS SSM Parameter Store (encrypted)
  - Retrieved dynamically on instance boot and by the `status` command
- Security group rules:
  - SSH from configurable CIDRs (default 0.0.0.0/0 - can be restricted)
  - Tailscale UDP port 41641 for VPN
  - HTTP port 7681 for web terminal (consider restricting to trusted IPs)
- Instance has IAM permissions to:
  - Stop itself (for auto-shutdown)
  - Read SSM parameters for Tailscale and web terminal credentials
  - Write CloudWatch metrics
- Lifecycle policy ignores user_data changes to prevent instance replacement
- Terraform state file will contain sensitive variables - handle with care

## Modifying Infrastructure

To customize the deployed environment:
- Edit `terraform/variables.tf` to change defaults
- Modify `terraform/user-data.sh` to add/remove installed tools
- Update `terraform/main.tf` to adjust security group rules, instance settings, or IAM permissions
- Changes to user-data.sh require instance replacement (lifecycle policy ignores changes)

## Testing Locally

To test Terraform without deploying:
```bash
cd terraform/
terraform init
terraform plan \
  -var="aws_region=us-east-1" \
  -var="key_name=your-key" \
  -var="tailscale_auth_key=your-key"
```
