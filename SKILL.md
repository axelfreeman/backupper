---
name: backupper
description: Set up free, encrypted, deduplicated backups of remote Linux servers, pulled from a Windows PC with Restic — tar-over-SSH streaming, zero software installed server-side. Use when the user wants to back up VDS/VPS servers, protect against provider bans, "как не потерять всё", or automate backups. Works with any AI agent/model.
version: 0.1.0
license: MIT
install: "npx skills add axelfreeman/backupper"
---

# Backupper

Back up remote Linux servers **from a Windows PC** with **zero software installed on the
servers**. Restic streams a `tar` over SSH straight into an encrypted, deduplicated repo.

## What you get
- **Encrypted** (AES-256, key stays on your PC) — safe even if a server or repo leaks.
- **Deduplicated** — daily full snapshots cost almost nothing after the first.
- **Zero server-side install** — only `tar` + `sshd`, which every Linux box already has.
- **Free** — Restic is BSD-2-Clause. No licenses, no limits, no vendor lock-in.

## When to use
- Backing up a VDS/VPS fleet (one server or many).
- Recovering after a provider ban — the reason to keep backups OFF the servers themselves.
- Replacing a paid backup tool with a free one you fully control.

## The core idea (read this first)
You do **NOT** install Restic on the servers. Restic runs **on the Windows PC** and *pulls*
each server's files by streaming them over SSH:

```
ssh root@SERVER "tar -C / -cf - / 2>/dev/null" | restic -r C:\backups\REPO backup --stdin --stdin-filename rootfs.tar
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
2. Generate an SSH key; append the pubkey to the server's `~/.ssh/authorized_keys`.
3. Init the repo: `restic -r C:\backups\<name> init` (set a strong `RESTIC_PASSWORD`).
4. Create the `.bat` wrapper — template in `scripts/backup-server.bat`.
5. Schedule with Task Scheduler (daily, `-StartWhenAvailable`).
6. Verify: `restic -r C:\backups\<name> snapshots` shows a non-zero size.

## Pitfalls (hard-won — read before you run)
- **PowerShell 5.1 corrupts binary data in pipes.** Run the `ssh | restic` line in a `.bat`
  (cmd.exe), not in `powershell.exe` 5.1. (`pwsh` 7 is fine.)
- **`2>/dev/null` is the REMOTE-side redirect** (tar's stderr on Linux). Never write `2>nul`.
- **Do NOT gzip the tar** (`-z`). gzip re-randomizes the stream and kills cross-snapshot dedup.
- **First-connect host-key prompt hangs non-interactive jobs.** Always pass
  `-o StrictHostKeyChecking=accept-new` to `ssh`.
- **`ssh | restic` sets the exit code from restic, not ssh** — a dead server yields a 0-byte
  snapshot logged as OK. Add `-o ConnectTimeout=20` and verify sizes via `snapshots`.
- **`ssh-keygen -N ""` in PowerShell** sets a literal `""` passphrase (not empty), so the key
  silently fails auth. Generate interactively and press Enter twice.
- **Exclude mount noise** (`/proc /sys /dev /tmp /run /var/cache /swapfile`) plus any mounted
  recovery images (e.g. `/mnt/recovery`, `/mnt/image`) or you'll re-pull giant qcow2 files.
- **Databases need a dump first** — Restic has no DB hooks. `pg_dump`/`mysqldump` over SSH
  *before* the snapshot. See `references/database-dumps.md`.

## Verify + restore
- Snapshots: `restic -r C:\backups\<name> snapshots`
- Integrity: `restic -r C:\backups\<name> check` (fast, daily) / `check --read-data` (weekly, full)
- Restore: `restic -r C:\backups\<name> restore latest --target C:\restore\<name>`

## Scaling to a fleet
One `.bat`, one scheduled task, one repo per server. See the fleet pattern in
`references/windows-setup.md`.

## Model-agnostic
This skill is plain instructions — no model-specific syntax or assumptions. It works with
Claude, GPT, Gemini, DeepSeek, Llama, and any agent that can read a SKILL.md and run shell
commands.
