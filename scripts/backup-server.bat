@echo off
setlocal

:: ============================================================
::  Backupper — single-server Restic pull backup
::  Fill in CONFIG below, keep the rest as-is.
::  Run from cmd.exe (NOT PowerShell 5.1 — it corrupts the pipe).
:: ============================================================

:: === CONFIG (fill in) ===
set "RESTIC_PASSWORD=<strong-passphrase>"
set "REPO=C:\backups\<server-name>"
set "SERVER=root@<server-ip>"
:: Extra tar --exclude paths, space-separated:
::   - mounted recovery images:  /mnt/recovery /mnt/image
::   - recreatable caches on profile-heavy servers: /root/.cache /root/.npm /root/.agent-browser
set "EXCLUDES="

:: === common excludes (keep these) ===
set "BASE_EXCL=--exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp --exclude=/run --exclude=/var/cache --exclude=/swapfile"

:: === 0) reachability pre-check — fail fast instead of streaming nothing ===
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o BatchMode=yes %SERVER% "echo ok" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] %SERVER% unreachable
  exit /b 1
)

echo [1/3] Backup %SERVER% ...
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o BatchMode=yes %SERVER% "tar -C / -cf - %BASE_EXCL% %EXCLUDES% / 2>/dev/null" | restic -r %REPO% backup --stdin --stdin-filename rootfs.tar
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
