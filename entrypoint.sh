#!/bin/bash
set -e

echo "Starting Navidrome with cloud storage..."

# Configure rclone based on environment variables
mkdir -p ~/.config/rclone

if [ ! -z "$RCLONE_CONFIG_BASE64" ]; then
    echo "Decoding base64 rclone config..."
    echo "$RCLONE_CONFIG_BASE64" | base64 -d > ~/.config/rclone/rclone.conf
    echo "Rclone configured successfully from base64"
elif [ ! -z "$RCLONE_CONFIG" ]; then
    echo "Writing rclone config..."
    printf "%s" "$RCLONE_CONFIG" > ~/.config/rclone/rclone.conf
    echo "Rclone configured successfully"
else
    echo "ERROR: Neither RCLONE_CONFIG nor RCLONE_CONFIG_BASE64 environment variable is set"
    exit 1
fi

# Verify config file was created
if [ ! -f ~/.config/rclone/rclone.conf ]; then
    echo "ERROR: Failed to create rclone config file"
    exit 1
fi

echo "Rclone config file size: $(wc -c < ~/.config/rclone/rclone.conf) bytes"

# Test rclone connection with explicit config
echo "Testing rclone connection..."
if ! rclone --config ~/.config/rclone/rclone.conf lsd remote: --max-depth 1 2>&1; then
    echo "ERROR: Failed to connect to remote storage"
    echo "Config contents (first 100 chars):"
    head -c 100 ~/.config/rclone/rclone.conf
    exit 1
fi
echo "Rclone connection successful"

# Check if this is first run or if previous backup is incomplete
FIRST_RUN=false
if ! rclone --config ~/.config/rclone/rclone.conf ls remote:navi/navi-backup/data/.initialized > /dev/null 2>&1; then
    echo "First run detected - no backup found"
    FIRST_RUN=true
    # Create marker file
    touch /tmp/.initialized
    rclone --config ~/.config/rclone/rclone.conf copy /tmp/.initialized remote:navi/navi-backup/data/
elif ! rclone --config ~/.config/rclone/rclone.conf ls remote:navi/navi-backup/data/.backup_done > /dev/null 2>&1; then
    echo "Previous backup incomplete - skipping restore"
    FIRST_RUN=true  # Treat as first run to avoid restoring incomplete backup
else
    echo "Previous backup found - restoring data"
    /scripts/restore.sh
fi

# Sync music from cloud storage
echo "Syncing music library from cloud..."
rclone --config ~/.config/rclone/rclone.conf sync remote:navi/navi-music /music --transfers 8 --checkers 16 --progress

# Only backup if not first run
if [ "$FIRST_RUN" = false ]; then
    echo "Creating backup before starting..."
    /scripts/backup.sh
fi

echo "Starting Navidrome..."
exec /app/navidrome --configfile /data/navidrome.toml
