FROM deluan/navidrome:latest

# Install rclone for cloud storage access
RUN apk add --no-cache rclone curl bash

# Create necessary directories
RUN mkdir -p /data /music /scripts

# Copy scripts
COPY entrypoint.sh /scripts/entrypoint.sh
COPY backup.sh /scripts/backup.sh
COPY restore.sh /scripts/restore.sh

## Copy navidrome.toml into /data
#COPY navidrome.toml /data/navidrome.toml

# Copy navidrome.toml to /app (not /data, since /data is a volume)
COPY navidrome.toml /app/navidrome.toml

# Copy the custom placeholder image to the location checked by entrypoint.sh
COPY album-placeholder.webp /app/album-placeholder.webp

# Make scripts executable
RUN chmod +x /scripts/*.sh

# Set working directory
WORKDIR /app

# Use custom entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
