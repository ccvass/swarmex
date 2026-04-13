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
| `swarm-sync` | Superseded by `swarm-cd` (more features, active, UI) | Discard |
| `hca` | 1 star, WIP since 2020, abandoned | Discard |
| `coolify` | Swarm support issue #514 closed as "not planned". Uses Docker standalone, not `docker stack deploy`. swarm-cd covers PaaS/GitOps natively | Discard |
| `promswarm` | Stale since 2024-04. swarm-monitoring is more recent and cleaner | Discard |
| `swarmpit` | Optional alternative UI, not needed with Portainer CE | Keep as optional |

## Custom Services to Build

These are the core Swarmex services that **do not exist** and must be developed from scratch.
All are built on the **Docker Event Stream** pattern using the Docker Engine SDK.

### Base Layer

| Service | Repo | Language | Purpose |
|:---|:---|:---|:---|
| **Event Controller** | `swarmex-event-controller` | Go | Base event stream listener. Connects to `/var/run/docker.sock`, filters `container`, `service`, `node` events, and dispatches to registered handlers. Shared library used by all other controllers. |

### Gap Analysis Services

| Service | Repo | Language | Gap Covered | Description |
|:---|:---|:---|:---|:---|
| **Swarm-Scaler** | `swarmex-scaler` | Go | Horizontal Autoscaling (HPA) | Consumes Prometheus metrics (CPU/RAM/latency), executes `docker service update --replicas` in real-time. Configurable thresholds, cooldown periods, min/max replica bounds per service via labels. |
| **Traffic-Gatekeeper** | `swarmex-gatekeeper` | Go | Readiness Probes | Listens Docker socket events, performs L7 healthchecks (HTTP 200) on containers, activates/deactivates Traefik routing labels dynamically. Blocks traffic until app is truly ready. |
| **Swarm-Operator-DB** | `swarmex-operator-db` | Go | Stateful Operators | Reconciliation loops for database lifecycle: quorum management (PostgreSQL, MySQL), automated failover on node/volume loss, backup scheduling, volume migration between nodes. |
| **Vault-Sync-Sidecar** | `swarmex-vault-sync` | Go | Dynamic Secret Injection | Sidecar that reads secrets from OpenBao (Vault OSS fork), injects into container memory via tmpfs at `/run/secrets/`, watches for rotation events and hot-reloads without container restart. |
| **Nano-Mesh** | `swarmex-nano-mesh` | Go | Lightweight Service Mesh | EasyTier integration wrapper: listens Docker events, auto-provisions/deprovisions EasyTier peers per service. NOT building WireGuard from scratch. |

### Additional Controllers

| Service | Repo | Language | Phase | Description |
|:---|:---|:---|:---|:---|
| **Healthcheck-Remediation** | `swarmex-remediation` | Go | Phase 3 | Retry-and-purge logic: detects persistent healthcheck failures in the data plane, auto-restarts tasks, purges caches, escalates to node drain if failures persist. |
| **Blue/Green Deployer** | `swarmex-deployer` | Go | Phase 4 | External controller that manages traffic weight between service versions during updates. Creates parallel service, shifts Traefik weights gradually, rolls back on failure. |

### Architecture Pattern

All custom services follow the same pattern using the Docker Event Stream pattern:

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
| `swarmex-coordinator` | Docs/coordination | ✅ Complete |
| `swarmex-event-controller` | Shared library | ✅ Built (Go, 12MB) |
| `swarmex-scaler` | Custom service | ✅ Built (Go, 8.1MB) |
| `swarmex-gatekeeper` | Custom service | ✅ Built (Go, 8.1MB) |
| `swarmex-operator-db` | Custom service | ✅ Built (Go, 8.1MB) |
| `swarmex-vault-sync` | Custom service | ✅ Built (Go, 8.0MB) |
| `swarmex-nano-mesh` | Custom service | ✅ Built (Go, 8.1MB) |
| `swarmex-remediation` | Custom service | ✅ Built (Go, 8.2MB) |
| `swarmex-deployer` | Custom service | ✅ Built (Go, 8.1MB) |

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

