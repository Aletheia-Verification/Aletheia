# Aletheia Backup & Restore Guide

---

## 1. Why Backup Matters

Aletheia stores two critical SQLite databases:

| Database | Path | Contents | Retention Requirement |
|----------|------|----------|----------------------|
| `vault.db` | Project root | Verification results, RSA signatures, hash chains | 7+ years (SOC-2, regulatory) |
| `audit_log.db` | Project root | WHO ran WHAT verification WHEN | 7+ years (SOC-2, regulatory) |

**If these are lost:**
- Verification chain integrity breaks (no proof of prior verifications)
- Audit trail gaps violate SOC-2 compliance
- RSA-signed reports cannot be re-verified
- Regulatory auditors flag missing records as material weakness

---

## 2. SQLite Backup Commands

### 2.1 Online Backup (Safe While Running)

SQLite's `.backup` command creates a consistent snapshot even while Aletheia is serving requests:

```bash
# Backup vault.db
sqlite3 vault.db ".backup '/backups/vault_$(date +%Y%m%d_%H%M%S).db'"

# Backup audit_log.db
sqlite3 audit_log.db ".backup '/backups/audit_log_$(date +%Y%m%d_%H%M%S).db'"
```

### 2.2 Cold Backup (Service Stopped)

```bash
# Stop Aletheia
docker compose down

# Copy files directly
cp vault.db /backups/vault_$(date +%Y%m%d).db
cp audit_log.db /backups/audit_log_$(date +%Y%m%d).db

# Also backup WAL and SHM if they exist
cp vault.db-wal /backups/ 2>/dev/null
cp vault.db-shm /backups/ 2>/dev/null

# Restart
docker compose up -d
```

### 2.3 Verify Backup Integrity

```bash
# Check database integrity
sqlite3 /backups/vault_20260319.db "PRAGMA integrity_check;"
# Expected output: ok

# Check record count
sqlite3 /backups/vault_20260319.db "SELECT COUNT(*) FROM verifications;"
sqlite3 /backups/audit_log_20260319.db "SELECT COUNT(*) FROM audit_log;"
```

---

## 3. Automated Daily Backup (Cron)

### 3.1 Backup Script

Create `/opt/aletheia/backup.sh`:

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="/backups/aletheia"
RETENTION_DAYS=90
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
APP_DIR="/app"  # or wherever Aletheia is installed

mkdir -p "$BACKUP_DIR"

# Online backup (safe while running)
sqlite3 "$APP_DIR/vault.db" ".backup '$BACKUP_DIR/vault_$TIMESTAMP.db'"
sqlite3 "$APP_DIR/audit_log.db" ".backup '$BACKUP_DIR/audit_log_$TIMESTAMP.db'"

# Verify backups
for db in "$BACKUP_DIR/vault_$TIMESTAMP.db" "$BACKUP_DIR/audit_log_$TIMESTAMP.db"; do
    result=$(sqlite3 "$db" "PRAGMA integrity_check;" 2>&1)
    if [ "$result" != "ok" ]; then
        echo "ERROR: Backup integrity check failed for $db" >&2
        exit 1
    fi
done

# Compress
gzip "$BACKUP_DIR/vault_$TIMESTAMP.db"
gzip "$BACKUP_DIR/audit_log_$TIMESTAMP.db"

# Prune old backups
find "$BACKUP_DIR" -name "*.db.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup complete: $TIMESTAMP (vault + audit_log)"
```

```bash
chmod +x /opt/aletheia/backup.sh
```

### 3.2 Cron Schedule

```bash
# Daily at 02:00 UTC
crontab -e
```

```cron
0 2 * * * /opt/aletheia/backup.sh >> /var/log/aletheia_backup.log 2>&1
```

### 3.3 Monitoring

```bash
# Check last backup age
ls -lt /backups/aletheia/vault_*.db.gz | head -1

# Alert if no backup in 48 hours
find /backups/aletheia -name "vault_*.db.gz" -mmin -2880 | grep -q . \
    || echo "ALERT: No Aletheia backup in 48 hours"
```

---

## 4. Restore Procedure

### 4.1 Full Restore

```bash
# 1. Stop Aletheia
docker compose down

