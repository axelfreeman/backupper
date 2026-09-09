#!/usr/bin/env bash
# measure-tar-size.sh — measure the TRUE byte size of a full-rootfs tar on THIS server.
#
# Why: a restic --stdin snapshot can silently hold PARTIAL data (ssh dropped
# mid-pull, PC rebooted, network switched) and still look successful. Compare
# the snapshot's logical size against this probe to spot truncated backups:
#   snapshot_size(restic)  vs  TAR_SIZE_GiB(this script, run on the server)
# A snapshot much smaller than the probe = truncated = re-run the leg.
#
# Run it ON the target server (root), from anywhere that can ssh:
#   ssh root@SERVER 'bash -s' < measure-tar-size.sh
#
# Expect 10-20+ minutes on file-heavy servers (hundreds of thousands of small
# files). Launch it backgrounded and poll the output file — do NOT run it in a
# short foreground ssh: an agent-side timeout leaves an orphan tar running
# server-side, and do NOT `pkill -f "tar -C /"` afterwards — it kills this
# probe too. Re-running this script kills a stale probe via its pidfile.
#
# IMPORTANT: mirror EXCLUDES to the tar line of the .bat you are checking,
# otherwise the comparison is apples-to-oranges. Start from the base set and
# add whatever your .bat excludes (mounted recovery images under /mnt/...,
# recreatable caches like /root/.cache /root/.npm /root/.agent-browser).
set -u

EXCLUDES=(--exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp
          --exclude=/run --exclude=/var/cache --exclude=/swapfile)
# Add your own here, e.g.:
# EXCLUDES+=(--exclude=/mnt --exclude=/root/.cache --exclude=/root/.npm)

PIDFILE=/root/.tar_measure.pid
OUT=/root/tar_size_measure.txt

# Kill any orphaned probe left by a timed-out session (pidfile-scoped only)
if [ -f "$PIDFILE" ]; then
  OLDPID=$(cat "$PIDFILE" 2>/dev/null || echo 0)
  if kill -0 "$OLDPID" 2>/dev/null; then
    echo "killing stale probe PID $OLDPID" >>"$OUT"
    kill -9 "$OLDPID" 2>/dev/null
  fi
  rm -f "$PIDFILE"
fi

echo "$$" >"$PIDFILE"
start=$(date +%s)
SIZE=$(tar -C / -cf - "${EXCLUDES[@]}" / 2>/dev/null | wc -c)
end=$(date +%s)
rm -f "$PIDFILE"

{
  echo "TAR_SIZE_BYTES=$SIZE"
  echo "TAR_SIZE_GiB=$(awk -v b="$SIZE" 'BEGIN { printf "%.2f", b/1073741824 }')"
  echo "DURATION_SEC=$((end-start))"
  echo "df_used_KB=$(df --output=used / | tail -1 | tr -d ' ')"
} | tee "$OUT"

echo "Compare TAR_SIZE_GiB against the latest snapshot size (on the PC: restic -r C:\\backups\\<repo> snapshots --latest 1)."
