# Swarmex Roadmap

Detailed implementation plan with all open source resources mapped per phase.
Every tool listed is OSS. When dual-licensed (CE/EE), we fork the community edition.

## Resource Index

### Core Infrastructure

| Tool | Purpose | License | GitHub | Fork Priority |
|:---|:---|:---|:---|:---|
| SwarmKit | Swarm control plane (upstream) | Apache-2.0 | `moby/swarmkit` | Reference only |
| Portainer CE | Cluster management UI + RBAC | Zlib | `portainer/portainer` | Fork to extend |
| Swarmpit | Lightweight Swarm management UI | Eclipse | `swarmpit/swarmpit` | Fork to extend |
| Coolify | PaaS / GitOps deployments | Apache-2.0 | `coollabsio/coolify` | Fork to extend |
| Authentik | SSO / Identity Provider | MIT-variant | `goauthentik/authentik` | Deploy as-is |

### Observability

| Tool | Purpose | License | GitHub | Fork Priority |
|:---|:---|:---|:---|:---|
| Prometheus | Metrics collection | Apache-2.0 | `prometheus/prometheus` | Deploy as-is |
| Grafana | Dashboards and visualization | AGPL-3.0 | `grafana/grafana` | Deploy as-is |
| Loki | Log aggregation | AGPL-3.0 | `grafana/loki` | Deploy as-is |
| Tempo | Distributed tracing | AGPL-3.0 | `grafana/tempo` | Deploy as-is |
| Promswarm | Modernized Swarmprom stack | MIT | `neuroforgede/promswarm` | Fork as base |
| swarmlibs monitoring | Telemetry guide for Swarm | MIT | `swarmlibs/dockerswarm-monitoring-guide` | Reference |
| swarm-monitoring | Prometheus+cAdvisor+Grafana stack | MIT | `sam-mosleh/swarm-monitoring` | Fork as base |
| docker-engine-events-exporter | Prometheus exporter for Docker events | OSS | awesome-swarm reference | Fork to extend |

### Networking and Ingress

| Tool | Purpose | License | GitHub | Fork Priority |
|:---|:---|:---|:---|:---|
| Traefik Proxy | Dynamic reverse proxy + SSL | MIT | `traefik/traefik` | Deploy as-is |
| Caddy Docker Proxy | Alternative reverse proxy | Apache-2.0 | `lucaslorentz/caddy-docker-proxy` | Evaluate |
| Netmaker | WireGuard mesh networking | SSPL/Apache | `gravitl/netmaker` | Evaluate license |
| EasyTier | Decentralized WireGuard mesh VPN | Apache-2.0 | `EasyTier/EasyTier` | Fork for nano-mesh |
| Webmesh | Zero-config WireGuard mesh | Apache-2.0 | `webmeshproj/webmesh` | Fork for nano-mesh |

### Autoscaling

| Tool | Purpose | License | GitHub | Fork Priority |
|:---|:---|:---|:---|:---|
| docker-swarm-autoscaler | CPU-based autoscaling via Prometheus | MIT | `jcwimer/docker-swarm-autoscaler` | Fork as base |
| HCA | HPA-style autoscaler for Swarm | OSS | `lucianorc/hca` | Fork to extend |
| docker-swarm-service-autoscaler | Threshold-based scaling | OSS | `sahajsoft/docker-swarm-service-autoscaler` | Reference |
| Swarm Pilot | Scale by CPU and memory usage | OSS | awesome-swarm reference | Fork to extend |

### Storage

| Tool | Purpose | License | GitHub | Fork Priority |
|:---|:---|:---|:---|:---|
| SeaweedFS | Distributed blob/file storage | Apache-2.0 | `seaweedfs/seaweedfs` | Deploy as-is |
| SeaweedFS Docker Volume Plugin | Docker volume driver for SeaweedFS | OSS | `onaci/docker-plugin-seaweedfs` | Fork to extend |
| SeaweedFS Swarm Stack | HA SeaweedFS on Swarm | OSS | `cycneuramus/seaweedfs-docker-swarm` | Fork as base |
| JuiceFS | Distributed POSIX FS on S3 | Apache-2.0 | `juicedata/juicefs` | Evaluate |
| GlusterFS | Scale-out NAS filesystem | GPL-3.0 | `gluster/glusterfs` | Evaluate |

### Secrets Management

