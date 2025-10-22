#!/bin/bash
set -e

echo "Starting Navidrome with cloud storage..."

# Configure rclone
mkdir -p ~/.config/rclone
if [ ! -z "$RCLONE_CONFIG_BASE64" ]; then
    echo "$RCLONE_CONFIG_BASE64" | base64 -d > ~/.config/rclone/rclone.conf
elif [ ! -z "$RCLONE_CONFIG" ]; then
    printf "%s" "$RCLONE_CONFIG" > ~/.config/rclone/rclone.conf
else
    echo "ERROR: Neither RCLONE_CONFIG nor RCLONE_CONFIG_BASE64 is set"
    exit 1
fi

echo "Rclone config ready: $(wc -c < ~/.config/rclone/rclone.conf) bytes"

# Test rclone connection
echo "Testing rclone connection..."
if ! rclone --config ~/.config/rclone/rclone.conf lsd remote: --max-depth 1; then
    echo "ERROR: Cannot connect to remote"
    exit 1
fi
echo "Rclone connection successful"

# Sync music library
echo "Syncing music library from cloud..."
rclone --config ~/.config/rclone/rclone.conf sync remote:navi/navi-music /music --transfers 8 --checkers 16 --progress

# -------------------------
# Restore database if missing
# -------------------------
if [ ! -f /data/navidrome.db ]; then
    echo "Database not found, restoring from cloud backup..."
    rclone --config ~/.config/rclone/rclone.conf sync remote:navi/navi-backup/data /data --progress
fi

# -------------------------
# Override Navidrome placeholder image from repo
# -------------------------
if [ -f /app/album-placeholder.webp ]; then
    echo "Replacing default album placeholder from repo..."
# CREATE the directory just in case it's not ready yet
    mkdir -p /app/resources/
    cp /app/album-placeholder.webp /app/resources/album-placeholder.webp
else
    echo "Custom album placeholder not found at /app/resources/album-placeholder.webp"
fi

# Start Navidrome in background
echo "Starting Navidrome..."
/app/navidrome --configfile /data/navidrome.toml &
NAV_PID=$!

# -------------------------
# First user detection & initial backup
# -------------------------
echo "Waiting for first admin user..."
while ! sqlite3 /data/navidrome.db "SELECT COUNT(*) FROM user;" | grep -q '[1-9]'; do
    sleep 5
done

echo "First user detected - running initial backup..."
/scripts/backup.sh
# Mark backup as done
touch /tmp/.backup_done
rclone --config ~/.config/rclone/rclone.conf copy /tmp/.backup_done remote:navi/navi-backup/data/

# -------------------------
# Periodic backup loop
# -------------------------
echo "Starting periodic backup scheduler..."
while kill -0 $NAV_PID 2>/dev/null; do
    # Count existing timestamped backups in cloud
    BACKUP_COUNT=$(rclone --config ~/.config/rclone/rclone.conf lsf remote:navi/navi-backup/backups | wc -l)
    
    if [ "$BACKUP_COUNT" -lt 3 ]; then
        SLEEP_TIME=240      # 4 minutes
    else
        SLEEP_TIME=3600     # 1 hour
    fi

    sleep $SLEEP_TIME
    echo "Running periodic backup..."
    /scripts/backup.sh
done
