#!/bin/bash
# Nightly pg_dump loop. DATABASE_URL is a Railway reference to the Postgres
# service (private network). Custom-format dumps (-Fc) restore selectively
# with pg_restore. Keeps the 14 newest dumps on the /backups volume.
set -u

echo "db-backup service started $(date -u +%FT%TZ); first dump now, then every 24h"

while true; do
  ts=$(date -u +%Y%m%d_%H%M%S)
  f="/backups/sure_${ts}.dump"

  if pg_dump "$DATABASE_URL" -Fc --no-owner -f "$f"; then
    gzip -f "$f"
    echo "backup ok: ${f}.gz ($(du -h "${f}.gz" | cut -f1)) total_kept=$(ls -1 /backups/sure_*.dump.gz | wc -l)"
  else
    echo "backup FAILED at ${ts}"
    rm -f "$f"
  fi

  # Retention: newest 14
  ls -1t /backups/sure_*.dump.gz 2>/dev/null | tail -n +15 | xargs -r rm -f

  sleep 86400
done