| Tool | Purpose | License | GitHub | Fork Priority |
|:---|:---|:---|:---|:---|
| HashiCorp Vault | Secret storage and rotation | BUSL-1.1 | `hashicorp/vault` | Use last MPL-2.0 release |
| OpenBao | Vault OSS fork (post-BUSL) | MPL-2.0 | `openbao/openbao` | Fork to extend |
| docker-stack-deploy | Auto config/secret rotation | OSS | awesome-swarm reference | Fork to extend |
| Vault Swarm Plugin PoC | Docker secrets driver for Vault | OSS | blog.sunekeller.dk reference | Reference |

### GitOps and CD

| Tool | Purpose | License | GitHub | Fork Priority |
|:---|:---|:---|:---|:---|
| SwarmCD | Declarative GitOps for Swarm | OSS | `m-adawi/swarm-cd` | Fork to extend |
| Swarm Sync | GitOps for Docker Swarm | OSS | `swarm-pack/swarm-sync` | Fork to extend |
| doco-cd | Lightweight GitOps polling/webhooks | OSS | awesome-swarm reference | Evaluate |
| Gantry | Enhanced auto-update for services | OSS | `shizunge/gantry` | Fork to extend |
| Shepherd | Auto-update services on image refresh | MIT | `containrrr/shepherd` | Reference |

### Scheduling and Jobs

| Tool | Purpose | License | GitHub | Fork Priority |
|:---|:---|:---|:---|:---|
| swarm-cronjob | Cron-based jobs on Swarm | MIT | `crazy-max/swarm-cronjob` | Fork to extend |
| Ofelia | Docker job scheduler (crontab) | MIT | `mcuadros/ofelia` | Evaluate |

### Cluster Utilities

| Tool | Purpose | License | GitHub | Fork Priority |
|:---|:---|:---|:---|:---|
| CapRover | Self-hosted PaaS on Swarm | Apache-2.0 | `caprover/caprover` | Evaluate |
| Swarmhook | Redeploy via webhooks | OSS | awesome-swarm reference | Fork to extend |
| docker-swarm-proxy | `docker exec` for Swarm services | OSS | awesome-swarm reference | Fork to extend |
| docker-stack-wait | Wait for stack deploy completion | OSS | awesome-swarm reference | Integrate |
| nothelm.py | Stack templating tool | OSS | awesome-swarm reference | Evaluate |

---

## Phase 1: Observability Foundation

**Goal:** Establish telemetry for automated decision-making.

### Deliverables

- [ ] Deploy Prometheus + Grafana + Loki + Tempo stack on Swarm
- [ ] Fork `sam-mosleh/swarm-monitoring` as monitoring base
- [ ] Fork `neuroforgede/promswarm` for production-ready alerting
- [ ] Deploy Portainer CE for cluster management and RBAC
- [ ] Configure cAdvisor + Node Exporter on all nodes
- [ ] Create Grafana dashboards for Swarm-specific metrics
- [ ] Deploy Authentik for SSO across all services

### Key Resources to Fork

```text
sam-mosleh/swarm-monitoring       → ccvass/swarmex/swarm-monitoring
neuroforgede/promswarm            → ccvass/swarmex/promswarm
portainer/portainer (CE)          → ccvass/swarmex/portainer-ce
```

---

## Phase 2: Traffic Intelligence and Ingress

**Goal:** Guarantee traffic only reaches healthy containers.

### Deliverables

- [ ] Deploy Traefik Proxy with Swarm Mode provider
- [ ] Build `swarmex-gatekeeper`: service that listens Docker socket and toggles Traefik labels based on app-level healthchecks
- [ ] Implement L7 readiness probes (HTTP 200 check before routing)
- [ ] Configure automatic SSL via Let's Encrypt
- [ ] Evaluate WireGuard mesh options (EasyTier vs Webmesh) for nano-mesh

### Key Resources to Fork

```text
traefik/traefik                   → Deploy as-is (MIT)
EasyTier/EasyTier                 → ccvass/swarmex/easytier (evaluate)
webmeshproj/webmesh               → ccvass/swarmex/webmesh (evaluate)
```

### Custom Development

- `swarmex-gatekeeper` — New repo. Go service using Docker SDK to:
  1. Listen to container health events
  2. Add/remove Traefik routing labels dynamically
  3. Block traffic to containers that fail readiness checks

---

## Phase 3: Elasticity and Self-Healing

**Goal:** Eliminate human intervention for load management and failure recovery.

### Deliverables

