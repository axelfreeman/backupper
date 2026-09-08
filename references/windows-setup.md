# Windows setup + known-good patterns (fleet-proven)

## 1. Install Restic (winget alias bug)
`winget install Restic.Restic` often leaves `restic` "not recognized" even after reopening
the shell. Fix — copy the exe to a fixed dir and add it to the USER PATH:

```powershell
New-Item -ItemType Directory -Force C:\restic | Out-Null
$r = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet" -Recurse -Filter restic.exe -EA SilentlyContinue | Select-Object -First 1
if ($r) { Copy-Item $r.FullName C:\restic\restic.exe -Force }
else {
  $zip = "$env:TEMP\restic.zip"
  Invoke-WebRequest -Uri "https://github.com/restic/restic/releases/download/v0.19.1/restic_0.19.1_windows_amd64.zip" -OutFile $zip
  Expand-Archive $zip -DestinationPath C:\restic -Force
}
$p = [Environment]::GetEnvironmentVariable("Path","User")
if ($p -notlike "*C:\restic*") { [Environment]::SetEnvironmentVariable("Path", "$p;C:\restic", "User") }
```

Close + reopen the terminal, then verify: `restic version`.

## 2. Drive letter must exist
`restic -r D:\backups\... init` fails with "cannot find the path" when `D:` isn't mounted.
Confirm with `Get-PSDrive -PSProvider FileSystem`, or just use `C:\backups\<name>`.

## 3. SSH key auth (no password prompts in a scheduled job)
Generate a key **interactively** (press Enter twice for a truly empty passphrase — do NOT
use `ssh-keygen -N ""` in PowerShell, it sets a literal `""` passphrase and the key silently
fails auth):

```cmd
ssh-keygen -t ed25519 -f %USERPROFILE%\.ssh\id_ed25519
```

Append the pubkey to every server's `~/.ssh/authorized_keys`. Verify non-interactively:

```cmd
ssh -i %USERPROFILE%\.ssh\id_ed25519 -o BatchMode=yes root@SERVER "echo ok"
```

`BatchMode=yes` fails fast instead of prompting — no output except `ok` means it works.
Record the key fingerprint now — you will need it for the watchdog:
`ssh-keygen -lf %USERPROFILE%\.ssh\id_ed25519.pub`

## 4. Init the repo (one-time)
```cmd
set RESTIC_PASSWORD=<strong-passphrase>
restic -r C:\backups\<name> init
```
One repo per server. Store the same password in every .bat and in verify-backups.ps1.
Losing the password = backups unrecoverable — keep it somewhere safe.

## 5. Write the .bat wrapper
Copy `scripts/backup-server.bat` (single server) or `scripts/backup-all.bat` (fleet),
fill in CONFIG, and save it with **ASCII** encoding (a UTF-8 BOM breaks cmd).
Easiest way from PowerShell (here-string, no Notepad encoding issues):

```powershell
@'
@echo off
setlocal
set "RESTIC_PASSWORD=<strong-passphrase>"
set "REPO=C:\backups\<server-name>"
set "SERVER=root@<server-ip>"
set "EXCLUDES="
set "BASE_EXCL=--exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp --exclude=/run --exclude=/var/cache --exclude=/swapfile"
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o BatchMode=yes %SERVER% "echo ok" >nul 2>&1
if errorlevel 1 (echo [FAIL] unreachable & exit /b 1)
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o BatchMode=yes %SERVER% "tar -C / -cf - %BASE_EXCL% %EXCLUDES% / 2>/dev/null" | restic -r %REPO% backup --stdin --stdin-filename rootfs.tar
if errorlevel 1 (echo BACKUP FAILED & exit /b 1) else (echo BACKUP OK)
'@ | Set-Content -Path "$env:USERPROFILE\Desktop\backup-<name>.bat" -Encoding ASCII
```

Run: `cmd /c "%USERPROFILE%\Desktop\backup-<name>.bat"` (or double-click).
**Always run via cmd.exe — never paste the `ssh | restic` pipe into PowerShell 5.1**
(it corrupts binary data; pwsh 7 is fine).

## 6. Schedule (Task Scheduler, daily)
`-StartWhenAvailable` makes a missed run fire as soon as the PC next boots:

```powershell
$action   = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$env:USERPROFILE\Desktop\backup-<name>.bat`""
$trigger  = New-ScheduledTaskTrigger -Daily -At 11:30PM
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
Register-ScheduledTask -TaskName "Backup <name>" -Action $action -Trigger $trigger -Settings $settings
```

Verify: `Get-ScheduledTask -TaskName "Backup <name>" | Select-Object -ExpandProperty Triggers`.
Registering with an existing task name replaces it. **When listing/deleting tasks, never
filter broadly (e.g. `-like "Backup*"`)** — it catches Windows system tasks
(`ppListBackup`, `CloudRestore`, ...) and spams `Access is denied`.

## 7. Golden rules (learned the hard way — partial snapshots)
- **Do not let the PC reboot, sleep, or install updates mid-run.** A killed `ssh.exe` is
  EOF to restic = the truncated stream is SAVED AS A SUCCESSFUL SNAPSHOT, logged `[OK]`.
  The only thing that catches it is the size VERIFY next morning.
- **Do not start a manual catch-up while the scheduled run is about to fire** — two
  concurrent runs stepping on the same repos/servers produce garbage.
- After any interrupted run: re-run ONLY the failed legs (see §8), then VERIFY.
- Every server's tar line should have an **`echo ok` reachability pre-check first**
  (already in the templates) so an unreachable server fails in 1 second, not after
  streaming 0 bytes into a fresh snapshot.

## 8. Catch-up after an interrupted run
`ssh | restic` legs are resumable-by-dedup: a re-run re-reads the whole tar but only
stores what changed. To catch up, run just the affected servers — edit a copy of the
fleet .bat down to those legs, or use the single-server .bat per server:

```powershell
cmd /c "%USERPROFILE%\Desktop\backup-<name>.bat"
powershell -NoProfile -ExecutionPolicy Bypass -File C:\backups\verify-backups.ps1
```

## 9. Fleet pattern (multiple servers)
Consolidate to **one `.bat` + one scheduled task**, with a **separate repo per server**.
Use `scripts/backup-all.bat` (sequential, small servers first, per-server `[OK]/[FAIL]`,
log file, VERIFY at the end). Put `scripts/verify-backups.ps1` at `C:\backups\` and fill
in the thresholds (see `references/verification-and-failure-modes.md`).
