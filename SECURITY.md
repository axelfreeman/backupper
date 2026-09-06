# Security Policy

## Encryption

Backupper encrypts backups **client-side** with AES-256 via Restic. The encryption key (`RESTIC_PASSWORD`) lives on your Windows PC and never leaves it. If a server or the backup repo leaks, the data stays unreadable without the key.

## Data access

Backupper never touches your data beyond streaming it locally from your servers over SSH to your own PC. No third-party service sees, stores, or relays anything. Backups stay on your own hardware.

## Reporting a vulnerability

Report security issues privately to **axel@axelfreeman.com**. Do not open a public issue for a vulnerability.

## Best practices

- Use a strong, unique `RESTIC_PASSWORD` per repo.
- Store the key in a password manager — without it, restores are impossible.
- Use SSH key auth, never passwords, in scheduled jobs.
- Rotate the key if a server or repo is ever compromised.
- Verify integrity regularly: `restic check` (daily) and `restic check --read-data` (weekly).
