# Nightly logical backups for the sure-finance Postgres.
# Deploy: copy this directory OUTSIDE the repo first — `railway up` from
# inside the repo uploads the whole app (root Dockerfile wins) and the
# service crashes booting Rails:
#   cp -r infra/db-backup /tmp/db-backup && cd /tmp/db-backup \
#     && railway link -p sure-finance -e production -s db-backup \
#     && railway up --service db-backup --detach
# Runs as a tiny always-on loop (Railway CLI can't set cron schedules, and
# native volume backups are dashboard-only); sleeping costs ~nothing on
# usage-based billing. Dumps land on the service's volume at /backups,
# 14 most recent kept.
FROM postgres:16

COPY backup.sh /backup.sh
RUN chmod +x /backup.sh

CMD ["/backup.sh"]
