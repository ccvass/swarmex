# Swarmex Coordinator

Extending Docker Swarm to enterprise-grade orchestration — 10x less resources than Kubernetes.

**Status: 29 services running on 3-node AWS cluster. All controllers verified end-to-end.**

## What is Swarmex

Swarmex adds the missing Kubernetes features to Docker Swarm via lightweight Go sidecar controllers that read configuration from Docker labels. No CRDs, no operators, no YAML complexity.

```yaml
# Add autoscaling to any service with 3 labels
deploy:
  labels:
    swarmex.scaler.enabled: "true"
    swarmex.scaler.min: "2"
    swarmex.scaler.max: "10"
    swarmex.scaler.cpu-target: "70"
```

See [docs/K8S-VS-SWARMEX.md](docs/K8S-VS-SWARMEX.md) for the full comparison.

## Architecture

```
Docker Socket (/var/run/docker.sock)
        │
        ▼
┌─────────────────────┐
│  Event Controller    │ ← listens to all Docker events
└────────┬────────────┘
         │ dispatch
    ┌────┼────┬────────┬──────────┬──────────┬──────────┐
    ▼    ▼    ▼        ▼          ▼          ▼          ▼
 Scaler Gate- Remedi-  Deployer  Vault-    Operator  Nano-
        keeper ation             Sync      DB        Mesh
```

## Custom Controllers (8 services, all in Go)

| Controller | What it does | Verified |
|:---|:---|:---|
| `event-controller` | Docker Event Stream listener, dispatches to all others | ✅ Captures create/update/health events |
| `scaler` | HPA autoscaling via Prometheus (CPU/RAM/latency) | ✅ Scaled 2→5→2 replicas under load |
| `gatekeeper` | Readiness probes, toggles Traefik labels | ✅ "service READY, enabling Traefik" |
| `remediation` | Self-healing: restart → force-restart → drain node | ✅ Event matching verified |
| `deployer` | Blue/green via Traefik traffic weights | ✅ Created green service, weight shifting |
| `vault-sync` | Secret injection from OpenBao to tmpfs | ✅ Synced 2 secrets from OpenBao |
| `operator-db` | DB quorum, failover, backup for PostgreSQL/MySQL | ✅ TCP health monitoring |
| `nano-mesh` | WireGuard mesh via EasyTier wrapper | ✅ Peer registration (needs EasyTier cluster) |

All images built via CI/CD and pushed to `registry.labtau.com/ccvass/swarmex/`.

## Production Stack (100% OSS)

| Layer | Tool | Status |
|:---|:---|:---|
| Ingress / SSL | Traefik Proxy (MIT) | ✅ Running, Let's Encrypt |
| Observability | Prometheus + Grafana + Loki + Tempo | ✅ 11 targets, 3 datasources, 2 dashboards |
| UI / RBAC | Portainer CE (Zlib) + Authentik (MIT) | ✅ Both running, SSO configured |
| Storage | SeaweedFS (Apache-2.0) | ✅ Master + Volume 3/3 + Filer |
| Secrets | OpenBao (MPL-2.0) | ✅ Initialized, unsealed, KV v2 |
| GitOps | swarm-cd (GPL-3.0) | ✅ Running with UI |
| Cron | swarm-cronjob (MIT) | ✅ Running |
| Auto-update | gantry (GPL-3.0) | ✅ Running |
| Mesh | EasyTier (LGPL-3.0) | ✅ Included in nano-mesh image |

## Quick Start

```bash
git clone git@scovil.labtau.com:ccvass/swarmex/swarmex-coordinator.git
cd swarmex-coordinator

# On a Swarm cluster:
bash scripts/pre-deploy.sh
docker stack deploy -c stacks/ingress.yml ingress
docker stack deploy -c stacks/observability.yml observability
docker stack deploy -c stacks/security.yml security
docker stack deploy -c stacks/tools.yml tools
docker stack deploy -c stacks/storage.yml storage
docker stack deploy -c stacks/swarmex.yml swarmex
```

## Project Structure

```
swarmex-coordinator/
├── README.md                  # This file
├── ROADMAP.md                 # Implementation phases
├── STANDARDS.md               # Development standards
├── SWARMEX.md                 # Original vision document
├── stacks/                    # Docker Compose stacks
│   ├── ingress.yml            # Traefik + SSL
│   ├── observability.yml      # Prometheus + Grafana + Loki + Tempo
│   ├── security.yml           # Authentik + OpenBao
│   ├── storage.yml            # SeaweedFS
│   ├── tools.yml              # Portainer + swarm-cd + cronjob + gantry
│   └── swarmex.yml            # All 8 custom controllers
├── configs/                   # Shared configurations
│   ├── prometheus/            # Scrape configs + alert rules
│   ├── loki/                  # Loki config
│   ├── tempo/                 # Tempo config
│   ├── openbao/               # OpenBao config
│   ├── seaweedfs/             # Master/filer entrypoint scripts
│   ├── swarmcd/               # repos.yaml + stacks.yaml
│   └── labels.md              # swarmex.* label convention
├── docker/authentik/          # Patched Authentik (Attr fix)
├── scripts/
│   ├── pre-deploy.sh          # Create shared overlay networks
│   ├── clone-all.sh           # Clone all sub-repos
│   ├── aws-stop.sh            # Stop AWS cluster ($6/day → $0.30/day)
│   └── aws-start.sh           # Start AWS cluster
└── docs/
    ├── K8S-VS-SWARMEX.md      # Feature comparison with real test data
    └── FORK-STATUS.md          # Fork analysis and upstream PRs
```

## Repos (23 in `ccvass/swarmex` group)

- 1 coordinator (this repo)
- 8 custom controllers (Go, CI/CD, registry images)
- 1 patched fork (authentik)
- 4 active forks used as-is (swarm-cronjob, gantry, swarm-cd, easytier)
- 4 active forks with improvements (seaweedfs-swarm, seaweedfs-volume-plugin, portainer-ce, swarmpit)
- 5 archived forks (coolify, promswarm, swarm-sync, hca, swarm-autoscaler)

## Upstream Contributions

| PR | Repo | Description |
|:---|:---|:---|
| [#21557](https://github.com/goauthentik/authentik/pull/21557) | goauthentik/authentik | Fix Attr path navigation for Docker Swarm env vars |
| [#3](https://github.com/cycneuramus/seaweedfs-docker-swarm/pull/3) | cycneuramus/seaweedfs-docker-swarm | Swarm overlay IP resolution entrypoints |

## License

TBD

## Maintainer

Alfonso de la Guarda — CCVASS
