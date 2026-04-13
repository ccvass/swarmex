# Kubernetes vs Swarmex

Feature-by-feature comparison. No opinions — just what each one does and doesn't do.

## Feature Matrix

| Feature | Kubernetes | Swarmex | Notes |
|:---|:---|:---|:---|
| **Container scheduling** | ✅ Preemption, affinity, taints, topology spread | ✅ Constraints, placement preferences | K8s has more scheduling options |
| **Service discovery** | ✅ CoreDNS + Service objects | ✅ Docker DNS (automatic, zero config) | Swarmex is simpler — no Service objects needed |
| **Load balancing** | ✅ kube-proxy, ClusterIP, NodePort, LoadBalancer | ✅ Routing mesh (automatic for all services) | Swarmex routing mesh works out of the box |
| **Rolling updates** | ✅ Deployments (maxSurge, maxUnavailable) | ✅ `docker service update` (parallelism, delay, rollback) | Equivalent |
| **Blue/Green deploys** | ❌ Needs Argo Rollouts | ✅ `swarmex-deployer` (Traefik weight shifting) | Both need external tools |
| **Canary deploys** | ❌ Needs Argo Rollouts | ✅ `swarmex-deployer` (gradual weight shift) | Both need external tools |
| **Horizontal autoscaling** | ✅ Built-in HPA + metrics-server | ✅ `swarmex-scaler` + Prometheus | K8s HPA is event-driven; scaler polls every 15s |
| **Vertical autoscaling** | ✅ VPA (adjusts CPU/RAM requests) | ❌ Not implemented | K8s advantage |
| **Readiness probes** | ✅ Built-in per-pod (HTTP, TCP, exec) | ✅ `swarmex-gatekeeper` per-service (HTTP) | K8s is per-pod, more granular |
| **Liveness probes** | ✅ Built-in per-pod | ✅ Docker HEALTHCHECK + `swarmex-remediation` | Equivalent |
| **Self-healing** | ✅ kubelet restart + node controller | ✅ `swarmex-remediation` (restart → force → drain) | Swarmex has explicit escalation chain |
| **Secret management** | ✅ Secrets (etcd) + CSI Secret Store | ✅ Docker secrets + `swarmex-vault-sync` (OpenBao) | K8s CSI is more transparent; vault-sync writes files |
| **Secret rotation** | ✅ CSI driver auto-rotation | ✅ `swarmex-vault-sync` (poll + signal) | Equivalent |
| **Config management** | ✅ ConfigMaps + Secrets | ✅ Docker configs + secrets | Equivalent |
| **Service mesh (mTLS)** | ✅ Istio/Linkerd (full mesh) | ✅ `swarmex-nano-mesh` + EasyTier (WireGuard) | K8s meshes have traffic policies; nano-mesh encrypts only |
| **Traffic policies** | ✅ Istio (retries, circuit breaking, fault injection) | ❌ Not implemented | K8s advantage |
| **Ingress / routing** | ✅ Ingress, Gateway API (multiple controllers) | ✅ Traefik Swarm provider (labels) | Both work; K8s Gateway API is newer/more flexible |
| **SSL/TLS** | ✅ cert-manager + Ingress | ✅ Traefik + Let's Encrypt (automatic) | Swarmex is simpler — zero config SSL |
| **Persistent storage** | ✅ PV/PVC + StorageClass + 50+ CSI drivers | ✅ SeaweedFS + volume plugin | K8s has massive ecosystem; Swarm has fewer options |
| **Stateful workloads** | ✅ StatefulSets (stable IDs, ordered deploy, PVC per pod) | ✅ `swarmex-operator-db` (DB failover, health monitoring) | K8s StatefulSets are more general; operator-db is DB-specific |
| **CronJobs** | ✅ Built-in CronJob | ✅ swarm-cronjob (labels-based) | Equivalent |
| **GitOps** | ✅ ArgoCD / Flux (sync waves, app-of-apps) | ✅ swarm-cd (repos.yaml + stacks.yaml, UI) | ArgoCD is more powerful; swarm-cd is simpler |
| **RBAC** | ✅ Built-in (verbs × resources × namespaces) | ✅ Portainer CE + Authentik | K8s RBAC is more granular |
| **Namespaces** | ✅ Built-in (resource isolation, quotas) | ❌ Not available | K8s advantage |
| **Resource quotas** | ✅ Per-namespace quotas | 🔜 Part of swarmex-namespaces #36 | Planned |
| **Network policies** | ✅ NetworkPolicy | 🔜 swarmex-netpolicy #37 (iptables per service) | Planned |
| **Admission controllers** | ✅ Webhooks | 🔜 swarmex-admission #39 (post-creation validate/mutate) | Planned |
| **Custom Resource Definitions** | ✅ CRDs + Operators | ❌ Uses labels instead | Different approach, not a gap |
| **Multi-cluster** | ✅ Federation, Liqo, Admiralty | ❌ Single cluster only | K8s advantage |
| **Managed offerings** | ✅ EKS, GKE, AKS, DOKS | ❌ Self-managed only | K8s advantage |
| **Observability** | ✅ Prometheus Operator (ServiceMonitor CRDs) | ✅ Prometheus + Grafana + Loki + Tempo | Equivalent (different discovery method) |
| **Image auto-update** | ❌ Needs Argo Image Updater | ✅ gantry (built-in rollback, webhooks) | Equivalent |
| **SSO / Identity** | ❌ Needs Dex/Keycloak | ✅ Authentik (OIDC, SAML, LDAP, proxy) | Equivalent |
| **Web UI** | ❌ Needs Dashboard/Lens/Rancher | ✅ Portainer CE + swarm-cd UI | Equivalent |

