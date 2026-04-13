#!/bin/bash
set -euo pipefail

# Swarmex Installer
# Deploys the complete Swarmex platform on an existing Docker Swarm cluster.
# Prerequisites: 3+ node Swarm cluster with Docker 24.0+

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
ask()   { read -rp "$(echo -e "${BOLD}$1${NC}")" "$2"; }
askpw() { read -rsp "$(echo -e "${BOLD}$1${NC}")" "$2"; echo; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║           SWARMEX INSTALLER v1.0                 ║"
echo "║  Enterprise orchestration for Docker Swarm       ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "This script deploys 39 services (17 controllers + platform stack)"
echo "on your existing Docker Swarm cluster."
echo ""

# ─── Connection ───────────────────────────────────────────────────────
echo -e "${BOLD}── Swarm Manager Connection ──${NC}"
ask "SSH user [ubuntu]: " SSH_USER
SSH_USER=${SSH_USER:-ubuntu}
ask "Manager IP: " MANAGER_IP
[ -z "$MANAGER_IP" ] && error "Manager IP is required"
ask "SSH key path [~/.ssh/id_rsa]: " SSH_KEY
SSH_KEY=${SSH_KEY:-~/.ssh/id_rsa}

SSH="ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$MANAGER_IP"

echo ""
info "Testing connection..."
$SSH "docker node ls --format '{{.Hostname}} {{.Status}}' 2>/dev/null" || error "Cannot connect or Docker Swarm not initialized"
NODE_COUNT=$($SSH "docker node ls -q | wc -l")
info "Connected to Swarm cluster with $NODE_COUNT nodes"

# ─── Domain ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Domain & SSL ──${NC}"
ask "Domain (e.g. swarmex.example.com): " DOMAIN
[ -z "$DOMAIN" ] && error "Domain is required"
ask "ACME email for Let's Encrypt: " ACME_EMAIL
[ -z "$ACME_EMAIL" ] && error "Email is required"
echo ""
echo "SSL certificate method:"
echo "  1) HTTP challenge (simple, requires port 80 open)"
echo "  2) Cloudflare DNS challenge (supports wildcards, recommended)"
ask "Choose [1/2]: " SSL_METHOD
SSL_METHOD=${SSL_METHOD:-1}

CF_TOKEN=""
if [ "$SSL_METHOD" = "2" ]; then
  askpw "Cloudflare API token (Zone:DNS:Edit): " CF_TOKEN
  [ -z "$CF_TOKEN" ] && error "Cloudflare token is required for DNS challenge"
fi

# ─── Credentials ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Credentials ──${NC}"
echo "These will be stored as Docker secrets (never in plain text)."
echo ""

askpw "Authentik DB password: " AK_DB_PASS
[ -z "$AK_DB_PASS" ] && AK_DB_PASS=$(openssl rand -base64 24)
askpw "Authentik secret key: " AK_SECRET
[ -z "$AK_SECRET" ] && AK_SECRET=$(openssl rand -base64 32)
askpw "Grafana admin password: " GF_PASS
[ -z "$GF_PASS" ] && GF_PASS=$(openssl rand -base64 16)

info "Empty passwords were auto-generated"

# ─── Registry ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Container Registry ──${NC}"
ask "Registry URL [registry.labtau.com]: " REGISTRY
REGISTRY=${REGISTRY:-registry.labtau.com}
ask "Registry username [gitlab+deploy-token-409]: " REG_USER
REG_USER=${REG_USER:-gitlab+deploy-token-409}
askpw "Registry password: " REG_PASS
[ -z "$REG_PASS" ] && error "Registry password is required"

# ─── Cloud Provider (optional) ────────────────────────────────────────
echo ""
echo -e "${BOLD}── Cluster Autoscaling (optional) ──${NC}"
echo "Configure automatic cloud node provisioning?"
ask "Enable cluster-scaler? [y/N]: " ENABLE_CS
ENABLE_CS=${ENABLE_CS:-n}

CS_PROVIDER=""
CS_REGION=""
CS_INSTANCE=""
CS_IMAGE=""
CS_KEY=""
CS_SG=""
CS_SUBNET=""

if [[ "$ENABLE_CS" =~ ^[yY] ]]; then
  echo "  1) AWS   2) GCP   3) Azure   4) DigitalOcean"
  ask "Provider [1]: " CS_PROVIDER_NUM
  case ${CS_PROVIDER_NUM:-1} in
    1) CS_PROVIDER="aws"
       ask "  AWS region [us-east-1]: " CS_REGION; CS_REGION=${CS_REGION:-us-east-1}
       ask "  Instance type [t3.large]: " CS_INSTANCE; CS_INSTANCE=${CS_INSTANCE:-t3.large}
       ask "  AMI ID (Ubuntu 24.04): " CS_IMAGE
       ask "  SSH key name: " CS_KEY
       ask "  Security group ID: " CS_SG
       ask "  Subnet ID: " CS_SUBNET ;;
    2) CS_PROVIDER="gcp"
       ask "  GCP project: " CS_PROJECT
       ask "  GCP zone [us-central1-a]: " CS_REGION; CS_REGION=${CS_REGION:-us-central1-a}
       ask "  Machine type [e2-medium]: " CS_INSTANCE; CS_INSTANCE=${CS_INSTANCE:-e2-medium}
       CS_IMAGE="ubuntu-2404-lts-amd64" ;;
    3) CS_PROVIDER="azure"
       ask "  Resource group: " CS_RG
       ask "  Location [eastus]: " CS_REGION; CS_REGION=${CS_REGION:-eastus}
       ask "  VM size [Standard_B2s]: " CS_INSTANCE; CS_INSTANCE=${CS_INSTANCE:-Standard_B2s}
       CS_IMAGE="Canonical:ubuntu-24_04-lts:server:latest" ;;
    4) CS_PROVIDER="digitalocean"
       ask "  Region [nyc1]: " CS_REGION; CS_REGION=${CS_REGION:-nyc1}
       ask "  Droplet size [s-2vcpu-4gb]: " CS_INSTANCE; CS_INSTANCE=${CS_INSTANCE:-s-2vcpu-4gb}
       ask "  SSH key ID: " CS_KEY
       CS_IMAGE="ubuntu-24-04-x64" ;;
  esac
