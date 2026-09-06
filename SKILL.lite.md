---
name: backupper
description: Free encrypted deduplicated backups of remote Linux servers from a Windows PC via Restic pull-backup (tar over SSH, zero server install). Use for server/VPS backup, provider-ban protection, scheduled backups.
version: 0.1.0
license: MIT
install: "npx skills add axelfreeman/backupper"
---

# Backupper (lite)

Back up remote Linux servers from a Windows PC. Restic runs on the PC, streams `tar` over SSH, encrypts (AES-256) and dedups into a local repo. **Nothing installed server-side.**

## Core command

```
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 root@SERVER "tar -C / -cf - --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp --exclude=/run --exclude=/var/cache --exclude=/swapfile / 2>/dev/null" | restic -r C:\backups\REPO backup --stdin --stdin-filename rootfs.tar
```

## Steps

1. Install Restic (winget; if PATH broken, copy exe to `C:\restic`).
2. Generate SSH key **interactively** (empty passphrase); append pubkey to server `~/.ssh/authorized_keys`.
3. Init repo: `restic -r C:\backups\<name> init` (set strong `RESTIC_PASSWORD`).
4. Copy `scripts/backup-server.bat`, fill CONFIG, save as **ASCII**.
5. Schedule daily via Task Scheduler (`-StartWhenAvailable`).
6. Verify: `restic -r C:\backups\<name> snapshots` shows non-zero size.

## Pitfalls (must read)

- Run the pipe in `.bat`/cmd — **NOT PowerShell 5.1** (corrupts binary pipes). `pwsh` 7 is fine.
- `2>/dev/null` is the **remote-side** redirect; never write `2>nul`.
- **No gzip** on the tar (`-z`) — it kills cross-snapshot dedup.
- `ssh | restic` exit code = restic's, not ssh's — a dead server yields a 0-byte `[OK]`. Verify sizes via `snapshots`.
- `ssh-keygen -N ""` in PowerShell sets a literal `""` passphrase — generate interactively, press Enter twice.
- Exclude mount noise + recovery images (`/mnt/recovery`, `/mnt/image`) or you re-pull giant qcow2 files.
- **Databases need a dump first** — see `references/database-dumps.md`.

## Verify + restore

```
restic -r C:\backups\<name> snapshots
restic -r C:\backups\<name> check                 # fast, daily
restic -r C:\backups\<name> check --read-data     # full, weekly
restic -r C:\backups\<name> restore latest --target C:\restore\<name>
```
