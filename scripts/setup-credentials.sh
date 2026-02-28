#!/bin/bash
# Start noVNC for manual credential setup
# Access via browser at http://your-vps-ip:6080
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLAW_REPO="${OPENCLAW_REPO:-/opt/openclaw}"
cd "$OPENCLAW_REPO"

ACTION="${1:-start}"

case "$ACTION" in
  start)
    echo "=== Starting noVNC for manual credential setup ==="
    echo "WARNING: noVNC exposes a desktop on port 6080. Stop it when done!"
    echo ""
    docker compose --profile setup up -d novnc
    echo ""
    echo "noVNC is running. Open http://YOUR-VPS-IP:6080 in your browser."
    echo "Log into all grandmother's accounts in the Chrome window."
    echo ""
    echo "When done, run: $0 stop"
    ;;
  stop)
    echo "=== Stopping noVNC ==="
    docker compose --profile setup down
    echo "noVNC stopped. Browser sessions are saved in the persistent profile."
    ;;
  *)
    echo "Usage: $0 [start|stop]"
    exit 1
    ;;
esac
