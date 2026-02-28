#!/bin/bash
# Deploy OpenClaw with all skills and configuration
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Checking .env ==="
if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in your keys."
  exit 1
fi

echo "=== Starting OpenClaw ==="
docker compose up -d openclaw

echo "=== Waiting for OpenClaw to start ==="
sleep 10

echo "=== Installing Zalo plugin ==="
docker exec openclaw openclaw plugins install @openclaw/zalo

echo "=== Installing official skills ==="
# Browser skills
docker exec openclaw openclaw skills install @openclaw/browser-use
docker exec openclaw openclaw skills install @openclaw/autofillin
docker exec openclaw openclaw skills install @openclaw/browser-automation

# Office/document skills
docker exec openclaw openclaw skills install @openclaw/office-to-md
docker exec openclaw openclaw skills install @openclaw/pdf-converter
docker exec openclaw openclaw skills install @openclaw/pdf-extraction
docker exec openclaw openclaw skills install @openclaw/md-to-office
docker exec openclaw openclaw skills install @openclaw/template-engine

# Utility skills
docker exec openclaw openclaw skills install @openclaw/file-links-tool

# Install markitdown dependency for office-to-md
docker exec openclaw pip install 'markitdown[all]'

echo "=== Verifying skills ==="
docker exec openclaw openclaw skills list

echo "=== Starting persistent browser ==="
docker exec openclaw openclaw browser start --profile grandma --keep-alive

echo "=== Deployment complete ==="
echo ""
echo "OpenClaw is running on port 3000."
echo ""
echo "Next steps:"
echo "1. Configure Caddy: sudo cp config/Caddyfile /etc/caddy/Caddyfile"
echo "2. Reload Caddy: sudo systemctl reload caddy"
echo "3. Set up credentials: scripts/setup-credentials.sh"
echo "4. Test with: scripts/test-vietnamese.sh"
