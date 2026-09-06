# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] — 2026-09-06

### Added
- Initial release — Restic pull-backup skill: encrypted (AES-256), deduplicated, tar-over-SSH streaming, zero server-side install.
- `SKILL.md` — the agent skill with hard-won pitfalls.
- `scripts/backup-server.bat` — single-server backup wrapper (backup → check → forget/prune).
- `references/windows-setup.md` — Restic install + PATH fix, SSH keys, Task Scheduler, fleet pattern.
- `references/database-dumps.md` — Postgres/MySQL dump patterns before the snapshot.
- `llms.txt`, `SKILL.lite.md`, `AGENTS.md`, `SECURITY.md` — agent discoverability + compact version + security policy.
