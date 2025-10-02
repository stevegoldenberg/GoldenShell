# GoldenShell

Deploy ephemeral Linux development environments in AWS with Claude Code, GitHub CLI, Warp Terminal, and Tailscale.

## Features

- 🚀 **One-command deployment** to AWS EC2
- 💻 **Pre-configured dev environment** with Claude Code CLI, GitHub CLI, and Warp Terminal
- 🔒 **Secure access** via Tailscale VPN
- 💰 **Cost-optimized** with automatic shutdown after 30 minutes of inactivity
- 🔧 **Fully customizable** Terraform infrastructure

## Prerequisites

1. **AWS Account** with appropriate permissions to create EC2 instances, security groups, and IAM roles
2. **AWS SSH Key Pair** created in your target region
3. **Tailscale Account** with an auth key ([Get one here](https://login.tailscale.com/admin/settings/keys))
4. **Python 3.8+** installed locally
5. **Terraform** installed locally ([Install guide](https://developer.hashicorp.com/terraform/downloads))

## Installation

1. Clone or navigate to this repository:
```bash
cd GoldenShell
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
```

3. Make the CLI executable:
```bash
chmod +x goldenshell.py
```

4. (Optional) Create a symlink for easier access:
```bash
sudo ln -s $(pwd)/goldenshell.py /usr/local/bin/goldenshell
```

## Usage

### Initialize Configuration

Set up your AWS and Tailscale credentials:

```bash
./goldenshell.py init
```

You'll be prompted for:
- AWS Access Key ID
- AWS Secret Access Key
- AWS Region (default: us-east-1)
- Tailscale Auth Key
- AWS SSH Key Pair Name

Configuration is stored in `~/.goldenshell/config.yaml`

### View Configuration

Display your current configuration (with sensitive values masked):

```bash
./goldenshell.py config
```

### Deploy Environment

Deploy a new development instance:

```bash
./goldenshell.py deploy
```

Optional flags:
- `--instance-type t3.large` - Specify EC2 instance type (default: t3.medium)

### Check Status

Check if your instance is running:

```bash
./goldenshell.py status
```

### Get Connection Details

Get SSH connection information:

```bash
./goldenshell.py connect
```

You can connect via:
- Public IP: `ssh ubuntu@<public-ip>`
- Tailscale: `ssh ubuntu@<tailscale-hostname>` (recommended)

### Destroy Environment

Tear down all AWS resources:

```bash
./goldenshell.py destroy
```

## What Gets Installed

The deployed Ubuntu 22.04 instance includes:

- **Claude Code CLI** - AI-powered coding assistant
- **GitHub CLI (gh)** - GitHub command-line interface
- **Warp Terminal** - Modern terminal emulator (requires GUI/X11)
- **Tailscale** - Secure VPN connectivity
- **AWS CLI** - Amazon Web Services CLI
- **Git** - Version control
- **Python 3** - Programming language
- **Build tools** - gcc, make, etc.

## Auto-Shutdown

The instance automatically monitors for inactivity and will shut down (not terminate) after **30 minutes** of:
- No active SSH sessions
- No established network connections (excluding SSH)

The monitoring script runs every 5 minutes via systemd timer. When shut down:
- Instance stops to prevent charges (you only pay for EBS storage)
- Data is preserved on the EBS volume
- Restart via AWS Console or CLI: `aws ec2 start-instances --instance-ids <instance-id>`

## Cost Estimates

Approximate hourly costs (us-east-1):
- **t3.medium**: ~$0.042/hour
- **t3.large**: ~$0.083/hour
- **EBS storage**: ~$0.10/GB/month (30GB default)

With auto-shutdown after 30 minutes, maximum daily cost is ~$0.02 for t3.medium (if used once).

## Architecture

```
┌─────────────────────────────────────────┐
│  Local Machine                          │
│  ┌────────────────┐                     │
│  │ goldenshell.py │ (CLI Tool)          │
│  └────────┬───────┘                     │
│           │                             │
│  ┌────────▼───────┐                     │
│  │ Terraform      │                     │
│  └────────┬───────┘                     │
└───────────┼─────────────────────────────┘
            │
            │ AWS API
            │
┌───────────▼─────────────────────────────┐
│  AWS Cloud                              │
│  ┌────────────────────────────────┐    │
│  │ EC2 Instance (Ubuntu 22.04)    │    │
│  │  - Claude Code CLI             │    │
│  │  - GitHub CLI                  │    │
│  │  - Warp Terminal               │    │
│  │  - Tailscale Client            │    │
│  │  - Auto-shutdown Monitor       │    │
│  └────────────────────────────────┘    │
│           │                             │
│  ┌────────▼───────┐                     │
│  │ Security Group │                     │
│  │  - SSH (22)    │                     │
│  │  - Tailscale   │                     │
│  └────────────────┘                     │
└─────────────────────────────────────────┘
            │
            │ Tailscale VPN
            │
┌───────────▼─────────────────────────────┐
│  Your Tailnet                           │
│  (Secure private network)               │
└─────────────────────────────────────────┘
```

## Terraform Details

Infrastructure components:
- **EC2 Instance**: Ubuntu 22.04 LTS with 30GB gp3 EBS volume
- **Security Group**: SSH (port 22) and Tailscale (port 41641 UDP) access
- **IAM Role**: Permissions for CloudWatch metrics and EC2 stop operations
- **User Data**: Bootstrap script that installs all tools and configures auto-shutdown

To customize the Terraform configuration, edit files in the `terraform/` directory:
- `main.tf` - Main infrastructure configuration
- `variables.tf` - Variable definitions
- `user-data.sh` - Instance initialization script
- `outputs.tf` - Output values

## Troubleshooting

### Instance won't start
- Check AWS service quotas for EC2 instances in your region
- Verify your SSH key pair exists in the target region
- Check AWS credentials are valid

### Can't connect via Tailscale
- Verify Tailscale auth key is valid and hasn't expired
- Check instance logs: `ssh ubuntu@<public-ip>` then `sudo journalctl -u tailscaled`
- Ensure Tailscale is running: `tailscale status`

### Instance shut down unexpectedly
- Check auto-shutdown logs: `sudo journalctl -u goldenshell-idle-monitor.timer`
- Review idle threshold in configuration (default: 30 minutes)
- Restart instance: `aws ec2 start-instances --instance-ids <instance-id>`

### Warp Terminal not working
- Warp requires a GUI environment. For headless Linux, use SSH with X11 forwarding
- Alternative: Use standard terminal emulators (bash, zsh work fine)

### Deployment fails
- Ensure Terraform is installed and in PATH
- Check AWS credentials have sufficient permissions
- Review Terraform logs in the `terraform/` directory

## Security Notes

- Configuration file (`~/.goldenshell/config.yaml`) contains sensitive credentials
- Keep your Tailscale auth keys secure and rotated regularly
- Consider using AWS IAM roles instead of access keys for production use
- Security group allows SSH from anywhere (0.0.0.0/0) - consider restricting to your IP
- Instance has IAM permissions to stop itself - review permissions for your use case

## Contributing

This project is based on concepts from [claudetainer](https://github.com/smithclay/claudetainer).

Feel free to open issues or submit pull requests for improvements!

## License

MIT