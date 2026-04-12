# Swarmex Coordinator

Integration hub for the **Swarmex** project — extending Docker Swarm to enterprise-grade orchestration.

This repo coordinates all services: shared documentation, common configurations, docker-compose stacks for the full platform, and project tracking.

## Quick Start

```bash
# Clone coordinator
git clone git@scovil.labtau.com:ccvass/swarmex/swarmex-coordinator.git
cd swarmex-coordinator

# Clone all sub-repos (each is independent)
./scripts/clone-all.sh
```

## Project Structure

```
swarmex-coordinator/
├── README.md              # This file
├── ROADMAP.md             # Detailed phases with resources
├── SWARMEX.md             # Original vision document
├── stacks/                # Docker Compose stacks for deployment
│   ├── observability.yml  # Prometheus + Grafana + Loki + Tempo
│   ├── ingress.yml        # Traefik + SSL
│   ├── storage.yml        # SeaweedFS cluster
│   ├── security.yml       # Authentik + OpenBao
│   └── swarmex.yml        # All custom Swarmex controllers
├── configs/               # Shared configurations
│   ├── prometheus/        # Prometheus scrape configs, alert rules
│   ├── grafana/           # Dashboard JSON exports
│   ├── traefik/           # Traefik static/dynamic config
│   └── labels.md          # Standard Docker label conventions
├── scripts/               # Utility scripts
│   └── clone-all.sh       # Clone all sub-repos
└── docs/                  # Architecture decisions, guides
```

## All Repos (23 total in `ccvass/swarmex`)

### Custom Services to Build (Go, Docker Engine SDK)

All depend on `swarmex-event-controller` as shared base. **All 8 services are built, tested, and pushed.**

| Repo | Issue | Purpose | Binary | Status |
|:---|:---|:---|:---|:---|
| `swarmex-event-controller` | #2 | Docker Event Stream listener, handler dispatch | 12MB | ✅ |
| `swarmex-scaler` | #3 | HPA autoscaling (CPU/RAM/latency via Prometheus) | 8.1MB | ✅ |
| `swarmex-gatekeeper` | #4 | Readiness probes, Traefik label gating | 8.1MB | ✅ |
| `swarmex-operator-db` | #5 | DB quorum, failover, backup, volume migration | 8.1MB | ✅ |
| `swarmex-vault-sync` | #6 | Secret injection from OpenBao, hot-reload | 8.0MB | ✅ |
| `swarmex-nano-mesh` | #7 | EasyTier wrapper for Docker auto-provisioning | 8.1MB | ✅ |
| `swarmex-remediation` | #8 | Self-healing: retry, purge, drain escalation | 8.2MB | ✅ |
| `swarmex-deployer` | #9 | Blue/green with Traefik traffic weights | 8.1MB | ✅ |

### Forked OSS Projects

Sorted by value to the project (activity, stars, relevance).

#### Production-Ready (deploy directly, no custom build needed)

| Repo | Source | Stars | Last Push | What it solves |
|:---|:---|:---|:---|:---|
| `swarm-cronjob` | `crazy-max/swarm-cronjob` | 868 | 2026-04-09 | ✅ Cron jobs via labels. Go, v1.15, 509 commits |
| `gantry` | `shizunge/gantry` | 88 | 2026-04-12 | ✅ Auto-update services, rollback, webhooks. 36 releases |
| `swarm-cd` | `m-adawi/swarm-cd` | 182 | 2026-02-08 | ✅ GitOps declarative (ArgoCD for Swarm), UI, SOPS secrets |
| `easytier` | `EasyTier/EasyTier` | 10800 | 2026-04-12 | ✅ Full WireGuard mesh, NAT traversal, web UI. Reduces nano-mesh to wrapper |

#### Tier 1: Active, High Value (deploy and extend)

| Repo | Source | Stars | Last Push | Language | Role |
|:---|:---|:---|:---|:---|:---|
| `coolify` | `coollabsio/coolify` | 52963 | 2026-04-12 | PHP | PaaS / GitOps deployments |
| `portainer-ce` | `portainer/portainer` | 37145 | 2026-04-10 | TypeScript | Cluster management UI + RBAC |
| `swarmpit` | `swarmpit/swarmpit` | 3420 | 2026-03-04 | Clojure | Lightweight Swarm UI |

