# Fork Status Report

Status of each forked repository and changes made.

## Summary

- **31 repositories** in `ccvass/swarmex` GitLab group
- **17 custom controllers** built from scratch in Go
- **1 patched fork** (Authentik) with CI/CD pipeline
- **4 active forks** used as-is (swarm-cronjob, gantry, swarm-cd, EasyTier)
- **4 active forks** with improvements (SeaweedFS Swarm, SeaweedFS volume plugin, Portainer CE, Swarmpit)
- **5 archived forks** (superseded)
- **2 upstream PRs** submitted to GitHub

## Custom Controllers (16)

All built in Go 1.26, ~8MB binaries, CI/CD via kaniko, images at `registry.labtau.com/ccvass/swarmex/`.

| Controller | Pipeline | /metrics | Verified |
|:---|:---|:---|:---|
| event-controller | ✅ | ✅ | ✅ Real-time event capture |
| scaler | ✅ | ✅ | ✅ 2→5→2 replicas |
| gatekeeper | ✅ | ✅ | ✅ Traefik label toggle |
| remediation | ✅ | ✅ | ✅ Drained node + safety check |
| deployer | ✅ | ✅ | ✅ Green service created |
| vault-sync | ✅ | ✅ | ✅ 2 secrets synced |
| operator-db | ✅ | ✅ | ✅ PostgreSQL failover |
| nano-mesh | ✅ | ✅ | ✅ Peer registration |
| namespaces | ✅ | ✅ | ✅ Overlay networks created |
| netpolicy | ✅ | ✅ | ✅ Cross-namespace access |
| rbac | ✅ | ✅ | ✅ JWT + role-based access |
| admission | ✅ | ✅ | ✅ Validate + mutate + stack deploy |
| vpa | ✅ | ✅ | ✅ 512M→32M adjustment |
| traffic | ✅ | ✅ | ✅ retry + rate-limit |
| federation | ✅ | ✅ | ✅ AWS→GCP cross-cloud |
| api | ✅ | ✅ | ✅ CRUD + bbolt persistence |
| cluster-scaler | ✅ | ✅ | ✅ AWS scale-up/down verified, bbolt persistence |

## Patched Fork

| Fork | Change | CI/CD | Image |
|:---|:---|:---|:---|
| Authentik 2024.8.3 | `config.py` + `dict.py` — Attr dataclass path navigation fix | ✅ | `registry.labtau.com/ccvass/swarmex/swarmex-coordinator/authentik-patched:latest` |

## Upstream PRs

| PR | Repository | Description | Status |
|:---|:---|:---|:---|
| [#21557](https://github.com/goauthentik/authentik/pull/21557) | goauthentik/authentik | Fix Attr path navigation for Docker Swarm env vars | Open |
| [#3](https://github.com/cycneuramus/seaweedfs-docker-swarm/pull/3) | cycneuramus/seaweedfs-docker-swarm | Swarm overlay IP resolution in entrypoint scripts | Open |

## Bugs Found and Fixed

| Issue | Problem | Fix |
|:---|:---|:---|
| #45 | Remediation drained the only manager node | Safety check: never drain last active manager |
| #59 | AlertManager webhook format mismatch | Added `/api/v1/alerts` endpoint to swarmex-api |
| #61 | Remediation left with DEBUG log level | Default INFO, configurable via `LOG_LEVEL` env var |
| #63 | Grafana lost datasources on restart | Provisioning via config file + persistent volume |
| #64 | Authentik image only on manager | Pushed to registry, services use registry image |
