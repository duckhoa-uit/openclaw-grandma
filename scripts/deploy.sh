#!/bin/bash
# Deploy OpenClaw Grandma on Hetzner VPS (official Docker deployment)
# Run this script from the openclaw-grandma repo directory.
# Requires: OpenClaw repo cloned at /opt/openclaw (or set OPENCLAW_REPO)
set -euo pipefail

GRANDMA_REPO="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLAW_REPO="${OPENCLAW_REPO:-/opt/openclaw}"

echo "=== Checking prerequisites ==="
if [ ! -f "$OPENCLAW_REPO/docker-compose.yml" ]; then
  echo "ERROR: OpenClaw repo not found at $OPENCLAW_REPO"
  echo "Clone it first: git clone https://github.com/openclaw/openclaw.git $OPENCLAW_REPO"
  echo "Or set OPENCLAW_REPO to the correct path."
  exit 1
fi

cd "$OPENCLAW_REPO"

if [ ! -f .env ]; then
  echo "ERROR: .env file not found in $OPENCLAW_REPO."
  echo "Copy .env.example to .env and fill in your keys."
  exit 1
fi

echo "=== Copying grandma config files ==="
PERSISTENT_DIR="/root/.openclaw"

# Copy config files (gateway.yaml, models.providers.json, system-prompt.md)
mkdir -p "$PERSISTENT_DIR"
cp -v "$GRANDMA_REPO/config/gateway.yaml" "$PERSISTENT_DIR/" 2>/dev/null || true
cp -v "$GRANDMA_REPO/config/models.providers.json" "$PERSISTENT_DIR/" 2>/dev/null || true
cp -v "$GRANDMA_REPO/config/system-prompt.md" "$PERSISTENT_DIR/workspace/" 2>/dev/null || true

# Copy Caddyfile to system Caddy config (optional — only needed for webhook mode)
if [ -f "$GRANDMA_REPO/config/Caddyfile" ]; then
  sudo cp -v "$GRANDMA_REPO/config/Caddyfile" /etc/caddy/Caddyfile
  echo "(Caddy config copied — only needed if you switch Zalo to webhook mode)"
fi

# Copy custom Vietnamese skills to workspace
mkdir -p "$PERSISTENT_DIR/workspace/skills"
cp -v "$GRANDMA_REPO/skills/"* "$PERSISTENT_DIR/workspace/skills/" 2>/dev/null || true

# Clean up any user-installed Zalo plugin (use bundled one from /app/extensions/zalo)
# The bundled plugin has all deps (zod etc.); user-installed copies don't.
echo "=== Cleaning up duplicate Zalo plugin ==="
rm -rf "$PERSISTENT_DIR/extensions/zalo" 2>/dev/null || true

# Remove stale Zalo install metadata from openclaw.json if present
if [ -f "$PERSISTENT_DIR/openclaw.json" ] && command -v jq &>/dev/null; then
  if jq -e '.plugins.installs.zalo' "$PERSISTENT_DIR/openclaw.json" &>/dev/null; then
    echo "Removing stale plugins.installs.zalo from openclaw.json"
    jq 'del(.plugins.installs.zalo)' "$PERSISTENT_DIR/openclaw.json" > /tmp/oc-clean.json \
      && mv /tmp/oc-clean.json "$PERSISTENT_DIR/openclaw.json"
  fi
fi

# Ensure correct ownership for container user (uid 1000)
chown -R 1000:1000 "$PERSISTENT_DIR"

echo "=== Starting OpenClaw gateway ==="
docker compose up -d openclaw-gateway

echo "=== Waiting for OpenClaw to start ==="
sleep 15

echo "=== Installing Playwright browsers ==="
docker compose run --rm openclaw-cli node /app/node_modules/playwright-core/cli.js install chromium

echo "=== Installing official skills ==="
# Browser skills
docker compose exec openclaw-gateway openclaw skills install @openclaw/browser-use
docker compose exec openclaw-gateway openclaw skills install @openclaw/autofillin
docker compose exec openclaw-gateway openclaw skills install @openclaw/browser-automation

# Office/document skills
docker compose exec openclaw-gateway openclaw skills install @openclaw/office-to-md
docker compose exec openclaw-gateway openclaw skills install @openclaw/pdf-converter
docker compose exec openclaw-gateway openclaw skills install @openclaw/pdf-extraction
docker compose exec openclaw-gateway openclaw skills install @openclaw/md-to-office
docker compose exec openclaw-gateway openclaw skills install @openclaw/template-engine

# Utility skills
docker compose exec openclaw-gateway openclaw skills install @openclaw/file-links-tool

# Install markitdown dependency for office-to-md
docker compose exec openclaw-gateway pip install 'markitdown[all]'

echo "=== Verifying skills ==="
docker compose exec openclaw-gateway openclaw skills list

echo "=== Starting persistent browser ==="
docker compose exec openclaw-gateway openclaw browser start --profile grandma --keep-alive

echo "=== Deployment complete ==="
echo ""
echo "OpenClaw gateway is running on port 18789 (localhost only)."
echo ""
echo "Next steps:"
echo "1. Pair grandmother's Zalo: have her message the bot, then run:"
echo "   docker compose exec openclaw-gateway openclaw pairing approve zalo <CODE>"
echo "2. Set up browser credentials: $GRANDMA_REPO/scripts/setup-credentials.sh"
echo "3. Test with: $GRANDMA_REPO/scripts/test-vietnamese.sh"
echo ""
echo "Access from your machine via SSH tunnel:"
echo "  ssh -N -L 18789:127.0.0.1:18789 root@your-vps-ip"
echo "  Then open: http://localhost:18789"
