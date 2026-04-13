# Standards

Development standards applied to the Swarmex project.

## Language

- All custom controllers: **Go 1.26+**
- Docker Engine SDK: `github.com/docker/docker v27.5.1`
- Prometheus client: `github.com/prometheus/client_golang`
- Persistent storage: `go.etcd.io/bbolt` (swarmex-api)
- Build: `CGO_ENABLED=0` static binaries (~8MB each)
- Linter: `golangci-lint`

## Project Structure (per controller)

```
swarmex-<name>/
├── <name>.go          # Core logic (exported package)
├── <name>_test.go     # Unit tests
├── cmd/main.go        # Entrypoint: Docker client, event loop, health, metrics, signals
├── Dockerfile         # Multi-stage: golang:1.26-alpine → alpine:3.21
├── .gitlab-ci.yml     # kaniko build → registry.labtau.com
├── go.mod / go.sum
├── README.md
└── .gitignore
```

## Controller Patterns

Every controller follows the same structure:

```go
// Package-level: HandleEvent(ctx, event) called from main event loop
// Main: Docker client + event loop + /health on :8080 + /metrics + SIGTERM
// Config: parsed from Docker service deploy labels with swarmex.<controller>.* prefix
// Debounce: pending map + goroutine with time.Sleep to avoid race conditions
```

- Config via Docker service deploy labels: `swarmex.<controller>.<key>`
- Docker socket: `/var/run/docker.sock` (read-only mount)
- Health endpoint: `GET /health` on `:8080`
- Metrics endpoint: `GET /metrics` on `:8080` (Prometheus format)
- Graceful shutdown: `SIGTERM` / `SIGINT`
- Logging: `log/slog` with JSON handler, default INFO, configurable via `LOG_LEVEL=debug`
- Panic recovery in goroutine dispatchers

## Docker

- Multi-stage builds (build + runtime)
- Runtime image: `alpine:3.21`
- `HEALTHCHECK` in Dockerfile
- All controllers run on manager nodes (`node.role == manager`)
- Images pushed to `registry.labtau.com/ccvass/swarmex/swarmex-<name>:latest`

## CI/CD

- GitLab CI with kaniko (no Docker-in-Docker)
- Deploy token: `gitlab+deploy-token-409` (group-level, read/write registry)
- Pipeline: build → push to registry on every push to `main`

## Deployment

- Docker Compose v3.8 stack files in `stacks/`
- Overlay networks for inter-stack communication (created by `scripts/pre-deploy.sh`)
- Secrets via Docker secrets (external, created manually)
- Configs via Docker configs (external, created from `configs/` directory)
- Deploy order: ingress → observability → security → storage → tools → swarmex

## Security

- Credentials stored as Docker secrets, never in env vars
- Authentik for SSO/OIDC
- OpenBao for secret management (MPL-2.0, not Vault BUSL)
- RBAC proxy validates JWT tokens from Authentik
- Admission controller enforces memory limits and team labels

## Commits

- Conventional Commits: `<type>(<scope>): <subject>`
- Every commit references an issue: `Ref #N` or `Closes #N`

## OSS Policy

- All components 100% open source
- When dual-licensed (CE/EE): fork CE only
- OpenBao over Vault (BUSL → MPL-2.0)
- EasyTier over Netmaker (SSPL → Apache-2.0)
- Valkey over Redis, PostgreSQL over MySQL
