# Swarmex Docker Label Reference

All Swarmex controllers read configuration from Docker service deploy labels.
Prefix: `swarmex.<controller>.<key>`

## swarmex.scaler (Horizontal Autoscaling)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.scaler.enabled` | bool | `false` | Enable autoscaling |
| `swarmex.scaler.min` | int | `1` | Minimum replicas |
| `swarmex.scaler.max` | int | `10` | Maximum replicas |
| `swarmex.scaler.cpu-target` | int | `70` | CPU % threshold to scale up |
| `swarmex.scaler.ram-target` | int | `80` | RAM % threshold to scale up |
| `swarmex.scaler.cooldown` | duration | `60s` | Cooldown between scaling actions |

## swarmex.vpa (Vertical Autoscaling)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.vpa.enabled` | bool | `false` | Enable vertical autoscaling |
| `swarmex.vpa.min-memory` | string | `32M` | Minimum memory limit |
| `swarmex.vpa.max-memory` | string | `2G` | Maximum memory limit |
| `swarmex.vpa.min-cpu` | float | `0.1` | Minimum CPU limit |
| `swarmex.vpa.max-cpu` | float | `2.0` | Maximum CPU limit |

## swarmex.gatekeeper (Readiness)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.gatekeeper.enabled` | bool | `false` | Enable readiness gating |
| `swarmex.gatekeeper.path` | string | `/health/ready` | HTTP path to check |
| `swarmex.gatekeeper.interval` | duration | `5s` | Check interval |
| `swarmex.gatekeeper.timeout` | duration | `3s` | Check timeout |
| `swarmex.gatekeeper.threshold` | int | `3` | Consecutive successes to pass |

## swarmex.remediation (Self-Healing)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.remediation.enabled` | bool | `true` | Enable remediation |
| `swarmex.remediation.failure-threshold` | int | `5` | Failures before escalation |

Escalation chain: restart container → force-update service → drain node (never drains last manager).

## swarmex.deployer (Blue/Green)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.deployer.enabled` | bool | `false` | Enable blue/green deploys |
| `swarmex.deployer.strategy` | string | `rolling` | `rolling`, `blue-green`, `canary` |
| `swarmex.deployer.green-image` | string | — | Image for green deployment |
| `swarmex.deployer.shift-interval` | duration | `30s` | Time between traffic shifts |
| `swarmex.deployer.shift-step` | int | `20` | Traffic % to shift per step |
| `swarmex.deployer.rollback-on-fail` | bool | `true` | Auto-rollback on errors |

## swarmex.vault (Secret Injection)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.vault.enabled` | bool | `false` | Enable secret injection from OpenBao |
| `swarmex.vault.path` | string | — | OpenBao secret path (e.g. `secret/data/my-app`) |
| `swarmex.vault.refresh` | duration | `300s` | Secret refresh interval |
| `swarmex.vault.signal` | string | `SIGHUP` | Signal to send on rotation |

## swarmex.operator (Database Operator)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.operator.enabled` | bool | `false` | Enable DB operator |
| `swarmex.operator.type` | string | — | `postgresql`, `mysql`, `redis` |
| `swarmex.operator.port` | int | — | TCP port to health-check |

## swarmex.mesh (Service Mesh)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.mesh.enabled` | bool | `false` | Enable EasyTier mesh |
| `swarmex.mesh.network` | string | — | EasyTier network name |
| `swarmex.mesh.secret` | string | — | EasyTier network secret |

## swarmex.namespace (Namespace Isolation)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.namespace` | string | — | Namespace name (creates overlay network `ns-<name>`) |

## swarmex.netpolicy (Network Policies)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.netpolicy.allow` | string | — | Comma-separated namespace names to allow traffic from |

## swarmex.traffic (Traffic Policies)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.traffic.retry` | int | — | Number of retries on failure |
| `swarmex.traffic.rate-limit` | int | — | Requests per second |
| `swarmex.traffic.circuit-breaker` | float | — | Error % to open circuit (0.0–1.0) |

## swarmex.federation (Multi-Cluster)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.federation.replicate` | bool | `false` | Enable cross-cluster replication |
| `swarmex.federation.clusters` | string | — | Comma-separated cluster names (e.g. `gcp,azure`) |

Clusters configured via env vars on the federation controller: `FEDERATION_CLUSTER_<NAME>=tcp://<host>:2376`

## Admission Rules (Config File)

Admission is configured via YAML file, not labels. Mounted at `/etc/swarmex/admission.yaml`:

```yaml
rules:
  - name: require-memory-limit
    validate:
      message: "Service must have a memory limit"
      require_memory_limit: true
  - name: require-team-label
    validate:
      message: "Service must have a team label"
      require_labels:
        - team
  - name: add-managed-by
    mutate:
      add_labels:
        managed-by: swarmex
```

## RBAC (Config File)

RBAC is configured via YAML file at `/etc/swarmex/rbac.yaml`:

```yaml
roles:
  admin:
    actions: ["*"]
  viewer:
    actions: ["GET"]
users:
  akadmin: admin
```

Authentication priority: JWT Bearer token → X-Authentik-Username header → X-Swarmex-User header → anonymous.
