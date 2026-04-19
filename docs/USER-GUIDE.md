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
18. [Automatic Cloud Node Scaling](#18-automatic-cloud-node-scaling)
19. [Traefik High Availability and Multiple Domains](#19-traefik-high-availability-and-multiple-domains)
20. [Canary Deployments](#20-canary-deployments)
21. [Service Affinity and Anti-Affinity](#21-service-affinity-and-anti-affinity)
22. [Disruption Budgets](#22-disruption-budgets)
23. [Namespace Resource Quotas](#23-namespace-resource-quotas)
24. [Stateful Services](#24-stateful-services)
25. [Swarmex Pack (Helm-like Packaging)](#25-swarmex-pack-helm-like-packaging)
26. [Troubleshooting](#26-troubleshooting)

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

On **every node** (manager and all workers):

```bash
echo "<deploy-token-password>" | docker login registry.labtau.com \
  -u "gitlab+deploy-token-409" --password-stdin
```

If you skip a node, services scheduled there will fail with "image not found".

### Create Networks and Configs

```bash
bash scripts/pre-deploy.sh
```

This creates the overlay networks (`monitoring`, `traefik-public`, `security`, `swarmex_swarmex`) and Docker configs from the `configs/` directory.

### Create Docker Secrets

Secret names must match exactly — the stacks reference these specific names:

```bash
# Authentik (note: authentik_db_pw, NOT authentik_db_password)
echo -n "<db-password>" | docker secret create authentik_db_pw -
echo -n "<secret-key>" | docker secret create authentik_secret -

# Grafana
echo -n "<grafana-password>" | docker secret create grafana_admin_pw -

# Cloudflare (for DNS challenge SSL)
echo -n "<cloudflare-api-token>" | docker secret create cloudflare_api_token -

# OpenBao
echo -n "<root-token>" | docker secret create openbao_root_token -
```

### Deploy Stacks (In Order)

The order matters — each stack depends on the previous ones. The swarmex stack **must be deployed last** because it contains the admission controller, which enforces `team` label and `memory` limit on all services. If admission starts before platform services are running, it will remove them.

```bash
# 1. Ingress (Traefik — SSL termination, routing)
docker stack deploy -c stacks/ingress.yml --with-registry-auth ingress

# 2. Observability (Prometheus, Grafana, Loki, Tempo)
docker stack deploy -c stacks/observability.yml --with-registry-auth observability

# 3. Security (Authentik SSO, OpenBao secrets)
docker stack deploy -c stacks/security.yml --with-registry-auth security

# 4. Storage (SeaweedFS distributed storage)
docker stack deploy -c stacks/storage.yml --with-registry-auth storage

# 5. Tools (Portainer, swarm-cd, swarm-cronjob, gantry)
docker stack deploy -c stacks/tools.yml --with-registry-auth tools

# 6. WAIT for platform services to stabilize
sleep 60

# 7. Swarmex Controllers (LAST — admission enforces policies)
docker stack deploy -c stacks/swarmex.yml --with-registry-auth swarmex
```

All platform stacks (ingress through tools) include `team: platform` labels and memory limits so they pass admission validation. Your application stacks need these too — see [Section 5](#5-deploying-your-first-app).

## 4. Verifying the Installation

### Check All Services

```bash
docker service ls
# All 35 services should show matching replicas (e.g., 1/1, 3/3)
# Expected: 35/35 on a fresh install

# Quick count
total=$(docker service ls -q | wc -l)
running=$(docker service ls --format '{{.Replicas}}' | grep -v '0/' | wc -l)
echo "$running/$total services running"
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

Swarmex admission requires every service to have a `memory limit` and a `team` label in `deploy.labels`. Services missing either will be removed automatically.

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
        team: my-team    # Required by admission (must be in deploy.labels)
        # Traefik routing
        traefik.enable: "true"
        traefik.http.routers.myapp.rule: "Host(`myapp.<domain>`)"
        traefik.http.routers.myapp.tls.certresolver: "le"
        traefik.http.services.myapp.loadbalancer.server.port: "8080"
    networks:
      - traefik-public

networks:
  traefik-public:
    external: true
```

> **Healthcheck note:** If your image is distroless (no shell, no wget, no curl), do not add a Docker healthcheck — Docker will just check if the process is running. For images with a shell, use `CMD-SHELL` with a fallback: `["CMD-SHELL", "wget -qO- http://localhost:8080/health || curl -sf http://localhost:8080/health || exit 1"]`

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

#### How It Works

The scaler controller runs a reconciliation loop every 15 seconds:

1. Queries Prometheus for CPU and RAM usage of each service: `avg(rate(container_cpu_usage_seconds_total{service="<name>"}[5m]))` and `avg(container_memory_usage_bytes{service="<name>"})`
2. Compares usage against configured thresholds (default: 70% CPU, 80% RAM)
3. If usage exceeds threshold: calculates desired replicas = current × (usage / target), capped at `max`
4. If usage is below threshold × 0.5: scales down, respecting `min`
5. After scaling, enters cooldown period (default 60s) — no further scaling during this time

The scaler only acts on services with `swarmex.scaler.enabled=true` in deploy labels.

#### Configuration

```yaml
deploy:
  labels:
    swarmex.scaler.enabled: "true"
    swarmex.scaler.min: "2"          # Never fewer than 2 replicas
    swarmex.scaler.max: "10"         # Never more than 10 replicas
    swarmex.scaler.cpu-target: "70"  # Scale up when avg CPU > 70%
    swarmex.scaler.ram-target: "80"  # Scale up when avg RAM > 80%
    swarmex.scaler.cooldown: "60"    # Wait 60s between scale events
```

#### Observable Behavior

```bash
# Check scaler decisions
docker logs $(docker ps -q --filter name=swarmex_scaler) --tail 20
# Look for: "scaling service" with old→new replica count
```

### Vertical Autoscaling (VPA)

#### How It Works

The VPA controller runs an evaluation cycle every 30 seconds:

1. Queries Prometheus for actual CPU and memory usage of each VPA-enabled service
2. Calculates target limits: `actual_usage × 1.2` (20% headroom)
3. Clamps the target between configured min and max values
4. Only updates if the change exceeds 10% (avoids constant small adjustments)
5. Calls `docker service update` to change the resource limits

This means an idle nginx using 7MB of RAM with a 512MB limit will be reduced to ~32MB (the configured minimum), freeing 480MB for other services.

#### Configuration

```yaml
deploy:
  labels:
    swarmex.vpa.enabled: "true"
    swarmex.vpa.min-memory: "64M"    # Never set limit below 64MB
    swarmex.vpa.max-memory: "2G"     # Never set limit above 2GB
    swarmex.vpa.min-cpu: "0.1"       # Never set limit below 0.1 CPU
    swarmex.vpa.max-cpu: "2.0"       # Never set limit above 2.0 CPU
```

#### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_vpa) --tail 20
# Look for: "vpa adjusted" with cpu old→new, mem old→new
# Verify: docker service inspect <svc> --format '{{.Spec.TaskTemplate.Resources.Limits}}'
```

You can use HPA and VPA together — HPA scales the number of replicas, VPA optimizes each replica's resource allocation.

## 7. Namespace Isolation and Network Policies

### How Namespaces Work

The namespaces controller watches for services with a `swarmex.namespace` label:

1. On service create/update, reads the `swarmex.namespace` label value
2. Creates an overlay network named `ns-<namespace>` if it doesn't exist
3. Attaches the service to that network via `docker service update --network-add`
4. Services in the same namespace share a network and can communicate via DNS
5. Services in different namespaces are on separate overlay networks — no connectivity by default

#### Configuration

```yaml
deploy:
  labels:
    swarmex.namespace: "production"
```

This creates `ns-production` overlay network and attaches the service. All services with `swarmex.namespace: "production"` can reach each other by service name.

#### Observable Behavior

```bash
# See namespace networks
docker network ls --filter name=ns-

# Check which network a service is on
docker service inspect <svc> --format '{{range .Spec.TaskTemplate.Networks}}{{.Target}} {{end}}'
```

### How Network Policies Work

The netpolicy controller enables cross-namespace communication:

1. Watches for services with `swarmex.netpolicy.allow` label
2. Parses the comma-separated list of namespace names
3. For each allowed namespace, attaches the service to that namespace's overlay network
4. The service can now receive traffic from services in the allowed namespaces

This is an additive model — you grant access, not deny it. By default, namespaces are isolated.

#### Configuration

```yaml
# Backend service in "backend" namespace, allowing traffic from "frontend"
deploy:
  labels:
    swarmex.namespace: "backend"
    swarmex.netpolicy.allow: "ns-frontend"
```

Multiple namespaces:

```yaml
    swarmex.netpolicy.allow: "ns-frontend,ns-monitoring"
```

#### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_netpolicy) --tail 10
# Look for: "cross-namespace access granted" with service and network names
```

## 8. Secret Management

### How Vault-Sync Works

The vault-sync controller bridges OpenBao (Vault-compatible) with Docker services:

1. Watches for services with `swarmex.vault.enabled=true`
2. Reads the configured OpenBao path (e.g., `secret/data/my-app`)
3. Fetches all key-value pairs from that path using the OpenBao HTTP API
4. Writes each key as a file in `/run/secrets/swarmex/` (tmpfs mount — never touches disk)
5. Sends the configured signal (default: SIGHUP) to the service containers so they reload
6. Repeats every `refresh` interval (default: 300 seconds)

The vault token is read from `VAULT_TOKEN` env var or `VAULT_TOKEN_FILE` (Docker secret).

### Storing Secrets in OpenBao

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
    swarmex.vault.path: "secret/data/my-app"   # OpenBao KV v2 path
    swarmex.vault.refresh: "300"                # Re-read every 5 minutes
    swarmex.vault.signal: "SIGHUP"             # Signal to send on rotation
```

### How Your App Reads Secrets

Secrets appear as files:

```
/run/secrets/swarmex/db_password    → contains "secret123"
/run/secrets/swarmex/api_key        → contains "abc456"
```

Your app reads them at startup and on SIGHUP:

```python
# Python example
db_password = open("/run/secrets/swarmex/db_password").read().strip()
```

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_vault-sync) --tail 10
# Look for: "secrets synced" with service name and key count
# Error: "vault read failed" means OpenBao is unreachable or path doesn't exist
```

## 9. Blue/Green and Canary Deployments

The deployer controller supports two strategies: **blue/green** (full parallel service swap) and **canary** (gradual traffic shifting with 1 replica). See [Section 20](#20-canary-deployments) for canary details.

### How the Deployer Works (Blue/Green)

The deployer controller manages zero-downtime deployments:

1. Detects services with `swarmex.deployer.strategy=blue-green` and a `green-image` label
2. Creates a parallel "green" service (`<name>-green`) with the new image
3. Waits for the green service to become healthy (Docker HEALTHCHECK)
4. Gradually shifts Traefik traffic weights: blue 100/green 0 → 80/20 → 60/40 → ... → 0/100
5. Each shift waits `shift-interval` (default 30s) before the next step
6. If error rate exceeds threshold during any step, rolls back all traffic to blue
7. After full cutover, removes the old blue service and renames green to blue

The deployer manages Traefik labels on both services to control traffic distribution.

### Configuration

```yaml
deploy:
  labels:
    swarmex.deployer.enabled: "true"
    swarmex.deployer.strategy: "blue-green"
    swarmex.deployer.green-image: "registry.example.com/my-app:v2"
    swarmex.deployer.shift-interval: "30s"   # 30s between weight shifts
    swarmex.deployer.shift-step: "20"        # Shift 20% per step
    swarmex.deployer.rollback-on-fail: "true" # Auto-rollback on errors
```

Traffic flow over time:

```
t=0s    blue=100%  green=0%    (green service created)
t=30s   blue=80%   green=20%   (first shift)
t=60s   blue=60%   green=40%
t=90s   blue=40%   green=60%
t=120s  blue=20%   green=80%
t=150s  blue=0%    green=100%  (cutover complete, blue removed)
```

### Combining with Readiness Gates

The gatekeeper controller ensures Traefik only routes to healthy services:

1. Periodically sends HTTP requests to the configured health path
2. Counts consecutive successes (threshold, default 3)
3. When threshold is met, adds `traefik.enable=true` label to the service
4. If health check fails, removes the Traefik label — traffic stops immediately

```yaml
deploy:
  labels:
    swarmex.gatekeeper.enabled: "true"
    swarmex.gatekeeper.path: "/health/ready"  # HTTP path to probe
    swarmex.gatekeeper.interval: "5s"         # Check every 5 seconds
    swarmex.gatekeeper.timeout: "3s"          # Timeout per check
    swarmex.gatekeeper.threshold: "3"         # 3 consecutive successes to pass
    swarmex.deployer.enabled: "true"
    swarmex.deployer.strategy: "blue-green"
    swarmex.deployer.green-image: "registry.example.com/my-app:v2"
```

### Observable Behavior

```bash
# Deployer logs
docker logs $(docker ps -q --filter name=swarmex_deployer) --tail 20
# Look for: "green service created", "shifting traffic", "cutover complete"

# Gatekeeper logs
docker logs $(docker ps -q --filter name=swarmex_gatekeeper) --tail 20
# Look for: "service READY, enabling Traefik" or "service NOT READY, disabling Traefik"
```

## 10. Database Workloads

### How Operator-DB Works

The operator-db controller provides automated health monitoring and failover for databases:

1. Watches for services with `swarmex.operator.enabled=true`
2. Every 15 seconds, performs TCP health checks on the configured port for each task (replica)
3. Counts healthy replicas (successful TCP connection within 3 seconds)
4. If healthy count drops below `min-ready` (default 1), triggers failover
5. Failover = `docker service update --force` which kills the unhealthy task and schedules a new one

The operator does NOT manage replication, clustering, or data consistency — it only ensures the database container is running and accepting TCP connections.

### Configuration

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
        team: my-team
        swarmex.operator.enabled: "true"
        swarmex.operator.type: "postgresql"   # Logged for context, no behavior change
        swarmex.operator.port: "5432"         # TCP port to health-check
        swarmex.operator.min-ready: "1"       # Minimum healthy replicas
    volumes:
      - db-data:/var/lib/postgresql/data
```

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_operator-db) --tail 20
# Healthy: "operator watching DB service" with service name and engine
# Unhealthy: "DB service unhealthy" with healthy count and min_ready
# Failover: "failover triggered" with service name and engine
```

### Self-Healing with Remediation

For additional protection, combine with remediation:

```yaml
deploy:
  labels:
    swarmex.operator.enabled: "true"
    swarmex.operator.port: "5432"
    swarmex.remediation.enabled: "true"
    swarmex.remediation.failure-threshold: "3"
```

Remediation provides a three-step escalation chain:

1. **Restart** — `docker service update --force` (same as operator-db failover)
2. **Force-restart** — removes and recreates the task
3. **Drain node** — marks the node as `Drain` to move all services to other nodes (never drains the last active manager)

The failure counter resets after 5 minutes of no failures.

## 11. Traffic Policies

### How It Works

The traffic controller watches for services with `swarmex.traffic.*` labels and automatically creates Traefik middlewares:

1. On service create/update, reads traffic policy labels
2. For each policy, creates a corresponding Traefik middleware via deploy labels:
   - `retry` → `traefik.http.middlewares.<svc>-retry.retry.attempts=<N>`
   - `rate-limit` → `traefik.http.middlewares.<svc>-ratelimit.ratelimit.average=<N>`
   - `circuit-breaker` → `traefik.http.middlewares.<svc>-cb.circuitbreaker.expression=ResponseCodeRatio(500,600,0,600) > <threshold>`
3. Attaches all middlewares to the service's Traefik router

You don't need to configure Traefik directly — the controller manages all middleware labels.

### Configuration

```yaml
deploy:
  labels:
    # Traefik routing (required)
    traefik.enable: "true"
    traefik.http.routers.myapp.rule: "Host(`myapp.example.com`)"
    traefik.http.routers.myapp.tls.certresolver: "le"
    traefik.http.services.myapp.loadbalancer.server.port: "8080"
    # Traffic policies (Swarmex manages the middlewares)
    swarmex.traffic.retry: "3"              # Retry failed requests 3 times
    swarmex.traffic.rate-limit: "100"       # Max 100 requests/second average
    swarmex.traffic.rate-burst: "200"       # Allow bursts up to 200 req/s
    swarmex.traffic.circuit-breaker: "0.5"  # Open circuit at 50% error rate
```

### What Each Policy Does

**Retry**: When a request fails (5xx response or connection error), Traefik retries it up to N times on different backend instances. Useful for transient failures.

**Rate Limit**: Limits incoming requests to N per second (average) with optional burst. Requests exceeding the limit get HTTP 429 Too Many Requests.

**Circuit Breaker**: Monitors the ratio of 5xx responses. When the error ratio exceeds the threshold (0.0–1.0), the circuit opens and all requests get HTTP 503 for a recovery period. After recovery, the circuit closes and traffic resumes.

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_traffic) --tail 10
# Look for: "traffic policies applied" with policy names

# Verify middlewares were created
docker service inspect <svc> --format '{{json .Spec.Labels}}' | python3 -m json.tool | grep middleware
```

## 12. Multi-Cluster Federation

### How It Works

The federation controller replicates services across Swarm clusters:

1. Connects to remote Docker APIs via TCP (configured via `FEDERATION_CLUSTER_<NAME>` env vars)
2. Watches for services with `swarmex.federation.replicate=true`
3. Reads `swarmex.federation.clusters` to determine target clusters
4. On service create: calls `docker service create` on each remote cluster with the same image, replicas, environment variables, labels, and resource limits
5. On service update: calls `docker service update` on each remote cluster to sync changes
6. If the service already exists on the remote, it updates instead of creating

#### What Gets Replicated

- Image and tag
- Replica count
- Environment variables
- Service labels
- Resource limits (CPU, memory)

#### What Does NOT Get Replicated

- Volumes (must exist on remote cluster)
- Docker secrets and configs (must be created on remote)
- Network attachments (remote cluster uses its own networks)
- Placement constraints (remote cluster has different nodes)

### Setup

#### 1. Enable Docker TCP API on Remote Cluster Manager

```bash
# On the remote manager node
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2376 --containerd=/run/containerd/containerd.sock
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

**Security warning**: This exposes the Docker API without authentication. For production, use TLS mutual authentication or a VPN.

#### 2. Configure Federation Controller

```bash
docker service update \
  --env-add FEDERATION_CLUSTER_GCP=tcp://<gcp-manager-ip>:2376 \
  --env-add FEDERATION_CLUSTER_AZURE=tcp://<azure-manager-ip>:2376 \
  swarmex_federation
```

#### 3. Replicate a Service

```yaml
deploy:
  labels:
    swarmex.federation.replicate: "true"
    swarmex.federation.clusters: "gcp,azure"   # Comma-separated cluster names
```

### Verified: AWS → GCP Cross-Cloud

Tested with a temporary 3-node GCP cluster:

1. Federation connected: `"connected to remote cluster", cluster=gcp`
2. Created `fed-test` (nginx, 2 replicas) → appeared on GCP as `fed-test 2/2`
3. Updated image to httpd → GCP synced: `"federation updated", service=fed-test`

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_federation) --tail 10
# "connected to remote cluster" — startup, one per remote
# "federation replicated" — new service created on remote
# "federation updated" — existing service updated on remote
# "unknown remote cluster" — cluster name in label doesn't match any FEDERATION_CLUSTER_* env var
```

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

All platform stacks (ingress, observability, security, storage, tools) already include `team: platform` and memory limits, so they pass admission. You only need to worry about your own application stacks.

### Default Rules

| Rule | Effect |
|:---|:---|
| `require-memory-limit` | Service must have `deploy.resources.limits.memory` set |
| `require-team-label` | Service must have a `team` label in `deploy.labels` |
| `add-managed-by` | Automatically adds `managed-by: swarmex` label |

**Important:** The `team` label must be in `deploy.labels` (service-level), not in the top-level `labels` (container-level). Admission reads Swarm service labels which map to `deploy.labels` in Docker Compose.

```yaml
services:
  web:
    # ❌ This does NOT satisfy admission (container label)
    labels:
      team: my-team

    deploy:
      # ✅ This satisfies admission (service label)
      labels:
        team: my-team
      resources:
        limits:
          memory: 256M    # Also required
```

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

## 18. Automatic Cloud Node Scaling

### How It Works

The cluster-scaler controller monitors overall cluster CPU usage and automatically provisions or terminates cloud instances:

1. Every 30 seconds, queries Prometheus: `avg(1 - rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100`
2. If CPU exceeds threshold and total nodes < max: provisions a new instance via the configured cloud provider
3. The instance installs Docker and joins the Swarm automatically via user-data/cloud-init
4. If CPU drops below threshold and managed workers > min: drains the youngest auto-provisioned node, waits 30s for task migration, removes from Swarm, terminates the instance
5. Managed nodes are persisted in bbolt — survives controller restarts

### Protections

- Cooldown: 5 min after scale-up, 10 min after scale-down
- New node protection: nodes younger than 10 minutes won't be removed
- Only manages its own nodes: manually added nodes are never touched
- Persistence: managed node list stored in bbolt at `/data/cluster-scaler.db`

### Configuration

All configuration is in a YAML file mounted at `/etc/swarmex/cluster-scaler.yaml`:

```yaml
swarm_token: "SWMTKN-1-xxxxx"
manager_ip: "10.0.0.1"
min_nodes: 2
max_nodes: 10
scale_up_cpu: 80
scale_down_cpu: 15
eval_interval: "30s"
cooldown_up: "5m"
cooldown_down: "10m"
prometheus_url: "http://observability_prometheus:9090"

providers:
  aws:
    region: "us-east-1"
    key_name: "my-key"
    security_group: "sg-xxxxxxxx"
    subnet_id: "subnet-xxxxxxxx"
    template:
      instance_type: "t3.large"
      image: "ami-xxxxxxxxx"
      disk_gb: 30

  # Multiple providers = round-robin provisioning
  # gcp:
  #   project: "my-project"
  #   zone: "us-central1-a"
  #   template:
  #     instance_type: "e2-medium"
  #     image: "ubuntu-2404-lts-amd64"
  #     disk_gb: 30
  # azure:
  #   resource_group: "swarmex-rg"
  #   location: "eastus"
  #   vnet: "swarmex-vnet"
  #   subnet: "default"
  #   template:
  #     instance_type: "Standard_B2s"
  #     image: "Canonical:ubuntu-24_04-lts:server:latest"
  #     disk_gb: 30
  # digitalocean:
  #   region: "nyc1"
  #   ssh_key_id: "12345678"
  #   template:
  #     instance_type: "s-2vcpu-4gb"
  #     image: "ubuntu-24-04-x64"
  #     disk_gb: 50
```

### Supported Providers

| Provider | CLI Required | Instance Types | Image Format |
|:---|:---|:---|:---|
| AWS | `aws` | `t3.large`, `m5.xlarge` | AMI ID |
| GCP | `gcloud` | `e2-medium`, `n2-standard-4` | Image family |
| Azure | `az` | `Standard_B2s`, `Standard_D4s_v3` | URN |
| DigitalOcean | `doctl` | `s-2vcpu-4gb`, `s-4vcpu-8gb` | Slug |

### Verified: Full Cycle on AWS

```
15:20  CPU 72% > 70% → provisioned i-05368af8cf75693c3 (t3.medium)
15:21  Controller restarted → "restored managed nodes, count=1" (bbolt works)
15:22  CPU 89% → provisioned second node (managed=2, cluster=5 nodes)
15:24  Stress removed, CPU dropping: 89→50→13→9%
15:30  Node age > 10min, CPU < 15% → drained + terminated first node
15:35  → drained + terminated second node
15:36  Back to 3 original nodes, managed=0
```

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_cluster-scaler) --tail 20
# "cluster eval" — periodic with worker count, CPU%, managed count
# "provisioning node" / "node provisioned" — scale-up
# "restored managed nodes" — bbolt loaded on startup
# "node drained" / "node terminated" — scale-down
```

## 19. Traefik High Availability and Multiple Domains

### How HA Works

Traefik runs as a `global` service — one instance on every node. Docker Swarm's routing mesh distributes incoming traffic (ports 80/443) across all nodes. If any node goes down, traffic automatically routes to the surviving nodes.

```
Internet → DNS (Cloudflare) → Any Node IP
                                  │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
               Node 1         Node 2         Node 3
              Traefik        Traefik        Traefik
              (global)       (global)       (global)
```

The `mode: ingress` port publishing uses Swarm's built-in load balancer. Even if you point DNS to a single node and that node dies, you only need to update DNS to another node's IP.

For zero-downtime DNS failover, use Cloudflare with health checks or point DNS to all node IPs (Cloudflare supports multiple A records with automatic failover).

### Rolling Updates

Traefik updates use `start-first` order with 30s delay between nodes, so at least one Traefik instance is always running during updates.

### Multiple Domains with Cloudflare

Swarmex uses Cloudflare DNS challenge for SSL certificates. This supports:

- Wildcard certificates (`*.domain1.com`, `*.domain2.com`)
- Multiple domains on the same cluster
- No need to expose port 80 for ACME challenges

#### Setup

1. Create a Cloudflare API token with `Zone:DNS:Edit` permission for your zones

2. Store the token as a Docker secret:

```bash
echo -n "<cloudflare-api-token>" | docker secret create cloudflare_api_token -
```

3. Deploy the ingress stack:

```bash
ACME_EMAIL=admin@example.com DOMAIN=swarmex.example.com \
  docker stack deploy -c stacks/ingress.yml ingress
```

#### Adding a New Domain

In Cloudflare, add A records pointing to any node IP:

```
app.domain2.com    → <node-ip>
*.domain2.com      → <node-ip>
```

In your service compose file, just use the new domain in the Traefik router rule:

```yaml
deploy:
  labels:
    traefik.enable: "true"
    traefik.http.routers.myapp.rule: "Host(`app.domain2.com`)"
    traefik.http.routers.myapp.tls.certresolver: "le"
    traefik.http.services.myapp.loadbalancer.server.port: "8080"
```

Traefik automatically requests a certificate for `app.domain2.com` via Cloudflare DNS challenge. No configuration changes needed on Traefik itself.

#### Multiple Domains on One Service

```yaml
traefik.http.routers.myapp.rule: "Host(`app.domain1.com`) || Host(`app.domain2.com`)"
```

#### Wildcard Certificates

To use a single wildcard cert for all subdomains of a domain:

```yaml
traefik.http.routers.myapp.tls.domains[0].main: "domain1.com"
traefik.http.routers.myapp.tls.domains[0].sans: "*.domain1.com"
```

#### DNS Failover with Cloudflare

For automatic failover when a node dies:

1. In Cloudflare, add multiple A records for the same hostname — one per node IP
2. Enable Cloudflare proxy (orange cloud) for DDoS protection and automatic failover
3. Or use Cloudflare Load Balancing (paid) for health-check-based failover

```
swarmex.example.com  A  44.202.134.209   (node 1)
swarmex.example.com  A  54.211.43.209    (node 2)
swarmex.example.com  A  44.203.57.80     (node 3)
```

Cloudflare round-robins between healthy IPs. If a node goes down, Cloudflare removes it from rotation within ~30 seconds.

## 20. Canary Deployments

### How It Works

The deployer controller supports canary deployments alongside blue/green. Canary creates a parallel service with 1 replica and gradually shifts Traefik traffic weights from 0% to 100%, monitoring error rates at each step. If errors exceed the threshold, it rolls back automatically.

### Configuration

```yaml
deploy:
  labels:
    swarmex.deployer.strategy: "canary"
    swarmex.deployer.shift-interval: "60s"    # time between weight shifts (default 60s)
    swarmex.deployer.shift-step: "5"          # percentage per step (default 5%)
    swarmex.deployer.error-threshold: "5"     # rollback if error rate > 5%
    swarmex.deployer.rollback-on-fail: "true"
```

### Triggering a Canary

Call the deployer API with the new image:

```bash
# From inside the swarmex network
curl -X POST "http://swarmex_deployer:8080/deploy?service=<service-id>&image=registry/app:v2"
```

### Traffic Flow

```
t=0s    blue=100%  canary=0%    (canary service created with 1 replica)
t=60s   blue=95%   canary=5%    (first shift, error rate checked)
t=120s  blue=90%   canary=10%
...
t=20m   blue=0%    canary=100%  (promote: blue updated with canary image, canary removed)
```

If error rate exceeds threshold at any step: all traffic returns to blue, canary removed.

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_deployer) --tail 20
# "shifting traffic" with green_weight and error_rate at each step
# "error threshold exceeded, rolling back" if errors detected
# "deployment complete, cleaning up blue" on success
```

## 21. Service Affinity and Anti-Affinity

### How It Works

The affinity controller manages service placement using Docker constraints:

- **Colocate**: forces a service onto the same node as a target service
- **Avoid**: forces a service onto a different node than a target service
- **Spread**: distributes replicas across nodes with different label values

### Configuration

```yaml
deploy:
  labels:
    swarmex.affinity.colocate: "svc-cache"     # same node as svc-cache
    swarmex.affinity.avoid: "svc-db"           # different node than svc-db
    swarmex.affinity.spread: "zone"            # spread across node.labels.zone values
```

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_affinity) --tail 10
# "affinity colocate" with service, target, and node
# "affinity avoid" with service, target, and node
# "affinity spread" with service and label
```

## 22. Disruption Budgets

### How It Works

Disruption budgets protect services during remediation actions. Before draining a node or force-restarting a service, remediation checks if the action would violate the budget.

### Configuration

```yaml
deploy:
  labels:
    swarmex.remediation.enabled: "true"
    swarmex.remediation.failure-threshold: "3"
    swarmex.disruption.min-available: "2"      # drain blocked if <2 replicas would survive
    swarmex.disruption.max-unavailable: "1"    # force-restart blocked if >1 already unavailable
```

- `min-available`: checked before node drain — counts surviving replicas on other nodes
- `max-unavailable`: checked before force-restart — compares current unavailable vs limit

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_remediation) --tail 20
# "drain blocked by disruption budget" when min-available would be violated
# "force-restart blocked by disruption budget" when max-unavailable exceeded
```

## 23. Namespace Resource Quotas

### How It Works

Admission enforces resource quotas per namespace. When a new service with `swarmex.namespace` is created, admission sums the memory limits and service count of all existing services in that namespace and denies the new service if it would exceed the quota.

### Configuration

In `configs/admission/rules.yaml`:

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
  - name: add-managed-by
    mutate:
      add_labels:
        managed-by: swarmex

quotas:
  production:
    max_memory: "8G"
    max_services: 20
  staging:
    max_memory: "4G"
    max_services: 10
```

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_admission) --tail 10
# "quota exceeded: max_services" with namespace, count, max
# "quota exceeded: max_memory" with namespace, total_mb, max_mb
# "admission denied — namespace quota exceeded" with service name
```

## 24. Stateful Services

### How It Works

The stateful controller provides StatefulSet-like behavior. When a service with `swarmex.stateful.enabled=true` is created, the controller:

1. Scales the original service to 0 (keeps it as a template)
2. Creates N individual services (`svc-0`, `svc-1`, `svc-2`) each with 1 replica
3. Each instance gets its own named volume from the template
4. If `ordered=true`, waits for each instance to be healthy before creating the next

### Configuration

```yaml
deploy:
  labels:
    swarmex.stateful.enabled: "true"
    swarmex.stateful.replicas: "3"
    swarmex.stateful.volume-template: "data-{index}"   # creates data-0, data-1, data-2
    swarmex.stateful.ordered: "true"                    # sequential startup
```

### Limitations

- Volumes are local to the node — use distributed storage (SeaweedFS/NFS) for node migration
- No automatic rebalancing if a node dies
- Deleting the template service does not delete the instances

### Observable Behavior

```bash
docker logs $(docker ps -q --filter name=swarmex_stateful) --tail 10
# "creating stateful set" with service name, replicas, ordered
# "stateful instance created" with name and index for each instance
```

## 25. Swarmex Pack (Helm-like Packaging)

### How It Works

`swarmex-pack` is a CLI tool that renders Go templates into Docker Compose files and deploys them as stacks. It provides Helm-like packaging for Docker Swarm.

### Pack File

Create `swarmex-pack.yml`:

```yaml
name: my-app
version: "1.0"
values:
  image: registry.example.com/my-app:latest
  replicas: "2"
  memory: 256M
  team: my-team
  domain: myapp.example.com
template: stack.yml.tmpl
```

### Template

Create `stack.yml.tmpl`:

```yaml
version: "3.8"
services:
  web:
    image: {{.image}}
    deploy:
      replicas: {{.replicas}}
      resources:
        limits:
          memory: {{.memory}}
      labels:
        team: {{.team}}
        traefik.enable: "true"
        traefik.http.routers.myapp.rule: "Host(`{{.domain}}`)"
        traefik.http.routers.myapp.tls.certresolver: "le"
        traefik.http.services.myapp.loadbalancer.server.port: "8080"
    networks:
      - traefik-public

networks:
  traefik-public:
    external: true
```

### Commands

```bash
# Render template to stdout (preview)
swarmex-pack render --set image=registry/app:v2

# Install (deploy stack)
swarmex-pack install my-app --set image=registry/app:v2 --set replicas=3

# Upgrade (same as install — stack deploy is idempotent)
swarmex-pack upgrade my-app --set image=registry/app:v3

# Uninstall (remove stack)
swarmex-pack uninstall my-app
```

### Running via Docker

```bash
docker run --rm -v $(pwd):/app -v /var/run/docker.sock:/var/run/docker.sock \
  registry.labtau.com/ccvass/swarmex/swarmex-pack:latest \
  install my-app --pack-file /app/swarmex-pack.yml
```

## 26. Troubleshooting

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
