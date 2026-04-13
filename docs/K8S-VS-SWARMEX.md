# Kubernetes vs Swarmex

Feature-by-feature comparison. No opinions — just what each one does and doesn't do.

## Feature Matrix

| Feature | Kubernetes | Swarmex | Notes |
|:---|:---|:---|:---|
| Container scheduling | ✅ Preemption, affinity, taints | ✅ Constraints + `swarmex-affinity` (colocate/avoid/spread) | ✅ Verified: same node + different node |
| Service discovery | ✅ CoreDNS + Service objects | ✅ Docker DNS (zero config) | Swarmex is simpler |
| Load balancing | ✅ kube-proxy, ClusterIP, NodePort | ✅ Routing mesh (automatic) | Both work out of the box |
| Rolling updates | ✅ Deployments | ✅ `docker service update` | Equivalent |
| Blue/Green deploys | ⚠️ Needs Argo Rollouts | ✅ `swarmex-deployer` | Both need external tools |
| Canary deploys | ⚠️ Needs Argo Rollouts | ✅ `swarmex-deployer` canary strategy | ✅ Verified: 0→25→50→75→100% + auto-rollback |
| Horizontal autoscaling | ✅ HPA + metrics-server | ✅ `swarmex-scaler` + Prometheus | Verified: 2→5→2 |
| Vertical autoscaling | ✅ VPA | ✅ `swarmex-vpa` | Verified: 512M→32M |
| Readiness probes | ✅ Built-in per-pod | ✅ `swarmex-gatekeeper` per-service | K8s is per-pod |
| Liveness probes | ✅ Built-in per-pod | ✅ Docker HEALTHCHECK + remediation | Equivalent |
| Self-healing | ✅ kubelet restart | ✅ `swarmex-remediation` (escalation + disruption budgets) | Swarmex: restart→force→drain, respects min-available |
| Secret management | ✅ Secrets + CSI | ✅ Docker secrets + `vault-sync` | Both work |
| Secret rotation | ✅ CSI auto-rotation | ✅ `vault-sync` (poll + signal) | Equivalent |
| Config management | ✅ ConfigMaps | ✅ Docker configs | Equivalent |
| Service mesh | ✅ Istio/Linkerd | ✅ `nano-mesh` + EasyTier | K8s meshes more mature |
| Traffic policies | ✅ Istio | ✅ `swarmex-traffic` + Traefik | Verified: retry + rate-limit |
| Ingress / routing | ✅ Gateway API | ✅ Traefik Swarm provider | Both work |
| SSL/TLS | ✅ cert-manager | ✅ Traefik + Let's Encrypt | Swarmex: zero config |
| Persistent storage | ✅ PV/PVC + 50+ CSI | ✅ SeaweedFS + volume plugin | K8s has more options |
| Stateful workloads | ✅ StatefulSets | ✅ `swarmex-stateful` (ordered deploy + named volumes) | ✅ Verified: 3 instances svc-0/1/2 |
| Resource quotas | ✅ ResourceQuotas per namespace | ✅ `swarmex-admission` quotas (max_memory, max_services) | ✅ Verified: 4th service denied |
| Disruption budgets | ✅ PodDisruptionBudget | ✅ `swarmex-remediation` (min-available, max-unavailable) | ✅ Verified: drain blocked |
| Package management | ✅ Helm | ✅ `swarmex-pack` (template + values → deploy) | ✅ Verified: render + install |
| CronJobs | ✅ Built-in | ✅ swarm-cronjob | Equivalent |
| GitOps | ✅ ArgoCD / Flux | ✅ swarm-cd | ArgoCD more powerful |
| RBAC | ✅ Built-in | ✅ `swarmex-rbac` + Authentik | Verified: JWT + roles |
| Namespaces | ✅ Built-in | ✅ `swarmex-namespaces` | Verified: overlay isolation |
| Network policies | ✅ NetworkPolicy | ✅ `swarmex-netpolicy` | Verified: cross-ns access |
| Admission control | ✅ Webhooks | ✅ `swarmex-admission` (validate + mutate + quotas) | Verified: validate + mutate + namespace quotas |
| Custom resources | ✅ CRDs + Operators | ✅ `swarmex-api` (bbolt) | Verified: CRUD + persistence |
| Multi-cluster | ✅ Federation, Liqo | ✅ `swarmex-federation` | **Verified: AWS→GCP** |
| Observability | ✅ Prometheus Operator | ✅ Prometheus + Grafana + Loki | 40 services in Loki |
| Centralized logging | ✅ EFK/Loki | ✅ Promtail → Loki | Verified: 40 services |
| Alerting | ✅ AlertManager | ✅ AlertManager → webhook | Verified: 3 alerts received |
| Image auto-update | ⚠️ Needs Argo Image Updater | ✅ gantry | Equivalent |
| SSO / Identity | ⚠️ Needs Dex/Keycloak | ✅ Authentik | Equivalent |
| Web UI | ⚠️ Needs Dashboard/Lens | ✅ Portainer CE + swarm-cd | Equivalent |
| Managed offerings | ✅ EKS, GKE, AKS | ❌ Self-managed only | K8s advantage |
| Cluster autoscaling | ✅ Cluster Autoscaler | ✅ `swarmex-cluster-scaler` | Verified: AWS 3→5→3 nodes |

