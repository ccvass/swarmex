# Swarmex Coordinator

Integration hub for the **Swarmex** project — extending Docker Swarm to enterprise-grade orchestration.

This repo coordinates all services: shared documentation, common configurations, docker-compose stacks for the full platform, and project tracking.

## Quick Start

```bash
# Clone coordinator
git clone git@scovil.labtau.com:ccvass/swarmex/swarmex-coodinator.git
cd swarmex-coodinator

# Clone all sub-repos (each is independent)
./scripts/clone-all.sh
```

## Project Structure

```
swarmex-coodinator/
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

All depend on `swarmex-event-controller` as shared base.

| Repo | Issue | Purpose | Priority |
|:---|:---|:---|:---|
| `swarmex-event-controller` | #2 | Docker Event Stream listener, handler dispatch | `critical` |
| `swarmex-scaler` | #3 | HPA autoscaling (CPU/RAM/latency via Prometheus) | `high` |
| `swarmex-gatekeeper` | #4 | Readiness probes, Traefik label gating | `high` |
| `swarmex-operator-db` | #5 | DB quorum, failover, backup, volume migration | `medium` |
| `swarmex-vault-sync` | #6 | Secret injection from OpenBao, hot-reload | `medium` |
| `swarmex-nano-mesh` | #7 | WireGuard tunnels between services | `medium` |
| `swarmex-remediation` | #8 | Self-healing: retry, purge, drain escalation | `high` |
| `swarmex-deployer` | #9 | Blue/green with Traefik traffic weights | `medium` |

### Forked OSS Projects

Sorted by value to the project (activity, stars, relevance).

#### Tier 1: Active and Critical

These are actively maintained, high-star projects essential to the stack.

| Repo | Source | Stars | Last Push | Language | Role |
|:---|:---|:---|:---|:---|:---|
| `coolify` | `coollabsio/coolify` | 52963 | 2026-04-12 | PHP | PaaS / GitOps deployments |
| `portainer-ce` | `portainer/portainer` | 37145 | 2026-04-10 | TypeScript | Cluster management UI + RBAC |
| `easytier` | `EasyTier/EasyTier` | 10800 | 2026-04-12 | Rust | WireGuard mesh (nano-mesh base) |
| `swarmpit` | `swarmpit/swarmpit` | 3420 | 2026-03-04 | Clojure | Lightweight Swarm UI |
| `swarm-cronjob` | `crazy-max/swarm-cronjob` | 868 | 2026-04-09 | Go | Cron jobs on Swarm |
| `swarm-cd` | `m-adawi/swarm-cd` | 182 | 2026-02-08 | Go | GitOps for Swarm |
| `gantry` | `shizunge/gantry` | 88 | 2026-04-12 | Shell | Auto-update services |

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

#### Tier 3: Reference / Evaluate

Low activity, useful as reference code but likely needs rewrite.

| Repo | Source | Stars | Last Push | Language | Role |
|:---|:---|:---|:---|:---|:---|
| `hca` | `lucianorc/hca` | 1 | 2020-02-26 | Go | HPA concept (WIP) |

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

## OSS Policy

All components are 100% open source. When dual-licensed (CE/EE), we fork the community edition only.

| Decision | Reason |
|:---|:---|
| OpenBao over HashiCorp Vault | Vault changed to BUSL-1.1; OpenBao is MPL-2.0 |
| Portainer CE only | EE is proprietary; CE is Zlib |
| EasyTier over Netmaker | Netmaker has SSPL components; EasyTier is Apache-2.0 |
| Grafana stack (AGPL-3.0) | OK for internal use, no SaaS redistribution |

## License

TBD

## Maintainer

Alfonso de la Guarda — CCVASS
