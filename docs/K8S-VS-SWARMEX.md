# Kubernetes vs Swarmex — Feature Comparison

Side-by-side comparison of Kubernetes capabilities vs what Swarmex provides on Docker Swarm.

## Core Orchestration

| Feature | Kubernetes | Swarmex | Notes |
|:---|:---|:---|:---|
| Container scheduling | Built-in (kube-scheduler) | Built-in (SwarmKit) | Both handle placement, constraints, affinity |
| Service discovery | CoreDNS + Services | Docker DNS + overlay networks | Swarm DNS is simpler, no Service objects needed |
| Load balancing | kube-proxy + Services | Swarm routing mesh | Swarm mesh is automatic, K8s needs Service type config |
| Rolling updates | Deployments | `docker service update` | Both support rollback, parallelism, delay |
| Config management | ConfigMaps + Secrets | Docker configs + secrets | Equivalent functionality |
| Namespaces | Built-in | Not available | Swarm has no namespace isolation — use labels + RBAC |
| Resource limits | Requests + Limits | `--limit-cpu`, `--limit-memory` | K8s has requests (scheduling) + limits (enforcement), Swarm only limits |

## What Swarmex Adds (Closing the Gaps)

| K8s Feature | K8s Tool | Swarmex Equivalent | Limitation |
|:---|:---|:---|:---|
| **HPA (Horizontal Pod Autoscaler)** | Built-in HPA + metrics-server | `swarmex-scaler` + Prometheus | K8s HPA supports custom metrics natively; swarmex-scaler queries Prometheus directly |
| **Readiness Probes** | Built-in kubelet probes | `swarmex-gatekeeper` + Traefik | K8s probes are per-pod; gatekeeper operates at service level via Traefik labels |
| **Liveness Probes** | Built-in kubelet probes | Docker HEALTHCHECK + `swarmex-remediation` | K8s restarts individual pods; remediation has escalation chain (restart → purge → drain) |
| **StatefulSets** | Built-in StatefulSet controller | `swarmex-operator-db` + SeaweedFS | K8s StatefulSets have stable network IDs + ordered deploy; operator-db only handles DB failover |
| **Secret Rotation** | CSI Secret Store Driver | `swarmex-vault-sync` + OpenBao | K8s CSI is more integrated; vault-sync writes to tmpfs and signals containers |
| **Service Mesh (mTLS)** | Istio / Linkerd | `swarmex-nano-mesh` + EasyTier | K8s meshes have traffic policies, retries, circuit breaking; nano-mesh only provides encryption |
| **Blue/Green Deploys** | Argo Rollouts | `swarmex-deployer` + Traefik | Argo has canary analysis, experiments; deployer does weight shifting with error monitoring |
| **GitOps** | ArgoCD / Flux | swarm-cd | ArgoCD has app-of-apps, sync waves, RBAC; swarm-cd is simpler (repos.yaml + stacks.yaml) |
| **CronJobs** | Built-in CronJob | swarm-cronjob | Equivalent functionality |
| **Ingress** | Ingress / Gateway API | Traefik Swarm provider | K8s Gateway API is more flexible; Traefik labels are simpler |
| **Storage (PV/PVC)** | CSI + StorageClass | SeaweedFS + volume plugin | K8s has dozens of CSI drivers; Swarm has limited CSI support, SeaweedFS is the main option |
| **RBAC** | Built-in RBAC | Portainer CE + Authentik | K8s RBAC is granular (verbs on resources); Portainer CE has basic roles only |
| **Observability** | Prometheus Operator | Prometheus + Grafana + Loki + Tempo | Equivalent, but K8s has ServiceMonitor CRDs for auto-discovery |
| **Auto-update images** | Not built-in (Argo Image Updater) | gantry | Equivalent functionality |
| **Self-healing** | kubelet restarts + node controller | `swarmex-remediation` | K8s has node auto-repair in managed clusters; remediation has manual escalation |

## Advantages of Swarmex over Kubernetes

| Advantage | Detail |
|:---|:---|
| **10x less resources** | Swarm control plane: ~100MB RAM. K8s control plane: etcd + apiserver + scheduler + controller-manager = ~1-2GB minimum |
| **Zero learning curve** | If you know Docker Compose, you know Swarm. K8s has its own API, YAML schema, and concepts (Pods, Deployments, Services, Ingress, etc.) |
| **Single binary** | Docker Engine includes Swarm. K8s needs kubelet, kubeadm, kubectl, etcd, CNI plugin, CSI driver, etc. |
| **5-minute setup** | `docker swarm init` + `docker swarm join`. K8s: kubeadm init + CNI install + join + post-install configs |
| **Label-based config** | All Swarmex controllers read config from Docker deploy labels. No CRDs, no custom resources, no operators to install |
| **Compose compatibility** | Stack files are Docker Compose v3. No translation needed from dev to prod |
| **Lower operational cost** | No etcd backup/restore, no certificate rotation, no API server tuning, no kubelet config |

## Limitations of Swarmex vs Kubernetes

| Limitation | Detail | Mitigation |
|:---|:---|:---|
| **No namespaces** | All services share the same namespace | Use labels + Portainer teams for isolation |
| **No pod concept** | Can't run sidecar containers in the same network namespace | Use overlay networks for service-to-service communication |
| **Limited RBAC** | Portainer CE has Admin/User/ReadOnly only | Authentik adds SSO but not resource-level RBAC |
| **No admission controllers** | Can't validate/mutate resources before creation | No equivalent — rely on CI/CD validation |
| **No CRDs** | Can't extend the API with custom resources | Swarmex controllers use labels instead of CRDs |
| **Single-master by default** | Swarm supports multi-manager but most setups use 1 | Use 3 or 5 managers for HA (odd numbers for Raft quorum) |
| **Limited storage ecosystem** | Only SeaweedFS + a few volume plugins | K8s has 50+ CSI drivers for every cloud and storage vendor |
| **No managed offering** | No EKS/GKE/AKS equivalent for Swarm | Must self-manage. Mirantis offers commercial support until 2030 |
| **Smaller community** | Fewer tools, fewer blog posts, fewer Stack Overflow answers | awesome-swarm list + swarmlibs + Swarmex fills gaps |
| **No multi-cluster** | Swarm is single-cluster only | K8s has federation, Liqo, Admiralty for multi-cluster |
| **Readiness is service-level** | Gatekeeper gates traffic per service, not per container | K8s readiness is per-pod, more granular |
| **Autoscaling is external** | swarmex-scaler polls Prometheus every 15s | K8s HPA is event-driven via metrics-server, faster reaction |

## When to Use Swarmex

- Small to medium teams (1-20 developers)
- Up to ~100 services
- Single datacenter or region
- Teams that already know Docker but not Kubernetes
- Budget-conscious (no managed K8s costs)
- Sovereignty requirement (full control, no cloud lock-in)

## When to Use Kubernetes

- Large teams (20+ developers)
- 100+ services with complex dependencies
- Multi-region, multi-cluster requirements
- Need managed offerings (EKS, GKE, AKS)
- Require admission controllers, CRDs, operators ecosystem
- Compliance requiring namespace-level isolation
