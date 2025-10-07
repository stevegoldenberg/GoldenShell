#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting GoldenShell instance setup..."

# Idempotency check - skip if already completed
SETUP_COMPLETE_FLAG="/var/lib/goldenshell-setup-complete"
if [ -f "$SETUP_COMPLETE_FLAG" ]; then
    echo "Setup already completed. Skipping..."
    exit 0
fi

# Update system
echo "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
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
    python3-pip \
    nginx \
    nodejs \
    npm

# Install GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update
    apt-get install -y gh
    echo "GitHub CLI installed: $(gh --version)"
else
    echo "GitHub CLI already installed: $(gh --version)"
fi

# Install Claude Code CLI via npm (official package)
if ! command -v claude &> /dev/null; then
    echo "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
    echo "Claude Code CLI installed: $(claude --version)"
else
    echo "Claude Code CLI already installed: $(claude --version)"
fi

# Install Tailscale
if ! command -v tailscale &> /dev/null; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Configure Tailscale if not already connected
if ! tailscale status &> /dev/null; then
    # Retrieve Tailscale auth key from SSM Parameter Store
    echo "Retrieving Tailscale auth key from SSM..."
    TAILSCALE_AUTH_KEY=$(aws ssm get-parameter \
      --name "/goldenshell/tailscale-auth-key" \
      --with-decryption \
      --region "${aws_region}" \
      --query "Parameter.Value" \
      --output text)

    # Start and authenticate Tailscale
    echo "Configuring Tailscale..."
    tailscale up --authkey="$TAILSCALE_AUTH_KEY" --ssh

    # Clear the auth key from memory
    unset TAILSCALE_AUTH_KEY

    echo "Tailscale configured and connected"
else
    echo "Tailscale already configured and connected"
fi

# Install AWS CLI (useful for auto-shutdown script)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
    echo "AWS CLI installed: $(aws --version)"
else
    echo "AWS CLI already installed: $(aws --version)"
fi

# Install Zellij (terminal multiplexer for web terminal)
if ! command -v zellij &> /dev/null; then
    echo "Installing Zellij..."
    ZELLIJ_VERSION="0.41.2"
    wget -q "https://github.com/zellij-org/zellij/releases/download/v$${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" -O /tmp/zellij.tar.gz
    tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin/
    chmod +x /usr/local/bin/zellij
    rm /tmp/zellij.tar.gz
    echo "Zellij installed: $(zellij --version)"
else
    echo "Zellij already installed"
fi

# Install ttyd (web-based terminal)
if ! command -v ttyd &> /dev/null; then
    echo "Installing ttyd..."
    TTYD_VERSION="1.7.7"
    wget -q "https://github.com/tsl0922/ttyd/releases/download/$${TTYD_VERSION}/ttyd.x86_64" -O /tmp/ttyd
    mv /tmp/ttyd /usr/local/bin/ttyd
    chmod +x /usr/local/bin/ttyd
    echo "ttyd installed: $(ttyd --version)"
else
    echo "ttyd already installed"
fi

# Configure Zellij default config for ubuntu user
echo "Configuring Zellij..."
mkdir -p /home/ubuntu/.config/zellij
cat > /home/ubuntu/.config/zellij/config.kdl << 'EOF'
// Zellij configuration for GoldenShell
keybinds {
    normal {
        bind "Ctrl t" { NewTab; }
        bind "Ctrl w" { CloseTab; }
        bind "Alt 1" { GoToTab 1; }
        bind "Alt 2" { GoToTab 2; }
        bind "Alt 3" { GoToTab 3; }
        bind "Alt 4" { GoToTab 4; }
        bind "Alt 5" { GoToTab 5; }
        bind "Ctrl n" { NewPane; }
    }
}

// Simplified UI for mobile
simplified_ui true

// Default shell
default_shell "bash"

// Copy on select
copy_on_select true

// Theme
theme "default"

// Session name
session_name "goldenshell"
EOF

chown -R ubuntu:ubuntu /home/ubuntu/.config

# Create ttyd systemd service
echo "Creating ttyd systemd service..."
cat > /etc/systemd/system/ttyd.service << 'EOF'
[Unit]
Description=ttyd - Web Terminal with Zellij for GoldenShell
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
# Run ttyd on port 7681 with basic auth
# Username: ubuntu, Password: GoldenShell2025!
# -W = writable terminal, -t = client options
ExecStart=/usr/local/bin/ttyd -p 7681 -W -t disableReconnect=true -c ubuntu:GoldenShell2025! /usr/local/bin/zellij attach --create default
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start ttyd service
systemctl daemon-reload
systemctl enable ttyd.service
systemctl start ttyd.service

echo "ttyd web terminal service started on port 7681"

# Create auto-shutdown monitoring script
cat > /usr/local/bin/check-idle-shutdown.sh << 'EOF'
#!/bin/bash

# Configuration
IDLE_THRESHOLD_MINUTES=${auto_shutdown_minutes}
IDLE_THRESHOLD_SECONDS=$((IDLE_THRESHOLD_MINUTES * 60))

# Get instance metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

# Get the idle time in seconds (time since last user activity)
# Check for active SSH sessions, running processes, and network activity
ACTIVE_SESSIONS=$(who | wc -l)
RECENT_CONNECTIONS=$(ss -tn | grep ESTAB | grep -v ':22' | wc -l)

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
echo "  - Zellij (terminal multiplexer): zellij --version"
echo "  - Tailscale: tailscale status"
echo "  - AWS CLI: aws --version"
echo ""
echo "Web Terminal Access:"
echo "  - Access via browser: http://YOUR_INSTANCE_IP:7681"
echo "  - Username: ubuntu"
echo "  - Password: GoldenShell2025!"
echo ""
echo "Zellij Commands:"
echo "  - New tab: Ctrl+t"
echo "  - Close tab: Ctrl+w"
echo "  - Switch tab: Alt+1, Alt+2, etc."
echo "  - New pane: Ctrl+n"
echo ""
echo "Auto-shutdown: This instance will shut down after ${auto_shutdown_minutes} minutes of inactivity"
echo "================================================"
WELCOME

# Source the welcome message in bashrc
echo "source ~/.bash_profile" >> ~/.bashrc

USEREOF

# Create setup completion flag
touch "$SETUP_COMPLETE_FLAG"

echo "GoldenShell setup complete!"
echo "Instance ready for use."
echo "Setup completion flag created at: $SETUP_COMPLETE_FLAG"
echo ""
echo "Web Terminal URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):7681"
echo "Username: ubuntu"
echo "Password: GoldenShell2025!"
