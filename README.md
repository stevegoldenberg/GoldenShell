# GoldenShell

**A secure, cost-optimized cloud development environment with Claude Code CLI, GitHub CLI, and Tailscale VPN.**

GoldenShell lets you spin up a Linux development server in AWS that automatically shuts down when you're not using it, saving you money. Access is secured through Tailscale VPN, and everything is managed with simple Terraform commands.

---

## What You Get

When you deploy GoldenShell, you get an Ubuntu 22.04 server with:

- ✅ **Claude Code CLI** - AI-powered coding assistant
- ✅ **GitHub CLI (gh)** - Work with GitHub from the command line
- ✅ **Tailscale VPN** - Secure remote access (no exposed SSH ports!)
- ✅ **Auto-shutdown** - Stops after 30 minutes of inactivity to save money
- ✅ **Daily backups** - Automated EBS snapshots
- ✅ **Cost alerts** - Email notifications when spending approaches your budget

**Monthly Cost Estimate**: ~$10-15/month with auto-shutdown, or ~$30-35/month if running 24/7.

---

## Prerequisites (What You Need Before Starting)

### 1. AWS Account
- Create a free account at [aws.amazon.com](https://aws.amazon.com)
- You'll need a credit card, but AWS offers a free tier

### 2. Tailscale Account
- Create a free account at [tailscale.com](https://tailscale.com)
- Install Tailscale on your computer ([download here](https://tailscale.com/download))

### 3. Software to Install on Your Computer
- **Terraform** - Infrastructure automation tool ([install guide](https://developer.hashicorp.com/terraform/install))
- **AWS CLI** - Amazon's command-line tool ([install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Git** - Version control ([install guide](https://git-scm.com/downloads))

### 4. Check Your Installations
Run these commands to verify everything is installed:
```bash
terraform --version
aws --version
git --version
```

You should see version numbers for each. If you get "command not found", the software isn't installed correctly.

---

## Step-by-Step Setup Guide

### Part 1: Get Your AWS Credentials

1. **Log in to AWS Console** at [console.aws.amazon.com](https://console.aws.amazon.com)

2. **Create an Access Key**:
   - Click your name (top right) → Security credentials
   - Scroll to "Access keys" → Click "Create access key"
   - Choose "Command Line Interface (CLI)"
   - Check the confirmation box → Click "Next"
   - Add description: "GoldenShell" → Click "Create access key"
   - **IMPORTANT**: Copy both the Access Key ID and Secret Access Key (you won't see the secret again!)

3. **Configure AWS CLI**:
   ```bash
   aws configure
   ```

   Enter when prompted:
   - **AWS Access Key ID**: [paste your access key]
   - **AWS Secret Access Key**: [paste your secret key]
   - **Default region name**: `us-east-1` (or your preferred region)
   - **Default output format**: `json`

4. **Create an SSH Key Pair in AWS**:
   ```bash
   # List your key pairs (will be empty if you haven't created one)
   aws ec2 describe-key-pairs

   # Create a new key pair (replace 'goldenshell-key' with your preferred name)
   aws ec2 create-key-pair --key-name goldenshell-key --query 'KeyMaterial' --output text > ~/.ssh/goldenshell-key.pem

   # Set correct permissions
   chmod 600 ~/.ssh/goldenshell-key.pem
   ```

   **Remember this key name** - you'll need it later.

### Part 2: Get Your Tailscale Auth Key

1. **Log in to Tailscale** at [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)

2. **Generate an auth key**:
   - Click "Generate auth key"
   - Check "Reusable" (so you can recreate the instance)
   - Optionally check "Ephemeral" for better security
   - Click "Generate key"
   - **Copy the key** (starts with `tskey-auth-`)

### Part 3: Set Up GoldenShell

1. **Clone or download this repository**:
   ```bash
   cd ~/Code  # or wherever you keep projects
   git clone <repository-url> GoldenShell
   cd GoldenShell
   ```

2. **Set up the Terraform backend** (this stores your infrastructure state securely):
   ```bash
   ./setup-backend.sh
   ```

   This creates an encrypted S3 bucket to store your Terraform state.

   After it completes:
   - Edit `terraform/backend.tf`
   - Uncomment the `backend "s3"` block (remove the `#` symbols)
   - Update the `bucket` name and `region` to match what the script output

3. **Configure your deployment**:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

   Edit `terraform.tfvars` and fill in these values:

   ```hcl
   # AWS region you chose earlier
   aws_region = "us-east-1"

   # The SSH key name you created in Part 1, Step 4
   key_name = "goldenshell-key"

   # The Tailscale auth key you copied in Part 2
   tailscale_auth_key = "tskey-auth-xxxxxxxxxxxxx"

   # Your email for budget alerts
   budget_email_addresses = ["your-email@example.com"]

   # Optional: adjust these if you want
   instance_type = "t3.medium"  # t3.small is cheaper but slower
   monthly_budget_limit = 50     # Alert when you approach $50/month
   ```

### Part 4: Deploy!

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

   This downloads the AWS provider and sets up the backend.

2. **Preview what will be created**:
   ```bash
   terraform plan
   ```

   Review the output. You should see it will create:
   - 1 EC2 instance
   - 1 security group
   - IAM roles and policies
   - CloudWatch alarms
   - Budget alerts
   - And more...

3. **Create everything**:
   ```bash
   terraform apply
   ```

   Type `yes` when prompted.

   This takes 3-5 minutes. When complete, you'll see outputs like:
   ```
   instance_id = "i-0123456789abcdef0"
   public_ip = "3.81.123.45"
   ```

4. **Wait for the instance to finish setup** (about 5 minutes):
   The instance needs time to install all the software. You can check if it's ready:

   ```bash
   # Get the public IP from terraform output
   terraform output public_ip

   # Watch the setup log (only works after Tailscale is connected)
   # We'll use this in the next section
   ```

### Part 5: Connect to Your Instance

1. **Check Tailscale**:
   Open the Tailscale app on your computer. You should see a new device listed (something like `ip-xxx-xxx-xxx-xxx`). This is your GoldenShell instance!

2. **Get the Tailscale hostname**:
   ```bash
   # In Tailscale app, click on the GoldenShell device and copy its name
   # OR use the Tailscale CLI:
   tailscale status
   ```

3. **Connect via SSH**:
   ```bash
   # Replace 'goldenshell-hostname' with your actual Tailscale hostname
   ssh ubuntu@goldenshell-hostname
   ```

   You should see a welcome message!

4. **Verify everything is installed**:
   ```bash
   claude --version
   gh --version
   tailscale status
   ```

---

## Daily Usage

### Starting Work

If your instance is stopped:
```bash
# Start the instance
aws ec2 start-instances --instance-ids $(cd terraform && terraform output -raw instance_id)

# Wait about 1 minute for it to boot

# Connect via Tailscale
ssh ubuntu@your-goldenshell-hostname
```

### Stopping Work

The instance will automatically stop after 30 minutes of inactivity. Or manually stop it:

```bash
# From your local machine:
aws ec2 stop-instances --instance-ids $(cd terraform && terraform output -raw instance_id)
```

### Checking Costs

```bash
# View current month's costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=TAG,Key=Project

# Or check the AWS Console:
# https://console.aws.amazon.com/cost-management/home#/cost-explorer
```

---

## Troubleshooting

### "I can't connect via Tailscale"

1. Check if Tailscale is running on your computer
2. Check if the instance appears in Tailscale app/dashboard
3. Try SSHing to the public IP temporarily (you'll need to add port 22 to the security group - see below)
4. Check the setup logs:
   ```bash
   ssh ubuntu@<public-ip>
   sudo tail -100 /var/log/user-data.log
   ```

### "terraform apply" fails with 'InvalidKeyPair.NotFound'

Your SSH key name doesn't match. Check:
```bash
aws ec2 describe-key-pairs
```

Update `key_name` in `terraform.tfvars` to match an existing key pair.

### Instance keeps shutting down

The auto-shutdown script detects idle time. If you're running long processes:

```bash
# Disable auto-shutdown temporarily
sudo systemctl stop goldenshell-idle-monitor.timer

# Re-enable when done
sudo systemctl start goldenshell-idle-monitor.timer
```

### Need to access via regular SSH (emergency fallback)

If Tailscale isn't working and you need emergency access:

1. Add SSH rule to security group:
   ```bash
   cd terraform

   # Get your public IP
   MY_IP=$(curl -s https://checkip.amazonaws.com)

   # Add temporary SSH rule
   aws ec2 authorize-security-group-ingress \
     --group-id $(terraform output -raw security_group_id) \
     --protocol tcp \
     --port 22 \
     --cidr $MY_IP/32
   ```

2. Connect:
   ```bash
   ssh -i ~/.ssh/goldenshell-key.pem ubuntu@$(terraform output -raw public_ip)
   ```

3. **IMPORTANT**: Remove the SSH rule when done:
   ```bash
   aws ec2 revoke-security-group-ingress \
     --group-id $(terraform output -raw security_group_id) \
     --protocol tcp \
     --port 22 \
     --cidr $MY_IP/32
   ```

### Budget alerts aren't working

1. Check your email for AWS Budget confirmation (you must confirm the subscription)
2. Verify email in `terraform.tfvars`:
   ```hcl
   budget_email_addresses = ["your-actual-email@example.com"]
   ```
3. Re-apply:
   ```bash
   terraform apply
   ```

---

## Updating the Instance

### Updating Installed Software

SSH into the instance and run:
```bash
sudo apt update
sudo apt upgrade -y
```

### Changing Terraform Configuration

1. Edit `terraform/terraform.tfvars`
2. Run:
   ```bash
   cd terraform
   terraform plan   # Review changes
   terraform apply  # Apply changes
   ```

---

## Destroying Everything

When you're completely done and want to remove everything:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted.

**Note**: This deletes:
- ✅ The EC2 instance
- ✅ EBS volume (your data!)
- ✅ Security groups
- ✅ IAM roles
- ✅ CloudWatch alarms
- ❌ EBS snapshots (manual deletion required)
- ❌ S3 backend bucket (manual deletion required)

To delete snapshots:
```bash
# List snapshots
aws ec2 describe-snapshots --owner-ids self --filters "Name=tag:Project,Values=GoldenShell"

# Delete each snapshot
aws ec2 delete-snapshot --snapshot-id snap-xxxxx
```

To delete the backend bucket:
```bash
# List buckets
aws s3 ls | grep goldenshell

# Delete bucket (after emptying it)
aws s3 rb s3://goldenshell-terraform-state-xxxxx --force
```

---

## Security Notes

- 🔒 **No public SSH**: SSH access is only via Tailscale VPN
- 🔒 **Encrypted storage**: EBS volumes are encrypted at rest
- 🔒 **Secrets in SSM**: Tailscale key stored securely in AWS Parameter Store
- 🔒 **Minimal IAM permissions**: Instance can only stop itself and write CloudWatch metrics
- 🔒 **Budget protection**: Alerts prevent surprise bills

For more details, see [SECURITY.md](SECURITY.md)

---

## Getting Help

- **AWS Issues**: Check [AWS Documentation](https://docs.aws.amazon.com/)
- **Terraform Issues**: Check [Terraform Docs](https://www.terraform.io/docs)
- **Tailscale Issues**: Check [Tailscale Docs](https://tailscale.com/kb/)
- **This Project**: Open an issue on GitHub

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

## Advanced Topics

### Using a Different AWS Region

Edit `terraform/terraform.tfvars`:
```hcl
aws_region = "us-west-2"  # or any AWS region
```

Then run `terraform apply`.

### Increasing Storage Size

Edit `terraform/terraform.tfvars`:
```hcl
ebs_volume_size = 50  # increased from 30GB to 50GB
```

Then run `terraform apply`.

**Note**: You can only increase size, not decrease.

### Disabling Auto-Shutdown

Edit `terraform/terraform.tfvars`:
```hcl
auto_shutdown_minutes = 0  # 0 = disabled
```

Or set a longer timeout:
```hcl
auto_shutdown_minutes = 120  # 2 hours
```

---

## What's Next?

Now that your GoldenShell instance is running:

1. **Install your dev tools**: Python, Node.js, Docker, etc.
2. **Clone your repositories**: Use GitHub CLI (`gh repo clone ...`)
3. **Configure your shell**: Install oh-my-zsh, configure vim, etc.
4. **Use Claude Code**: Run `claude` to start the AI coding assistant

Happy coding! 🚀
