#!/usr/bin/env bash
set -euo pipefail

# Clone all swarmex sub-repos alongside the coordinator
BASE="git@scovil.labtau.com:ccvass/swarmex"
DIR="$(cd "$(dirname "$0")/.." && pwd)"

repos=(
  # Custom services
  swarmex-event-controller
  swarmex-scaler
  swarmex-gatekeeper
  swarmex-operator-db
  swarmex-vault-sync
  swarmex-nano-mesh
  swarmex-remediation
  swarmex-deployer
  # Forked OSS - Tier 1
  coolify
  portainer-ce
  easytier
  swarmpit
  swarm-cronjob
  swarm-cd
  gantry
  # Forked OSS - Tier 2
  swarm-autoscaler
  swarm-sync
  promswarm
  swarm-monitoring
  seaweedfs-swarm
  seaweedfs-volume-plugin
  # Forked OSS - Tier 3
  hca
)

echo "Cloning ${#repos[@]} repos into parent directory..."
cd "$DIR/.."

for repo in "${repos[@]}"; do
  if [ -d "$repo" ]; then
    echo "  ✓ $repo (exists)"
  else
    echo "  ↓ $repo"
    git clone "$BASE/$repo.git" 2>/dev/null && echo "    done" || echo "    FAILED"
  fi
done

echo ""
echo "All repos cloned. Each is an independent git repo."
