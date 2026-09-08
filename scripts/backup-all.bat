@echo off
setlocal

:: ============================================================
::  Backupper — fleet backup: one .bat for N servers, one repo each.
::  Sequential, small/fast servers FIRST (a slow server at the head
::  starves the rest of the nightly window).
::  Logs full output to C:\backups\backup-all.log, prints [OK]/[FAIL]
::  per server, then runs the size VERIFY (verify-backups.ps1).
::  Run from cmd.exe (NOT PowerShell 5.1 — it corrupts the pipe).
:: ============================================================

set "RESTIC_PASSWORD=<strong-passphrase>"
set "LOG=C:\backups\backup-all.log"
set "SSHOPT=-o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o BatchMode=yes"
set "BASE_EXCL=--exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp --exclude=/run --exclude=/var/cache --exclude=/swapfile --exclude=/mnt"

echo === %date% %time% START ===>>"%LOG%"

:: ============ legs: call :leg "name" "root@ip" "C:\backups\repo" "<extra-excludes>" ============
call :leg "server1" "root@1.2.3.4"  "C:\backups\server1"  ""
call :leg "server2" "root@5.6.7.8"  "C:\backups\server2"  "--exclude=/root/.cache --exclude=/root/.npm --exclude=/root/.agent-browser"
call :leg "server3" "root@9.10.11.12" "C:\backups\server3" ""
:: ==============================================================================================

echo.
echo === VERIFY ===
powershell -NoProfile -ExecutionPolicy Bypass -File C:\backups\verify-backups.ps1
echo === %date% %time% END ===>>"%LOG%"
exit /b 0

:leg
set "NAME=%~1"
set "SERVER=%~2"
set "REPO=%~3"
set "EXTRA=%~4"
call :log "--- %NAME% %SERVER% ---"
ssh %SSHOPT% %SERVER% "echo ok" >nul 2>&1
if errorlevel 1 (call :log "[FAIL] %NAME% (unreachable)" & exit /b 0)
ssh %SSHOPT% %SERVER% "tar -C / -cf - %BASE_EXCL% %EXTRA% / 2>/dev/null" | restic -r %REPO% backup --stdin --stdin-filename rootfs.tar >>"%LOG%" 2>&1
if errorlevel 1 (call :log "[FAIL] %NAME%") else (call :log "[OK] %NAME%")
exit /b 0

:log
echo %~1
echo %~1>>"%LOG%"
exit /b