fi

# ─── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Summary ──${NC}"
echo "  Manager:    $SSH_USER@$MANAGER_IP"
echo "  Domain:     *.$DOMAIN"
echo "  SSL:        $([ "$SSL_METHOD" = "2" ] && echo "Cloudflare DNS" || echo "HTTP challenge")"
echo "  Registry:   $REGISTRY"
echo "  Nodes:      $NODE_COUNT"
[ -n "$CS_PROVIDER" ] && echo "  Autoscale:  $CS_PROVIDER ($CS_INSTANCE in $CS_REGION)"
echo ""
ask "Proceed with installation? [Y/n]: " CONFIRM
[[ "${CONFIRM:-y}" =~ ^[nN] ]] && exit 0

# ═══════════════════════════════════════════════════════════════════════
# DEPLOY
# ═══════════════════════════════════════════════════════════════════════

info "Logging into registry on all nodes..."
NODES=$($SSH "docker node ls --format '{{.Hostname}}'")
# Login on manager
$SSH "echo '$REG_PASS' | docker login $REGISTRY -u '$REG_USER' --password-stdin" >/dev/null 2>&1
info "Registry login OK"

# ─── Create secrets ───────────────────────────────────────────────────
info "Creating Docker secrets..."
$SSH "
echo -n '$AK_DB_PASS' | docker secret create authentik_db_pw - 2>/dev/null || true
echo -n '$AK_SECRET' | docker secret create authentik_secret - 2>/dev/null || true
echo -n '$GF_PASS' | docker secret create grafana_admin_pw - 2>/dev/null || true
echo -n 'init-pending' | docker secret create openbao_root_token - 2>/dev/null || true
" >/dev/null
if [ -n "$CF_TOKEN" ]; then
  $SSH "echo -n '$CF_TOKEN' | docker secret create cloudflare_api_token - 2>/dev/null || true" >/dev/null
fi
info "Secrets created"

