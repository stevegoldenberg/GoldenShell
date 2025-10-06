#!/bin/bash
set -e

echo "==============================================="
echo "  Installing Web Terminal Stack for GoldenShell"
echo "==============================================="

# Install basic dependencies
echo "[1/8] Installing system dependencies..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
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
    certbot \
    python3-certbot-nginx

# Install GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "[2/8] Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y gh
    echo "GitHub CLI installed: $(gh --version)"
else
    echo "[2/8] GitHub CLI already installed"
fi

# Install Claude Code CLI
if ! command -v claude &> /dev/null; then
    echo "[3/8] Installing Claude Code CLI..."
    # Try the official installation method
    curl -fsSL https://claude.ai/install.sh | sh || true

    # Alternative: install via npm if the above fails
    if ! command -v claude &> /dev/null; then
        echo "Trying alternative Claude CLI installation via npm..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        sudo npm install -g @anthropic-ai/claude-code-cli || echo "NPM installation not available, will configure manually"
    fi

    # Make claude available system-wide if installed
    if [ -f "$HOME/.claude/bin/claude" ]; then
        sudo ln -sf "$HOME/.claude/bin/claude" /usr/local/bin/claude
    fi

    echo "Claude Code CLI installation attempted"
else
    echo "[3/8] Claude Code CLI already installed"
fi

# Install AWS CLI
if ! command -v aws &> /dev/null; then
    echo "[4/8] Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
    echo "AWS CLI installed: $(aws --version)"
else
    echo "[4/8] AWS CLI already installed"
fi

# Install Tailscale
if ! command -v tailscale &> /dev/null; then
    echo "[5/8] Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "Tailscale installed"
else
    echo "[5/8] Tailscale already installed"
fi

# Install Zellij (terminal multiplexer)
if ! command -v zellij &> /dev/null; then
    echo "[6/8] Installing Zellij..."
    ZELLIJ_VERSION="0.41.2"
    wget -q "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" -O /tmp/zellij.tar.gz
    sudo tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin/
    sudo chmod +x /usr/local/bin/zellij
    rm /tmp/zellij.tar.gz
    echo "Zellij installed: $(zellij --version)"
else
    echo "[6/8] Zellij already installed"
fi

# Install ttyd (web terminal)
if ! command -v ttyd &> /dev/null; then
    echo "[7/8] Installing ttyd..."
    TTYD_VERSION="1.7.7"
    wget -q "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" -O /tmp/ttyd
    sudo mv /tmp/ttyd /usr/local/bin/ttyd
    sudo chmod +x /usr/local/bin/ttyd
    echo "ttyd installed: $(ttyd --version)"
else
    echo "[7/8] ttyd already installed"
fi

# Configure Zellij default config for ubuntu user
echo "[8/8] Configuring Zellij..."
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
    }
}

// Simplified UI
simplified_ui true

// Default shell
default_shell "bash"

// Copy on select
copy_on_select true

// Theme
theme "default"
EOF

chown -R ubuntu:ubuntu /home/ubuntu/.config

echo ""
echo "==============================================="
echo "  Installation Complete!"
echo "==============================================="
echo ""
echo "Next steps:"
echo "1. Configure ttyd systemd service with password"
echo "2. Start ttyd service"
echo "3. Optional: Configure nginx reverse proxy with SSL"
echo ""
