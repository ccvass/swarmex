# Swarmex Roadmap

Detailed implementation plan with all open source resources mapped per phase.
Every tool listed is OSS. When dual-licensed (CE/EE), we fork the community edition.

## Fork Maturity Analysis

Before building anything, we analyzed what the forked projects already solve.

### Production-Ready (deploy directly, no custom build needed)

| Fork | Lang | Commits | Version | What it solves | Impact |
|:---|:---|:---|:---|:---|:---|
| `swarm-cronjob` | Go | 509 | v1.15 | Cron jobs via labels + Docker API | No custom cron needed |
| `gantry` | Shell | 479 | 36 releases | Auto-update services, rollback, webhooks, parallel | Replaces Shepherd |
| `swarm-cd` | Go+TS | 65 | v1.10 | GitOps declarative (ArgoCD for Swarm), UI, SOPS | **Eliminates swarm-sync** |
| `easytier` | Rust | 10.8K stars | v2.4.5 | Full WireGuard mesh, NAT traversal, subnet proxy, web UI | **Reduces #7 nano-mesh to wrapper** |

### Useful Base (concept validated, code needs work)

| Fork | Lang | Commits | What's useful | What's missing |
|:---|:---|:---|:---|:---|
| `swarm-autoscaler` | Ruby | 8 | Label pattern (`swarm.autoscaler.*`), Prometheus+cAdvisor approach | Full rewrite in Go, RAM/latency, configurable thresholds, cooldown |
| `seaweedfs-swarm` | Shell | 16 | Compose stack for 3-node SeaweedFS with locality | Adapt to our cluster, add volume plugin, HA |

### Reference Only (superseded or abandoned)

| Fork | Reason | Action |
|:---|:---|:---|
| `swarm-sync` | Superseded by `swarm-cd` (more features, active, UI) | Keep as reference, use swarm-cd |
| `hca` | 1 star, WIP since 2020, abandoned | API reference only |

## Custom Services to Build

These are the core Swarmex services that **do not exist** and must be developed from scratch.
All are built on the **Docker Event Stream** pattern (section 5 of SWARMEX.md) using the Docker Engine SDK.

### Base Layer

| Service | Repo | Language | Purpose |
|:---|:---|:---|:---|
| **Event Controller** | `swarmex-event-controller` | Go | Base event stream listener. Connects to `/var/run/docker.sock`, filters `container`, `service`, `node` events, and dispatches to registered handlers. Shared library used by all other controllers. |

### Gap Analysis Services (SWARMEX.md Section 3)

| Service | Repo | Language | Gap Covered | Description |
|:---|:---|:---|:---|:---|
| **Swarm-Scaler** | `swarmex-scaler` | Go | Horizontal Autoscaling (HPA) | Consumes Prometheus metrics (CPU/RAM/latency), executes `docker service update --replicas` in real-time. Configurable thresholds, cooldown periods, min/max replica bounds per service via labels. |
| **Traffic-Gatekeeper** | `swarmex-gatekeeper` | Go | Readiness Probes | Listens Docker socket events, performs L7 healthchecks (HTTP 200) on containers, activates/deactivates Traefik routing labels dynamically. Blocks traffic until app is truly ready. |
| **Swarm-Operator-DB** | `swarmex-operator-db` | Go | Stateful Operators | Reconciliation loops for database lifecycle: quorum management (PostgreSQL, MySQL), automated failover on node/volume loss, backup scheduling, volume migration between nodes. |
| **Vault-Sync-Sidecar** | `swarmex-vault-sync` | Go | Dynamic Secret Injection | Sidecar that reads secrets from OpenBao (Vault OSS fork), injects into container memory via tmpfs at `/run/secrets/`, watches for rotation events and hot-reloads without container restart. |
| **Nano-Mesh** | `swarmex-nano-mesh` | Go | Lightweight Service Mesh | EasyTier integration wrapper: listens Docker events, auto-provisions/deprovisions EasyTier peers per service. NOT building WireGuard from scratch. |

### Additional Controllers (SWARMEX.md Section 4)

| Service | Repo | Language | Phase | Description |
|:---|:---|:---|:---|:---|
| **Healthcheck-Remediation** | `swarmex-remediation` | Go | Phase 3 | Retry-and-purge logic: detects persistent healthcheck failures in the data plane, auto-restarts tasks, purges caches, escalates to node drain if failures persist. |
| **Blue/Green Deployer** | `swarmex-deployer` | Go | Phase 4 | External controller that manages traffic weight between service versions during updates. Creates parallel service, shifts Traefik weights gradually, rolls back on failure. |

### Architecture Pattern

All custom services follow the same pattern from SWARMEX.md section 5:

```
Docker Socket (/var/run/docker.sock)
        │
        ▼
┌─────────────────────┐
│  Event Controller    │  ← swarmex-event-controller (shared)
│  GET /events         │
│  Filter: container,  │
│  service, node       │
└────────┬────────────┘
         │ dispatch
         ▼
┌─────────────────────┐
│  Business Logic      │  ← swarmex-scaler, gatekeeper, etc.
│  - Query Prometheus  │
│  - Check health      │
│  - Update service    │
│  - Rotate secrets    │
└─────────────────────┘
```

