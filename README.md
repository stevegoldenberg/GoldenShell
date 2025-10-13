# GoldenShell

**A secure, cost-optimized cloud development environment with Claude Code CLI, tmux, mosh, and Tailscale VPN.**

GoldenShell lets you spin up a Linux development server in AWS that automatically shuts down when you're not using it. Access is secured through Tailscale VPN, and everything is managed with simple commands.

**Monthly Cost**: ~$10-15/month with auto-shutdown, or ~$30-35/month if running 24/7.

---

## Daily Usage (Quick Reference)

### Managing Your Instance

Check instance status:
```bash
cd ~/Code/GoldenShell
python3 goldenshell.py status
```

Start the instance:
```bash
python3 goldenshell.py start
```

Stop the instance:
```bash
python3 goldenshell.py stop
```

### Connecting to Your Instance

#### Option 1: SSH via Tailscale (Recommended)

Find your Tailscale hostname at [https://login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines), then:

```bash
ssh ubuntu@<your-tailscale-hostname>
```

#### Option 2: Mosh (Survives Network Drops)

```bash
mosh ubuntu@<your-tailscale-hostname>
```

Mosh is perfect for mobile connections or unstable networks.

#### Option 3: Web Terminal

Access via browser:
```
http://<instance-public-ip>:7681
```
- Username: `ubuntu`
- Password: `GoldenShell2025!`

### Persistent Sessions with tmux

Start tmux for persistent sessions that survive disconnections:

```bash
# Start a new tmux session
tmux

# Detach from session (keeps running)
# Press: Ctrl+a, then d

# List running sessions
tmux ls

# Reattach to session
tmux attach

# Split panes
# Horizontal: Ctrl+a, then |
# Vertical: Ctrl+a, then -
```

Your tmux sessions keep running even if you disconnect!

### Adding New Devices/Terminals

#### iOS/Mobile Terminal Apps

1. Install a terminal app (Termius, Blink, etc.)
2. Connect to Tailscale on your iOS device
3. In the terminal app, add SSH connection:
   - Host: `<your-tailscale-hostname>`
   - User: `ubuntu`
   - Authentication: Tailscale SSH (passwordless)

#### Alternative: Use Mosh from Mobile

```bash
mosh ubuntu@<your-tailscale-hostname>
```

Mosh works great on mobile networks with frequent reconnections.

### Auto-Shutdown Management

Check auto-shutdown status:
```bash
systemctl status goldenshell-idle-monitor.timer
```

View auto-shutdown logs:
```bash
sudo journalctl -u goldenshell-idle-monitor.service -f
```

Disable auto-shutdown temporarily:
```bash
sudo systemctl stop goldenshell-idle-monitor.timer
```

Re-enable auto-shutdown:
```bash
sudo systemctl start goldenshell-idle-monitor.timer
```

Check last activity time:
```bash
cat /tmp/last-activity
```

### Changing Instance Type

Change to a more/less powerful instance:

```bash
python3 goldenshell.py resize
```

This shows an interactive menu with common instance types and pricing.

---

## What's Installed

Your instance comes with:
- ✅ **Claude Code CLI** - AI-powered coding assistant (auto-updates daily)
- ✅ **GitHub CLI (gh)** - Work with GitHub from the command line
- ✅ **tmux** - Persistent terminal sessions
- ✅ **mosh** - Mobile shell (survives network drops)
- ✅ **Tailscale VPN** - Secure remote access (no exposed SSH ports!)
- ✅ **Zellij** - Modern terminal multiplexer (for web terminal)
- ✅ **Auto-shutdown** - Stops after 30 minutes of inactivity
- ✅ **Daily backups** - Automated EBS snapshots
- ✅ **Cost alerts** - Email notifications when spending approaches budget

---

## Destroying the Infrastructure

### Complete Teardown

When you're done and want to delete everything:

```bash
cd ~/Code/GoldenShell
python3 goldenshell.py destroy
```

Or using Terraform directly:

```bash
cd ~/Code/GoldenShell/terraform
terraform destroy
```

Type `yes` when prompted.

### What Gets Deleted

- ✅ EC2 instance
- ✅ EBS volume (your data!)
- ✅ Security groups
- ✅ IAM roles and policies
- ✅ CloudWatch alarms
- ✅ Budget alerts
- ✅ SSM parameters

### Manual Cleanup Required

Some resources must be deleted manually:

**EBS Snapshots:**
```bash
# List snapshots
aws ec2 describe-snapshots --owner-ids self --filters "Name=tag:Project,Values=GoldenShell"

# Delete each snapshot
aws ec2 delete-snapshot --snapshot-id snap-xxxxx
```

**S3 Backend Bucket (if you set one up):**
```bash
# List buckets
aws s3 ls | grep goldenshell

# Empty and delete bucket
aws s3 rm s3://goldenshell-terraform-state-xxxxx --recursive
aws s3 rb s3://goldenshell-terraform-state-xxxxx
```

---

## Initial Setup Guide

*This section is only needed for first-time setup.*

### Prerequisites

Before starting, you need:

1. **AWS Account** - [aws.amazon.com](https://aws.amazon.com)
2. **Tailscale Account** - [tailscale.com](https://tailscale.com)
3. **Software on your computer:**
   - Terraform ([install guide](https://developer.hashicorp.com/terraform/install))
   - AWS CLI ([install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
   - Git ([install guide](https://git-scm.com/downloads))

Verify installations:
```bash
terraform --version
aws --version
git --version
```

### Step 1: AWS Setup

1. **Get AWS Credentials:**
   - Log in to [AWS Console](https://console.aws.amazon.com)
   - Click your name (top right) → Security credentials
   - Scroll to "Access keys" → Create access key
   - Choose "Command Line Interface (CLI)"
   - Copy both Access Key ID and Secret Access Key

2. **Configure AWS CLI:**
   ```bash
   aws configure
   ```
   Enter your access key, secret key, region (e.g., `us-east-1`), and output format (`json`).

3. **Create SSH Key Pair:**
   ```bash
   aws ec2 create-key-pair --key-name goldenshell-key \
     --query 'KeyMaterial' --output text > ~/.ssh/goldenshell-key.pem

   chmod 600 ~/.ssh/goldenshell-key.pem
   ```

### Step 2: Tailscale Setup

1. Log in to [Tailscale Admin](https://login.tailscale.com/admin/settings/keys)
2. Click "Generate auth key"
3. Check "Reusable" (so you can recreate the instance)
4. Copy the key (starts with `tskey-auth-`)

### Step 3: Deploy GoldenShell

1. **Clone the repository:**
   ```bash
   cd ~/Code
   git clone <repository-url> GoldenShell
   cd GoldenShell
   ```

2. **Optional: Set up S3 backend** (for team use):
   ```bash
   ./setup-backend.sh
   ```
   Then edit `terraform/backend.tf` and uncomment the S3 backend block.

3. **Configure deployment:**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

   Edit `terraform.tfvars`:
   ```hcl
   aws_region = "us-east-1"
   key_name = "goldenshell-key"
   tailscale_auth_key = "tskey-auth-xxxxxxxxxxxxx"
   budget_email_addresses = ["your-email@example.com"]

   # Optional customization
   instance_type = "t3.medium"
   monthly_budget_limit = 50
   auto_shutdown_minutes = 30
   ```

4. **Deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   Type `yes` when prompted. Wait 3-5 minutes for deployment to complete.

5. **Wait for setup** (about 5 more minutes):
   The instance installs software on first boot. Check progress:
   ```bash
   # Get Tailscale hostname from Tailscale admin panel, then:
   ssh ubuntu@<tailscale-hostname>
   sudo tail -f /var/log/user-data.log
   ```

---

## Troubleshooting

### Can't Connect via Tailscale

1. Check if Tailscale is running on your computer
2. Verify the instance appears in Tailscale admin panel
3. Try connecting via public IP temporarily (requires adding SSH to security group)

### Instance Keeps Shutting Down

The auto-shutdown script detects idle time. To disable temporarily:

```bash
sudo systemctl stop goldenshell-idle-monitor.timer
```

Re-enable when done:
```bash
sudo systemctl start goldenshell-idle-monitor.timer
```

### Emergency SSH Access (Tailscale Not Working)

Add temporary SSH access:

```bash
cd ~/Code/GoldenShell/terraform

# Get your public IP
MY_IP=$(curl -s https://checkip.amazonaws.com)

# Add SSH rule
aws ec2 authorize-security-group-ingress \
  --group-id $(terraform output -raw security_group_id) \
  --protocol tcp --port 22 --cidr $MY_IP/32

# Connect
ssh -i ~/.ssh/goldenshell-key.pem ubuntu@$(terraform output -raw public_ip)

# IMPORTANT: Remove SSH rule when done
aws ec2 revoke-security-group-ingress \
  --group-id $(terraform output -raw security_group_id) \
  --protocol tcp --port 22 --cidr $MY_IP/32
```

### Budget Alerts Not Working

1. Check your email for AWS Budget confirmation (you must confirm the subscription)
2. Verify email in `terraform.tfvars`
3. Run `terraform apply` again

---

## Advanced Configuration

### Change AWS Region

Edit `terraform/terraform.tfvars`:
```hcl
aws_region = "us-west-2"
```

Then run `terraform apply`.

### Increase Storage Size

Edit `terraform/terraform.tfvars`:
```hcl
ebs_volume_size = 50  # increased from 30GB
```

Then run `terraform apply`. (You can only increase, not decrease)

### Disable Auto-Shutdown

Edit `terraform/terraform.tfvars`:
```hcl
auto_shutdown_minutes = 0  # 0 = disabled
```

Or set a longer timeout:
```hcl
auto_shutdown_minutes = 120  # 2 hours
```

Then run `terraform apply`.

---

## Security Features

- 🔒 **No public SSH**: SSH access only via Tailscale VPN
- 🔒 **Encrypted storage**: EBS volumes encrypted at rest
- 🔒 **Secrets in SSM**: Tailscale key stored securely in AWS Parameter Store
- 🔒 **Minimal IAM permissions**: Instance can only stop itself and write CloudWatch metrics
- 🔒 **Budget protection**: Alerts prevent surprise bills

For more details, see [SECURITY.md](SECURITY.md)

---

## Cost Breakdown

Approximate costs in `us-east-1`:

| Resource | Cost |
|----------|------|
| t3.medium instance (running) | ~$0.042/hour (~$30/month if 24/7) |
| t3.medium with auto-shutdown | ~$0.50-1.50/day (~$15-45/month) |
| EBS storage (30GB) | ~$3/month |
| EBS snapshots (7 days) | ~$0.05/GB/month (~$1.50/month) |
| Data transfer out | First 100GB free, then $0.09/GB |
| **Typical monthly total** | **$10-20/month with auto-shutdown** |

**Pro tip**: Use `t3.small` instead of `t3.medium` to cut instance costs in half!

---

## Getting Help

- **AWS Issues**: [AWS Documentation](https://docs.aws.amazon.com/)
- **Terraform Issues**: [Terraform Docs](https://www.terraform.io/docs)
- **Tailscale Issues**: [Tailscale Docs](https://tailscale.com/kb/)
- **This Project**: Open an issue on GitHub

---

## What's Next?

Now that your GoldenShell instance is running:

1. **Install your dev tools**: Python, Node.js, Docker, etc.
2. **Clone your repositories**: Use GitHub CLI (`gh repo clone ...`)
3. **Configure your shell**: Install oh-my-zsh, configure vim, etc.
4. **Use Claude Code**: Run `claude` to start the AI coding assistant
5. **Set up tmux**: Create persistent sessions for long-running tasks

Happy coding! 🚀