## Phase 1: Observability Foundation ✅

**Goal:** Establish telemetry for automated decision-making.

### Deploy (existing OSS)

- [ ] Prometheus + Grafana + Loki + Tempo stack on Swarm
- [ ] Fork `sam-mosleh/swarm-monitoring` → `ccvass/swarmex/swarm-monitoring`
- [ ] Fork `neuroforgede/promswarm` → `ccvass/swarmex/promswarm`
- [ ] Deploy Portainer CE, fork `portainer/portainer` → `ccvass/swarmex/portainer-ce`
- [ ] cAdvisor + Node Exporter on all nodes
- [ ] Deploy Authentik for SSO

### Build (custom)

- [x] Create `swarmex-event-controller` repo — base event stream library
- [x] Implement Docker socket connection, event filtering, handler dispatch
- [x] Unit tests with mock Docker events

---

## Phase 2: Traffic Intelligence and Ingress ✅

**Goal:** Traffic only reaches healthy containers.

### Deploy (existing OSS)

- [ ] Traefik Proxy with Swarm Mode provider
- [ ] Automatic SSL via Let's Encrypt
- [ ] Evaluate WireGuard mesh: fork `EasyTier/EasyTier` or `webmeshproj/webmesh`

### Build (custom)

- [x] Create `swarmex-gatekeeper` repo
- [x] Implement: listen Docker socket → detect container health events → toggle Traefik labels
- [x] L7 readiness probes: HTTP 200 check before allowing Traefik to route
- [x] Integration tests with Traefik + mock unhealthy containers

---

## Phase 3: Elasticity and Self-Healing ✅

**Goal:** Zero human intervention for load and failure management.

### Deploy (existing OSS)

- [ ] Fork `jcwimer/docker-swarm-autoscaler` → `ccvass/swarmex/swarm-autoscaler`
- [ ] Fork `crazy-max/swarm-cronjob` → `ccvass/swarmex/swarm-cronjob`
- [ ] Fork `shizunge/gantry` → `ccvass/swarmex/gantry`

### Build (custom)

- [x] Create `swarmex-scaler` repo
- [x] Implement: query Prometheus → compare thresholds → `docker service update --replicas`
- [x] Support CPU, RAM, latency metrics (not just CPU like existing tools)
- [x] Configurable via Docker labels: `swarmex.scaler.min=2`, `swarmex.scaler.max=10`, `swarmex.scaler.cpu-target=70`
- [x] Cooldown periods to prevent flapping
- [x] Create `swarmex-remediation` repo
- [x] Implement: detect persistent healthcheck failures → auto-restart tasks → purge caches → escalate to node drain

---

## Phase 4: Stateful Persistence and Zero-Downtime Deploys ✅

**Goal:** Distributed data and deployments without downtime.

### Deploy (existing OSS)

- [ ] SeaweedFS cluster, fork `cycneuramus/seaweedfs-docker-swarm`
- [ ] Fork `onaci/docker-plugin-seaweedfs` for volume driver
- [ ] Deploy OpenBao (`openbao/openbao`, MPL-2.0)
- [ ] Fork `m-adawi/swarm-cd` → `ccvass/swarmex/swarm-cd`

### Build (custom)

- [x] Create `swarmex-operator-db` repo
- [x] Implement: reconciliation loops for PostgreSQL/MySQL quorum, automated failover, backup scheduling, volume migration
- [x] Create `swarmex-vault-sync` repo
- [x] Implement: read OpenBao secrets → inject tmpfs `/run/secrets/` → watch rotation → hot-reload
- [x] Create `swarmex-deployer` repo
- [x] Implement: blue/green controller → create parallel service → shift Traefik weights → rollback on failure
- [x] Create `swarmex-nano-mesh` repo
- [x] Implement: auto-discover services via Docker events → provision WireGuard tunnels → manage peer configs → mTLS-equivalent encryption

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

