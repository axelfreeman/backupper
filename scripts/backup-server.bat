@echo off
setlocal

:: ============================================================
::  Backupper — single-server Restic pull backup
::  Fill in CONFIG below, keep the rest as-is.
::  Run this from cmd.exe (NOT PowerShell 5.1 — it corrupts the pipe).
:: ============================================================

:: === CONFIG (fill in) ===
set "RESTIC_PASSWORD=<strong-passphrase>"
set "REPO=C:\backups\<server-name>"
set "SERVER=root@<server-ip>"
:: Extra tar --exclude paths, space-separated (e.g. /mnt/recovery /mnt/image)
set "EXCLUDES="

:: === common excludes (keep these) ===
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