#### Tier 2: Useful but Less Active

Valuable code to fork and extend, but upstream is slower or stale.

| Repo | Source | Stars | Last Push | Language | Role |
|:---|:---|:---|:---|:---|:---|
| `swarm-autoscaler` | `jcwimer/docker-swarm-autoscaler` | 102 | 2019-12-18 | Ruby | CPU autoscaling (base for scaler) |
| `swarm-sync` | `swarm-pack/swarm-sync` | 98 | 2023-01-07 | JavaScript | GitOps alternative |
| `promswarm` | `neuroforgede/promswarm` | 33 | 2024-04-06 | Jinja | Prometheus/Grafana stack |
| `swarm-monitoring` | `sam-mosleh/swarm-monitoring` | 19 | 2025-08-11 | Dockerfile | Monitoring stack |
| `seaweedfs-swarm` | `cycneuramus/seaweedfs-docker-swarm` | 16 | 2023-01-10 | Shell | SeaweedFS on Swarm |
| `seaweedfs-volume-plugin` | `onaci/docker-plugin-seaweedfs` | 14 | 2021-02-18 | Go | Docker volume driver |

#### Tier 3: Reference / Superseded

| Repo | Source | Stars | Last Push | Language | Status |
|:---|:---|:---|:---|:---|:---|
| `hca` | `lucianorc/hca` | 1 | 2020-02-26 | Go | ❌ Abandoned |
| `swarm-sync` | `swarm-pack/swarm-sync` | 98 | 2023-01-07 | JavaScript | ❌ Superseded by swarm-cd |
| `coolify` | `coollabsio/coolify` | 52963 | 2026-04-12 | PHP | ❌ No Swarm support (issue #514 closed) |
| `promswarm` | `neuroforgede/promswarm` | 33 | 2024-04-06 | Jinja | ❌ Stale, swarm-monitoring is newer |
| `swarmpit` | `swarmpit/swarmpit` | 3420 | 2026-03-04 | Clojure | Optional (Portainer CE is primary UI) |

## Docker Label Convention

All Swarmex services are configured via Docker deploy labels with the `swarmex.` prefix:

```yaml
services:
  my-api:
    deploy:
      labels:
        # Scaler
        swarmex.scaler.enabled: "true"
        swarmex.scaler.min: "2"
        swarmex.scaler.max: "10"
        swarmex.scaler.cpu-target: "70"
        # Gatekeeper
        swarmex.gatekeeper.enabled: "true"
        swarmex.gatekeeper.path: "/health/ready"
        # Vault
        swarmex.vault.enabled: "true"
        swarmex.vault.path: "secret/data/my-api"
        # Deployer
        swarmex.deployer.strategy: "blue-green"
```

## Production Stack (OSS Only)

| Layer | Tool | License | Decision |
|:---|:---|:---|:---|
| UI / RBAC | Portainer CE + Authentik | Zlib + MIT | CE lacks granular RBAC/SSO, Authentik fills both |
| Ingress / L7 | Traefik Proxy | MIT | Native Swarm provider |
| GitOps / PaaS | swarm-cd | GPL-3.0 | ArgoCD for Swarm. Coolify discarded (no Swarm support) |
| Observability | swarm-monitoring + AlertManager + Loki + Tempo | MIT + Apache | swarm-monitoring base (2025), promswarm discarded (stale 2024) |
| Storage | SeaweedFS | Apache-2.0 | seaweedfs-swarm + volume-plugin |
| SSO | Authentik | MIT-variant | OIDC/SAML for Portainer, Grafana, Traefik |
| Secrets | OpenBao | MPL-2.0 | Vault fork, API-compatible |
| Mesh | EasyTier | LGPL-3.0 | nano-mesh wraps it |
| Cron | swarm-cronjob | MIT | Production-ready, v1.15 |
| Auto-update | gantry | GPL-3.0 | 36 releases, rollback, webhooks |

## License

TBD

## Maintainer

Alfonso de la Guarda — CCVASS
