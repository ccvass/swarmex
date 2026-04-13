# User Guide — Deploying Apps on Swarmex

## Prerequisites

- Docker Swarm cluster with Swarmex deployed (all stacks: ingress, observability, security, storage, tools, swarmex)
- Access to the manager node via SSH
- Your app as a Docker image in a registry

## Quick Start

```yaml
# my-app.yml
version: "3.8"
services:
  web:
    image: registry.example.com/my-app:latest
    deploy:
      replicas: 2
      labels:
        # Traefik ingress
        traefik.enable: "true"
        traefik.http.routers.myapp.rule: "Host(`myapp.swarmex.apulab.info`)"
        traefik.http.routers.myapp.tls.certresolver: "le"
        traefik.http.services.myapp.loadbalancer.server.port: "8080"
      resources:
        limits:
          memory: 256M
          cpus: "0.5"
    labels:
      team: my-team
    networks:
      - traefik-public

networks:
  traefik-public:
    external: true
```

```bash
docker stack deploy -c my-app.yml --with-registry-auth my-app
```

## Swarmex Labels Reference

### Autoscaling (HPA)

```yaml
labels:
  swarmex.scaler.enabled: "true"
  swarmex.scaler.min: "2"
  swarmex.scaler.max: "10"
  swarmex.scaler.cpu-threshold: "70"    # scale up at 70% CPU
  swarmex.scaler.cooldown: "60"         # seconds between scale events
```

### Vertical Autoscaling (VPA)

```yaml
labels:
  swarmex.vpa.enabled: "true"
  swarmex.vpa.min-memory: "64M"
  swarmex.vpa.max-memory: "2G"
```

VPA adjusts CPU/memory limits based on actual usage (20% headroom).

### Readiness Gates

```yaml
labels:
  swarmex.gatekeeper.enabled: "true"
  swarmex.gatekeeper.probe-url: "http://localhost:8080/health"
  swarmex.gatekeeper.interval: "5"
```

Gatekeeper enables Traefik routing only after the service passes health checks.

### Blue/Green Deploys

```yaml
labels:
  swarmex.deployer.enabled: "true"
  swarmex.deployer.strategy: "blue-green"
  swarmex.deployer.green-image: "registry.example.com/my-app:v2"
```

### Secrets from OpenBao

```yaml
labels:
  swarmex.vault.enabled: "true"
  swarmex.vault.path: "secret/data/my-app"
  swarmex.vault.refresh: "300"          # seconds
```

Vault-sync reads secrets from OpenBao and writes them to `/run/secrets/swarmex/` inside the container.

### Namespace Isolation

```yaml
labels:
  swarmex.namespace: "production"
```

Creates an overlay network `ns-production` and attaches the service. Services in different namespaces cannot communicate unless allowed by netpolicy.

### Network Policies

```yaml
labels:
  swarmex.netpolicy.allow: "ns-frontend"   # allow traffic from frontend namespace
```

### Service Mesh (EasyTier)

```yaml
labels:
  swarmex.mesh.enabled: "true"
  swarmex.mesh.network: "my-mesh"
```

### Traffic Policies

```yaml
labels:
  swarmex.traffic.retry: "3"
  swarmex.traffic.rate-limit: "100"     # requests per second
  swarmex.traffic.circuit-breaker: "0.5" # open at 50% errors
```

### Database Operator

```yaml
labels:
  swarmex.operator.enabled: "true"
  swarmex.operator.type: "postgresql"
  swarmex.operator.port: "5432"
```

Monitors TCP health and triggers failover (force-update) on failure.

### Remediation

```yaml
labels:
  swarmex.remediation.enabled: "true"
  swarmex.remediation.failure-threshold: "5"
```

Escalation chain: restart container → force-update service → drain node (never drains last manager).

### Multi-Cluster Federation

```yaml
labels:
  swarmex.federation.replicate: "true"
```

Replicates the service to configured remote Swarm clusters.

## Admission Rules

Swarmex enforces admission rules on all new services:

- **require-memory-limit**: Services must have a memory limit set
- **require-team-label**: Services must have a `team` label
- **add-managed-by**: Automatically adds `managed-by: swarmex` label

Services that fail validation are automatically removed.

## Monitoring

- **Grafana**: `https://grafana.swarmex.apulab.info` — dashboards and log search
- **Prometheus**: Metrics from all services via cAdvisor
- **Loki**: Centralized logs from all containers via Promtail
- **AlertManager**: Alerts forwarded to webhook (configurable)

### Searching Logs

In Grafana → Explore → Loki:

```logql
{service="my-app_web"} |= "error"
```

## Troubleshooting

```bash
# Check service status
docker service ls --filter name=my-app

# Check why a service won't start
docker service ps my-app_web --no-trunc

# Check if admission denied your service
docker logs $(docker ps -q --filter name=swarmex_admission) --tail 10

# Check scaler decisions
docker logs $(docker ps -q --filter name=swarmex_scaler) --tail 10
```
