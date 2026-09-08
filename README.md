# Backupper

[![GitHub Repo stars](https://img.shields.io/github/stars/axelfreeman/backupper?style=flat)](https://github.com/axelfreeman/backupper/stargazers)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)](CHANGELOG.md)

Free, encrypted, deduplicated backups of remote Linux servers — pulled from a Windows PC
with [Restic](https://restic.net), with **zero software installed on the servers** and a
built-in size VERIFY that catches silently truncated snapshots.

## How it works

Restic runs on your Windows PC and streams a `tar` of each server over SSH straight into an
encrypted local repo. The servers only need `tar` + `sshd` (always present).

```text
ssh root@SERVER "tar -C / -cf - ... /" | restic -r C:\backups\REPO backup --stdin
```

## Features

- **AES-256 client-side encryption** — the key never leaves your PC.
- **Deduplication** — daily snapshots are nearly free after the first; interrupted runs
  re-run cheaply (catch-up = dedup, not re-upload).
- **No server-side agents** — nothing to install or babysit on the servers.
- **Verified by design** — per-repo size thresholds flag 0-byte and truncated snapshots
  that Restic silently saves as "OK" when the stream dies mid-run.
- **Free forever** — Restic is BSD-2-Clause.

## Quick start

```sh
npx skills add axelfreeman/backupper
```

Or drop this folder into any AI agent (Claude Code, Hermes, Cursor, etc.) and ask it to
"set up backups of my servers". The agent reads `SKILL.md` and does the rest — install,
key setup, repo init, the `.bat` wrapper, scheduling, and the size VERIFY.

## Layout

| Path | What |
|---|---|
| `SKILL.md` | The agent skill (works with any LLM) |
| `SKILL.lite.md` | Compact version for low-context models |
| `llms.txt` | Agent-discoverable index (when-to-use + key phrases) |
| `scripts/backup-server.bat` | Single-server backup wrapper (template) |
| `scripts/backup-all.bat` | Fleet wrapper: N servers, one scheduled task, `[OK]/[FAIL]` log, VERIFY |
| `scripts/verify-backups.ps1` | Per-repo size check vs thresholds |
| `scripts/backup_watchdog.sh` | Server-side hourly freshness status (runs on any Linux box) |
| `references/windows-setup.md` | Install, SSH keys, Task Scheduler, catch-up, golden rules |
| `references/verification-and-failure-modes.md` | Silent failure modes + how to catch them |
| `references/database-dumps.md` | Postgres/MySQL dump patterns |
| `examples/backup-demo.md` | A full setup transcript |

## Keywords

server backup · self-hosted backup · back up VPS · back up Linux server · automatic backup · scheduled backup · encrypted backup · deduplicated backup · free backup · no-cloud backup · restic backup · database backup · postgres backup · mysql backup · backup verification

## Roadmap

- [x] Core pull-backup skill (v0.1)
- [x] Size VERIFY against truncated/0-byte snapshots (v0.2)
- [x] Fleet .bat + per-server status + log (v0.2)
- [x] Server-side freshness watchdog (v0.2)
- [ ] Multi-server dashboard
- [ ] Self-hosted control plane

## Stay updated

Axel Freeman ships releases and improvements to this repo regularly. **Watch + star** the repo to get each new release automatically. See [CHANGELOG.md](CHANGELOG.md).

## License

Tool = [Restic](https://github.com/restic/restic) (BSD-2-Clause). This repo's own files = MIT.