# 2. Decompress backup
gunzip -k /backups/aletheia/vault_20260319_020000.db.gz
gunzip -k /backups/aletheia/audit_log_20260319_020000.db.gz

# 3. Verify backup before restoring
sqlite3 /backups/aletheia/vault_20260319_020000.db "PRAGMA integrity_check;"

# 4. Replace current databases
cp /backups/aletheia/vault_20260319_020000.db /app/vault.db
cp /backups/aletheia/audit_log_20260319_020000.db /app/audit_log.db

# 5. Remove stale WAL/SHM files
rm -f /app/vault.db-wal /app/vault.db-shm
rm -f /app/audit_log.db-wal /app/audit_log.db-shm

# 6. Restart Aletheia
docker compose up -d

# 7. Verify chain integrity (see Section 8)
curl -X POST https://aletheia.internal/vault/verify-chain \
    -H "Authorization: Bearer $TOKEN"
```

### 4.2 Partial Restore (Single Table)

```bash
# Export from backup
sqlite3 /backups/aletheia/vault_20260319.db ".dump verifications" > verifications.sql

# Import into current
sqlite3 /app/vault.db < verifications.sql
```

---

## 5. Encrypted Backup

### 5.1 Encrypt with GPG

```bash
# Encrypt (symmetric)
sqlite3 vault.db ".backup '/tmp/vault_backup.db'"
gpg --symmetric --cipher-algo AES256 \
    --output /backups/vault_20260319.db.gpg \
    /tmp/vault_backup.db
rm /tmp/vault_backup.db

# Decrypt
gpg --decrypt /backups/vault_20260319.db.gpg > vault_restored.db
```

### 5.2 Encrypt with OpenSSL

```bash
# Encrypt
openssl enc -aes-256-cbc -salt -pbkdf2 \
    -in /tmp/vault_backup.db \
    -out /backups/vault_20260319.db.enc

# Decrypt
openssl enc -aes-256-cbc -d -pbkdf2 \
    -in /backups/vault_20260319.db.enc \
    -out vault_restored.db
```

### 5.3 Key Management

| Key | Storage | Access |
|-----|---------|--------|
| Backup encryption passphrase | Hardware Security Module (HSM) or secrets manager | DBA + security officer (dual control) |
| RSA signing keys (`aletheia_keys/`) | Separate from database backups | Backup independently, never co-located |
| JWT secret (`JWT_SECRET_KEY` env var) | Environment/secrets manager | Not stored in database |

**Do NOT store encryption keys alongside the encrypted backups.**

---

## 6. Docker Volume Backup

### 6.1 Named Volume Backup

If using Docker named volumes (from `docker-compose.yml`):

```bash
# Find volume path
docker volume inspect aletheia_vault_data

# Backup from running container
docker run --rm \
    -v aletheia_vault_data:/data:ro \
    -v /backups:/backups \
    alpine \
    sh -c "cp /data/vault.db /backups/vault_$(date +%Y%m%d).db"
```

### 6.2 Docker Compose Volume Backup Script

```bash
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CONTAINER=$(docker compose ps -q aletheia)

# Online backup via exec
docker exec "$CONTAINER" sqlite3 /app/vault.db \
    ".backup '/app/vault_backup.db'"
docker cp "$CONTAINER:/app/vault_backup.db" \
    "/backups/vault_$TIMESTAMP.db"
docker exec "$CONTAINER" rm /app/vault_backup.db

docker exec "$CONTAINER" sqlite3 /app/audit_log.db \
    ".backup '/app/audit_log_backup.db'"
docker cp "$CONTAINER:/app/audit_log_backup.db" \
    "/backups/audit_log_$TIMESTAMP.db"
docker exec "$CONTAINER" rm /app/audit_log_backup.db

echo "Docker volume backup: $TIMESTAMP"
```

### 6.3 Docker Compose Volumes Reference

```yaml
# docker-compose.yml
services:
  aletheia:
    volumes:
      - vault_data:/app/vault.db
      - audit_data:/app/audit_log.db
      - ./copybooks:/app/copybooks
      - ./license:/app/license:ro
      - ./backups:/backups  # mount backup destination

volumes:
  vault_data:
  audit_data:
