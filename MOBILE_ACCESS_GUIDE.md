# Mobile Access Guide - iPhone Edition

## Overview

This guide shows you how to access your GoldenShell development environment from an iPhone using the Termius app with Mosh protocol over Tailscale VPN. This setup provides a robust, mobile-friendly terminal experience that survives network changes and works seamlessly on cellular networks.

**Key Benefits:**
- Access Claude Code CLI from anywhere on your iPhone
- Persistent sessions that survive network roaming (WiFi to cellular transitions)
- Low latency and instant character feedback via Mosh
- Mobile-optimized terminal multiplexer (Zellij) with simplified UI
- Secure private network access via Tailscale (no exposed SSH ports)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setup Methods](#setup-methods)
   - [Method A: Tailscale SSH (Recommended)](#method-a-tailscale-ssh-recommended)
   - [Method B: Traditional SSH with Private Key](#method-b-traditional-ssh-with-private-key)
3. [SSH Key Management (Method B Only)](#ssh-key-management-method-b-only)
4. [Connection Instructions](#connection-instructions)
5. [Mobile Workflow Optimization](#mobile-workflow-optimization)
6. [Security Considerations](#security-considerations)
7. [Quick Start Checklist](#quick-start-checklist)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### On Your Mac (Before Deploying)

1. **Tailscale Account**
   - Sign up at https://tailscale.com if you don't have an account
   - Generate an auth key from Tailscale admin console
   - This key is used during GoldenShell initialization

2. **AWS Account**
   - Active AWS account with EC2 permissions
   - AWS Access Key ID and Secret Access Key
   - SSH key pair created in AWS (EC2 > Key Pairs)

3. **GoldenShell Deployed**
   - Run `./goldenshell.py init` to configure credentials
   - Run `./goldenshell.py deploy` to create the instance
   - Note the instance's public IP from deployment output

### On Your iPhone

1. **Tailscale App** (Free)
   - Download from App Store: https://apps.apple.com/us/app/tailscale/id1470499037
   - Sign in with the same Tailscale account used on Mac
   - Ensure the VPN is connected (blue toggle in app)

2. **Termius App** (Free/Premium)
   - Download from App Store: https://apps.apple.com/us/app/termius-ssh-client/id549039908
   - Free version works fine for basic use
   - Premium ($10/month) adds features like port forwarding, SFTP

---

## Setup Methods

### Method A: Tailscale SSH (Recommended)

**Why This Method is Best:**
- No private key management needed on iPhone
- Tailscale handles authentication via your account
- Most secure and simplest approach
- Works seamlessly across devices

**How It Works:**
GoldenShell automatically enables Tailscale SSH with the `--ssh` flag (line 164 in user-data.sh). This means Tailscale acts as your SSH authentication layer, eliminating the need to manage private keys.

**Requirements:**
- Tailscale app installed on iPhone
- Logged into same Tailscale account
- Instance deployed with GoldenShell (Tailscale SSH is auto-enabled)

**Connection Process:**
1. Find your instance's Tailscale hostname in the Tailscale admin console
2. Use that hostname in Termius to connect
3. No password or key required - Tailscale handles auth

**Finding Your Tailscale Hostname:**

On your Mac (after deploying):
```bash
# SSH into the instance first
./goldenshell.py ssh

# Then run this command on the instance:
tailscale status
```

You'll see output like:
```
100.64.1.23   goldenshell-dev       ubuntu@      linux   -
100.64.1.45   steve-macbook        steve@       macOS   -
```

The Tailscale hostname is: `goldenshell-dev` (or whatever appears in the second column)

**Alternative:** Check the Tailscale admin console at https://login.tailscale.com/admin/machines

---

### Method B: Traditional SSH with Private Key

**When to Use This:**
- Tailscale SSH isn't working
- You prefer traditional SSH key authentication
- Emergency access without Tailscale
- Connecting via public IP instead of Tailscale network

**Requirements:**
- AWS SSH private key (.pem file) transferred to iPhone
- Termius app configured with the private key
- Instance must be running and have public IP

**Security Warning:**
Storing private keys on mobile devices increases risk if the phone is lost or compromised. Only use this method if Method A doesn't work for you.

---

## SSH Key Management (Method B Only)

**Skip this section if using Method A (Tailscale SSH).**

### Step 1: Export Private Key from Mac

Your AWS SSH private key should be at:
```bash
~/.ssh/<key-name>.pem
```

Where `<key-name>` is what you specified during `goldenshell.py init`.

### Step 2: Transfer Key to iPhone

**Option 1: AirDrop (Recommended for Security)**
1. On Mac, locate the `.pem` file in Finder
2. Right-click > Share > AirDrop
3. Select your iPhone
4. On iPhone, tap "Save to Files" > choose location
5. Open Termius > Keychain > Add Key > Import from Files

**Option 2: iCloud Drive**
1. On Mac, copy `.pem` file to iCloud Drive
2. On iPhone, open Files app > iCloud Drive
3. Locate the `.pem` file
4. Open Termius > Keychain > Add Key > Import from Files

**Option 3: Email (Least Secure - Not Recommended)**
1. Email the `.pem` file to yourself (use encrypted email if possible)
2. On iPhone, download attachment
3. Open in Termius

### Step 3: Import Key into Termius

1. Open Termius app
2. Tap "Keychain" tab at bottom
3. Tap "+" button > "Import Key"
4. Select the `.pem` file from Files
5. Give it a descriptive name (e.g., "GoldenShell AWS Key")
6. Leave passphrase empty (unless you set one when creating the key)

### Step 4: Delete Temporary Key Files

After importing to Termius:
- Delete the `.pem` file from Files app
- Delete from iCloud Drive if you used that method
- Delete email if you used that method

The key is now stored securely in Termius's encrypted keychain.

---

## Connection Instructions

### Initial Setup in Termius

**Method A: Tailscale SSH Connection**

1. Open Termius app
2. Tap "Hosts" tab at bottom
3. Tap "+" button > "New Host"
4. Configure:
   - **Alias**: `GoldenShell Dev` (or any name you like)
   - **Hostname**: Your Tailscale hostname (e.g., `goldenshell-dev`)
   - **Port**: `22`
   - **Username**: `ubuntu`
   - **Key**: Leave as "None" (Tailscale handles auth)
   - **Password**: Leave empty
5. Tap "Save" (checkmark in top right)

**Method B: Traditional SSH Connection**

1. Open Termius app
2. Tap "Hosts" tab at bottom
3. Tap "+" button > "New Host"
4. Configure:
   - **Alias**: `GoldenShell Dev - Public IP`
   - **Hostname**: Your instance's public IP (get from `goldenshell.py status`)
   - **Port**: `22`
   - **Username**: `ubuntu`
   - **Key**: Select the imported AWS key from keychain
   - **Password**: Leave empty
5. Tap "Save"

### Connecting with Mosh

**Why Use Mosh?**
- Survives network changes (WiFi to cellular)
- Instant character feedback (no lag on slow connections)
- Auto-reconnects after iPhone sleep
- Better for mobile roaming

**Method A: Mosh via Tailscale (Recommended)**

1. In Termius, long-press on your "GoldenShell Dev" host
2. Tap "Edit"
3. Scroll down to "Advanced settings"
4. Enable "Use Mosh"
5. Mosh port: Leave as default or set `60001`
6. Save

**Method B: Mosh via Public IP**

1. Same steps as Method A, but use the public IP host
2. Enable "Use Mosh"
3. Ensure security group allows UDP 60000-61000 (GoldenShell does this by default)

### First Connection

1. Tap on your saved host in Termius
2. If prompted about host key fingerprint, tap "Continue"
3. You should land in a bash shell on your GoldenShell instance
4. You'll see a welcome message with tool versions

### Starting a Zellij Session

Once connected, start Zellij for a better mobile terminal experience:

```bash
# Attach to default session (creates if doesn't exist)
zellij attach --create default
```

Or use the web terminal shortcut:
```bash
# This is what ttyd uses automatically
zellij attach --create default
```

**Zellij Mobile Tips:**
- Simplified UI enabled by default (no clutter)
- Tabs and panes work well on mobile
- Copy-on-select enabled for easy text copying
- Keyboard shortcuts simplified for mobile

---

## Mobile Workflow Optimization

### 1. Using Claude Code CLI on Mobile

Once in a Zellij session, you can use Claude Code CLI just like on desktop:

```bash
# Start Claude Code in current directory
claude

# Create a new project
mkdir my-project && cd my-project
claude init
claude "create a python web server"
```

**Mobile-Specific Tips:**
- Use Claude Code's chat mode for less typing
- Leverage code generation to avoid manual typing
- Use arrow keys for command history
- Set up aliases (see below)

### 2. Mobile-Friendly Aliases

Add these to `~/.bashrc` on the GoldenShell instance for faster mobile workflows:

```bash
# Quick aliases for common commands
alias c='claude'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gd='git diff'
alias ls='ls --color=auto -F'
alias ll='ls -lah'

# Quick directory navigation
alias ..='cd ..'
alias ...='cd ../..'

# Zellij shortcuts
alias z='zellij'
alias za='zellij attach --create default'
alias zl='zellij list-sessions'

# Claude Code shortcuts
alias ccode='claude code'
alias cchat='claude chat'

# System info
alias myip='curl -s http://169.254.169.254/latest/meta-data/public-ipv4'
alias tsip='tailscale ip -4'
```

To add these:
```bash
# Edit bashrc
nano ~/.bashrc

# Add the aliases above at the end
# Save: Ctrl+X, then Y, then Enter

# Reload
source ~/.bashrc
```

### 3. Reducing Typing on Mobile

**Use Tab Completion:**
- Start typing and tap Tab to autocomplete
- Works for commands, file names, directories

**Use Command History:**
- Up/Down arrows to navigate previous commands
- `Ctrl+R` to search command history

**Use Claude Code for Repetitive Tasks:**
```bash
# Instead of typing complex commands, ask Claude
claude "create a git commit message for my changes"
claude "write a bash script to backup my code"
```

### 4. Zellij Mobile Layout

The default Zellij config is already mobile-optimized with:
- `simplified_ui true` - reduces visual clutter
- `copy_on_select true` - easy text copying
- Minimal keybindings shown

**Useful Zellij Commands on Mobile:**
```bash
# Create a new tab (useful for multitasking)
# Ctrl+T (if keyboard supports it)

# Or use Zellij actions:
# Ctrl+P then T (for new tab)
# Ctrl+P then W (to close tab)
# Ctrl+P then N (for new pane)
```

**Zellij Mobile Pro Tip:**
Use tabs instead of panes on mobile - easier to navigate on small screen.

### 5. Optional: Push Notifications with ntfy

**Not yet implemented in GoldenShell**, but you can add this manually for notifications when Claude Code needs input.

Install ntfy on the instance:
```bash
# Install ntfy
wget https://github.com/binwiederhier/ntfy/releases/download/v2.8.0/ntfy_2.8.0_linux_amd64.tar.gz
tar xzf ntfy_2.8.0_linux_amd64.tar.gz
sudo mv ntfy /usr/local/bin/

# Send a test notification
ntfy publish mytopic "Claude Code is waiting for input"
```

On iPhone:
1. Install ntfy app from App Store
2. Subscribe to your topic (e.g., "mytopic")
3. Create a wrapper script for Claude Code that sends notifications

Example wrapper:
```bash
#!/bin/bash
# ~/bin/claude-notify.sh

claude "$@"
ntfy publish goldenshell-alerts "Claude Code task completed"
```

---

## Security Considerations

### Tailscale Security (Method A)

**Advantages:**
- Zero-trust network model
- End-to-end encryption
- No exposed SSH ports on public internet
- Device authentication via Tailscale account
- Can revoke access from admin console

**Best Practices:**
- Enable two-factor authentication on Tailscale account
- Use Tailscale ACLs to restrict access if sharing network with others
- Monitor connected devices in admin console
- Revoke old devices you no longer use

### SSH Key Security (Method B)

**Risks:**
- Private key stored on mobile device
- If iPhone is lost/stolen, key could be compromised
- No passphrase on AWS keys by default

**Mitigations:**
1. **Enable iPhone Encryption:**
   - Use a strong passcode
   - Enable Face ID/Touch ID
   - Turn on "Erase Data" after 10 failed attempts

2. **Use Termius Security Features:**
   - Termius encrypts keychain with device encryption
   - Enable Termius passcode (Settings > Security)
   - Enable biometric unlock in Termius

3. **Key Rotation:**
   - Periodically create new AWS key pairs
   - Delete old keys from AWS console
   - Update GoldenShell config with new key name

4. **Emergency Revocation:**
   If phone is lost:
   ```bash
   # On Mac, immediately revoke the AWS key pair
   aws ec2 delete-key-pair --key-name goldenshell-key --region us-east-1

   # Create a new key pair
   aws ec2 create-key-pair --key-name goldenshell-key-new --query 'KeyMaterial' --output text > ~/.ssh/goldenshell-key-new.pem

   # Update instance to use new key (requires instance restart)
   # This is complex - easier to destroy and redeploy
   ./goldenshell.py destroy
   ./goldenshell.py init  # Update with new key name
   ./goldenshell.py deploy
   ```

### Network Security

**GoldenShell Security Features Already Enabled:**
- Security group restricts Mosh to UDP 60000-61000
- Tailscale VPN encrypts all traffic
- Auto-shutdown after 30 minutes of inactivity (prevents unauthorized access)
- IMDSv2 enforced (protects instance metadata)
- EBS encryption enabled

**Additional Recommendations:**
1. **Restrict SSH CIDR blocks** (optional):
   Edit `terraform/variables.tf`:
   ```hcl
   variable "ssh_allowed_cidrs" {
     default = ["YOUR_HOME_IP/32"]  # Only your home IP
   }
   ```

2. **Use VPN on public WiFi:**
   - Tailscale already provides this
   - All traffic between iPhone and instance is encrypted

3. **Monitor Access:**
   Check who's connected:
   ```bash
   # On the instance
   who

   # Check active SSH sessions
   ss -tn | grep :22

   # Check Tailscale connections
   tailscale status
   ```

### Auto-Shutdown Protection

**How it Works:**
- Systemd timer checks for activity every 5 minutes
- Monitors: SSH sessions, network connections, web terminal connections
- Shuts down (not terminates) instance after 30 minutes of inactivity
- Prevents runaway costs and unauthorized access after you disconnect

**To Disable Auto-Shutdown (Not Recommended):**
```bash
# On the instance
sudo systemctl stop goldenshell-idle-monitor.timer
sudo systemctl disable goldenshell-idle-monitor.timer
```

**To Change Timeout Period:**
Edit during deployment by modifying `terraform/variables.tf`:
```hcl
variable "auto_shutdown_minutes" {
  default = 60  # Change from 30 to 60 minutes
}
```

---

## Quick Start Checklist

Use this checklist to get from zero to connected on iPhone:

### On Mac (One-Time Setup)

- [ ] Sign up for Tailscale account
- [ ] Generate Tailscale auth key (https://login.tailscale.com/admin/settings/keys)
- [ ] Create AWS SSH key pair in EC2 console
- [ ] Download private key (.pem file) to `~/.ssh/`
- [ ] Install GoldenShell: `git clone <repo> && cd GoldenShell && pip install -r requirements.txt`
- [ ] Initialize config: `./goldenshell.py init`
  - Enter AWS credentials
  - Enter Tailscale auth key
  - Enter SSH key name
- [ ] Deploy instance: `./goldenshell.py deploy`
- [ ] Note the public IP from deployment output
- [ ] Get Tailscale hostname: `./goldenshell.py ssh` then `tailscale status`

### On iPhone (One-Time Setup)

- [ ] Install Tailscale app from App Store
- [ ] Install Termius app from App Store
- [ ] Open Tailscale, sign in with same account
- [ ] Toggle VPN on (blue switch)
- [ ] Wait for "Connected" status

**For Method A (Tailscale SSH - Recommended):**
- [ ] Open Termius > Hosts > New Host
- [ ] Hostname: `<your-tailscale-hostname>`
- [ ] Username: `ubuntu`
- [ ] Key: None (leave blank)
- [ ] Save
- [ ] Enable Mosh in Advanced settings
- [ ] Tap host to connect

**For Method B (Traditional SSH with Key):**
- [ ] Transfer `.pem` key to iPhone via AirDrop
- [ ] Import key into Termius Keychain
- [ ] Delete temporary key file from Files app
- [ ] Create host with public IP
- [ ] Select imported key from keychain
- [ ] Enable Mosh in Advanced settings
- [ ] Tap host to connect

### First Use (Every Session)

- [ ] Ensure Tailscale is connected on iPhone
- [ ] Open Termius
- [ ] Tap on GoldenShell host
- [ ] Wait for Mosh connection (5-10 seconds)
- [ ] Start Zellij: `zellij attach --create default`
- [ ] Use Claude Code: `claude`

---

## Troubleshooting

### Connection Issues

**Problem: "Connection refused" in Termius**

Possible causes:
1. Instance is stopped
   - Solution: On Mac, run `./goldenshell.py start`

2. Tailscale not connected
   - Solution: Open Tailscale app, ensure VPN is on

3. Wrong hostname
   - Solution: Verify Tailscale hostname in admin console

**Problem: "Host key verification failed"**

Solution:
1. Tap "Continue" when prompted in Termius
2. Or remove old fingerprint: Settings > Known Hosts > Delete entry

**Problem: Mosh connection hangs**

Possible causes:
1. UDP ports blocked by network
   - Solution: Try disabling Mosh, use regular SSH

2. Security group not allowing Mosh ports
   - Solution: Verify ports 60000-61000 UDP in AWS console

3. Firewall on instance
   - Solution: GoldenShell doesn't add firewall by default, shouldn't be an issue

**Problem: "Permission denied (publickey)"**

For Method A (Tailscale SSH):
- Ensure you're signed into same Tailscale account on Mac and iPhone
- Check Tailscale admin console for device authorization

For Method B (Traditional SSH):
- Verify correct key is selected in Termius
- Check key has correct permissions (Termius handles this)
- Verify key matches AWS key pair

### Mosh-Specific Issues

**Problem: Mosh says "mosh-server not found"**

Solution: Mosh is installed by default in GoldenShell. If missing:
```bash
# Connect via regular SSH first
ssh ubuntu@<hostname>

# Install mosh
sudo apt-get update
sudo apt-get install -y mosh
```

**Problem: Mosh disconnects frequently**

Causes:
1. Cellular network issues
   - Solution: Try WiFi connection

2. Aggressive NAT traversal
   - Solution: Reduce Mosh timeout: `mosh --server-timeout=300`

3. Instance stopped by auto-shutdown
   - Solution: Start instance, increase timeout in variables.tf

### Tailscale Issues

**Problem: Can't see GoldenShell instance in Tailscale network**

Solutions:
1. Check Tailscale status on instance:
   ```bash
   # SSH via public IP first
   ssh -i ~/.ssh/<key>.pem ubuntu@<public-ip>

   # Check Tailscale status
   sudo tailscale status

   # Restart if needed
   sudo tailscale up --ssh
   ```

2. Verify auth key in SSM Parameter Store:
   ```bash
   aws ssm get-parameter --name /goldenshell/tailscale-auth-key --with-decryption --region us-east-1
   ```

**Problem: Tailscale SSH not working**

Solution: Re-enable Tailscale SSH:
```bash
# On the instance
sudo tailscale up --ssh
```

### Zellij Issues

**Problem: Zellij not found**

Solution:
```bash
# Install Zellij manually
wget https://github.com/zellij-org/zellij/releases/download/v0.41.2/zellij-x86_64-unknown-linux-musl.tar.gz
tar -xzf zellij-x86_64-unknown-linux-musl.tar.gz
sudo mv zellij /usr/local/bin/
chmod +x /usr/local/bin/zellij
```

**Problem: Zellij keybindings not working on mobile**

- Some keybindings require keyboard modifiers not available on mobile keyboards
- Use external Bluetooth keyboard, or
- Use simplified commands via Zellij's command mode

### Claude Code Issues

**Problem: Claude command not found**

Solution:
```bash
# Check if installed
which claude

# Reinstall if needed
sudo npm install -g @anthropic-ai/claude-code

# Check version
claude --version
```

**Problem: Claude API authentication fails**

Solution:
```bash
# Set API key on the instance
export ANTHROPIC_API_KEY="your-key-here"

# Or configure Claude CLI
claude config
```

### Performance Issues

**Problem: Slow connection on mobile**

Solutions:
1. Switch to Mosh (better for high-latency connections)
2. Reduce Zellij plugins/features
3. Use simpler shell prompt (less rendering)
4. Close unused Zellij tabs/panes

**Problem: High data usage**

- Mosh uses minimal bandwidth (~5KB/sec idle)
- SSH uses more but still very low
- Most data is from Claude Code API calls, not terminal
- Monitor with: Settings > Cellular > Termius

### Emergency Access

**Problem: Can't connect any way**

Last resort - use AWS Systems Manager Session Manager:

```bash
# On Mac
aws ssm start-session --target <instance-id> --region us-east-1
```

This gives you shell access without SSH or Tailscale.

---

## Additional Resources

### Official Documentation

- **Termius:** https://termius.com/documentation
- **Mosh:** https://mosh.org
- **Tailscale:** https://tailscale.com/kb/
- **Zellij:** https://zellij.dev/documentation/
- **Claude Code:** https://docs.anthropic.com/claude/docs

### GoldenShell Documentation

- `README.md` - Main project documentation
- `INSTALLATION_GUIDE.md` - Detailed setup instructions
- `WEB_TERMINAL_GUIDE.md` - Web-based terminal access
- `SECURITY.md` - Security best practices
- `INTERACTIVE_MODE.md` - Interactive CLI mode guide

### Community

- **GoldenShell Issues:** File bugs or feature requests on GitHub
- **Tailscale Community:** https://forum.tailscale.com
- **Termius Support:** support@termius.com

---

## Appendix: Quick Command Reference

### Mac Commands

```bash
# Deploy instance
./goldenshell.py deploy

# Check status
./goldenshell.py status

# SSH to instance
./goldenshell.py ssh

# Start stopped instance
./goldenshell.py start

# Stop instance
./goldenshell.py stop

# Destroy everything
./goldenshell.py destroy
```

### Instance Commands

```bash
# Tailscale status
tailscale status

# List active connections
who
ss -tn | grep ESTAB

# Check auto-shutdown status
systemctl status goldenshell-idle-monitor.timer

# Check Claude version
claude --version

# Start Zellij session
zellij attach --create default

# List Zellij sessions
zellij list-sessions
```

### Termius Keyboard Shortcuts

- **Ctrl + C** - Interrupt current command
- **Ctrl + D** - Exit shell (logout)
- **Ctrl + L** - Clear screen
- **Ctrl + R** - Search command history
- **Ctrl + Z** - Suspend current process
- **Tab** - Autocomplete

---

## Conclusion

With this setup, you have a powerful mobile development environment accessible from your iPhone. The combination of Mosh (for reliable connections) + Tailscale (for security) + Zellij (for multiplexing) + Claude Code (for AI assistance) creates a professional mobile coding experience.

**Recommended Workflow:**
1. Use Method A (Tailscale SSH) for simplicity and security
2. Enable Mosh for best mobile experience
3. Always work in a Zellij session for persistence
4. Set up mobile-friendly aliases to reduce typing
5. Let auto-shutdown protect you from runaway costs

**Happy mobile coding!**
