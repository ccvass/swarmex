#!/usr/bin/env bash
set -euo pipefail

# Install SeaweedFS FUSE mount on a Swarm node.
# Run this on EVERY node (managers and workers) AFTER the storage stack is running.
#
# Usage: bash scripts/setup-seaweedfs-mount.sh [filer_address]
#
# This creates /mnt/swarmex as a shared filesystem backed by SeaweedFS.
# All services can use bind mounts to /mnt/swarmex/<service-name> for persistence.

FILER=${1:-storage_seaweedfs-filer:8888}
MOUNT_POINT=/mnt/swarmex

echo "Setting up SeaweedFS FUSE mount..."

# Install weed binary if not present
if ! command -v weed &>/dev/null; then
  echo "Installing SeaweedFS client..."
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
  esac
  WEED_VERSION=$(curl -sf https://api.github.com/repos/seaweedfs/seaweedfs/releases/latest | grep tag_name | cut -d'"' -f4)
  curl -sL "https://github.com/seaweedfs/seaweedfs/releases/download/${WEED_VERSION}/linux_${ARCH}_full.tar.gz" | tar xz -C /usr/local/bin weed
  echo "  ✓ weed ${WEED_VERSION} installed"
fi

# Create mount point
mkdir -p "$MOUNT_POINT"

# Create systemd service for persistent mount
cat > /etc/systemd/system/seaweedfs-mount.service << EOF
[Unit]
Description=SeaweedFS FUSE Mount
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/weed mount -filer=${FILER} -dir=${MOUNT_POINT} -filer.path=/ -allowOthers
ExecStop=/bin/fusermount -u ${MOUNT_POINT}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable seaweedfs-mount
systemctl start seaweedfs-mount

sleep 3
if mountpoint -q "$MOUNT_POINT"; then
  echo "  ✓ SeaweedFS mounted at $MOUNT_POINT"
else
  echo "  ✗ Mount failed — is the storage stack running?"
  echo "    Check: systemctl status seaweedfs-mount"
  exit 1
fi

echo ""
echo "Services can now use bind mounts:"
echo "  volumes:"
echo "    - /mnt/swarmex/my-service:/data"
echo ""
echo "Data is replicated across SeaweedFS volume servers."
