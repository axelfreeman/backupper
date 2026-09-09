# Verification & silent failure modes

A fresh row in `restic snapshots` is NOT proof of a good backup. This document is the
operating manual for the question "это точно весь бекап?" — fleet-proven.

## The three silent failure modes

1. **0-byte snapshot, fresh timestamp** — ssh died before producing any data
   (e.g. port 22 filtered on the PC's path to that server, or the first-connect
   host-key prompt stalled a non-interactive job). Restic saves an empty stream
   and the .bat logs `[OK]`.
2. **PARTIAL snapshot (the nasty one)** — ssh/tar died mid-stream (network switch,
   ISP hiccup, PC reboot/Windows Update). Restic does NOT error on truncated stdin:
   EOF is EOF — the partial tar is saved as a full "successful" snapshot.
   Real fleet cases: a server's repo showed 9.9 GiB vs ~23 GiB actually on disk;
   two others showed 0.44 GiB / 0.05 GiB vs 12.4 GiB / 2.9 GiB good sizes after a
   nightly run overlapped a PC reboot.
3. **Stale-by-starvation** — one slow server at the head of a sequential .bat eats
   the whole nightly window; later servers get skipped or 0 B. Mitigate: order legs
   small/fast first; per-server tasks if one box is consistently slow.

No data is lost in mode 2 IF older full snapshots exist in the repo (dedup keeps them) —
only `latest` is garbage. The fix is a catch-up re-run of the affected legs.

## Size VERIFY (the completeness check)

`scripts/verify-backups.ps1` compares each repo's LATEST snapshot logical size against
a per-repo threshold and prints `[OK]/[FAIL]`. Wire it at the end of every fleet run
(the `backup-all.bat` template already calls it).

**Threshold setting:** after the first clean full run of a server, note its snapshot size
and set the threshold to ~50–60% of it. The snapshot size is the LOGICAL tar size
(`--json` → `summary.total_bytes_processed`, same number as the `Size` column of
`restic snapshots`). Cross-check it server-side: `df --output=used /` minus the tar
excludes (swapfile, /var/cache, caches, /mnt). If the numbers match, the threshold is
trustworthy and a truncated run will trip `[FAIL]` next morning.

## Server-side freshness watchdog (not a completeness check)

`scripts/backup_watchdog.sh` — run hourly from any agent host that can SSH to the fleet.
For each server it greps sshd logs for the PC key's last `Accepted publickey` and reports
freshness. It ALWAYS prints a per-server status every tick (silent-when-OK watchdogs get
rejected by operators). Its blind spot is exactly failure mode 2: a partial snapshot is
still a fresh contact. Completeness lives only in the PC-side VERIFY — the two checks
are complementary, run both.

## When VERIFY trips [FAIL] but the network is fine

Test whether the server's filesystem actually tars cleanly — run the same tar ON the
server and look at its stderr (which `2>/dev/null` normally hides):

```bash
tar -C / -cf /dev/null --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp \
  --exclude=/run --exclude=/var/cache --exclude=/swapfile --exclude=/mnt / 2>&1 | tail -20
echo "tar exit=$?"
```

Exit 0 + only `socket ignored` / `Removing leading` lines = filesystem is readable, the
problem was the transfer, so a catch-up re-run fixes it. Errors like `Cannot open: No
such file or directory` mean the filesystem itself is unhealthy (or churning under a
live docker GC) — fix the server first. Takes minutes on big servers; can be run
backgrounded.

## Server-side completeness checks (no PC access needed)

You have no access to the PC, but you need to know whether a pull actually FINISHED.
Freshness alone lies (a truncated run is still a fresh contact). Three checks, in order:

1. **Session-duration check (the strongest one).** In the server's sshd log, pair each
   PC "Accepted" line with its `pam_unix(sshd:session): session opened/closed` lines:
   ```bash
   journalctl -u ssh --since "7 days ago" --no-pager | grep -E "Accepted publickey|session (opened|closed)"
   ```
   A COMPLETED full pull = ONE long session that closes CLEANLY. A truncated run = a
   short session, an aborted close, or an "Accepted" with no clean close nearby.
2. **Overlap signature.** Two "Accepted" lines ~2 s apart on ONE server = one normal
   .bat leg (echo-ok pre-check + tar ssh). Same-second "Accepted" lines on TWO
   DIFFERENT servers = two concurrent backup processes → expect garbage snapshots
   (a scheduled task fired while a manual run was still going, or a reboot mid-run).
3. **Disk layout before trusting the size math.** Check the CURRENT layout first —
   `lsblk`, `df -h`, `du -sh /mnt/*` — before comparing snapshot size to disk usage.
   A second data disk from an old spec may have been detached (or a recovery image
   unmounted) since you wrote the excludes; stale specs corrupt the completeness math.

The authoritative probe is `scripts/measure-tar-size.sh`: it runs the real tar ON the
server (backgrounded, pidfile-guarded) and prints the true byte count to compare
against the latest snapshot. If `snapshot ≈ probe`, the backup is whole.

## Other verified facts

- **Snapshot timestamp = backup START**, shown in PC-local time; sshd "Accepted" lines
  are server-local time — mind the TZ offset when correlating the two.
- **`--stdin` snapshots contain one file** (`rootfs.tar`) — `restic ls latest` will not
  show individual paths; content verification = size math above or a restore drill.
- **Stored size < logical size**: compression + dedup shrink the repo; logical size is
  what the VERIFY compares, so thresholds stay stable across days.
- **Quarterly restore drill** (cheap insurance): restore a few files from each repo,
  e.g. `restic -r C:\backups\<name> restore latest --target C:\restore-test --include rootfs.tar` + `restic -r C:\backups\<name> check --read-data`.
- **Databases**: dump before snapshot (`references/database-dumps.md`); the tar can't
  capture a consistent live DB data dir.
