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

# Install basic dependencies (excluding nodejs/npm - will be installed later)
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
    tmux \
    mosh

# Install AWS CLI first (needed for SSM parameter access)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
    echo "AWS CLI installed: $(aws --version)"
else
    echo "AWS CLI already installed: $(aws --version)"
fi

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

# Install Node.js v20 LTS (required for latest Claude Code CLI)
echo "Installing Node.js v20 LTS..."
# Remove any conflicting packages first to avoid installation failures
apt-get remove -y libnode-dev nodejs npm 2>/dev/null || true
# Install Node.js v20 from NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
echo "Node.js installed: $(node --version)"
echo "npm version: $(npm --version)"

# Install Claude Code CLI via npm (official package)
if ! command -v claude &> /dev/null; then
    echo "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
    echo "Claude Code CLI installed: $(claude --version)"
else
    echo "Reinstalling Claude Code CLI to ensure compatibility..."
    npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
    npm install -g @anthropic-ai/claude-code
    echo "Claude Code CLI installed: $(claude --version)"
fi

# Create Claude auto-update script
cat > /usr/local/bin/update-claude.sh << 'EOF'
#!/bin/bash
# Auto-update Claude Code CLI

echo "$(date): Checking for Claude Code CLI updates..."

# Update Claude Code CLI globally
npm update -g @anthropic-ai/claude-code

echo "$(date): Claude Code CLI update check complete"
EOF

chmod +x /usr/local/bin/update-claude.sh

# Create systemd service for Claude updates
cat > /etc/systemd/system/claude-update.service << 'EOF'
[Unit]
Description=Claude Code CLI Auto-Update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-claude.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer for daily Claude updates
cat > /etc/systemd/system/claude-update.timer << 'EOF'
[Unit]
Description=Daily Claude Code CLI Update Check

[Timer]
OnCalendar=daily
OnBootSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
systemctl daemon-reload
systemctl enable claude-update.timer
systemctl start claude-update.timer

echo "Claude auto-update configured (daily updates via systemd)"

# Install Tailscale
if ! command -v tailscale &> /dev/null; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Enable Tailscale service to start on boot
echo "Enabling Tailscale service..."
systemctl enable tailscaled
systemctl start tailscaled

# Configure Tailscale if not already connected
if ! sudo tailscale status &> /dev/null; then
    # Retrieve Tailscale auth key from SSM Parameter Store
    echo "Retrieving Tailscale auth key from SSM..."
    export AWS_DEFAULT_REGION=${aws_region}
    TAILSCALE_AUTH_KEY=$(aws ssm get-parameter \
      --name "/goldenshell/tailscale-auth-key" \
      --with-decryption \
      --query "Parameter.Value" \
      --output text)

    # Start and authenticate Tailscale
    echo "Authenticating Tailscale..."
    sudo tailscale up --authkey="$TAILSCALE_AUTH_KEY" --ssh

    # Clear the auth key from memory
    unset TAILSCALE_AUTH_KEY

    echo "Tailscale configured and connected"
else
    echo "Tailscale already configured and connected"
fi

# Display Tailscale status
sudo tailscale status

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
WEB_TERMINAL_CONNECTIONS=$(sudo ss -tn | grep ':7681' | grep ESTAB | wc -l)

# If there are active sessions or connections, reset idle timer
if [ "$ACTIVE_SESSIONS" -gt 0 ] || [ "$RECENT_CONNECTIONS" -gt 0 ] || [ "$WEB_TERMINAL_CONNECTIONS" -gt 0 ]; then
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

# Configure tmux
cat > ~/.tmux.conf << 'TMUXCONF'
# Tmux configuration for GoldenShell

# Set prefix to Ctrl-a (easier to reach than Ctrl-b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Enable mouse support
set -g mouse on

# Increase scrollback buffer
set -g history-limit 10000

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on

# Enable 256 colors
set -g default-terminal "screen-256color"

# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Reload config with r
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Switch panes with Alt+arrow (no prefix needed)
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Status bar styling
set -g status-style bg=black,fg=white
set -g status-left-length 40
set -g status-left "#[fg=green]GoldenShell #[fg=yellow]#S "
set -g status-right "#[fg=cyan]%d %b %R"
TMUXCONF

# Create a welcome message
cat > ~/.bash_profile << 'WELCOME'
echo "================================================"
echo "  Welcome to GoldenShell Development Instance  "
echo "================================================"
echo ""
echo "Installed tools:"
echo "  - Claude Code CLI: claude --version"
echo "  - GitHub CLI: gh --version"
echo "  - tmux (persistent sessions): tmux --version"
echo "  - mosh (mobile shell): mosh --version"
echo "  - Zellij (web terminal): zellij --version"
echo "  - Tailscale: tailscale status"
echo "  - AWS CLI: aws --version"
echo ""
echo "Web Terminal Access:"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "  - Access via browser: http://$PUBLIC_IP:7681"
echo "  - Username: ubuntu"
echo "  - Password: GoldenShell2025!"
echo ""
echo "Auto-shutdown: This instance will shut down after 30 minutes of inactivity"
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