### Repo Summary (all under `ccvass/swarmex` group)

| Repo | Type | Status |
|:---|:---|:---|
| `swarmex-coordinator` | Docs/coordination | Created |
| `swarmex-event-controller` | Shared library | To create |
| `swarmex-scaler` | Custom service | To create |
| `swarmex-gatekeeper` | Custom service | To create |
| `swarmex-operator-db` | Custom service | To create |
| `swarmex-vault-sync` | Custom service | To create |
| `swarmex-nano-mesh` | Custom service | To create |
| `swarmex-remediation` | Custom service | To create |
| `swarmex-deployer` | Custom service | To create |

---

## OSS Resources to Fork or Deploy

Existing tools that complement the custom services.

### Core Infrastructure

| Tool | Purpose | License | GitHub | Action |
|:---|:---|:---|:---|:---|
| SwarmKit | Swarm control plane (upstream) | Apache-2.0 | `moby/swarmkit` | Reference only |
| Portainer CE | Cluster management UI + RBAC | Zlib | `portainer/portainer` | Fork CE |
| Swarmpit | Lightweight Swarm management UI | Eclipse | `swarmpit/swarmpit` | Fork |
| Coolify | PaaS / GitOps deployments | Apache-2.0 | `coollabsio/coolify` | Fork, extend Swarm support |
| Authentik | SSO / Identity Provider | MIT-variant | `goauthentik/authentik` | Deploy as-is |

### Observability

| Tool | Purpose | License | GitHub | Action |
|:---|:---|:---|:---|:---|
| Prometheus | Metrics collection | Apache-2.0 | `prometheus/prometheus` | Deploy as-is |
| Grafana | Dashboards | AGPL-3.0 | `grafana/grafana` | Deploy as-is |
| Loki | Log aggregation | AGPL-3.0 | `grafana/loki` | Deploy as-is |
| Tempo | Distributed tracing | AGPL-3.0 | `grafana/tempo` | Deploy as-is |
| Promswarm | Swarmprom modernized | MIT | `neuroforgede/promswarm` | Fork as base |
| swarm-monitoring | Prometheus+cAdvisor+Grafana | MIT | `sam-mosleh/swarm-monitoring` | Fork as base |

### Networking and Ingress

| Tool | Purpose | License | GitHub | Action |
|:---|:---|:---|:---|:---|
| Traefik Proxy | Dynamic reverse proxy + SSL | MIT | `traefik/traefik` | Deploy as-is |
| EasyTier | Decentralized WireGuard mesh | Apache-2.0 | `EasyTier/EasyTier` | Fork for nano-mesh base |
| Webmesh | Zero-config WireGuard mesh | Apache-2.0 | `webmeshproj/webmesh` | Evaluate vs EasyTier |

### Autoscaling (bases for swarmex-scaler)

| Tool | Purpose | License | GitHub | Action |
|:---|:---|:---|:---|:---|
| docker-swarm-autoscaler | CPU-based autoscaling | MIT | `jcwimer/docker-swarm-autoscaler` | Fork, extend in scaler |
| HCA | HPA-style for Swarm | OSS | `lucianorc/hca` | Fork, reference |

### Storage

| Tool | Purpose | License | GitHub | Action |
|:---|:---|:---|:---|:---|
| SeaweedFS | Distributed blob/file storage | Apache-2.0 | `seaweedfs/seaweedfs` | Deploy as-is |
| SeaweedFS Volume Plugin | Docker volume driver | OSS | `onaci/docker-plugin-seaweedfs` | Fork |
| SeaweedFS Swarm Stack | HA SeaweedFS on Swarm | OSS | `cycneuramus/seaweedfs-docker-swarm` | Fork as base |

### Secrets (bases for swarmex-vault-sync)

| Tool | Purpose | License | GitHub | Action |
|:---|:---|:---|:---|:---|
| OpenBao | Vault OSS fork (post-BUSL) | MPL-2.0 | `openbao/openbao` | Deploy, integrate |
| docker-stack-deploy | Auto config/secret rotation | OSS | awesome-swarm ref | Fork |

### GitOps and CD

| Tool | Purpose | License | GitHub | Action |
|:---|:---|:---|:---|:---|
| SwarmCD | Declarative GitOps for Swarm | OSS | `m-adawi/swarm-cd` | Fork |
| Swarm Sync | GitOps for Docker Swarm | OSS | `swarm-pack/swarm-sync` | Fork |
| Gantry | Enhanced auto-update services | OSS | `shizunge/gantry` | Fork |

### Scheduling and Utilities

| Tool | Purpose | License | GitHub | Action |
|:---|:---|:---|:---|:---|
| swarm-cronjob | Cron-based jobs on Swarm | MIT | `crazy-max/swarm-cronjob` | Fork |
| Shepherd | Auto-update on image refresh | MIT | `containrrr/shepherd` | Reference |

