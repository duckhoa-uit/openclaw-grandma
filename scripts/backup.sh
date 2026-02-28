#!/bin/bash
# Daily backup of browser profiles and configuration
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="/home/openclaw/backups"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

echo "=== Backing up browser profiles and config ==="
tar -czf "$BACKUP_DIR/openclaw-backup-$DATE.tar.gz" \
  -C "$PROJECT_DIR" \
  browser-profiles/ \
  config/ \
  skills/ \
  .env \
  docker-compose.yml

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "openclaw-backup-*.tar.gz" -mtime +7 -delete

echo "Backup saved to $BACKUP_DIR/openclaw-backup-$DATE.tar.gz"
