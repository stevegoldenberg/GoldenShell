# GoldenShell Software Installation Guide

This guide explains how to install additional software on your GoldenShell Ubuntu 22.04 instance.

## Table of Contents

- [Package Management Overview](#package-management-overview)
- [Using APT (Recommended)](#using-apt-recommended)
- [Alternative Package Managers](#alternative-package-managers)
- [Language-Specific Package Managers](#language-specific-package-managers)
- [Common Development Tools](#common-development-tools)
- [Persistence Considerations](#persistence-considerations)

---

## Package Management Overview

GoldenShell runs Ubuntu 22.04 LTS, which uses **APT (Advanced Package Tool)** as its primary package manager. Unlike macOS, Ubuntu does NOT support Homebrew natively.

### Key Package Managers for Ubuntu:

1. **APT** - Default Ubuntu package manager (recommended)
2. **Snap** - Universal Linux package manager
3. **npm** - Node.js packages (already installed)
4. **pip** - Python packages
5. **cargo** - Rust packages

---

## Using APT (Recommended)

APT is the standard package manager for Ubuntu and provides access to thousands of pre-compiled packages.

### Basic APT Commands

```bash
# Update package lists (run this first!)
sudo apt update

# Search for a package
apt search <package-name>

# Get package information
apt show <package-name>

# Install a package
sudo apt install <package-name>

# Install multiple packages
sudo apt install <package1> <package2> <package3>

# Remove a package
sudo apt remove <package-name>

# Remove package and configuration files
sudo apt purge <package-name>

# Upgrade all installed packages
sudo apt upgrade

# Clean up unused packages
sudo apt autoremove
```

### Example: Installing Common Tools

```bash
# Update package lists first
sudo apt update

# Install development tools
sudo apt install -y htop tmux vim neovim tree fd-find ripgrep

# Install compression tools
sudo apt install -y zip unzip tar gzip

# Install network tools
sudo apt install -y net-tools curl wget httpie

# Install system monitoring tools
sudo apt install -y sysstat iotop nethogs
```

---

## Alternative Package Managers

### Snap

Snap is a universal package manager that works across many Linux distributions. Some software is only available via Snap.

```bash
# Search for packages
snap find <package-name>

# Install a package
sudo snap install <package-name>

# List installed snaps
snap list

# Remove a snap
sudo snap remove <package-name>

# Update all snaps
sudo snap refresh
```

### Common Snap Packages

```bash
# Code editors
sudo snap install code --classic           # VS Code
sudo snap install sublime-text --classic   # Sublime Text

# Communication tools
sudo snap install slack --classic

# Developer tools
sudo snap install docker
sudo snap install kubectl --classic
```

---

## Language-Specific Package Managers

### Python (pip)

Python 3 and pip are already installed on GoldenShell.

```bash
# Check versions
python3 --version
pip3 --version

# Install Python packages globally
sudo pip3 install <package-name>

# Install Python packages for current user only (recommended)
pip3 install --user <package-name>

# Create a virtual environment (best practice)
python3 -m venv myenv
source myenv/bin/activate
pip install <package-name>
```

### Node.js (npm)

Node.js and npm are already installed on GoldenShell.

```bash
# Check versions
node --version
npm --version

# Install packages globally (requires sudo)
sudo npm install -g <package-name>

# Install packages locally (in current directory)
npm install <package-name>

# Install packages from package.json
npm install
```

### Rust (cargo)

Install Rust and cargo using rustup:

```bash
# Install Rust (includes cargo)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Add to PATH (or restart shell)
source $HOME/.cargo/env

# Verify installation
rustc --version
cargo --version

# Install Rust packages
cargo install <package-name>
```

### Go

```bash
# Install Go
sudo apt update
sudo apt install -y golang-go

# Verify installation
go version

# Set up Go environment (add to ~/.bashrc)
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc

# Install Go packages
go install <package-url>
```

---

## Common Development Tools

### Essential Development Tools

```bash
# Build tools and compilers
sudo apt install -y build-essential gcc g++ make cmake

# Version control
sudo apt install -y git git-lfs

# Text editors
sudo apt install -y vim neovim emacs nano

# Terminal multiplexers
sudo apt install -y tmux screen

# Modern CLI tools
sudo apt install -y \
    bat \           # Better cat
    exa \           # Better ls
    fd-find \       # Better find
    ripgrep \       # Better grep
    fzf \           # Fuzzy finder
    jq \            # JSON processor
    httpie \        # Better curl
    tldr            # Simplified man pages
```

### Docker

```bash
# Install Docker
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Add current user to docker group (no sudo required)
sudo usermod -aG docker $USER

# Restart shell or run:
newgrp docker

# Verify
docker --version
docker run hello-world
```

### Database Clients

```bash
# PostgreSQL client
sudo apt install -y postgresql-client

# MySQL client
sudo apt install -y mysql-client

# MongoDB client
sudo apt install -y mongodb-clients

# Redis client
sudo apt install -y redis-tools

# SQLite
sudo apt install -y sqlite3
```

### Cloud CLIs

```bash
# AWS CLI (already installed via user-data)
aws --version

# Google Cloud SDK
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt update
sudo apt install -y google-cloud-cli

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y terraform
```

---

## Persistence Considerations

### Important Notes:

1. **User-Data Script Runs Once**: The GoldenShell user-data script uses an idempotency flag (`/var/lib/goldenshell-setup-complete`). It only runs on the first boot after instance creation.

2. **EBS Snapshots**: Your root volume is backed up daily (if backups are enabled). Any software installed will persist across instance stops/starts and will be included in snapshots.

3. **Installing After Initial Setup**: Software installed after the initial setup will persist on the EBS volume but won't be in the user-data script. To make installations reproducible:
   - Add installation commands to `user-data.sh` and destroy/recreate the instance, OR
   - Create a setup script in your home directory for manual installations

### Making Installations Reproducible

Option 1: Update user-data.sh (recommended for critical tools)

```bash
# Edit terraform/user-data.sh locally
# Add your installation commands
# Recreate the instance:
cd terraform
terraform destroy -target=aws_instance.goldenshell
terraform apply
```

Option 2: Create a personal setup script

```bash
# Create a setup script
cat > ~/setup-my-tools.sh << 'EOF'
#!/bin/bash
set -e

echo "Installing my custom tools..."

# Add your installation commands here
sudo apt update
sudo apt install -y <your-packages>

echo "Setup complete!"
EOF

chmod +x ~/setup-my-tools.sh

# Run it whenever needed
~/setup-my-tools.sh
```

---

## Troubleshooting

### Package Not Found

```bash
# Update package lists
sudo apt update

# Search for the package
apt search <package-name>

# Check if it's available in a PPA or snap
snap find <package-name>
```

### Permission Denied

```bash
# Most package installations require sudo
sudo apt install <package-name>

# For user-level installations, use --user flag
pip3 install --user <package-name>
npm install -g <package-name>  # This also needs sudo
```

### Disk Space Issues

```bash
# Check disk space
df -h

# Clean up APT cache
sudo apt clean
sudo apt autoclean
sudo apt autoremove

# Find large files
du -sh /* | sort -h
```

### Conflicting Packages

```bash
# Remove old package first
sudo apt remove <old-package>

# Or purge (removes config files)
sudo apt purge <old-package>

# Then install new package
sudo apt install <new-package>
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Update package lists | `sudo apt update` |
| Install package | `sudo apt install <package>` |
| Search for package | `apt search <keyword>` |
| Remove package | `sudo apt remove <package>` |
| Clean up unused packages | `sudo apt autoremove` |
| Install snap | `sudo snap install <package>` |
| Install Python package | `pip3 install --user <package>` |
| Install Node.js package | `npm install -g <package>` |
| Install Rust package | `cargo install <package>` |

---

## Pre-Installed Tools

GoldenShell comes with these tools pre-installed:

- **Version Control**: Git, GitHub CLI (`gh`)
- **Cloud**: AWS CLI, Tailscale
- **Development**: Node.js, npm, Python 3, pip
- **Editors**: Claude Code CLI (`claude`)
- **Terminal**: Zellij, ttyd (web terminal)
- **System**: curl, wget, jq, nginx, build-essential

---

## Need Help?

- APT documentation: `man apt`
- Ubuntu packages: https://packages.ubuntu.com/
- Snap store: https://snapcraft.io/store
- Node packages: https://www.npmjs.com/
- Python packages: https://pypi.org/

---

Last updated: 2025-10-07