```

---

## 7. Point-in-Time Recovery (WAL Mode)

### 7.1 Enable WAL Mode

SQLite WAL (Write-Ahead Log) mode enables concurrent reads during writes and supports point-in-time recovery:

```bash
# Enable WAL mode (one-time, persists)
sqlite3 vault.db "PRAGMA journal_mode=WAL;"
sqlite3 audit_log.db "PRAGMA journal_mode=WAL;"
```

### 7.2 WAL Checkpoint

WAL files grow until checkpointed. Force checkpoint before backup:

```bash
# Checkpoint (merge WAL into main db)
sqlite3 vault.db "PRAGMA wal_checkpoint(TRUNCATE);"
sqlite3 audit_log.db "PRAGMA wal_checkpoint(TRUNCATE);"

# Then backup the main .db file (no WAL needed)
```

### 7.3 Backup with WAL

If WAL mode is active, backup **all three files** for consistency:

```bash
# All three must be copied atomically
cp vault.db vault.db-wal vault.db-shm /backups/

# Or use .backup which handles this automatically
sqlite3 vault.db ".backup '/backups/vault_snapshot.db'"
```

### 7.4 Recovery to Specific Point

SQLite doesn't have native PITR like PostgreSQL. Workaround:

```bash
# 1. Restore from most recent backup before the target time
cp /backups/vault_20260319_020000.db vault_restored.db

# 2. Query what was added after that backup
sqlite3 vault_restored.db "SELECT MAX(timestamp) FROM verifications;"
# → 2026-03-19T02:00:00Z

# 3. If you need records from after the backup,
#    they exist only in the current vault.db
#    Export and re-import selectively:
sqlite3 /app/vault.db \
    "SELECT * FROM verifications WHERE timestamp > '2026-03-19T02:00:00Z'" \
    > recent_records.sql
```

---

## 8. Verification After Restore

### 8.1 Database Integrity

```bash
sqlite3 vault.db "PRAGMA integrity_check;"
sqlite3 audit_log.db "PRAGMA integrity_check;"
```

### 8.2 Chain Integrity (Vault)

The vault uses hash-chain linkage. After restore, verify the chain is intact:

```bash
# Via API
curl -X POST https://aletheia.internal/vault/verify-chain \
    -H "Authorization: Bearer $TOKEN" | jq .

# Expected response:
# {
#   "total_records": 42,
#   "valid_signatures": 40,
#   "invalid_signatures": 0,
#   "unsigned_records": 2,
#   "chain_breaks": [],
#   "tampered_records": [],
#   "chain_intact": true,
#   "verified_at": "2026-03-19T10:00:00Z"
# }
```

### 8.3 Record Count Verification

```bash
# Compare backup vs restored
BACKUP_COUNT=$(sqlite3 /backups/vault_20260319.db "SELECT COUNT(*) FROM verifications;")
RESTORED_COUNT=$(sqlite3 /app/vault.db "SELECT COUNT(*) FROM verifications;")

if [ "$BACKUP_COUNT" != "$RESTORED_COUNT" ]; then
    echo "ERROR: Record count mismatch (backup=$BACKUP_COUNT, restored=$RESTORED_COUNT)"
    exit 1
fi
echo "OK: $RESTORED_COUNT records verified"
```

### 8.4 Signature Spot Check

```bash
# Verify a random record's RSA signature
RECORD_ID=$(sqlite3 /app/vault.db "SELECT id FROM verifications ORDER BY RANDOM() LIMIT 1;")
curl -X POST https://aletheia.internal/verify \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"record_id\": $RECORD_ID}" | jq .valid
# Expected: true
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Online backup | `sqlite3 vault.db ".backup '/backups/vault.db'"` |
| Verify backup | `sqlite3 backup.db "PRAGMA integrity_check;"` |
| Restore | Stop service, `cp backup.db vault.db`, remove WAL/SHM, restart |
| Encrypt | `gpg --symmetric --cipher-algo AES256 backup.db` |
| Docker backup | `docker exec $C sqlite3 /app/vault.db ".backup '/app/bak.db'"` |
| Enable WAL | `sqlite3 vault.db "PRAGMA journal_mode=WAL;"` |
| Chain verify | `POST /vault/verify-chain` |
| Cron schedule | `0 2 * * *` (daily 02:00 UTC) |
| Retention | 90 days on disk, 7 years in cold storage |
