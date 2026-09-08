# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0] — 2026-09-08

### Added
- `scripts/verify-backups.ps1` — per-repo size VERIFY vs thresholds. Catches 0-byte and truncated snapshots that restic silently saves as successful when ssh dies mid-stream.
- `scripts/backup-all.bat` — fleet wrapper: N servers in one scheduled task, small-first order, per-server `[OK]/[FAIL]` + log, VERIFY at the end.
- `scripts/backup_watchdog.sh` — server-side hourly freshness status, run from any Linux box (always prints; freshness ≠ completeness).
- `references/verification-and-failure-modes.md` — the three silent failure modes, threshold tuning (~50–60% of measured full size), tar-readability test, restore drill.

### Changed
- `scripts/backup-server.bat` — reachability pre-check (`echo ok`, `BatchMode`), `ConnectTimeout=30`.
- `references/windows-setup.md` — golden rules (no reboot mid-run, no concurrent runs), catch-up procedure, Task Scheduler naming warning.
- `references/database-dumps.md` — pull-model pattern: dump inside the same ssh command, right before tar.
- `SKILL.md` / `README.md` / `SKILL.lite.md` / `llms.txt` — verification-first workflow, layout updated.

## [0.1.0] — 2026-09-06

### Added
- Initial release — Restic pull-backup skill: encrypted (AES-256), deduplicated, tar-over-SSH streaming, zero server-side install.
- `SKILL.md` — the agent skill with hard-won pitfalls.
- `scripts/backup-server.bat` — single-server backup wrapper (backup → check → forget/prune).
- `references/windows-setup.md` — Restic install + PATH fix, SSH keys, Task Scheduler, fleet pattern.
- `references/database-dumps.md` — Postgres/MySQL dump patterns before the snapshot.
- `llms.txt`, `SKILL.lite.md`, `AGENTS.md`, `SECURITY.md` — agent discoverability + compact version + security policy.
