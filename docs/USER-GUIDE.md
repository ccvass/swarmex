# Swarmex User Guide

Complete guide from cluster setup to deploying and operating applications on Swarmex.

## Table of Contents

1. [Infrastructure Setup](#1-infrastructure-setup)
2. [Installing Docker Swarm](#2-installing-docker-swarm)
3. [Deploying Swarmex](#3-deploying-swarmex)
4. [Verifying the Installation](#4-verifying-the-installation)
5. [Deploying Your First App](#5-deploying-your-first-app)
6. [Configuring Autoscaling](#6-configuring-autoscaling)
7. [Namespace Isolation and Network Policies](#7-namespace-isolation-and-network-policies)
8. [Secret Management](#8-secret-management)
9. [Blue/Green Deployments](#9-bluegreen-deployments)
10. [Database Workloads](#10-database-workloads)
11. [Traffic Policies](#11-traffic-policies)
12. [Multi-Cluster Federation](#12-multi-cluster-federation)
13. [Monitoring and Logging](#13-monitoring-and-logging)
14. [Backup and Restore](#14-backup-and-restore)
15. [Admission Rules](#15-admission-rules)
16. [RBAC and Authentication](#16-rbac-and-authentication)
17. [Updating Swarmex](#17-updating-swarmex)
18. [Troubleshooting](#18-troubleshooting)

## 1. Infrastructure Setup

### Requirements

| Resource | Minimum | Recommended |
|:---|:---|:---|
| Nodes | 1 (single node) | 3+ (1 manager + 2 workers) |
| RAM per node | 4 GB | 8 GB |
| CPU per node | 2 vCPU | 4 vCPU |
| Disk per node | 20 GB | 50 GB SSD |
| OS | Ubuntu 22.04+ / Debian 12+ | Ubuntu 24.04 LTS |
| Docker | 24.0+ | 29.x (latest) |

### Network Ports

Open these ports between all Swarm nodes:

| Port | Protocol | Purpose |
|:---|:---|:---|
| 2377 | TCP | Swarm cluster management |
| 7946 | TCP + UDP | Node communication |
| 4789 | UDP | Overlay network (VXLAN) |

Open these ports to the internet (on the manager/ingress node):

| Port | Protocol | Purpose |
|:---|:---|:---|
| 80 | TCP | HTTP (redirects to HTTPS) |
| 443 | TCP | HTTPS (Traefik) |

### DNS

Point your domain and wildcard to the manager node's public IP:

```
swarmex.example.com    → <manager-public-ip>
*.swarmex.example.com  → <manager-public-ip>
```

This enables automatic subdomain routing for all services (e.g., `grafana.swarmex.example.com`, `portainer.swarmex.example.com`).

## 2. Installing Docker Swarm

### Install Docker on All Nodes

```bash
# On each node
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group to take effect
```

### Initialize the Swarm (Manager Node)

```bash
docker swarm init --advertise-addr <manager-private-ip>
```

This outputs a join token. Save it.

### Join Worker Nodes

```bash
# On each worker node, paste the join command from above
docker swarm join --token SWMTKN-1-xxxxx <manager-private-ip>:2377
```

### Verify

```bash
docker node ls
# Should show all nodes as Ready/Active
```

## 3. Deploying Swarmex

### Clone the Repository

```bash
git clone git@scovil.labtau.com:ccvass/swarmex/swarmex-coordinator.git
cd swarmex-coordinator
```

### Login to Container Registry

On every node:

```bash
echo "<deploy-token-password>" | docker login registry.labtau.com \
  -u "gitlab+deploy-token-409" --password-stdin
```

### Create Networks and Configs

```bash
bash scripts/pre-deploy.sh
```

This creates the overlay networks (`monitoring`, `traefik-public`, `security`, `swarmex_swarmex`) and Docker configs from the `configs/` directory.

### Create Docker Secrets

```bash
# Authentik
echo -n "<db-password>" | docker secret create authentik_db_password -
echo -n "<secret-key>" | docker secret create authentik_secret_key -

# OpenBao
echo -n "<root-token>" | docker secret create openbao_root_token -
echo -n "<unseal-key>" | docker secret create openbao_unseal_key -
```

### Deploy Stacks (In Order)

The order matters — each stack depends on the previous ones.

```bash
# 1. Ingress (Traefik — SSL termination, routing)
docker stack deploy -c stacks/ingress.yml --with-registry-auth ingress

# 2. Observability (Prometheus, Grafana, Loki, Tempo, Promtail)
docker stack deploy -c stacks/observability.yml --with-registry-auth observability

# 3. Security (Authentik SSO, OpenBao secrets)
docker stack deploy -c stacks/security.yml --with-registry-auth security

# 4. Storage (SeaweedFS distributed storage)
docker stack deploy -c stacks/storage.yml --with-registry-auth storage

# 5. Tools (Portainer, swarm-cd, swarm-cronjob, gantry)
docker stack deploy -c stacks/tools.yml --with-registry-auth tools

# 6. Swarmex Controllers (all 16)
docker stack deploy -c stacks/swarmex.yml --with-registry-auth swarmex
```

Wait 2–3 minutes between stacks for services to stabilize.

## 4. Verifying the Installation

### Check All Services

```bash
docker service ls
# All services should show matching replicas (e.g., 1/1, 3/3)
```

### Check Web UIs

| Service | URL | Default Credentials |
|:---|:---|:---|
| Grafana | `https://grafana.<domain>` | admin / (set via secret) |
| Portainer | `https://portainer.<domain>` | Set on first login |
| Authentik | `https://authentik.<domain>` | akadmin / (set during setup) |

### Check Controller Health

```bash
for ctrl in event-controller scaler gatekeeper remediation deployer \
  vault-sync operator-db nano-mesh namespaces netpolicy rbac \
  admission vpa traffic federation api; do
  CID=$(docker ps -q --filter name=swarmex_$ctrl | head -1)
  if [ -n "$CID" ]; then
    health=$(docker exec $CID wget -qO- http://localhost:8080/health 2>/dev/null)
    echo "$ctrl: $health"
  fi
done
```

## 5. Deploying Your First App

### Minimum Viable Compose File

Swarmex admission requires every service to have a `memory limit` and a `team` label:

```yaml
# my-app.yml
version: "3.8"
services:
  web:
    image: registry.example.com/my-app:latest
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 256M
          cpus: "0.5"
      labels:
        # Traefik routing
        traefik.enable: "true"
        traefik.http.routers.myapp.rule: "Host(`myapp.<domain>`)"
        traefik.http.routers.myapp.tls.certresolver: "le"
        traefik.http.services.myapp.loadbalancer.server.port: "8080"
    labels:
      team: my-team    # Required by admission
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/health"]
      interval: 10s
      timeout: 3s
      retries: 3
    networks:
      - traefik-public

networks:
  traefik-public:
    external: true
```

### Deploy

```bash
docker stack deploy -c my-app.yml --with-registry-auth my-app
```

### Verify

```bash
# Check service
docker service ls --filter name=my-app

# Check tasks
docker service ps my-app_web

# Test HTTPS
curl -s https://myapp.<domain>/health
```

If the service disappears immediately, check admission logs:

```bash
docker logs $(docker ps -q --filter name=swarmex_admission) --tail 5
```

## 6. Configuring Autoscaling

### Horizontal Autoscaling (HPA)

Automatically scales replicas based on CPU/RAM usage from Prometheus.

```yaml
deploy:
  labels:
    swarmex.scaler.enabled: "true"
    swarmex.scaler.min: "2"
    swarmex.scaler.max: "10"
    swarmex.scaler.cpu-target: "70"     # Scale up at 70% CPU
    swarmex.scaler.ram-target: "80"     # Scale up at 80% RAM
    swarmex.scaler.cooldown: "60"       # Wait 60s between scale events
```

The scaler queries Prometheus every 15 seconds. When usage exceeds the target, it adds replicas. When usage drops, it removes them (respecting the minimum).

### Vertical Autoscaling (VPA)

Automatically adjusts CPU/RAM limits based on actual usage (20% headroom above real consumption).

```yaml
deploy:
  labels:
    swarmex.vpa.enabled: "true"
    swarmex.vpa.min-memory: "64M"
    swarmex.vpa.max-memory: "2G"
    swarmex.vpa.min-cpu: "0.1"
    swarmex.vpa.max-cpu: "2.0"
```

VPA evaluates every 30 seconds. If the service uses 50MB of RAM but has a 512MB limit, VPA reduces the limit to ~64MB (actual usage × 1.2, clamped to min/max). This frees resources for other services.

You can use HPA and VPA together — HPA scales horizontally, VPA optimizes each replica's resources.

## 7. Namespace Isolation and Network Policies

### Creating Namespaces

Add a namespace label to isolate your service in its own overlay network:

```yaml
labels:
  swarmex.namespace: "production"
```

This creates an overlay network `ns-production` and attaches the service. Services in different namespaces cannot communicate by default.

### Allowing Cross-Namespace Traffic

To allow a backend service to receive traffic from the frontend namespace:

```yaml
# On the backend service
labels:
  swarmex.namespace: "backend"
  swarmex.netpolicy.allow: "ns-frontend"
```

Multiple namespaces can be allowed with comma separation:

```yaml
swarmex.netpolicy.allow: "ns-frontend,ns-monitoring"
```

## 8. Secret Management

### Storing Secrets in OpenBao

First, write secrets to OpenBao:

```bash
# From the manager node
CID=$(docker ps -q --filter name=security_openbao | head -1)
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_TOKEN=<root-token> $CID \
  bao kv put secret/my-app db_password=secret123 api_key=abc456
```

### Injecting Secrets into Your Service

```yaml
deploy:
  labels:
    swarmex.vault.enabled: "true"
    swarmex.vault.path: "secret/data/my-app"
    swarmex.vault.refresh: "300"        # Re-read every 5 minutes
    swarmex.vault.signal: "SIGHUP"      # Signal app to reload
```

Vault-sync writes secrets as files to `/run/secrets/swarmex/` inside the container. Your app reads them from there. When secrets change in OpenBao, vault-sync updates the files and sends the configured signal.

## 9. Blue/Green Deployments

### How It Works

The deployer creates a parallel "green" service with the new image, shifts Traefik traffic gradually, and removes the old "blue" service if healthy.

```yaml
deploy:
  labels:
    swarmex.deployer.enabled: "true"
    swarmex.deployer.strategy: "blue-green"
    swarmex.deployer.green-image: "registry.example.com/my-app:v2"
    swarmex.deployer.shift-interval: "30s"
    swarmex.deployer.shift-step: "20"
    swarmex.deployer.rollback-on-fail: "true"
```

Traffic flow: 100/0 → 80/20 → 60/40 → 40/60 → 20/80 → 0/100 (then remove blue).

If error rate exceeds the threshold during any step, traffic shifts back to blue automatically.

### Readiness Gates

Combine with gatekeeper to ensure the green service is healthy before receiving traffic:

```yaml
deploy:
  labels:
    swarmex.gatekeeper.enabled: "true"
    swarmex.gatekeeper.path: "/health/ready"
    swarmex.gatekeeper.interval: "5s"
    swarmex.gatekeeper.threshold: "3"
    swarmex.deployer.enabled: "true"
    swarmex.deployer.strategy: "blue-green"
    swarmex.deployer.green-image: "registry.example.com/my-app:v2"
```

## 10. Database Workloads

### PostgreSQL with Automatic Failover

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    deploy:
      replicas: 1
      resources:
        limits:
          memory: 512M
      labels:
        swarmex.operator.enabled: "true"
        swarmex.operator.type: "postgresql"
        swarmex.operator.port: "5432"
    labels:
      team: my-team
    volumes:
      - db-data:/var/lib/postgresql/data
```

The operator-db controller monitors TCP health on port 5432. If the container becomes unreachable, it force-updates the service to trigger a restart on a healthy node.

## 11. Traffic Policies

### Retries, Rate Limiting, Circuit Breaking

Applied via Traefik middlewares automatically:

```yaml
deploy:
  labels:
    swarmex.traffic.retry: "3"              # Retry failed requests 3 times
    swarmex.traffic.rate-limit: "100"       # Max 100 requests/second
    swarmex.traffic.circuit-breaker: "0.5"  # Open circuit at 50% error rate
```

These create Traefik middlewares attached to your service's router. No Traefik configuration needed — the traffic controller handles it.

## 12. Multi-Cluster Federation

### Setup

Federation replicates services to remote Swarm clusters. Configure the federation controller with remote cluster endpoints:

```bash
docker service update \
  --env-add FEDERATION_CLUSTER_GCP=tcp://<gcp-manager-ip>:2376 \
  --env-add FEDERATION_CLUSTER_AZURE=tcp://<azure-manager-ip>:2376 \
  swarmex_federation
```

The remote clusters need Docker TCP API enabled (port 2376).

### Replicating a Service

```yaml
deploy:
  labels:
    swarmex.federation.replicate: "true"
    swarmex.federation.clusters: "gcp,azure"   # Which clusters to replicate to
```

The federation controller creates the same service on the remote clusters. When you update the service (image, replicas, config), the changes sync automatically.

### What Gets Replicated

- Image and tag
- Replica count
- Environment variables
- Labels
- Resource limits

What does NOT get replicated: volumes, secrets, configs (these must exist on the remote cluster).

## 13. Monitoring and Logging

### Grafana

Access at `https://grafana.<domain>`. Three datasources are pre-configured:

- **Prometheus** — container metrics (CPU, RAM, network)
- **Loki** — centralized logs from all containers
- **Tempo** — distributed traces (if your app sends OTLP)

### Searching Logs

In Grafana → Explore → select Loki datasource:

```logql
# All logs from your service
{service="my-app_web"}

# Filter by content
{service="my-app_web"} |= "error"

# Filter by level (if JSON logs)
{service="my-app_web"} | json | level="error"

# Logs from all services in a stack
{stack="my-app"}

# Logs from a specific node
{node="<node-id>"}
```

### Alerts

AlertManager is configured to send alerts to the Swarmex API. You can query active alerts:

```bash
CID=$(docker ps -q --filter name=swarmex_api | head -1)
docker exec $CID wget -qO- http://localhost:8080/api/v1/resources?kind=Alert
```

To add custom alert rules, update the Prometheus alerts config:

```bash
# Edit configs/prometheus/alerts.yml, then:
docker config rm prometheus-alerts-v2
docker config create prometheus-alerts-v2 configs/prometheus/alerts.yml
docker service update --config-rm <old> --config-add source=prometheus-alerts-v2,target=/etc/prometheus/alerts.yml observability_prometheus
```

### Controller Metrics

All 16 controllers expose Prometheus metrics at `/metrics` on port 8080. Prometheus scrapes them automatically. You can see controller performance in Grafana by querying:

```promql
# Go runtime metrics for any controller
go_goroutines{job="swarmex"}
process_resident_memory_bytes{job="swarmex"}
```

## 14. Backup and Restore

### Automated Backups

A cron job runs daily at 3:00 AM on the manager node, backing up:

- Authentik PostgreSQL database (pg_dump)
- OpenBao file storage
- Docker config and secret names
- All service definitions (JSON)

Backups are stored in `/opt/swarmex/backups/` with 7-day retention.

### Manual Backup

```bash
bash /opt/swarmex/backup.sh
```

### Restore

```bash
# Restore Authentik DB
gunzip -c /opt/swarmex/backups/<date>/authentik-db.sql.gz | \
  docker exec -i $(docker ps -q --filter name=security_authentik-db) \
  psql -U authentik authentik

# Restore OpenBao
CID=$(docker ps -q --filter name=security_openbao)
docker cp /opt/swarmex/backups/<date>/openbao.tar.gz $CID:/tmp/
docker exec $CID tar xzf /tmp/openbao.tar.gz -C /

# Restore service definitions
for f in /opt/swarmex/backups/<date>/svc-*.json; do
  # Service definitions are for reference — recreate via stack deploy
  echo "Saved: $f"
done
```

## 15. Admission Rules

Swarmex enforces rules on every new service (including `docker stack deploy`). Services that fail validation are automatically removed.

### Default Rules

| Rule | Effect |
|:---|:---|
| `require-memory-limit` | Service must have `deploy.resources.limits.memory` set |
| `require-team-label` | Service must have a `team` label |
| `add-managed-by` | Automatically adds `managed-by: swarmex` label |

### Customizing Rules

Edit `configs/admission/rules.yaml`:

```yaml
rules:
  - name: require-memory-limit
    validate:
      message: "Service must have a memory limit"
      require_memory_limit: true
  - name: require-team-label
    validate:
      message: "Service must have a team label"
      require_labels:
        - team
        - environment
  - name: deny-latest-tag
    validate:
      message: "Do not use :latest tag in production"
      # Custom validation (requires code change)
  - name: add-managed-by
    mutate:
      add_labels:
        managed-by: swarmex
        cluster: production
```

Update the config:

```bash
docker config rm admission-rules
docker config create admission-rules configs/admission/rules.yaml
docker service update --force swarmex_admission
```

## 16. RBAC and Authentication

### How It Works

The RBAC controller acts as a proxy to the Docker socket. It authenticates requests using (in priority order):

1. JWT Bearer token (from Authentik)
2. `X-Authentik-Username` header (from Traefik forward-auth)
3. `X-Swarmex-User` header (manual)
4. `anonymous` (if none of the above)

### Configuring Roles

Edit the RBAC config at `/etc/swarmex/rbac.yaml`:

```yaml
roles:
  admin:
    actions: ["*"]              # Full access
  deployer:
    actions: ["GET", "POST"]    # Read + create
    deny: ["/nodes"]            # But not node management
  viewer:
    actions: ["GET"]            # Read-only

users:
  akadmin: admin
  ci-bot: deployer
  dashboard: viewer
```

### Getting a JWT Token

Authenticate via Authentik to get a JWT:

```bash
curl -X POST https://authentik.<domain>/application/o/token/ \
  -d "grant_type=password&username=<user>&password=<pass>&client_id=swarmex"
```

Use the token with the RBAC proxy:

```bash
curl -H "Authorization: Bearer <jwt>" http://<rbac-proxy>:2376/services
```

## 17. Updating Swarmex

### Updating Controllers

Controllers auto-update when new images are pushed to the registry (via gantry). To manually update:

```bash
# Update a single controller
docker service update --with-registry-auth \
  --image registry.labtau.com/ccvass/swarmex/swarmex-scaler:latest \
  swarmex_scaler

# Update all controllers
for ctrl in event-controller scaler gatekeeper remediation deployer \
  vault-sync operator-db nano-mesh namespaces netpolicy rbac \
  admission vpa traffic federation api; do
  docker service update --with-registry-auth --force \
    --image registry.labtau.com/ccvass/swarmex/swarmex-$ctrl:latest \
    swarmex_$ctrl
done
```

### Updating Platform Stack

```bash
cd swarmex-coordinator
git pull
docker stack deploy -c stacks/observability.yml --with-registry-auth observability
# Repeat for other stacks as needed
```

## 18. Troubleshooting

### Service Won't Start

```bash
# Check service status
docker service ps my-app_web --no-trunc

# Common causes:
# "no suitable node" → check constraints and node availability
# "image not found" → check registry login on all nodes
# Service disappears → check admission logs (see below)
```

### Admission Denied My Service

```bash
docker logs $(docker ps -q --filter name=swarmex_admission) --tail 20
# Look for: "admission denied", service name, rule name, message
```

Fix: add the required labels/limits to your compose file.

### Scaler Not Scaling

```bash
# Check scaler logs
docker logs $(docker ps -q --filter name=swarmex_scaler) --tail 20

# Check if Prometheus has metrics for your service
CID=$(docker ps -q --filter name=observability_prometheus | head -1)
docker exec $CID wget -qO- \
  "http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total{container_label_com_docker_swarm_service_name=\"my-app_web\"}"
```

### Service Logs

```bash
# Via Docker (may hang — use container ID instead)
CID=$(docker ps -q --filter name=my-app_web | head -1)
docker logs $CID --tail 50

# Via Loki (in Grafana)
# {service="my-app_web"} |= "error"
```

### Node Issues

```bash
# Check node status
docker node ls

# If a node is Drain (remediation may have drained it):
docker node update --availability active <node-id>

# Check remediation logs
docker logs $(docker ps -q --filter name=swarmex_remediation) --tail 20
```

### Network Issues

```bash
# List overlay networks
docker network ls --filter driver=overlay

# Check if service is on the right network
docker service inspect my-app_web --format '{{json .Spec.TaskTemplate.Networks}}'

# Check namespace networks
docker network ls --filter name=ns-
```

### Registry Authentication

```bash
# If services show "image not found", re-login on all nodes:
echo "<token>" | docker login registry.labtau.com -u "gitlab+deploy-token-409" --password-stdin

# Then force-update the service:
docker service update --with-registry-auth --force my-app_web
```
