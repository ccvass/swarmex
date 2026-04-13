# Swarmex Coordinator

Extending Docker Swarm to enterprise-grade orchestration — 10x less resources than Kubernetes.

**Status: 33 services running on 3-node AWS cluster. 12 controllers verified end-to-end. All K8s governance features implemented.**

## What is Swarmex

Swarmex adds every missing Kubernetes feature to Docker Swarm via lightweight Go sidecar controllers that read configuration from Docker labels. No CRDs, no operators, no YAML complexity.

```yaml
deploy:
  labels:
    swarmex.scaler.enabled: "true"
    swarmex.scaler.min: "2"
    swarmex.scaler.max: "10"
    swarmex.namespace: "production"
    swarmex.gatekeeper.enabled: "true"
    swarmex.netpolicy.allow: "frontend-svc"
```

See [docs/K8S-VS-SWARMEX.md](docs/K8S-VS-SWARMEX.md) for the full feature comparison.

## Controllers (12 total, all verified)

### Core (8)

| Controller | What it does | Verified |
|:---|:---|:---|
| `event-controller` | Docker Event Stream listener, dispatches to all others | ✅ Real-time event capture |
| `scaler` | HPA autoscaling via Prometheus (CPU/RAM/latency) | ✅ Scaled 2→5→2 under load |
| `gatekeeper` | Readiness probes, toggles Traefik labels | ✅ "service READY, enabling Traefik" |
| `remediation` | Self-healing: restart → force-restart → drain node | ✅ Escalation chain |
| `deployer` | Blue/green via Traefik traffic weights | ✅ Green service created |
| `vault-sync` | Secret injection from OpenBao to tmpfs | ✅ 2 secrets synced |
| `operator-db` | DB quorum, failover for PostgreSQL/MySQL | ✅ TCP health monitoring |
| `nano-mesh` | WireGuard mesh via EasyTier wrapper | ✅ Peer registration |

### Governance (4)

| Controller | What it does | Verified |
|:---|:---|:---|
| `namespaces` | Namespace isolation via auto-created overlay networks | ✅ ns-frontend, ns-backend created |
| `netpolicy` | Cross-namespace access control via network attachment | ✅ svc-be got ns-fe network added |
| `rbac` | Docker socket proxy with role-based access | ✅ admin granted, anonymous denied |
| `admission` | Validate/mutate services on creation | ✅ Running, configurable rules |

All images built via CI/CD (kaniko) and pushed to `registry.labtau.com/ccvass/swarmex/`.

## Production Stack (100% OSS)

| Layer | Tool | Status |
|:---|:---|:---|
| Ingress / SSL | Traefik Proxy (MIT) | ✅ Let's Encrypt |
| Observability | Prometheus + Grafana + Loki + Tempo (AGPL) | ✅ 11 targets, 3 datasources, 2 dashboards |
| UI / RBAC | Portainer CE (Zlib) + Authentik (MIT) | ✅ SSO configured |
| Storage | SeaweedFS (Apache-2.0) | ✅ Master + Volume 3/3 + Filer |
| Secrets | OpenBao (MPL-2.0) | ✅ Initialized, KV v2 |
| GitOps | swarm-cd (GPL-3.0) | ✅ UI accessible |
| Cron | swarm-cronjob (MIT) | ✅ |
| Auto-update | gantry (GPL-3.0) | ✅ |
| Mesh | EasyTier (LGPL-3.0) | ✅ In nano-mesh image |
| DB: PostgreSQL 18, Cache: Valkey 8 | | ✅ |

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
├── README.md
├── ROADMAP.md
├── STANDARDS.md
├── SWARMEX.md                 # Original vision
├── stacks/                    # Docker Compose deploy stacks
├── configs/                   # Prometheus, Loki, Tempo, OpenBao, SeaweedFS, swarm-cd
├── docker/authentik/          # Patched Authentik (Attr fix)
├── scripts/                   # pre-deploy, clone-all, aws-stop/start
└── docs/
    ├── K8S-VS-SWARMEX.md      # Feature comparison (35+ features)
    └── FORK-STATUS.md          # Fork analysis, upstream PRs
```

## Repos (27 in `ccvass/swarmex` group)

- 1 coordinator
- 12 custom controllers (Go, CI/CD, registry images)
- 1 patched fork (authentik)
- 4 active forks used as-is (swarm-cronjob, gantry, swarm-cd, easytier)
- 4 active forks with improvements (seaweedfs-swarm, seaweedfs-volume-plugin, portainer-ce, swarmpit)
- 5 archived forks

## Upstream Contributions

| PR | Repo | Description |
|:---|:---|:---|
| [#21557](https://github.com/goauthentik/authentik/pull/21557) | goauthentik/authentik | Fix Attr path navigation for Docker Swarm env vars |
| [#3](https://github.com/cycneuramus/seaweedfs-docker-swarm/pull/3) | cycneuramus/seaweedfs-docker-swarm | Swarm overlay IP resolution entrypoints |

## License

TBD

## Maintainer

Alfonso de la Guarda — CCVASS
