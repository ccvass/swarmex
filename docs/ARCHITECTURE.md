# Architecture

## Cluster Topology

```
                    Internet
                       |
                   [Traefik]  ← only service with published ports (80, 443)
                       |
              [traefik-public overlay]
               /    |    |    \
         [Apps] [SSO] [Swarmpit] [Controllers]
           |      |       |          |
    [stack overlays: monitoring, security, storage, swarmex, ...]
           |      |       |          |
    [vertix-01] [vertix-02] [vertix-03] [vertix-04] [vertix-05]
     Manager     Worker      Worker     Manager     Manager
```

All inter-service communication goes through Docker overlay networks.
Only Traefik exposes ports to the host (80, 443). Everything else is internal.

## Networking

### Endpoint Mode

All services use `endpoint_mode: dnsrr` except `traefik_traefik` (VIP).

DNSRR eliminates the IPVS load balancer layer that causes intermittent
connectivity loss in Docker Swarm overlay networks. With DNSRR, Docker's
embedded DNS (127.0.0.11) returns container IPs directly — no intermediary.

Traefik must remain VIP because it publishes ports via the ingress routing mesh.

### Overlay Networks

| Network | Purpose | Services |
|---------|---------|----------|
| traefik-public | Ingress routing | Traefik + all services with HTTP routes |
| monitoring | Observability stack | Prometheus, Grafana, Loki, Alertmanager, cAdvisor, node-exporter |
| security | Auth + secrets | Authentik, OpenBao, Authentik DB/Valkey |
| storage | Distributed storage | SeaweedFS master/filer/volume |
| swarmex | Controller mesh | All 18 swarmex controllers |
| gestioncampo | App stack | Gestion Campo services |
| icons-veo | App stack | VEO image server + MongoDB |
| shared | Cross-stack | Services shared between stacks |
| tools_default | Tools | Swarmpit, Portainer |

Pending: recreate all networks with `--opt encrypted --opt com.docker.network.driver.mtu=1450`.

### Kernel Tuning

Applied on all nodes via `/etc/sysctl.d/99-swarm-overlay.conf`:

```
net.netfilter.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.ipv4.neigh.default.gc_thresh1 = 4096
net.ipv4.neigh.default.gc_thresh2 = 8192
net.ipv4.neigh.default.gc_thresh3 = 16384
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
```

### Docker Daemon

`/etc/docker/daemon.json` on all nodes:

```json
{
  "mtu": 1450,
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" },
  "max-concurrent-downloads": 10
}
```

### Internal Proxy

A socat-based service (`internal-proxy`) runs on the manager node, connected
to all overlay networks. It forwards localhost ports to internal services,
enabling access via SSH tunnel without exposing services to the internet.

| Local Port | Target Service | Port |
|-----------|----------------|------|
| 3000 | observability_grafana | 3000 |
| 9000 | portainer | 9000 |
| 8200 | security_openbao | 8200 |
| 8888 | storage_seaweedfs-filer | 8888 |

## Service Policies

### Update Policy

All services have:

- `update-parallelism: 1` — rolling update, one task at a time
- `update-delay: 10s` — wait between task updates
- `update-failure-action: rollback` — auto-rollback on failed update
- `update-max-failure-ratio: 0.25` — tolerate 25% failures before rollback

### Restart Policy

All services have:

- `restart-max-attempts: 3` — max 3 restarts per window
- `restart-window: 120s` — 2-minute window for restart counting

This prevents restart storms where a crashing service consumes cluster resources.

### Rollback Policy

- `rollback-parallelism: 1`
- `rollback-delay: 5s`

## Security

### Public Services

Only these services are accessible from the internet via Traefik:

| Service | Purpose |
|---------|---------|
| Swarmpit | Cluster management UI |
| Authentik | SSO/Identity Provider (required for OAuth redirects) |
| Traefik dashboard | Protected by Authentik forwardAuth |
| Application services | CRM, Gestion Campo, etc. (protected by Authentik) |

### Internal Services

These are NOT exposed to the internet. Access via SSH tunnel only:

- Grafana (monitoring dashboards)
- Portainer (container management)
- OpenBao/Vault (secrets management)
- SeaweedFS (distributed storage)
- Prometheus, Loki, Alertmanager (observability backends)

### Database Security

No databases publish ports to the host. All DB access is internal via overlay:

- `crm_dex_pg-0` — PostgreSQL (was 55432, removed)
- `gestion_campo_prod_pg_gestioncampo` — PostgreSQL (was 54444, removed)
- `gestion_campo_prod_db_geolocation` — DB (was 49000, removed)
- `icons_veo_veo-image-mongo` — MongoDB (was 27019, removed)