# ─── Upload repo to manager ───────────────────────────────────────────
info "Uploading Swarmex to manager..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tar czf /tmp/swarmex-deploy.tar.gz -C "$SCRIPT_DIR" \
  stacks configs scripts docker 2>/dev/null
scp -o ConnectTimeout=5 -i "$SSH_KEY" /tmp/swarmex-deploy.tar.gz "$SSH_USER@$MANAGER_IP:/tmp/" >/dev/null
$SSH "mkdir -p /tmp/swarmex-coordinator && cd /tmp/swarmex-coordinator && tar xzf /tmp/swarmex-deploy.tar.gz" >/dev/null
info "Files uploaded"

# ─── Pre-deploy (networks + configs) ─────────────────────────────────
info "Creating overlay networks and configs..."
$SSH "cd /tmp/swarmex-coordinator && bash scripts/pre-deploy.sh" >/dev/null 2>&1
info "Networks and configs ready"

# ─── OpenBao init ─────────────────────────────────────────────────────
info "Deploying stacks (this takes 3-5 minutes)..."

# Stack 1: Ingress
$SSH "
cd /tmp/swarmex-coordinator
DOMAIN=$DOMAIN ACME_EMAIL=$ACME_EMAIL \
  docker stack deploy -c stacks/ingress.yml --with-registry-auth ingress
" >/dev/null 2>&1
info "Stack: ingress (Traefik)"

sleep 10

# Stack 2: Observability
$SSH "
cd /tmp/swarmex-coordinator
docker stack deploy -c stacks/observability.yml --with-registry-auth observability
" >/dev/null 2>&1
info "Stack: observability (Prometheus, Grafana, Loki, Tempo, Promtail)"

sleep 10

# Stack 3: Security
$SSH "
cd /tmp/swarmex-coordinator
docker stack deploy -c stacks/security.yml --with-registry-auth security
" >/dev/null 2>&1
info "Stack: security (Authentik, OpenBao)"

sleep 10

# Stack 4: Storage
$SSH "
cd /tmp/swarmex-coordinator
docker stack deploy -c stacks/storage.yml --with-registry-auth storage
" >/dev/null 2>&1
info "Stack: storage (SeaweedFS)"

sleep 5

# Stack 5: Tools
$SSH "
cd /tmp/swarmex-coordinator
docker stack deploy -c stacks/tools.yml --with-registry-auth tools
" >/dev/null 2>&1
info "Stack: tools (Portainer, swarm-cd, swarm-cronjob, gantry)"

sleep 5

# Stack 6: Swarmex controllers (LAST — admission must not kill platform services)
info "Waiting for platform services to stabilize..."
sleep 60

$SSH "
cd /tmp/swarmex-coordinator
docker stack deploy -c stacks/swarmex.yml --with-registry-auth swarmex
" >/dev/null 2>&1
info "Stack: swarmex (17 controllers)"

# ─── Cluster scaler (optional) ───────────────────────────────────────
if [ -n "$CS_PROVIDER" ]; then
  SWARM_TOKEN=$($SSH "docker swarm join-token -q worker")
  MANAGER_PRIVATE=$($SSH "hostname -I | awk '{print \$1}'")

  CS_CONFIG="swarm_token: \"$SWARM_TOKEN\"
manager_ip: \"$MANAGER_PRIVATE\"
min_nodes: 2
max_nodes: 10
scale_up_cpu: 80
scale_down_cpu: 15
prometheus_url: \"http://observability_prometheus:9090\"
providers:"

  case $CS_PROVIDER in
    aws) CS_CONFIG="$CS_CONFIG
  aws:
    region: \"$CS_REGION\"
    key_name: \"$CS_KEY\"
    security_group: \"$CS_SG\"
    subnet_id: \"$CS_SUBNET\"
    template:
      instance_type: \"$CS_INSTANCE\"
      image: \"$CS_IMAGE\"
      disk_gb: 30" ;;
    gcp) CS_CONFIG="$CS_CONFIG
  gcp:
    project: \"$CS_PROJECT\"
    zone: \"$CS_REGION\"
    template:
      instance_type: \"$CS_INSTANCE\"
      image: \"$CS_IMAGE\"
      disk_gb: 30" ;;
    azure) CS_CONFIG="$CS_CONFIG
  azure:
    resource_group: \"$CS_RG\"
    location: \"$CS_REGION\"
    template:
      instance_type: \"$CS_INSTANCE\"
      image: \"$CS_IMAGE\"
      disk_gb: 30" ;;
    digitalocean) CS_CONFIG="$CS_CONFIG
  digitalocean:
    region: \"$CS_REGION\"
    ssh_key_id: \"$CS_KEY\"
    template:
      instance_type: \"$CS_INSTANCE\"
      image: \"$CS_IMAGE\"
      disk_gb: 50" ;;
  esac

  $SSH "
