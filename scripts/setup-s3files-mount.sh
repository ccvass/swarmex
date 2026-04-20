#!/usr/bin/env bash
set -euo pipefail

# Mount AWS S3 Files as shared storage for Swarmex services.
# Run this on EVERY node (managers and workers).
#
# Usage: bash scripts/setup-s3files-mount.sh <filesystem-id>
#
# Prerequisites:
#   - AWS S3 Files filesystem created and linked to your S3 bucket
#   - Mount targets provisioned in your VPC
#   - IAM role on EC2 instances with s3:* permissions on the bucket
#   - amazon-efs-utils installed (for s3files mount type)
#
# This creates /mnt/swarmex backed by S3 Files.
# All services use bind mounts to /mnt/swarmex/<service-name> for persistence.
# Data syncs to S3 automatically (typically within 60 seconds).

FS_ID=${1:-}
MOUNT_POINT=/mnt/swarmex

if [ -z "$FS_ID" ]; then
  echo "Usage: $0 <filesystem-id>"
  echo "  Example: $0 fs-0123456789abcdef"
  echo ""
  echo "Create a filesystem first:"
  echo "  aws s3api create-file-system --bucket my-bucket --region us-east-1"
  exit 1
fi

echo "Setting up S3 Files mount..."

# Install mount helper if not present
if ! command -v mount.s3files &>/dev/null; then
  echo "Installing amazon-efs-utils..."
  if command -v apt-get &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq amazon-efs-utils
  elif command -v yum &>/dev/null; then
    yum install -y amazon-efs-utils
  fi
  echo "  ✓ amazon-efs-utils installed"
fi

# Create mount point
mkdir -p "$MOUNT_POINT"

# Create systemd service for persistent mount
cat > /etc/systemd/system/s3files-mount.service << EOF
[Unit]
Description=S3 Files Mount for Swarmex
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/sbin/mount.s3files ${FS_ID}:/ ${MOUNT_POINT} -o tls
ExecStop=/bin/umount ${MOUNT_POINT}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable s3files-mount
systemctl start s3files-mount

sleep 5
if mountpoint -q "$MOUNT_POINT"; then
  echo "  ✓ S3 Files mounted at $MOUNT_POINT (filesystem: $FS_ID)"
else
  echo "  ✗ Mount failed"
  echo "    Check: systemctl status s3files-mount"
  echo "    Verify: mount targets exist in your VPC"
  exit 1
fi

echo ""
echo "Services can now use bind mounts:"
echo "  volumes:"
echo "    - /mnt/swarmex/my-service:/data"
echo ""
echo "Data persists in S3. Sub-millisecond latency for cached files."
echo "Changes sync to S3 within ~60 seconds."
