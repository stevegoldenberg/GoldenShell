#!/bin/bash
# GoldenShell Quick Fix Script
# This script completes the installation that failed during initial deployment
# Run this on the GoldenShell instance via SSH or Systems Manager

set -e

echo "================================================"
echo "  GoldenShell Instance Quick Fix Script"
echo "================================================"
echo ""
echo "This script will complete the failed installation."
echo "Estimated time: 5-10 minutes"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root. Run as ubuntu user with sudo."
    exit 1
fi

# Check if already completed
if [ -f /var/lib/goldenshell-setup-complete ]; then
    echo "WARNING: Setup completion flag already exists."
    echo "This may indicate the setup was previously completed."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo "Phase 1: Installing AWS CLI..."
cd /tmp
if ! command -v aws &> /dev/null; then
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    echo "✓ AWS CLI installed: $(aws --version)"
else
    echo "✓ AWS CLI already installed: $(aws --version)"
fi

echo ""
echo "Phase 2: Configuring Tailscale..."
export AWS_DEFAULT_REGION=us-east-1
if ! sudo tailscale status &> /dev/null; then
    echo "Retrieving auth key from SSM..."
    TAILSCALE_AUTH_KEY=$(aws ssm get-parameter \
      --name "/goldenshell/tailscale-auth-key" \
      --with-decryption \
      --query "Parameter.Value" \
      --output text)

    echo "Authenticating Tailscale..."
    sudo tailscale up --authkey="$TAILSCALE_AUTH_KEY" --ssh
    unset TAILSCALE_AUTH_KEY
    echo "✓ Tailscale configured"
else
    echo "✓ Tailscale already configured"
fi
sudo tailscale status

echo ""
echo "Phase 3: Upgrading Node.js to v20 LTS..."
NODE_VERSION=$(node --version)
if [[ "$NODE_VERSION" < "v18" ]]; then
    echo "Current version: $NODE_VERSION (upgrading...)"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    echo "✓ Node.js upgraded: $(node --version)"
else
    echo "✓ Node.js version sufficient: $(node --version)"
fi

echo ""
echo "Phase 4: Reinstalling Claude Code CLI..."
sudo npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
sudo npm install -g @anthropic-ai/claude-code
echo "✓ Claude Code CLI installed: $(claude --version 2>&1 | head -1)"

echo ""
echo "Phase 5: Installing Zellij..."
if ! command -v zellij &> /dev/null; then
    ZELLIJ_VERSION="0.41.2"
    wget -q "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" -O /tmp/zellij.tar.gz
    sudo tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin/
    sudo chmod +x /usr/local/bin/zellij
    rm /tmp/zellij.tar.gz
    echo "✓ Zellij installed: $(zellij --version)"
else
    echo "✓ Zellij already installed: $(zellij --version)"
fi

echo "Configuring Zellij..."
mkdir -p ~/.config/zellij
cat > ~/.config/zellij/config.kdl << 'EOF'
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

simplified_ui true
default_shell "bash"
copy_on_select true
theme "default"
session_name "goldenshell"
EOF
echo "✓ Zellij configured"

echo ""
echo "Phase 6: Installing ttyd Web Terminal..."
if ! command -v ttyd &> /dev/null; then
    TTYD_VERSION="1.7.7"
    wget -q "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" -O /tmp/ttyd
    sudo mv /tmp/ttyd /usr/local/bin/ttyd
    sudo chmod +x /usr/local/bin/ttyd
    echo "✓ ttyd installed: $(ttyd --version 2>&1 | head -1)"
else
    echo "✓ ttyd already installed"
fi

echo "Creating ttyd systemd service..."
sudo tee /etc/systemd/system/ttyd.service > /dev/null << 'EOF'
[Unit]
Description=ttyd - Web Terminal with Zellij for GoldenShell
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/usr/local/bin/ttyd -p 7681 -W -t disableReconnect=true -c ubuntu:GoldenShell2025! /usr/local/bin/zellij attach --create default
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ttyd.service
sudo systemctl start ttyd.service
echo "✓ ttyd service started"

echo ""
echo "Phase 7: Configuring Auto-Shutdown..."
sudo tee /usr/local/bin/check-idle-shutdown.sh > /dev/null << 'EOF'
#!/bin/bash

# Configuration
IDLE_THRESHOLD_MINUTES=30
IDLE_THRESHOLD_SECONDS=$((IDLE_THRESHOLD_MINUTES * 60))

# Get instance metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

# Check for active sessions and connections
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

sudo chmod +x /usr/local/bin/check-idle-shutdown.sh

sudo tee /etc/systemd/system/goldenshell-idle-monitor.service > /dev/null << 'EOF'
[Unit]
Description=GoldenShell Idle Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check-idle-shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/goldenshell-idle-monitor.timer > /dev/null << 'EOF'
[Unit]
Description=GoldenShell Idle Monitor Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable goldenshell-idle-monitor.timer
sudo systemctl start goldenshell-idle-monitor.timer
echo "✓ Auto-shutdown configured (30 minute idle timeout)"

echo ""
echo "Phase 8: Configuring User Environment..."
cat > ~/.bash_profile << 'EOF'
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
EOF

grep -q "bash_profile" ~/.bashrc || echo "source ~/.bash_profile" >> ~/.bashrc
echo "✓ User environment configured"

echo ""
echo "Phase 9: Setting Completion Flag..."
sudo touch /var/lib/goldenshell-setup-complete
sudo chmod 644 /var/lib/goldenshell-setup-complete
echo "✓ Setup completion flag set"

echo ""
echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo ""
echo "Verification:"
echo ""
echo "AWS CLI: $(aws --version 2>&1 | head -1)"
echo "Tailscale: $(sudo tailscale status 2>&1 | head -1)"
echo "Claude CLI: $(claude --version 2>&1 | head -1)"
echo "Zellij: $(zellij --version 2>&1 | head -1)"
echo "ttyd: $(ttyd --version 2>&1 | head -1)"
echo "ttyd service: $(systemctl is-active ttyd.service)"
echo "Auto-shutdown: $(systemctl is-active goldenshell-idle-monitor.timer)"
echo ""
echo "Web Terminal Access:"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "  URL: http://$PUBLIC_IP:7681"
echo "  Username: ubuntu"
echo "  Password: GoldenShell2025!"
echo ""
echo "Tailscale Admin:"
echo "  Check your instance at: https://login.tailscale.com/admin/machines"
echo ""
echo "================================================"
echo "  Setup Complete - Ready to Use!"
echo "================================================"