echo '$CS_CONFIG' > /tmp/cluster-scaler.yaml
docker config create cluster-scaler-config /tmp/cluster-scaler.yaml 2>/dev/null || true
" >/dev/null
  info "Cluster-scaler configured for $CS_PROVIDER"
fi

# ─── Wait for services ───────────────────────────────────────────────
echo ""
info "Waiting for services to start (up to 3 minutes)..."
for i in $(seq 1 18); do
  sleep 10
  RUNNING=$($SSH "docker service ls --format '{{.Replicas}}' | grep -v '0/' | wc -l" 2>/dev/null || echo 0)
  TOTAL=$($SSH "docker service ls -q | wc -l" 2>/dev/null || echo 0)
  echo -ne "\r  $RUNNING/$TOTAL services running..."
  [ "$RUNNING" = "$TOTAL" ] && [ "$TOTAL" -gt 30 ] && break
done
echo ""

# ─── Final status ────────────────────────────────────────────────────
echo ""
RUNNING=$($SSH "docker service ls --format '{{.Replicas}}' | grep -v '0/' | wc -l")
TOTAL=$($SSH "docker service ls -q | wc -l")
FAILED=$($SSH "docker service ls --format '{{.Replicas}}' | grep '0/' | wc -l")

echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║           INSTALLATION COMPLETE                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Services:    ${GREEN}$RUNNING/$TOTAL running${NC}"
[ "$FAILED" -gt 0 ] && echo -e "  Failed:      ${RED}$FAILED services at 0 replicas${NC}"
echo ""
echo -e "${BOLD}  Web UIs:${NC}"
echo "    Grafana:     https://grafana.$DOMAIN"
echo "    Portainer:   https://portainer.$DOMAIN"
echo "    Authentik:   https://authentik.$DOMAIN"
echo "    Traefik:     https://traefik.$DOMAIN"
echo ""
echo -e "${BOLD}  Credentials:${NC}"
echo "    Grafana:     admin / (password you entered)"
echo "    Authentik:   Complete setup at https://authentik.$DOMAIN/if/flow/initial-setup/"
echo "    Portainer:   Set password on first login"
echo ""
echo -e "${BOLD}  Useful commands:${NC}"
echo "    ssh $SSH_USER@$MANAGER_IP 'docker service ls'          # List services"
echo "    ssh $SSH_USER@$MANAGER_IP 'docker node ls'             # List nodes"
echo ""
echo "  Full documentation: docs/USER-GUIDE.md"
echo ""

# ─── Save REMOTE.md ──────────────────────────────────────────────────
cat > REMOTE.md << EOF
# Remote Configuration — Swarmex

## Server
- Manager: $SSH_USER@$MANAGER_IP
- SSH: ssh -i $SSH_KEY $SSH_USER@$MANAGER_IP
- Nodes: $NODE_COUNT

## Domain
- Base: $DOMAIN
- Wildcard: *.$DOMAIN
- SSL: $([ "$SSL_METHOD" = "2" ] && echo "Cloudflare DNS challenge" || echo "HTTP challenge")

## Services
- Grafana: https://grafana.$DOMAIN
- Portainer: https://portainer.$DOMAIN
- Authentik: https://authentik.$DOMAIN

## Registry
- URL: $REGISTRY
- User: $REG_USER
EOF
[ -n "$CS_PROVIDER" ] && cat >> REMOTE.md << EOF

## Cluster Autoscaling
- Provider: $CS_PROVIDER
- Region: $CS_REGION
- Instance: $CS_INSTANCE
EOF
info "REMOTE.md saved (not tracked in git)"
