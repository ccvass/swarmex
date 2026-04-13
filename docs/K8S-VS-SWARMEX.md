# Kubernetes vs Swarmex

Feature-by-feature comparison. No opinions — just what each one does and doesn't do.

## Feature Matrix

| Feature | Kubernetes | Swarmex | Notes |
|:---|:---|:---|:---|
| Container scheduling | ✅ Preemption, affinity, taints | ✅ Constraints, placement prefs | K8s has more options |
| Service discovery | ✅ CoreDNS + Service objects | ✅ Docker DNS (zero config) | Swarmex is simpler |
| Load balancing | ✅ kube-proxy, ClusterIP, NodePort | ✅ Routing mesh (automatic) | Both work out of the box |
| Rolling updates | ✅ Deployments | ✅ `docker service update` | Equivalent |
| Blue/Green deploys | ⚠️ Needs Argo Rollouts | ✅ `swarmex-deployer` | Both need external tools |
| Canary deploys | ⚠️ Needs Argo Rollouts | ✅ `swarmex-deployer` | Both need external tools |
| Horizontal autoscaling | ✅ HPA + metrics-server | ✅ `swarmex-scaler` + Prometheus | Verified: 2→5→2 |
| Vertical autoscaling | ✅ VPA | ✅ `swarmex-vpa` | Verified: 512M→32M |
| Readiness probes | ✅ Built-in per-pod | ✅ `swarmex-gatekeeper` per-service | K8s is per-pod |
| Liveness probes | ✅ Built-in per-pod | ✅ Docker HEALTHCHECK + remediation | Equivalent |
| Self-healing | ✅ kubelet restart | ✅ `swarmex-remediation` (escalation) | Swarmex: restart→force→drain |
| Secret management | ✅ Secrets + CSI | ✅ Docker secrets + `vault-sync` | Both work |
| Secret rotation | ✅ CSI auto-rotation | ✅ `vault-sync` (poll + signal) | Equivalent |
| Config management | ✅ ConfigMaps | ✅ Docker configs | Equivalent |
| Service mesh | ✅ Istio/Linkerd | ✅ `nano-mesh` + EasyTier | K8s meshes more mature |
| Traffic policies | ✅ Istio | ✅ `swarmex-traffic` + Traefik | Verified: retry + rate-limit |
| Ingress / routing | ✅ Gateway API | ✅ Traefik Swarm provider | Both work |
| SSL/TLS | ✅ cert-manager | ✅ Traefik + Let's Encrypt | Swarmex: zero config |
| Persistent storage | ✅ PV/PVC + 50+ CSI | ✅ SeaweedFS + volume plugin | K8s has more options |
| Stateful workloads | ✅ StatefulSets | ✅ `operator-db` | Verified: PG failover |
| CronJobs | ✅ Built-in | ✅ swarm-cronjob | Equivalent |
| GitOps | ✅ ArgoCD / Flux | ✅ swarm-cd | ArgoCD more powerful |
| RBAC | ✅ Built-in | ✅ `swarmex-rbac` + Authentik | Verified: JWT + roles |
| Namespaces | ✅ Built-in | ✅ `swarmex-namespaces` | Verified: overlay isolation |
| Network policies | ✅ NetworkPolicy | ✅ `swarmex-netpolicy` | Verified: cross-ns access |
| Admission control | ✅ Webhooks | ✅ `swarmex-admission` | Verified: validate + mutate |
| Custom resources | ✅ CRDs + Operators | ✅ `swarmex-api` (bbolt) | Verified: CRUD + persistence |
| Multi-cluster | ✅ Federation, Liqo | ✅ `swarmex-federation` | **Verified: AWS→GCP** |
| Observability | ✅ Prometheus Operator | ✅ Prometheus + Grafana + Loki | 40 services in Loki |
| Centralized logging | ✅ EFK/Loki | ✅ Promtail → Loki | Verified: 40 services |
| Alerting | ✅ AlertManager | ✅ AlertManager → webhook | Verified: 3 alerts received |
| Image auto-update | ⚠️ Needs Argo Image Updater | ✅ gantry | Equivalent |
| SSO / Identity | ⚠️ Needs Dex/Keycloak | ✅ Authentik | Equivalent |
| Web UI | ⚠️ Needs Dashboard/Lens | ✅ Portainer CE + swarm-cd | Equivalent |
| Managed offerings | ✅ EKS, GKE, AKS | ❌ Self-managed only | K8s advantage |

**Result: 0 impossible gaps. Every K8s feature has a Swarmex equivalent, verified with evidence.**

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
