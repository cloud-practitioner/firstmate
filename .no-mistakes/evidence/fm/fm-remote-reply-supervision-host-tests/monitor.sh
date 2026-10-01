#!/usr/bin/env bash
# Samples every 10s the live hosts and watchers belonging to the suite's fixture
# homes (FM_HOME under an fm-supervision-host.* temp root), plus load average.
out=$1; pidf=$2
printf 'elapsed_s\tload1\thosts\twatchers\n' > "$out"
start=$(date +%s)
while kill -0 "$(cat "$pidf")" 2>/dev/null; do
  h=0; w=0
  for p in /proc/[0-9]*; do
    tr '\0' '\n' < "$p/environ" 2>/dev/null | grep -q '^FM_HOME=.*/fm-supervision-host\.' || continue
    a=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$a" in *bin/fm-supervision-host.sh*) h=$((h+1)) ;; *bin/fm-watch.sh*) w=$((w+1)) ;; esac
  done
  printf '%s\t%s\t%s\t%s\n' $(( $(date +%s) - start )) "$(cut -d' ' -f1 /proc/loadavg)" "$h" "$w" >> "$out"
  sleep 10
done
