# Standards

Development standards applied to the Swarmex project.

## Language

- All custom services: **Go 1.26+**
- Docker Engine SDK: `github.com/docker/docker v27.5.1`
- Build: `CGO_ENABLED=0` static binaries
- Linter: `golangci-lint`

## Project Structure (per service)

```
swarmex-<name>/
├── <name>.go          # Core logic (exported package)
├── <name>_test.go     # Unit tests
├── cmd/main.go        # Entrypoint: Docker client, health endpoint, signal handling
├── Dockerfile          # Multi-stage: golang:1.26-alpine → alpine:3.21
├── go.mod / go.sum
└── .gitignore
```

## Patterns

- Config via Docker service deploy labels: `swarmex.<controller>.<key>`
- Docker socket: `/var/run/docker.sock` (read-only mount)
- Health endpoint: `GET /health` on `:8080`
- Graceful shutdown: `SIGTERM` / `SIGINT`
- Logging: `log/slog` with JSON handler
- Panic recovery in goroutine dispatchers

## Docker

- Multi-stage builds (build + runtime)
- Runtime image: `alpine:3.21`
- `HEALTHCHECK` in Dockerfile
- All services run on manager nodes (`node.role == manager`)

## Deployment

- Docker Compose v3.8 stack files in `stacks/`
- Overlay networks for inter-stack communication
- Secrets via Docker secrets (external)
- Deploy order: ingress → observability → security → tools → storage → swarmex

## Commits

- Conventional Commits: `<type>(<scope>): <subject>`
- Every commit references an issue: `Ref #N` or `Closes #N`

## OSS Policy

- All components 100% open source
- When dual-licensed (CE/EE): fork CE only
- OpenBao over Vault (BUSL → MPL-2.0)
- EasyTier over Netmaker (SSPL → Apache-2.0)
