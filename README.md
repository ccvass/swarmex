# Swarmex Coordinator

Coordination repository for the **Swarmex** project — extending Docker Swarm to enterprise-grade orchestration without inheriting Kubernetes complexity.

## Vision

Swarmex transforms Docker Swarm into a sovereign orchestrator by adding programmable sidecar controllers that cover the critical gaps versus Kubernetes, while maintaining Swarm's lightweight footprint (10x less resources than K8s).

All components are **100% open source**. When a tool has OSS and enterprise editions, we use and fork the OSS version.

## Architecture

Multi-repo structure under the `ccvass/swarmex` GitLab group:

| Repository | Purpose |
|:---|:---|
| `swarmex-coordinator` | This repo. Roadmap, docs, coordination |
| `swarmex-scaler` | Horizontal autoscaling via Prometheus metrics |
| `swarmex-gatekeeper` | Traffic gating with readiness probes via Traefik |
| `swarmex-operator-db` | Stateful operator for DB lifecycle and failover |
| `swarmex-vault-sync` | Dynamic secret injection from HashiCorp Vault |
| `swarmex-nano-mesh` | Lightweight service mesh with WireGuard tunnels |

## Core Concept

All extensions are built around the **Docker Event Stream** pattern:

1. Listen to `/var/run/docker.sock` events
2. Filter by `container`, `service`, and `node` event types
3. Execute business logic (scale, gate traffic, rotate secrets, etc.)

## Phases

See [ROADMAP.md](ROADMAP.md) for the detailed implementation plan with all OSS resources mapped.

1. **Observability Foundation** — Prometheus, Grafana, Loki, Portainer CE
2. **Traffic Intelligence** — Traefik, Traffic-Gatekeeper readiness probes
3. **Elasticity and Self-Healing** — Swarm-Scaler HPA, healthcheck remediation
4. **Stateful Persistence** — SeaweedFS, blue/green deployments

## Production Stack (OSS Only)

| Layer | Tool | License | Repo |
|:---|:---|:---|:---|
| UI / RBAC | Portainer CE | Zlib | `portainer/portainer` |
| Ingress / L7 | Traefik Proxy | MIT | `traefik/traefik` |
| PaaS / GitOps | Coolify | Apache-2.0 | `coollabsio/coolify` |
| Storage | SeaweedFS | Apache-2.0 | `seaweedfs/seaweedfs` |
| SSO | Authentik | MIT-variant | `goauthentik/authentik` |

## Getting Started

```bash
git clone git@scovil.labtau.com:ccvass/swarmex/swarmex-coodinator.git
cd swarmex-coodinator
```

## License

TBD

## Maintainer

Alfonso de la Guarda — CCVASS
