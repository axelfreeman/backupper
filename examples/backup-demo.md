# Example — agent sets up a backup (transcript)

This is what a successful first run looks like, so you can match the expected flow.

**User:** "Set up backups of my VPS with this skill."

**Agent:**
1. Reads `SKILL.md` → confirms the model: Restic on the Windows PC, `tar`-over-SSH pull, nothing installed on the server.
2. `references/windows-setup.md` → installs Restic, fixes the PATH bug, confirms `restic version`.
3. Generates an SSH key interactively (empty passphrase), appends the pubkey to the server:
   ```
   ssh root@SERVER "mkdir -p ~/.ssh && echo '<pubkey>' >> ~/.ssh/authorized_keys"
   ssh -i ~/.ssh/id_ed25519 -o BatchMode=yes root@SERVER "echo ok"
   # -> ok
   ```
4. Inits the repo:
   ```
   set RESTIC_PASSWORD=<strong-passphrase>
   restic -r C:\backups\vps init
   ```
5. Writes `backup-vps.bat` from the template, fills in `SERVER`, `REPO`, `RESTIC_PASSWORD`, `EXCLUDES` (adds `/mnt/recovery /mnt/image`).
6. Schedules it daily via Task Scheduler with `-StartWhenAvailable`.
7. Runs it once, then verifies:
   ```
   restic -r C:\backups\vps snapshots
   # -> snapshot 1234abc 2026-09-06 00:00  (size: 12.3 GiB)
   ```

**Done.** Daily encrypted, deduplicated backups now run automatically on the user's own PC.
