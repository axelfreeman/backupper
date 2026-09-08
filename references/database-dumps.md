# Database dumps before the snapshot

Restic snapshots the filesystem; a live Postgres/MySQL data dir can be inconsistent at the
moment tar reads it. Dump the DB over SSH **before** the tar runs, and keep the dump in a
path the snapshot includes (not an excluded one).

## Postgres (Docker container)
```bash
ssh root@SERVER "docker exec <container> pg_dump -U <user> -d <db> | gzip > /root/backups/<db>_$(date +%Y%m%d).sql.gz"
```

## Postgres (native)
```bash
ssh root@SERVER "pg_dump -U <user> -d <db> | gzip > /root/backups/<db>_$(date +%Y%m%d).sql.gz"
```

## MySQL / MariaDB
```bash
ssh root@SERVER "mysqldump -u <user> -p<pass> --all-databases | gzip > /root/backups/all_$(date +%Y%m%d).sql.gz"
```

## Restore
```bash
gunzip < dump.sql.gz | psql -U <user> -d <db>      # Postgres
gunzip < dump.sql.gz | mysql -u <user> -p <db>     # MySQL
```

## Gotchas
- Put dumps in `/root/backups/` (or any non-excluded path) so the tar picks them up.
- Add the dump line to the `.bat` **before** the `ssh | restic` line.
- **Pull-model fleet legs:** run the dump INSIDE the same remote command, right before the
  tar, so the leg stays one ssh connection:
  `ssh root@S "pg_dump ... | gzip > /root/backups/db.sql.gz; tar -C / -cf - ... / 2>/dev/null" | restic ...`
  (note the `;` — the dump must finish before tar reads the file, or the tar grabs a
  half-written dump).
- Rotate old dumps to avoid growth: `find /root/backups -name '*.sql.gz' -mtime +7 -delete`.
- The dump file itself is what gets backed up — a raw `pg_dump` output is a consistent
  point-in-time snapshot even while the DB keeps running.