**Result: 38 features compared. 36 matched or exceeded. 2 remaining gaps require Docker Engine changes (kernel-level network policies, CRD API machinery). All Swarmex features verified on a live 3-node AWS cluster.**

## Remaining K8s Advantages (Not Feasible Without Docker Engine Changes)

| Area | Why It Can't Be Closed |
|:---|:---|
| **Kernel-level NetworkPolicies** | Requires eBPF/iptables per-container filtering. Swarm uses VXLAN overlays without per-container firewall rules. Our `netpolicy` controller connects/disconnects overlay networks but cannot filter traffic within a network. |
| **CRDs + full API machinery** | K8s has etcd + API server + admission webhook chains + watch semantics. Our `api` controller with bbolt provides CRUD but not the same consistency guarantees or extensibility. Reimplementing this = reimplementing half of K8s. |
| **L7 service mesh (Istio/Cilium)** | Requires dataplane control (sidecar injection, eBPF hooks) that Swarm doesn't expose. Our `nano-mesh` provides WireGuard encryption but not L7 observability or header-based traffic splitting. |
| **Managed offerings** | EKS/GKE/AKS provide zero-ops K8s. Swarm has no managed equivalent — this is a market problem, not a technical one. |

## What Swarmex Has That K8s Doesn't (Out of the Box)

| Feature | Detail |
|:---|:---|
| Zero-config load balancing | Routing mesh works for every service automatically |
| Zero-config SSL | Traefik + Let's Encrypt, no cert-manager needed |
| Label-based everything | No CRDs, no custom resources, no operators to install |
| Compose compatibility | Same file format from dev laptop to production cluster |
| Embedded control plane | No etcd to backup, no certificates to rotate |
| Self-healing with escalation | restart → force-restart → drain (K8s just restarts) |
| Built-in secret sync | vault-sync with hot-reload signals |

## When to Use Each

| Scenario | Recommendation | Why |
|:---|:---|:---|
| Budget-conscious | **Swarmex** | 10× less compute, no managed fees |
| Rapid prototyping → production | **Swarmex** | Docker Compose to production in minutes |
| Existing Docker Compose setup | **Swarmex** | Zero migration effort |
| Sovereignty / no cloud lock-in | **Swarmex** | Runs anywhere Docker runs |
| Starting fresh, want simplicity | **Swarmex** | Much easier to learn and operate |
| Need managed service (no ops) | **Kubernetes** | EKS/GKE/AKS |
| Already invested in K8s | **Kubernetes** | Don't migrate |
| Need CRD/operator ecosystem | **Kubernetes** | Larger ecosystem |
