# Fork Status Report

Status of each forked repository and what changes (if any) were made.

## Changes Made in Forks: NONE

All 14 forked repositories contain upstream code without modifications.
All fixes and adaptations were done in the **coordinator repo** (stacks, configs, Dockerfiles).

This is a problem — the forks should contain our improvements, not the coordinator.

## What Should Be Done Per Fork

### Active Forks (need work)

| Fork | Upstream Code | What We Did in Coordinator | What Should Be in the Fork |
|:---|:---|:---|:---|
| `seaweedfs-swarm` | Generic 3-node compose | Created `configs/seaweedfs/master-entrypoint.sh` with `hostname -i` fix | Entrypoint scripts should be in this repo, not coordinator |
| `seaweedfs-volume-plugin` | Generic volume driver | Nothing | Test compatibility with current SeaweedFS version |
| `swarm-monitoring` | Prometheus+cAdvisor+Grafana stack | Created our own `stacks/observability.yml` from scratch | Merge our observability stack improvements back |
| `portainer-ce` | Upstream CE | Pinned to 2.25.1 in stack | No changes needed in fork |
| `easytier` | Upstream mesh VPN | Nothing | nano-mesh wrapper needs EasyTier as dependency, not fork changes |
| `swarm-cronjob` | Production-ready | Nothing | No changes needed — use as-is |
| `gantry` | Production-ready | Nothing | No changes needed — use as-is |
| `swarm-cd` | Production-ready | Created `configs/swarmcd/repos.yaml` + `stacks.yaml` | Config templates could live in fork |
| `swarm-autoscaler` | Ruby, obsolete | Nothing | Superseded by swarmex-scaler (Go). Archive this fork |

### Authentik (special case)

| Fork | What Happened |
|:---|:---|
| `authentik` | NOT FORKED to GitLab. We patched `config.py` directly on the AWS cluster via a custom Dockerfile in the coordinator (`docker/authentik/Dockerfile`). The patch adds `__setitem__`, `__getitem__`, `get()` methods to the `Attr` dataclass to fix Python 3.12+ compatibility. This patch MUST be moved to the fork repo. |

### Inactive Forks (discard candidates)

| Fork | Status | Action |
|:---|:---|:---|
| `coolify` | Discarded — no Swarm support | Archive |
| `promswarm` | Discarded — stale, replaced by swarm-monitoring | Archive |
| `swarm-sync` | Discarded — superseded by swarm-cd | Archive |
| `hca` | Discarded — abandoned, superseded by swarmex-scaler | Archive |
| `swarmpit` | Optional — not needed with Portainer CE | Keep but don't invest |

## Priority Actions

1. ~~**Fork Authentik properly**~~ ✅ Done — `ccvass/swarmex/authentik` with patches + CI/CD
2. ~~**Move SeaweedFS entrypoint scripts**~~ ✅ Done — pushed to `ccvass/swarmex/seaweedfs-swarm`
3. ~~**Archive inactive forks**~~ ✅ Done — coolify, promswarm, swarm-sync, hca, swarm-autoscaler marked archived
4. ~~**Add CI/CD**~~ ✅ Done — `.gitlab-ci.yml` added to all 8 swarmex controller repos + authentik fork

## Upstream PRs

| PR | Repo | Status | URL |
|:---|:---|:---|:---|
| Attr path navigation fix | goauthentik/authentik | Open | https://github.com/goauthentik/authentik/pull/21557 |
| Swarm overlay IP entrypoints | cycneuramus/seaweedfs-docker-swarm | Open | https://github.com/cycneuramus/seaweedfs-docker-swarm/pull/3 |
