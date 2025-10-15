#!/bin/bash
set -e

echo "Starting backup process..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/backup_$TIMESTAMP"

# Create temporary backup directory
mkdir -p "$BACKUP_DIR"

# Backup Navidrome data directory (contains database and config)
if [ -d "/data" ]; then
    echo "Backing up Navidrome data..."
    cp -r /data "$BACKUP_DIR/"
    
    # Upload to cloud storage
    echo "Uploading backup to cloud..."
    rclone sync "$BACKUP_DIR/data" remote:navi/navi-backup/data --progress
    
    # Keep last 3 timestamped backups for safety
    rclone copy "$BACKUP_DIR/data" "remote:navi/navi-backup/backups/$TIMESTAMP" --progress
    
    echo "Backup completed successfully"
    
    # Cleanup old backups (keep last 3)
    rclone lsf remote:navi/navi-backup/backups --dirs-only | sort -r | tail -n +4 | while read dir; do
        echo "Removing old backup: $dir"
        rclone purge "remote:navi/navi-backup/backups/$dir"
    done

    # ✅ Create marker that backup finished
    touch /tmp/.backup_done
    rclone --config ~/.config/rclone/rclone.conf copy /tmp/.backup_done remote:navi/navi-backup/data/
else
    echo "No data directory found to backup"
fi

# Cleanup temporary directory
rm -rf "$BACKUP_DIR"

echo "Backup process finished"
