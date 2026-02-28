#!/bin/bash
# VPS Base Setup Script for OpenClaw Grandmother Assistant
# Run this on a fresh Ubuntu 22.04 VPS (Contabo VPS S, Singapore DC)
set -euo pipefail

echo "=== Updating system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"

echo "=== Installing Caddy (reverse proxy + auto HTTPS) ==="
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy

echo "=== Creating dedicated openclaw user ==="
sudo useradd -m -s /bin/bash openclaw || echo "User openclaw already exists"
sudo usermod -aG docker openclaw

echo "=== Setting up firewall (UFW) ==="
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 443/tcp   # HTTPS (Zalo webhook)
sudo ufw --force enable

echo "=== Disabling SSH password auth ==="
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

echo "=== Base setup complete ==="
echo ""
echo "Next steps:"
echo "1. Copy the openclaw-grandma project to /home/openclaw/openclaw-grandma"
echo "2. Copy .env.example to .env and fill in your API keys"
echo "3. Run: scripts/deploy.sh"
