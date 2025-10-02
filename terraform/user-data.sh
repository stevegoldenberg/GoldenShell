#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting GoldenShell instance setup..."

# Update system
apt-get update
apt-get upgrade -y

# Install basic dependencies
apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    jq \
    python3 \
    python3-pip

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
apt-get install -y gh

echo "GitHub CLI installed: $(gh --version)"

# Install Claude Code CLI
echo "Installing Claude Code CLI..."
curl -fsSL https://claude.ai/install.sh | sh

# Make claude available system-wide
ln -sf /root/.claude/bin/claude /usr/local/bin/claude || true

echo "Claude Code CLI installed"

# Install Warp Terminal
echo "Installing Warp Terminal..."
# Note: Warp requires a GUI environment, so we'll install it but it may need X11 forwarding
# For a headless Linux server, we'll document this requirement
wget -q https://releases.warp.dev/stable/latest/warp-terminal_amd64.deb -O /tmp/warp.deb
apt-get install -y /tmp/warp.deb || echo "Warp installation may require GUI environment"
rm -f /tmp/warp.deb

echo "Warp Terminal installation attempted (requires GUI for full functionality)"

# Install Tailscale
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Start and authenticate Tailscale
echo "Configuring Tailscale..."
tailscale up --authkey="${tailscale_auth_key}" --ssh

echo "Tailscale configured and connected"

# Install AWS CLI (useful for auto-shutdown script)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

echo "AWS CLI installed: $(aws --version)"

# Create auto-shutdown monitoring script
cat > /usr/local/bin/check-idle-shutdown.sh << 'EOF'
#!/bin/bash

# Configuration
IDLE_THRESHOLD_MINUTES=${auto_shutdown_minutes}
IDLE_THRESHOLD_SECONDS=$((IDLE_THRESHOLD_MINUTES * 60))
REGION=$(ec2-metadata --availability-zone | awk '{print $2}' | sed 's/[a-z]$//')
INSTANCE_ID=$(ec2-metadata --instance-id | awk '{print $2}')

# Get the idle time in seconds (time since last user activity)
# Check for active SSH sessions, running processes, and network activity
ACTIVE_SESSIONS=$(who | wc -l)
RECENT_CONNECTIONS=$(netstat -tn | grep ESTABLISHED | grep -v ':22' | wc -l)

# If there are active sessions or connections, reset idle timer
if [ "$ACTIVE_SESSIONS" -gt 0 ] || [ "$RECENT_CONNECTIONS" -gt 0 ]; then
    echo "$(date): Active sessions detected. Not shutting down."
    echo "$(date)" > /tmp/last-activity
    exit 0
fi

# Check last activity timestamp
if [ ! -f /tmp/last-activity ]; then
    echo "$(date)" > /tmp/last-activity
    exit 0
fi

LAST_ACTIVITY=$(cat /tmp/last-activity)
LAST_ACTIVITY_EPOCH=$(date -d "$LAST_ACTIVITY" +%s)
CURRENT_EPOCH=$(date +%s)
IDLE_SECONDS=$((CURRENT_EPOCH - LAST_ACTIVITY_EPOCH))

echo "$(date): Idle for $IDLE_SECONDS seconds (threshold: $IDLE_THRESHOLD_SECONDS)"

if [ "$IDLE_SECONDS" -gt "$IDLE_THRESHOLD_SECONDS" ]; then
    echo "$(date): Idle threshold exceeded. Shutting down instance..."
    aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
fi
EOF

chmod +x /usr/local/bin/check-idle-shutdown.sh

# Create systemd service for idle monitoring
cat > /etc/systemd/system/goldenshell-idle-monitor.service << EOF
[Unit]
Description=GoldenShell Idle Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check-idle-shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer (check every 5 minutes)
cat > /etc/systemd/system/goldenshell-idle-monitor.timer << EOF
[Unit]
Description=GoldenShell Idle Monitor Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
systemctl daemon-reload
systemctl enable goldenshell-idle-monitor.timer
systemctl start goldenshell-idle-monitor.timer

echo "Auto-shutdown monitoring configured (${auto_shutdown_minutes} minutes idle threshold)"

# Set up user environment for ubuntu user
sudo -u ubuntu bash << 'USEREOF'
cd ~

# Configure git
git config --global init.defaultBranch main

# Create a welcome message
cat > ~/.bash_profile << 'WELCOME'
echo "================================================"
echo "  Welcome to GoldenShell Development Instance  "
echo "================================================"
echo ""
echo "Installed tools:"
echo "  - Claude Code CLI: claude --version"
echo "  - GitHub CLI: gh --version"
echo "  - Warp Terminal: warp (requires GUI)"
echo "  - Tailscale: tailscale status"
echo "  - AWS CLI: aws --version"
echo ""
echo "Auto-shutdown: This instance will shut down after ${auto_shutdown_minutes} minutes of inactivity"
echo "================================================"
WELCOME

# Source the welcome message in bashrc
echo "source ~/.bash_profile" >> ~/.bashrc

USEREOF

echo "GoldenShell setup complete!"
echo "Instance ready for use."