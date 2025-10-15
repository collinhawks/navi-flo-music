#!/bin/bash
set -e

echo "Starting restore process..."

# Restore from cloud storage
if rclone ls remote:navi-backup/data > /dev/null 2>&1; then
    echo "Downloading backup from cloud..."
    rclone sync remote:navi-backup/data /data --progress
    echo "Restore completed successfully"
else
    echo "No backup found in cloud storage"
    exit 1
fi
