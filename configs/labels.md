# Swarmex Docker Label Convention

All Swarmex controllers read configuration from Docker service deploy labels.
Prefix: `swarmex.<controller>.<key>`

## swarmex.scaler (HPA)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.scaler.enabled` | bool | `false` | Enable autoscaling |
| `swarmex.scaler.min` | int | `1` | Minimum replicas |
| `swarmex.scaler.max` | int | `10` | Maximum replicas |
| `swarmex.scaler.cpu-target` | int | `70` | CPU % threshold to scale up |
| `swarmex.scaler.ram-target` | int | `80` | RAM % threshold to scale up |
| `swarmex.scaler.cooldown` | duration | `60s` | Cooldown between scaling actions |

## swarmex.gatekeeper (Readiness)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.gatekeeper.enabled` | bool | `false` | Enable readiness gating |
| `swarmex.gatekeeper.path` | string | `/health/ready` | HTTP path to check |
| `swarmex.gatekeeper.interval` | duration | `5s` | Check interval |
| `swarmex.gatekeeper.timeout` | duration | `3s` | Check timeout |
| `swarmex.gatekeeper.threshold` | int | `3` | Consecutive successes to pass |

## swarmex.vault (Secret Injection)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.vault.enabled` | bool | `false` | Enable secret injection |
| `swarmex.vault.path` | string | — | OpenBao secret path |
| `swarmex.vault.refresh` | duration | `300s` | Secret refresh interval |
| `swarmex.vault.signal` | string | `SIGHUP` | Signal to send on rotation |

## swarmex.deployer (Blue/Green)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.deployer.strategy` | string | `rolling` | `rolling`, `blue-green`, `canary` |
| `swarmex.deployer.shift-interval` | duration | `30s` | Time between traffic shifts |
| `swarmex.deployer.shift-step` | int | `20` | Traffic % to shift per step |
| `swarmex.deployer.error-threshold` | int | `5` | Error % to trigger rollback |
| `swarmex.deployer.rollback-on-fail` | bool | `true` | Auto-rollback on errors |

## swarmex.remediation (Self-Healing)

| Label | Type | Default | Description |
|:---|:---|:---|:---|
| `swarmex.remediation.enabled` | bool | `true` | Enable remediation |
| `swarmex.remediation.failure-threshold` | int | `5` | Failures before escalation |
| `swarmex.remediation.escalation` | string | `restart,purge,drain` | Escalation chain |
