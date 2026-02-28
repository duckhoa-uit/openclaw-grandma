#!/bin/bash
# Daily backup of OpenClaw persistent data and grandma config
set -euo pipefail

GRANDMA_REPO="${GRANDMA_REPO:-/opt/openclaw-grandma}"
OPENCLAW_CONFIG="/root/.openclaw"
BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

echo "=== Backing up OpenClaw persistent data and grandma config ==="
tar -czf "$BACKUP_DIR/openclaw-backup-$DATE.tar.gz" \
  -C / \
  root/.openclaw/ \
  -C "$GRANDMA_REPO" \
  config/ \
  skills/ \
  .env.example

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "openclaw-backup-*.tar.gz" -mtime +7 -delete

echo "Backup saved to $BACKUP_DIR/openclaw-backup-$DATE.tar.gz"
