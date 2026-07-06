# Nightly logical backups for the sure-finance Postgres.
# Deployed to the Railway "db-backup" service via:
#   cd infra/db-backup && railway up --service db-backup --detach
# Runs as a tiny always-on loop (Railway CLI can't set cron schedules, and
# native volume backups are dashboard-only); sleeping costs ~nothing on
# usage-based billing. Dumps land on the service's volume at /backups,
# 14 most recent kept.
FROM postgres:16

COPY backup.sh /backup.sh
RUN chmod +x /backup.sh

CMD ["/backup.sh"]
