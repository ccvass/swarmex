#!/bin/bash
# Swarmex backup script — run via swarm-cronjob or manually
# Usage: ssh manager "bash /opt/swarmex/scripts/backup.sh"
set -euo pipefail

BACKUP_DIR="/opt/swarmex/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== Backup started: $BACKUP_DIR ==="

# 1. Authentik PostgreSQL
echo "Backing up Authentik DB..."
CID=$(docker ps -q --filter name=security_authentik-db | head -1)
if [ -n "$CID" ]; then
  docker exec "$CID" pg_dump -U authentik authentik | gzip > "$BACKUP_DIR/authentik-db.sql.gz"
  echo "  ✓ authentik-db.sql.gz"
fi

# 2. OpenBao (Raft snapshot)
echo "Backing up OpenBao..."
CID=$(docker ps -q --filter name=security_openbao | head -1)
if [ -n "$CID" ]; then
  docker exec "$CID" bao operator raft snapshot save /tmp/bao-snapshot.snap 2>/dev/null || true
  docker cp "$CID:/tmp/bao-snapshot.snap" "$BACKUP_DIR/openbao-raft.snap" 2>/dev/null || echo "  ⚠ OpenBao snapshot failed (may need unseal)"
  echo "  ✓ openbao-raft.snap"
fi

# 3. Docker configs (all)
echo "Backing up Docker configs..."
docker config ls --format "{{.Name}}" > "$BACKUP_DIR/config-list.txt"
echo "  ✓ config-list.txt ($(wc -l < "$BACKUP_DIR/config-list.txt") configs)"

# 4. Docker secrets (names only — values can't be exported)
echo "Backing up Docker secret names..."
docker secret ls --format "{{.Name}}" > "$BACKUP_DIR/secret-list.txt"
echo "  ✓ secret-list.txt"

# 5. Service definitions
echo "Backing up service definitions..."
for svc in $(docker service ls --format "{{.Name}}"); do
  docker service inspect "$svc" > "$BACKUP_DIR/svc-$svc.json" 2>/dev/null
done
echo "  ✓ $(ls "$BACKUP_DIR"/svc-*.json 2>/dev/null | wc -l) service definitions"

# Cleanup old backups (keep 7 days)
find /opt/swarmex/backups/ -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null

echo "=== Backup complete: $(du -sh "$BACKUP_DIR" | cut -f1) ==="
