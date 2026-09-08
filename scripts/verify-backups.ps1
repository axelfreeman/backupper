# Backupper — per-repo size VERIFY.
# Compares the LATEST snapshot of each repo against a minimum threshold.
# Catches the silent failure mode where a truncated or 0-byte stream was
# still saved by restic as a "successful" snapshot (ssh died = EOF to restic).
#
# Run at the end of every backup-all.bat run, or anytime:
#   powershell -NoProfile -ExecutionPolicy Bypass -File C:\backups\verify-backups.ps1
# Exit code 0 = all OK, 1 = at least one repo below threshold.

$env:RESTIC_PASSWORD = "<strong-passphrase>"

# Edit: per-repo minimum FULL size (bytes). Set to ~50-60% of the good size you
# measured after the first successful full run. To measure: restic snapshots shows
# logical size; cross-check against `df --output=used /` on the server minus tar excludes.
$t = @{
  "server1" = [long]5*1GB
  "server2" = [long]12*1GB
  "server3" = [long]1*1GB
}

$fail = 0
foreach ($name in ($t.Keys | Sort-Object)) {
  $s = restic -r "C:\backups\$name" snapshots --latest 1 --json 2>$null | ConvertFrom-Json
  if (-not $s) {
    Write-Host ("[FAIL] {0} - NO snapshots" -f $name)
    $fail = 1
    continue
  }
  $b = [long]$s[0].summary.total_bytes_processed
  if ($b -lt $t[$name]) {
    Write-Host ("[FAIL] {0} - {1:N2} GiB < threshold" -f $name, ($b/1GB))
    $fail = 1
  } else {
    Write-Host ("[OK] {0} - {1:N2} GiB" -f $name, ($b/1GB))
  }
}

if ($fail -eq 1) {
  Write-Host ""
  Write-Host "Below-threshold repos are probably TRUNCATED snapshots (interrupted ssh)."
  Write-Host "Fix: re-run just those legs - catch-up is cheap (dedup). See references/verification-and-failure-modes.md"
}
exit $fail
