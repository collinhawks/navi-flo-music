#!/bin/bash
set -e

echo "Starting backup process..."

# ---- 1️⃣ Ensure rclone config exists ----
mkdir -p ~/.config/rclone
if [ ! -z "$RCLONE_CONFIG_BASE64" ]; then
    echo "Decoding base64 rclone config for backup..."
    echo "$RCLONE_CONFIG_BASE64" | base64 -d > ~/.config/rclone/rclone.conf
elif [ ! -z "$RCLONE_CONFIG" ]; then
    echo "Writing plain rclone config for backup..."
    printf "%s" "$RCLONE_CONFIG" > ~/.config/rclone/rclone.conf
else
    echo "ERROR: Neither RCLONE_CONFIG_BASE64 nor RCLONE_CONFIG is set"
    exit 1
fi

# Verify config file exists
if [ ! -f ~/.config/rclone/rclone.conf ]; then
    echo "ERROR: Failed to create rclone config file"
    exit 1
fi
echo "Rclone config ready: $(wc -c < ~/.config/rclone/rclone.conf) bytes"

# ---- 2️⃣ Backup process ----
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/backup_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

if [ -d "/data" ]; then
    echo "Backing up Navidrome data..."
    cp -r /data "$BACKUP_DIR/"

    echo "Uploading backup to cloud..."
    rclone --config ~/.config/rclone/rclone.conf sync "$BACKUP_DIR/data" remote:navi/navi-backup/data --progress

    echo "Copying timestamped backup..."
    rclone --config ~/.config/rclone/rclone.conf copy "$BACKUP_DIR/data" "remote:navi/navi-backup/backups/$TIMESTAMP" --progress

    # Cleanup old backups (keep last 3)
    rclone --config ~/.config/rclone/rclone.conf lsf remote:navi/navi-backup/backups --dirs-only | sort -r | tail -n +4 | while read dir; do
        echo "Removing old backup: $dir"
        rclone --config ~/.config/rclone/rclone.conf purge "remote:navi/navi-backup/backups/$dir"
    done

    # ✅ Mark backup done
    touch /tmp/.backup_done
    rclone --config ~/.config/rclone/rclone.conf copy /tmp/.backup_done remote:navi/navi-backup/data/
else
    echo "No data directory found to backup"
fi

# Cleanup temp directory
rm -rf "$BACKUP_DIR"

echo "Backup process finished"
