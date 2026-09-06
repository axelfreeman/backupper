# Windows setup + known-good patterns

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

## 4. Init the repo (one-time)
```cmd
set RESTIC_PASSWORD=<strong-passphrase>
restic -r C:\backups\<name> init
```

## 5. Write the .bat wrapper
Copy `scripts/backup-server.bat`, fill in CONFIG, and save it with **ASCII** encoding (a
UTF-8 BOM breaks cmd). Easiest way from PowerShell (here-string, no Notepad encoding issues):

```powershell
@'
@echo off
setlocal
set "RESTIC_PASSWORD=<strong-passphrase>"
set "REPO=C:\backups\<server-name>"
set "SERVER=root@<server-ip>"
set "EXCLUDES="
set "BASE_EXCL=--exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp --exclude=/run --exclude=/var/cache --exclude=/swapfile"
echo [1/3] Backup %SERVER% ...
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 %SERVER% "tar -C / -cf - %BASE_EXCL% %EXCLUDES% / 2>/dev/null" | restic -r %REPO% backup --stdin --stdin-filename rootfs.tar
if errorlevel 1 goto fail
echo [2/3] Check integrity ...
restic -r %REPO% check
if errorlevel 1 goto fail
echo [3/3] Cleanup: keep 30 daily snapshots ...
restic -r %REPO% forget --keep-daily 30 --prune
echo BACKUP OK
exit /b 0
:fail
echo BACKUP FAILED
exit /b 1
'@ | Set-Content -Path "$env:USERPROFILE\Desktop\backup-<name>.bat" -Encoding ASCII
```

Run: `cmd /c "%USERPROFILE%\Desktop\backup-<name>.bat"` (or double-click).

## 6. Schedule (Task Scheduler, daily + catch-up)
`-StartWhenAvailable` makes a missed run fire as soon as the PC next boots:

```powershell
$action   = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$env:USERPROFILE\Desktop\backup-<name>.bat`""
$trigger  = New-ScheduledTaskTrigger -Daily -At 11:30PM
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
Register-ScheduledTask -TaskName "Backup <name>" -Action $action -Trigger $trigger -Settings $settings
```

Verify: `Get-ScheduledTask -TaskName "Backup <name>" | Select-Object -ExpandProperty Triggers`.

## 7. Fleet pattern (multiple servers)
Consolidate to **one `.bat` + one scheduled task**, with a **separate repo per server**.
Loop each server's `ssh ... | restic` into its own repo, and log per-server `[OK]`/`[FAIL]`:

```bat
set "LOG=C:\backups\backup-all.log"
echo === %date% %time% ===>>"%LOG%"
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 root@SERVER1 "tar -C / -cf - --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp --exclude=/run --exclude=/var/cache --exclude=/swapfile / 2>/dev/null" | restic -r C:\backups\repo1 backup --stdin --stdin-filename rootfs.tar
if errorlevel 1 (echo [FAIL] server1>>"%LOG%") else (echo [OK] server1>>"%LOG%")
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 root@SERVER2 "tar -C / -cf - --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp --exclude=/run --exclude=/var/cache --exclude=/swapfile / 2>/dev/null" | restic -r C:\backups\repo2 backup --stdin --stdin-filename rootfs.tar
if errorlevel 1 (echo [FAIL] server2>>"%LOG%") else (echo [OK] server2>>"%LOG%")
```

Key points:
- **`if errorlevel 1` after `ssh | restic` checks restic's exit code, not ssh's** — a dead
  server still yields a 0-byte snapshot logged `[OK]`. Verify real sizes via `snapshots`.
- **Check `mount` + `du -sh /mnt/*` on each server before writing the tar line** — a server
  recovered from a disk image may still have a giant qcow2 mounted at `/mnt/recovery`.