---

## Phase 1: Observability Foundation

**Goal:** Establish telemetry for automated decision-making.

### Deploy (existing OSS)

- [ ] Prometheus + Grafana + Loki + Tempo stack on Swarm
- [ ] Fork `sam-mosleh/swarm-monitoring` → `ccvass/swarmex/swarm-monitoring`
- [ ] Fork `neuroforgede/promswarm` → `ccvass/swarmex/promswarm`
- [ ] Deploy Portainer CE, fork `portainer/portainer` → `ccvass/swarmex/portainer-ce`
- [ ] cAdvisor + Node Exporter on all nodes
- [ ] Deploy Authentik for SSO

### Build (custom)

- [ ] Create `swarmex-event-controller` repo — base event stream library
- [ ] Implement Docker socket connection, event filtering, handler dispatch
- [ ] Unit tests with mock Docker events

---

## Phase 2: Traffic Intelligence and Ingress

**Goal:** Traffic only reaches healthy containers.

### Deploy (existing OSS)

- [ ] Traefik Proxy with Swarm Mode provider
- [ ] Automatic SSL via Let's Encrypt
- [ ] Evaluate WireGuard mesh: fork `EasyTier/EasyTier` or `webmeshproj/webmesh`

### Build (custom)

- [ ] Create `swarmex-gatekeeper` repo
- [ ] Implement: listen Docker socket → detect container health events → toggle Traefik labels
- [ ] L7 readiness probes: HTTP 200 check before allowing Traefik to route
- [ ] Integration tests with Traefik + mock unhealthy containers

---

## Phase 3: Elasticity and Self-Healing

**Goal:** Zero human intervention for load and failure management.

### Deploy (existing OSS)

- [ ] Fork `jcwimer/docker-swarm-autoscaler` → `ccvass/swarmex/swarm-autoscaler`
- [ ] Fork `crazy-max/swarm-cronjob` → `ccvass/swarmex/swarm-cronjob`
- [ ] Fork `shizunge/gantry` → `ccvass/swarmex/gantry`

### Build (custom)

- [ ] Create `swarmex-scaler` repo
- [ ] Implement: query Prometheus → compare thresholds → `docker service update --replicas`
- [ ] Support CPU, RAM, latency metrics (not just CPU like existing tools)
- [ ] Configurable via Docker labels: `swarmex.scaler.min=2`, `swarmex.scaler.max=10`, `swarmex.scaler.cpu-target=70`
- [ ] Cooldown periods to prevent flapping
- [ ] Create `swarmex-remediation` repo
- [ ] Implement: detect persistent healthcheck failures → auto-restart tasks → purge caches → escalate to node drain

---

## Phase 4: Stateful Persistence and Zero-Downtime Deploys

**Goal:** Distributed data and deployments without downtime.

### Deploy (existing OSS)

- [ ] SeaweedFS cluster, fork `cycneuramus/seaweedfs-docker-swarm`
- [ ] Fork `onaci/docker-plugin-seaweedfs` for volume driver
- [ ] Deploy OpenBao (`openbao/openbao`, MPL-2.0)
- [ ] Fork `m-adawi/swarm-cd` → `ccvass/swarmex/swarm-cd`

### Build (custom)

- [ ] Create `swarmex-operator-db` repo
- [ ] Implement: reconciliation loops for PostgreSQL/MySQL quorum, automated failover, backup scheduling, volume migration
- [ ] Create `swarmex-vault-sync` repo
- [ ] Implement: read OpenBao secrets → inject tmpfs `/run/secrets/` → watch rotation → hot-reload
- [ ] Create `swarmex-deployer` repo
- [ ] Implement: blue/green controller → create parallel service → shift Traefik weights → rollback on failure
- [ ] Create `swarmex-nano-mesh` repo
- [ ] Implement: auto-discover services via Docker events → provision WireGuard tunnels → manage peer configs → mTLS-equivalent encryption

---

## License Audit

| Tool | Issue | Action |
|:---|:---|:---|
| HashiCorp Vault | Changed to BUSL-1.1 in 2023 | Use OpenBao (MPL-2.0 fork) |
| Portainer | CE is Zlib (OSS), EE is proprietary | Fork CE only |
| Netmaker | SSPL for some components | Prefer EasyTier (Apache-2.0) |
| Grafana/Loki/Tempo | AGPL-3.0 | OK for internal use |
| Coolify | Swarm support limited | Fork and extend |

## Reference Collections

- [BretFisher/awesome-swarm](https://github.com/BretFisher/awesome-swarm) — 726 stars
- [swarmlibs](https://github.com/swarmlibs) — Migrated from YouMightNotNeedKubernetes
- [Docker Swarm Docs](https://docs.docker.com/engine/swarm/)
- [SwarmKit](https://github.com/moby/swarmkit) — Apache-2.0
- [Mirantis Swarm Support until 2030](https://www.mirantis.com/blog/mirantis-guarantees-long-term-support-for-swarm/)