- [ ] Fork `jcwimer/docker-swarm-autoscaler` as base for swarmex-scaler
- [ ] Extend with RAM/latency metrics (not just CPU)
- [ ] Integrate with Prometheus for metric-driven scaling decisions
- [ ] Build healthcheck remediation: auto-restart + cache purge on persistent failures
- [ ] Fork `crazy-max/swarm-cronjob` for scheduled maintenance tasks
- [ ] Fork `shizunge/gantry` for automated service image updates

### Key Resources to Fork

```text
jcwimer/docker-swarm-autoscaler   → ccvass/swarmex/swarm-autoscaler
lucianorc/hca                     → ccvass/swarmex/hca
crazy-max/swarm-cronjob           → ccvass/swarmex/swarm-cronjob
shizunge/gantry                   → ccvass/swarmex/gantry
```

### Custom Development

- `swarmex-scaler` — New repo. Go service that:
  1. Queries Prometheus for CPU/RAM/latency per service
  2. Compares against configurable thresholds
  3. Calls `docker service update --replicas` in real-time
  4. Supports cooldown periods and min/max replica bounds

---

## Phase 4: Stateful Persistence and Zero-Downtime Deploys

**Goal:** Distributed data handling and deployments without downtime.

### Deliverables

- [ ] Deploy SeaweedFS cluster on Swarm for distributed volumes
- [ ] Fork `cycneuramus/seaweedfs-docker-swarm` as storage base
- [ ] Fork `onaci/docker-plugin-seaweedfs` for Docker volume integration
- [ ] Build blue/green deployment controller using Traefik traffic weights
- [ ] Integrate OpenBao (Vault OSS fork) for dynamic secret rotation
- [ ] Fork `m-adawi/swarm-cd` for GitOps-driven deployments
- [ ] Fork `swarm-pack/swarm-sync` as alternative GitOps approach
- [ ] Build `swarmex-operator-db` for database lifecycle management

### Key Resources to Fork

```text
seaweedfs/seaweedfs               → Deploy as-is (Apache-2.0)
cycneuramus/seaweedfs-docker-swarm → ccvass/swarmex/seaweedfs-swarm
onaci/docker-plugin-seaweedfs     → ccvass/swarmex/seaweedfs-volume-plugin
openbao/openbao                   → ccvass/swarmex/openbao
m-adawi/swarm-cd                  → ccvass/swarmex/swarm-cd
swarm-pack/swarm-sync             → ccvass/swarmex/swarm-sync
```

### Custom Development

- `swarmex-operator-db` — New repo. Reconciliation scripts for:
  1. Database quorum management (PostgreSQL, MySQL)
  2. Automated failover on volume server loss
  3. Backup scheduling integrated with swarm-cronjob
  4. Volume migration between nodes

- `swarmex-vault-sync` — New repo. Sidecar that:
  1. Reads secrets from OpenBao/Vault
  2. Injects into container memory (tmpfs)
  3. Watches for rotation events and hot-reloads

---

## Reference Collections

### Awesome Lists

- [BretFisher/awesome-swarm](https://github.com/BretFisher/awesome-swarm) — Curated list of Swarm tools (726 stars)
- [swarmlibs](https://github.com/swarmlibs) — Migrated from YouMightNotNeedKubernetes org
- [dockerswarm.rocks](https://dockerswarm.rocks) — Tutorials and code samples
- [Docker Swarm Still Rocks](https://dockerswarmstillrocks.com) — Updated tutorials

### Official Resources

- [Docker Swarm Docs](https://docs.docker.com/engine/swarm/)
- [SwarmKit Repository](https://github.com/moby/swarmkit) — Apache-2.0
- [Mirantis Swarm Support until 2030](https://www.mirantis.com/blog/mirantis-guarantees-long-term-support-for-swarm/)

### Community

- Discord: Cloud Native DevOps `#swarm` channel
- [SwarmKit.org Forum](https://swarmkit.org)

---

## License Audit Notes

| Tool | Issue | Action |
|:---|:---|:---|
| HashiCorp Vault | Changed to BUSL-1.1 in 2023 | Use OpenBao (MPL-2.0 fork) instead |
| Portainer | CE is Zlib (OSS), EE is proprietary | Fork CE only |
| Netmaker | SSPL for some components | Evaluate; prefer EasyTier (Apache-2.0) |
| Grafana/Loki/Tempo | AGPL-3.0 | OK for internal use, no SaaS redistribution |
| Coolify | Swarm support is limited | Fork and extend Swarm integration |