## Resource Usage (Measured)

| Metric | Kubernetes (3-node) | Swarmex (3-node) |
|:---|:---|:---|
| Control plane RAM | 1.5-2GB | ~100MB |
| Control plane components | 5 (etcd, apiserver, scheduler, controller-manager, coredns) | 0 (embedded in Docker Engine) |
| Setup time | 30-60 min | 2 min |
| Config files per service | 3-5 YAML files (Deployment, Service, Ingress, ConfigMap, Secret) | 1 Compose file + labels |
| Managed cost | $70-150/month (EKS/GKE control plane) | $0 |
| Total services tested | — | 29 on 3x t3.large (8GB each) |

## What K8s Has That Swarmex Doesn't (Yet)

| Feature | Swarmex Plan | Issue | Status |
|:---|:---|:---|:---|
| VPA (vertical autoscaling) | `swarmex-vpa`: monitor usage, adjust limits | #42 | Planned |
| Multi-cluster federation | `swarmex-federation`: replicate services + EasyTier cross-cluster networking | #41 | Planned |
| Custom resources (CRDs) | `swarmex-api`: HTTP API server + `swarmexctl` CLI | #44 | Planned |
| Traffic policies (circuit breaker, retries) | `swarmex-traffic`: auto-configure Traefik middlewares | #43 | Planned |

### Already Implemented (moved from this section)

| Feature | Controller | Status |
|:---|:---|:---|
| Namespaces | `swarmex-namespaces` #36 | ✅ Verified |
| Network policies | `swarmex-netpolicy` #37 | ✅ Verified |
| Granular RBAC | `swarmex-rbac` #38 | ✅ Verified |
| Admission control | `swarmex-admission` #39 | ✅ Verified |

## What Swarmex Has That K8s Doesn't (Out of the Box)

| Feature | Detail |
|:---|:---|
| Zero-config load balancing | Routing mesh works for every service automatically |
| Zero-config SSL | Traefik + Let's Encrypt, no cert-manager needed |
| Label-based everything | No CRDs, no custom resources, no operators to install |
| Compose compatibility | Same file format from dev laptop to production cluster |
| Embedded control plane | No etcd to backup, no certificates to rotate |
| Self-healing with escalation | remediation: restart → force-restart → drain (K8s just restarts) |
| Built-in secret sync | vault-sync with hot-reload signals (K8s needs CSI driver) |

## When to Use Each

| Scenario | Recommendation | Why |
|:---|:---|:---|
| Any team size, trusting environment | **Swarmex** | No technical scale limit. Less overhead. |
| Multi-tenant with isolation requirements | **Kubernetes** | Namespaces + network policies for tenant isolation |
| Compliance (SOC2, HIPAA, PCI-DSS) | **Kubernetes** | Namespace isolation, network policies, audit logs |
| Multi-region deployment | **Kubernetes** | Multi-cluster federation |
| Budget-conscious | **Swarmex** | 10x less compute, no managed fees |
| Rapid prototyping → production | **Swarmex** | Docker Compose to production in minutes |
| Existing Docker Compose setup | **Swarmex** | Zero migration effort |
| Need managed service (no ops team) | **Kubernetes** | EKS/GKE/AKS |
| Sovereignty / no cloud lock-in | **Swarmex** | Runs anywhere Docker runs |
| Already invested in K8s ecosystem | **Kubernetes** | Don't migrate |
| Starting fresh, want simplicity | **Swarmex** | Much easier to learn and operate |
| Need CRDs / operator ecosystem | **Kubernetes** | Swarmex uses labels, not extensible API |

**Note:** Team size is NOT a factor. Swarmex scales to the same number of services as Kubernetes. The difference is governance features (namespaces, network policies, granular RBAC), not capacity.
