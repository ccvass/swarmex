#!/usr/bin/env bash
set -euo pipefail

# Pre-deploy: create shared overlay networks before any stack is deployed.
# Run this ONCE on a Swarm manager node.

networks=(traefik-public monitoring security storage)

for net in "${networks[@]}"; do
  if docker network inspect "$net" >/dev/null 2>&1; then
    echo "  ✓ $net (exists)"
  else
    docker network create --driver overlay --attachable "$net"
    echo "  + $net (created)"
  fi
done

echo ""
echo "Shared networks ready. Deploy stacks in order:"
echo "  1. docker stack deploy -c stacks/ingress.yml ingress"
echo "  2. docker stack deploy -c stacks/observability.yml observability"
echo "  3. docker stack deploy -c stacks/security.yml security"
echo "  4. docker stack deploy -c stacks/tools.yml tools"
echo "  5. docker stack deploy -c stacks/storage.yml storage"
echo "  6. docker stack deploy -c stacks/swarmex.yml swarmex"
