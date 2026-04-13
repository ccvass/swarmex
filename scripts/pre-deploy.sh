#!/usr/bin/env bash
set -euo pipefail

# Pre-deploy: create shared overlay networks and Docker configs.
# Run this ONCE on a Swarm manager node from the swarmex-coordinator directory.

echo "Creating overlay networks..."
for net in traefik-public monitoring security storage swarmex_swarmex; do
  if docker network inspect "$net" >/dev/null 2>&1; then
    echo "  ✓ $net (exists)"
  else
    docker network create --driver overlay --attachable "$net"
    echo "  + $net (created)"
  fi
done

echo ""
echo "Creating Docker configs..."

create_config() {
  local name=$1 file=$2
  if docker config inspect "$name" >/dev/null 2>&1; then
    echo "  ✓ $name (exists)"
  else
    docker config create "$name" "$file"
    echo "  + $name (created)"
  fi
}

# Prometheus
[ -f configs/prometheus/prometheus.yml ] && create_config prometheus-config configs/prometheus/prometheus.yml
[ -f configs/prometheus/alerts.yml ] && create_config prometheus-alerts configs/prometheus/alerts.yml

# Grafana
[ -f configs/grafana/datasources.yaml ] && create_config grafana-datasources configs/grafana/datasources.yaml

# Loki
[ -f configs/loki/config.yaml ] && create_config loki-config configs/loki/config.yaml

# Tempo
[ -f configs/tempo/config.yaml ] && create_config tempo-config configs/tempo/config.yaml

# Promtail
[ -f configs/promtail/config.yaml ] && create_config promtail-config configs/promtail/config.yaml

# AlertManager
[ -f configs/alertmanager/alertmanager.yml ] && create_config alertmanager-config configs/alertmanager/alertmanager.yml

# Admission
[ -f configs/admission/rules.yaml ] && create_config admission-rules configs/admission/rules.yaml

# OpenBao
[ -f configs/openbao/config.hcl ] && create_config openbao-config configs/openbao/config.hcl

# SeaweedFS
[ -f configs/seaweedfs/master-entrypoint.sh ] && create_config seaweedfs-entrypoint configs/seaweedfs/master-entrypoint.sh

# swarm-cd
[ -f configs/swarmcd/repos.yaml ] && create_config swarmcd-repos configs/swarmcd/repos.yaml

echo ""
echo "Ready. Deploy stacks in order:"
echo "  1. docker stack deploy -c stacks/ingress.yml --with-registry-auth ingress"
echo "  2. docker stack deploy -c stacks/observability.yml --with-registry-auth observability"
echo "  3. docker stack deploy -c stacks/security.yml --with-registry-auth security"
echo "  4. docker stack deploy -c stacks/storage.yml --with-registry-auth storage"
echo "  5. docker stack deploy -c stacks/tools.yml --with-registry-auth tools"
echo "  6. docker stack deploy -c stacks/swarmex.yml --with-registry-auth swarmex"
