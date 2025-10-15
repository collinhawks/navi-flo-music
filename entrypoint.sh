#!/bin/bash
set -e

echo "Starting Navidrome with cloud storage..."

# Configure rclone based on environment variables
mkdir -p ~/.config/rclone

if [ ! -z "$RCLONE_CONFIG" ]; then
    # Write the config to file, handling multiline content properly
    printf "%s\n" "$RCLONE_CONFIG" > ~/.config/rclone/rclone.conf
    echo "Rclone configured successfully"
    echo "Config file contents:"
    cat ~/.config/rclone/rclone.conf
else
    echo "ERROR: RCLONE_CONFIG environment variable not set"
    exit 1
fi

# Check if this is first run (marker file doesn't exist in cloud)
FIRST_RUN=false
if ! rclone ls remote:navi-backup/data/.initialized > /dev/null 2>&1; then
    echo "First run detected - no backup found"
    FIRST_RUN=true
    # Create marker file
    touch /tmp/.initialized
    rclone copy /tmp/.initialized remote:navi-backup/data/
else
    echo "Previous backup found - restoring data"
    /scripts/restore.sh
fi

# Sync music from cloud storage
echo "Syncing music library from cloud..."
rclone sync remote:navi-music /music --transfers 8 --checkers 16 --progress

# Only backup if not first run
if [ "$FIRST_RUN" = false ]; then
    echo "Creating backup before starting..."
    /scripts/backup.sh
fi

echo "Starting Navidrome..."
exec /app/navidrome --configfile /data/navidrome.toml
