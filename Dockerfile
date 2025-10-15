FROM deluan/navidrome:latest

# Install rclone for cloud storage access
RUN apk add --no-cache rclone curl bash

# Create necessary directories
RUN mkdir -p /data /music /scripts

# Copy scripts
COPY entrypoint.sh /scripts/entrypoint.sh
COPY backup.sh /scripts/backup.sh
COPY restore.sh /scripts/restore.sh

# Make scripts executable
RUN chmod +x /scripts/*.sh

# Set working directory
WORKDIR /app

# Use custom entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
