# Kubernetes vs Swarmex — Feature Comparison

Comparison based on real deployment testing (3-node AWS cluster, 29 services).

## Core Orchestration

| Capability | Kubernetes | Swarmex | Winner |
|:---|:---|:---|:---|
| Container scheduling | kube-scheduler (preemption, affinity, taints) | SwarmKit (constraints, placement prefs) | K8s |
| Service discovery | CoreDNS + Service objects | Docker DNS (automatic) | Swarmex (simpler) |
| Load balancing | kube-proxy + Service types (ClusterIP, NodePort, LB) | Swarm routing mesh (automatic) | Swarmex (zero config) |
| Rolling updates | Deployment controller (maxSurge, maxUnavailable) | `docker service update` (parallelism, delay) | Tie |
| Config/Secrets | ConfigMaps + Secrets (etcd) | Docker configs + secrets (Raft) | Tie |
| Namespaces | Built-in (resource isolation) | Not available | K8s |
| Resource management | Requests + Limits (scheduling + enforcement) | Limits only (enforcement) | K8s |
| Multi-cluster | Federation, Liqo, Admiralty | Not available | K8s |

## Gap Analysis — What Swarmex Adds

| K8s Feature | K8s Implementation | Swarmex Implementation | Verified | Limitations |
|:---|:---|:---|:---|:---|
| **HPA** | Built-in HPA + metrics-server | `swarmex-scaler` + Prometheus | ✅ Tested: 2→5→2 replicas | K8s is event-driven (faster); scaler polls every 15s |
| **Readiness Probes** | kubelet per-pod probes | `swarmex-gatekeeper` + Traefik labels | ✅ Tested: "service READY, enabling Traefik" | K8s is per-pod; gatekeeper is per-service |
| **Liveness + Self-healing** | kubelet restart + node controller | `swarmex-remediation` (escalation chain) | ✅ Built, event matching fixed | K8s auto-repairs nodes in managed clusters; remediation is manual escalation |
| **Blue/Green Deploys** | Argo Rollouts (canary analysis, experiments) | `swarmex-deployer` + Traefik weights | ✅ Tested: green service created, weight shifting | Argo has canary analysis, A/B testing; deployer does linear weight shift |
| **Secret Rotation** | CSI Secret Store Driver (native mount) | `swarmex-vault-sync` + OpenBao | ✅ Tested: 2 secrets synced from OpenBao to tmpfs | K8s CSI is transparent; vault-sync writes files + signals containers |
| **Service Mesh** | Istio / Linkerd (mTLS, traffic policies, retries) | `swarmex-nano-mesh` + EasyTier | ⚠️ Partial: peer registration works, needs EasyTier cluster | K8s meshes have circuit breaking, retries, traffic splitting; nano-mesh only encrypts |
| **Stateful Workloads** | StatefulSets (stable IDs, ordered deploy) | `swarmex-operator-db` + SeaweedFS | ⚠️ Partial: TCP health check works, failover triggers | K8s StatefulSets have stable network IDs, persistent volume claims; operator-db only handles DB failover |
| **GitOps** | ArgoCD (app-of-apps, sync waves, RBAC, UI) | swarm-cd (repos.yaml + stacks.yaml, UI) | ✅ Deployed, UI accessible | ArgoCD has sync waves, app-of-apps, RBAC; swarm-cd is simpler |
| **CronJobs** | Built-in CronJob controller | swarm-cronjob (labels-based) | ✅ Deployed | Equivalent |
| **Ingress** | Ingress / Gateway API (multiple controllers) | Traefik Swarm provider (labels) | ✅ Tested: SSL, routing, healthchecks | K8s Gateway API is more flexible; Traefik labels are simpler |
| **Storage** | 50+ CSI drivers, StorageClass, PV/PVC | SeaweedFS + volume plugin | ✅ Master + Volume 3/3 + Filer running | K8s has massive storage ecosystem; Swarm has SeaweedFS and few others |
| **RBAC** | Built-in (verbs on resources, namespaces) | Portainer CE + Authentik | ✅ Both deployed and configured | K8s RBAC is granular (get/list/watch/create per resource); Portainer CE has Admin/User/ReadOnly |
| **Observability** | Prometheus Operator (ServiceMonitor CRDs) | Prometheus + Grafana + Loki + Tempo | ✅ 11 targets up, 3 datasources, 2 dashboards | K8s has auto-discovery via ServiceMonitor; Swarmex uses DNS-based discovery |
| **Image Updates** | Argo Image Updater / Flux | gantry (auto-update, rollback, webhooks) | ✅ Deployed | Equivalent |

