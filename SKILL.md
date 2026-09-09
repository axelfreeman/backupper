---
name: backupper
description: Set up free, encrypted, deduplicated backups of remote Linux servers, pulled from a Windows PC with Restic — tar-over-SSH streaming, zero software installed server-side, with size verification against silent partial-snapshot failures. Use when the user wants to back up VDS/VPS servers, protect against provider bans, "как не потерять всё", or automate backups. Works with any AI agent/model.
version: 0.3.0
license: MIT
install: "npx skills add axelfreeman/backupper"
---

# Backupper

Back up remote Linux servers **from a Windows PC** with **zero software installed on the
servers**. Restic streams a `tar` over SSH straight into an encrypted, deduplicated repo —
and a size VERIFY catches the silent failures (truncated snapshots saved as "OK").

## What you get
- **Encrypted** (AES-256, key stays on your PC) — safe even if a server or repo leaks.
- **Deduplicated** — daily full snapshots cost almost nothing after the first; interrupted
  runs are re-run cheaply (catch-up = dedup, not re-upload).
- **Zero server-side install** — only `tar` + `sshd`, which every Linux box already has.
- **Verified** — per-repo size thresholds flag truncated/0-byte snapshots the morning after.
- **Free** — Restic is BSD-2-Clause. No licenses, no limits, no vendor lock-in.

## When to use
- Backing up a VDS/VPS fleet (one server or many).
- Recovering after a provider ban — the reason to keep backups OFF the servers themselves.
- Replacing a paid backup tool with a free one you fully control.

## The core idea (read this first)
You do **NOT** install Restic on the servers. Restic runs **on the Windows PC** and *pulls*
each server's files by streaming them over SSH:

```
ssh root@SERVER "tar -C / -cf - --exclude=/proc ... / 2>/dev/null" | restic -r C:\backups\REPO backup --stdin --stdin-filename rootfs.tar
```

- Left side of `|`: streams a tar of the whole server over SSH.
- Right side: feeds that stream into Restic, which dedups + encrypts it into a local repo.
- Nothing is installed server-side; you only need SSH access.

## What you need
1. **A Windows PC** (the backup target that holds the repos). Any drive works.
2. **Restic** on the PC — see `references/windows-setup.md`.
3. **SSH key auth** to each server (a scheduled job can't answer password prompts).
4. **One repo per server** (keeps restores simple and isolated).

## Setup steps (one server first, then scale)
1. Install Restic + fix the PATH bug — `references/windows-setup.md`.
2. Generate an SSH key **interactively**; append the pubkey to each server's
   `~/.ssh/authorized_keys`; verify with `-o BatchMode=yes ssh "echo ok"`.
3. Init the repo: `restic -r C:\backups\<name> init` (strong `RESTIC_PASSWORD`, store it
   with the .bat files — losing it loses the backups).
4. Create the `.bat` wrapper — `scripts/backup-server.bat` (single) or
   `scripts/backup-all.bat` (fleet). Save ASCII. Run from cmd.exe.
5. Schedule with Task Scheduler (daily, `-StartWhenAvailable`) — snippet in
   `references/windows-setup.md`.
6. **Verify** — `scripts/verify-backups.ps1` (fill in thresholds). A fresh snapshot row
   alone proves nothing: see `references/verification-and-failure-modes.md`. With no PC
   access, confirm a pull really FINISHED from the server side (sshd session-duration /
   overlap checks) and cross-check sizes with `scripts/measure-tar-size.sh`.
7. Optional: hourly server-side freshness watchdog — `scripts/backup_watchdog.sh`.

## Pitfalls (hard-won — read before you run)
- **PowerShell 5.1 corrupts binary data in pipes.** Run the `ssh | restic` line in a
  `.bat` (cmd.exe), not in `powershell.exe` 5.1. (`pwsh` 7 is fine.)
- **`2>/dev/null` is the REMOTE-side redirect** (tar's stderr on Linux). Never write `2>nul`.
- **Do NOT gzip the tar** (`-z`). gzip re-randomizes the stream and kills cross-snapshot dedup.
- **First-connect host-key prompt hangs non-interactive jobs.** Always pass
  `-o StrictHostKeyChecking=accept-new`.
- **A dead server yields a 0-byte snapshot logged as OK** — `ssh | restic` sets the exit
  code from restic, not ssh, and EOF is success to restic. Add a reachability pre-check
  (`ssh ... "echo ok"`) before each leg.
- **A truncated stream is saved as a FULL snapshot (the big one).** If ssh dies mid-run
  (reboot, Windows Update, network switch), restic saves the partial tar as `[OK]`.
  Only the size VERIFY catches it. Never let the PC reboot/sleep during a run; after an
  interrupted run, re-run the affected legs and VERIFY.
- **`ssh-keygen -N ""` in PowerShell** sets a literal `""` passphrase (not empty), so the
  key silently fails auth. Generate interactively and press Enter twice.
- **Exclude mount noise** (`/proc /sys /dev /tmp /run /var/cache /swapfile`) plus mounted
  recovery images (`/mnt/...`) and, on profile-heavy servers, recreatable caches
  (`/root/.cache /root/.npm /root/.agent-browser`) — they re-generate, only slow the pull
  and inflate the repo.
- **Check `mount` + `du -sh /mnt/*` on each server before writing its tar line** — a server
  recovered from a disk image may still hold a giant qcow2 under `/mnt`.
- **Databases need a dump first** — Restic has no DB hooks. `pg_dump`/`mysqldump` over SSH
  *before* the snapshot, into a non-excluded path. See `references/database-dumps.md`.
- **Small/fast servers FIRST** in a fleet .bat — one slow box at the head starves the rest.

## Layout
| Path | What |
|---|---|
| `SKILL.md` | This agent skill (works with any LLM) |
| `scripts/backup-server.bat` | Single-server wrapper (template) |
| `scripts/backup-all.bat` | Fleet wrapper: N servers, one task, log, VERIFY |
| `scripts/verify-backups.ps1` | Size VERIFY vs per-repo thresholds |
| `scripts/backup_watchdog.sh` | Server-side hourly freshness status (cron) |
| `scripts/measure-tar-size.sh` | Probe the TRUE tar size on a server (truncation check) |
| `references/windows-setup.md` | Install, key auth, Task Scheduler, catch-up, golden rules |
| `references/verification-and-failure-modes.md` | Silent failures, thresholds, tar test, server-side finish checks |
| `references/database-dumps.md` | Postgres/MySQL dump patterns |

## Restore
- Snapshots: `restic -r C:\backups\<name> snapshots`
- Integrity: `restic -r C:\backups\<name> check` (fast, daily) / `check --read-data` (weekly)
- Restore: `restic -r C:\backups\<name> restore latest --target C:\restore\<name>`
  (note: `--stdin` snapshots contain a single `rootfs.tar` — restore it, then extract)
- Quarterly drill: restore a file from each repo + `check --read-data`.

## Model-agnostic
This skill is plain instructions — no model-specific syntax or assumptions. It works with
Claude, GPT, Gemini, DeepSeek, Llama, and any agent that can read a SKILL.md and run shell
commands.
