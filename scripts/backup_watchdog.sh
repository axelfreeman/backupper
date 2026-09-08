#!/bin/bash
# ============================================================
#  Backupper — server-side freshness watchdog.
#  Run from any Linux box that can SSH to all servers (e.g. an agent host),
#  hourly via cron. For each server it reports when the Windows PC last
#  pulled a backup, by grepping sshd logs for the PC key's fingerprint.
#
#  IMPORTANT: prints a status EVERY run — do NOT make it silent when OK.
#  Operators want to see the tick. (Explicit user preference, fleet-proven.)
#
#  LIMITATION: freshness != completeness. A truncated snapshot still counts
#  as "fresh contact". Fullness is only checked PC-side by verify-backups.ps1.
#
#  For servers needing a password instead of a key, wrap the ssh in sshpass.
# ============================================================

# === CONFIG ===
SSH_KEY="/path/to/agent-key"          # agent's key (root access to servers)
SSHOPT="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o BatchMode=yes"
PC_FP="SHA256:REPLACE_WITH_PC_KEY_FINGERPRINT"   # e.g. from: ssh-keygen -lf id_ed25519.pub
STALE_H=32                                       # hours after which contact = problem
# name -> root@host
declare -A SERVERS=(
  [server1]="root@1.2.3.4"
  [server2]="root@5.6.7.8"
)

# === remote one-liner: count contacts in 34h, last contact time ===
REMOTE="c=\$(journalctl -u ssh -o short-iso --since '34 hours ago' --no-pager 2>/dev/null | grep -c 'Accepted publickey.*${PC_FP}'); l=\$(journalctl -u ssh -o short-iso --since '34 hours ago' --no-pager 2>/dev/null | grep 'Accepted publickey.*${PC_FP}' | tail -1 | awk '{print \$1}'); a=\$(journalctl -u ssh --since '10 minutes ago' --no-pager 2>/dev/null | grep -c 'Accepted publickey.*${PC_FP}'); echo \"c=\$c|a=\$a|last=\$l\""

now=$(date -u +%s)
declare -A state=()
problems=0

process() {
  local name="$1" res="$2"
  local c a last ts age_h
  c=$(echo "$res" | sed -n 's/.*c=\([0-9]*\).*/\1/p')
  a=$(echo "$res" | sed -n 's/.*a=\([0-9]*\).*/\1/p')
  last=$(echo "$res" | sed -n 's/.*last=\(.*\)$/\1/p')
  [ -z "$c" ] && c=0
  [ -z "$a" ] && a=0
  if [ -n "$last" ] && ts=$(date -d "$last" +%s 2>/dev/null) && [ -n "$ts" ]; then
    age_h=$(( (now - ts) / 3600 ))
  else
    age_h=-1
  fi
  if [ "$a" -gt 0 ]; then
    state[$name]="BACKUP RUNNING NOW"
  elif [ "$age_h" -ge 0 ] && [ "$age_h" -le "$STALE_H" ]; then
    state[$name]="OK - ${age_h}h ago"
  elif [ "$age_h" -gt "$STALE_H" ]; then
    state[$name]="STALE - ${age_h}h"
    problems=1
  else
    state[$name]="NO CONTACT 34h+"
    problems=1
  fi
}

for name in "${!SERVERS[@]}"; do
  res=$(ssh -i "$SSH_KEY" $SSHOPT "${SERVERS[$name]}" "$REMOTE" 2>/dev/null)
  process "$name" "$res"
done

if [ "$problems" -eq 1 ]; then
  echo "BACKUP ALERT ($(date '+%d.%m %H:%M')):"
else
  echo "Backups ($(date '+%d.%m %H:%M')):"
fi
echo ""
for name in "${!SERVERS[@]}"; do
  echo "  ${state[$name]:-no data} - $name"
done
exit 0