## Resource Comparison (Measured)

| Metric | Kubernetes (typical 3-node) | Swarmex (our 3-node cluster) |
|:---|:---|:---|
| Control plane RAM | 1.5-2GB (etcd + apiserver + scheduler + controller-manager) | ~100MB (SwarmKit embedded in Docker) |
| Total services running | Depends on workload | 29 services on 3x t3.large (8GB each) |
| Setup time | 30-60 min (kubeadm + CNI + post-install) | 5 min (`docker swarm init` + `docker swarm join`) |
| Config complexity | YAML with 20+ resource types, CRDs | Docker Compose v3 + labels |
| Managed offering | EKS/GKE/AKS ($70-150/month for control plane) | None (self-managed only) |
| Learning curve | Pods, Deployments, Services, Ingress, PV/PVC, RBAC, CRDs, Operators | Docker Compose + `swarmex.*` labels |

## Advantages of Swarmex

| Advantage | Detail | Verified |
|:---|:---|:---|
| 10x less resources | Swarm control plane ~100MB vs K8s ~2GB | ✅ 29 services on 8GB nodes |
| Zero learning curve | Docker Compose → Swarm stack, add labels | ✅ All config via `swarmex.*` labels |
| Single binary | Docker Engine includes Swarm | ✅ Only `apt install docker-ce` needed |
| 5-minute setup | `docker swarm init` + join | ✅ Cluster ready in 2 minutes |
| Label-based config | No CRDs, no custom resources | ✅ All 8 controllers read labels |
| Compose compatibility | Same files for dev and prod | ✅ Stack files are Compose v3.8 |
| Lower operational cost | No etcd backup, no cert rotation | ✅ No maintenance needed beyond Docker |

## Limitations of Swarmex

| Limitation | Impact | Mitigation |
|:---|:---|:---|
| No namespaces | All services share same namespace | Labels + Portainer teams |
| No pod concept | Can't run sidecars in same network namespace | Overlay networks |
| Limited RBAC | Portainer CE: Admin/User/ReadOnly | Authentik adds SSO but not resource-level RBAC |
| No admission controllers | Can't validate resources before creation | CI/CD validation |
| No CRDs | Can't extend the API | Labels replace CRDs for config |
| Single-cluster only | No multi-cluster federation | One cluster per environment |
| Limited storage | Only SeaweedFS + few plugins | K8s has 50+ CSI drivers |
| No managed offering | Must self-manage | Mirantis supports Swarm until 2030 |
| Smaller community | Fewer tools, fewer answers | awesome-swarm + Swarmex fills gaps |
| Scaler polls (15s) | Slower reaction than K8s HPA | Acceptable for most workloads |
| Gatekeeper is per-service | Less granular than K8s per-pod probes | Sufficient for service-level health |
| Authentik intermittent timeouts | Gateway timeout under load | Needs investigation, may need more resources |

## When to Use Swarmex

- Teams of 1-20 developers
- Up to ~100 services
- Single datacenter/region
- Teams that know Docker but not Kubernetes
- Budget-conscious (no managed K8s costs, 10x less compute)
- Sovereignty requirement (full control, no cloud lock-in)
- Rapid prototyping → production path

## When to Use Kubernetes

- Teams of 20+ developers
- 100+ services with complex dependencies
- Multi-region, multi-cluster requirements
- Need managed offerings (EKS, GKE, AKS)
- Require admission controllers, CRDs, operator ecosystem
- Compliance requiring namespace-level isolation
- Need service mesh with traffic policies (circuit breaking, retries)