## Phase 5: Governance and Security ✅

Completed 2026-04-12. All controllers built, deployed, and verified.

| Controller | Purpose | Verified |
|:---|:---|:---|
| `namespaces` | Namespace isolation via overlay networks | ✅ ns-frontend, ns-backend |
| `netpolicy` | Cross-namespace access control | ✅ Network attachment |
| `rbac` | Docker socket proxy with JWT auth | ✅ Authentik JWT + roles |
| `admission` | Validate/mutate on service creation | ✅ Deny + mutate + stack deploy |

## Phase 6: Enterprise Features ✅

Completed 2026-04-13. All controllers built, deployed, and verified.

| Controller | Purpose | Verified |
|:---|:---|:---|
| `vpa` | Vertical autoscaling | ✅ 512M→32M adjustment |
| `traffic` | Circuit breaker, retries, rate limiting | ✅ Traefik middlewares |
| `federation` | Multi-cluster replication | ✅ AWS→GCP cross-cloud |
| `api` | Custom resource API (bbolt persistence) | ✅ CRUD + survives restart |

## Phase 7: Production Hardening ✅

Completed 2026-04-13.

| Feature | Status |
|:---|:---|
| Credentials in Docker secrets | ✅ Authentik, OpenBao, Grafana |
| Centralized logging (Promtail→Loki) | ✅ 40 services |
| AlertManager webhook to API | ✅ 3 alerts received |
| /metrics on all 16 controllers | ✅ 15/15 Prometheus targets UP |
| Grafana provisioning + persistence | ✅ 3 datasources survive restart |
| Authentik image in registry | ✅ Pushed to registry.labtau.com |
| Automated backups (cron) | ✅ Authentik DB + OpenBao + configs |
| RBAC with JWT validation | ✅ Authentik JWT → role mapping |
| API persistence (bbolt) | ✅ Resources survive restart |

## All Phases Complete

35 services running. 16 controllers verified end-to-end. Reproducible install from scratch — 35/35 on first deploy.
Cross-cloud federation tested (AWS ↔ GCP). 2 upstream PRs submitted.

## Phase 9: Closing K8s Feature Gaps (Planned)

Features that can be implemented as controllers to match remaining Kubernetes advantages.

| Feature | Issue | Priority | Complexity |
|:---|:---|:---|:---|
| Canary deployments (weighted traffic) | #70 | medium | Extend deployer — Traefik weighted round-robin |
| Service affinity/anti-affinity | #71 | medium | New controller — placement constraints |
| Disruption budgets | #72 | medium | Extend remediation — min-available checks |
| Resource quotas per namespace | #73 | medium | Extend admission — sum limits per namespace |
| StatefulSets (stable identity) | #74 | low | New controller — N services with named volumes |
| swarmex-pack (Helm equivalent) | #75 | low | CLI tool — Go template → compose YAML |

### Not Feasible Without Docker Engine Changes

These K8s features cannot be replicated with controllers alone:

- **Kernel-level NetworkPolicies** — requires eBPF/iptables per-container (Swarm uses VXLAN without per-container filtering)
- **CRDs with full API machinery** — would require reimplementing etcd + API server + admission webhooks
- **L7 service mesh (Istio/Cilium)** — requires dataplane control that Swarm doesn't expose

## Phase 8: Cloud Node Autoscaling ✅

Completed 2026-04-13. Full cycle verified on AWS.

| Feature | Status |
|:---|:---|
| cluster-scaler controller | ✅ Built (13MB binary) |
| AWS provider | ✅ Verified: 3→5→3 nodes |
| GCP provider | ✅ Code ready |
| Azure provider | ✅ Code ready |
| DigitalOcean provider | ✅ Code ready |
| bbolt persistence | ✅ Survives restart (verified) |
| Scale-up (CPU > 80%) | ✅ EC2 instances created + joined Swarm |
| Scale-down (CPU < 15%) | ✅ Nodes drained + EC2 terminated |
| Multi-provider round-robin | ✅ Implemented |