## Swarmex Controllers

18 sidecar controllers that extend Docker Swarm with enterprise features:

| Controller | Version | Function |
|-----------|---------|----------|
| admission | v1.0.0 | Validates service specs (requires team label, memory limit) |
| affinity | v1.0.0 | Advanced scheduling rules via labels |
| api | v1.0.0 | REST API for cluster management |
| deployer | v1.0.0 | Canary/blue-green deployments |
| event-controller | v1.0.0 | Docker event stream processor |
| federation | v1.0.0 | Multi-cluster federation |
| gatekeeper | v1.0.0 | Policy enforcement |
| namespaces | v1.0.0 | Logical namespace isolation |
| nano-mesh | v1.1.0 | Overlay health monitor + EasyTier mesh |
| netpolicy | v1.0.0 | Network policy enforcement |
| operator-db | v1.0.0 | Database lifecycle management |
| rbac | v1.0.0 | Role-based access control |
| remediation | v1.1.0 | Auto-healing (restart/force-restart, drain only for node-level failures) |
| scaler | v1.0.0 | Prometheus-based autoscaling |
| stateful | v1.0.0 | Stateful service management |
| traffic | v1.0.0 | Traffic management and routing |
| vault-sync | v1.0.0 | Secrets sync from OpenBao to Docker secrets |
| vpa | v1.0.0 | Vertical pod autoscaler (memory/CPU recommendations) |

### Key Changes (v1.1.0)

**remediation**: No longer drains nodes for single-service failures. Tracks
failures per service+node pair. Only escalates to drain-node when 3+ distinct
services fail on the same node (indicates node-level issue, not app bug).

**nano-mesh**: Added overlay health monitor. Every 30s checks for services with
0 running tasks. After 3 consecutive failures, force-updates the service to
trigger rescheduling. Prunes stale overlay networks with no containers.

## Observability

### Prometheus Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| NodeDown | node-exporter unreachable for 2m | critical |
| HighCPU | CPU > 85% for 5m | warning |
| HighMemory | Memory > 90% for 5m | warning |
| DiskSpaceLow | Disk > 85% for 5m | warning |
| ContainerHighCPU | Container CPU > 80% for 5m | warning |
| ContainerHighMemory | Container memory > 90% of limit for 5m | warning |
| ServiceUnhealthy | Service has 0 running containers for 2m | critical |
| ConntrackTableNearFull | Conntrack > 80% capacity for 5m | critical |
| OverlayPacketDrops | Packet drops on overlay interfaces for 5m | warning |
| ServiceRestartStorm | Service restarted > 3 times in 5m | warning |
| SwarmexControllerDown | Any swarmex controller unreachable for 2m | critical |

### Grafana Dashboards

- **Swarmex Overlay Health** — conntrack usage %, packet drops, container restarts, network I/O
- Standard node-exporter and cAdvisor dashboards

## DNS Records

### puqaz.info (Cloudflare)

| Record | Type | Target | Access |
|--------|------|--------|--------|
| suleiman.puqaz.info | A | cluster IP | Public (Swarmpit) |
| auth.puqaz.info | A | cluster IP | Public (Authentik SSO) |
| trk.puqaz.info | A | cluster IP | Public (Traefik dashboard) |
| grafana.puqaz.info | A | cluster IP | Blocked (traefik.enable=false) |
| vault.puqaz.info | A | cluster IP | Blocked (traefik.enable=false) |
| storage.puqaz.info | A | cluster IP | Blocked (traefik.enable=false) |

### apulab.info (Cloudflare)

| Record | Type | Target | Access |
|--------|------|--------|--------|
| portx.apulab.info | A | cluster IP | Blocked (traefik.enable=false) |

### dextratekia.com (Application DNS)

| Record | Service |
|--------|---------|
| tekiaconnect.dextratekia.com | CRM dashboard |
| crm.dextratekia.com | CRM dashboard |
| topup-crm.dextratekia.com | CRM dashboard |
| reclaim.dextratekia.com | CRM form |
| gestioncampo.dextratekia.com | Gestion Campo dashboard |
| apigc.dextratekia.com | Gestion Campo API |
| mobile-gc.dextratekia.com | Gestion Campo mobile |
| imagesrv.dextratekia.com | Image server |

### allwiya.net

| Record | Service |
|--------|---------|
| apidevgestioncampo.allwiya.net | Gestion Campo API |
| routing.allwiya.net | OSRM routing |
| mapping.allwiya.net | Tile server |

### asistx.com

| Record | Service |
|--------|---------|
| icons.asistx.com | VEO image server |
