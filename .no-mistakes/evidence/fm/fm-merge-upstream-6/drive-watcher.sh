#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
unset FM_HOME FM_BACKEND FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITLAB_TOKEN
export TMPDIR="$ROOT/.test-phase/tmp"
export HOME="$ROOT/.test-phase/watcher-user-home"
mkdir -p "$HOME" "$TMPDIR"
lab=$(mktemp -d "$ROOT/.test-phase/watcher-home.XXXXXX")
bin/fm-lab-home.sh create "$lab"
pids=()
cleanup() {
  rc=$?
  for pid in "${pids[@]}"; do kill -CONT "$pid" 2>/dev/null || true; kill -TERM "$pid" 2>/dev/null || true; done
  for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
  printf '\n=== Real watcher CLI diagnostics ===\n'
  for log in "$lab"/watch-*.log; do printf '\n%s\n' "${log##*/}"; cat "$log"; done
  printf '\n=== Persisted cycle ledger ===\n'
  if [ -f "$lab/state/.watcher-cycles.tsv" ]; then cat "$lab/state/.watcher-cycles.tsv"; fi
  rm -rf "$lab"
  exit "$rc"
}
trap cleanup EXIT
# Verify absence, rather than relying on an exited process PID that may be
# reused while forty contenders are starting.
dead=9999999
while kill -0 "$dead" 2>/dev/null; do dead=$((dead+1)); done
mkdir "$lab/state/.watch.lock"
printf '%s\n' "$dead" > "$lab/state/.watch.lock/pid"
printf 'initial verified-dead watcher PID=%s\n' "$dead"
# Real watcher successors, not mocked commands. Successor mode is the same
# runtime setting the watcher arm uses to avoid replaying an already-handled
# recovery wake; it does not bypass lock acquisition or PID identity checks.
for n in 1 2 3 4 5 6; do
  FM_HOME="$lab" FM_WATCH_HANDLING_SUCCESSOR=1 FM_POLL=1 FM_SIGNAL_GRACE=1 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
    bash bin/fm-watch.sh > "$lab/watch-$n.log" 2>&1 &
  pids+=("$!")
done
owner=
for ((i=0; i<200; i++)); do
  if [ -f "$lab/state/.watch.lock/pid" ]; then read -r owner < "$lab/state/.watch.lock/pid"; fi
  live=0
  for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=$((live+1)); fi; done
  if [ "$owner" != "$dead" ] && [ "$live" -eq 1 ] && [ -f "$lab/state/.last-watcher-beat" ]; then break; fi
  sleep 0.1
done
printf 'watcher candidates=%s published_owner=%s live_candidates=%s\n' "${pids[*]}" "$owner" "$live"
[ -n "$owner" ] && [ "$owner" != "$dead" ] && [ "$live" -eq 1 ]
case " ${pids[*]} " in *" $owner "*) ;; *) exit 1 ;; esac
kill -0 "$owner"
[ -f "$lab/state/.last-watcher-beat" ]
printf '\n=== Actual owner process and persisted lock identity ===\n'
ps -p "$owner" -o pid=,args=
for field in "$lab/state/.watch.lock"/*; do [ -f "$field" ] || continue; printf '%s=' "${field##*/}"; cat "$field"; done
printf 'watcher beacon epoch=%s\n' "$(stat -c %Y "$lab/state/.last-watcher-beat")"
for pid in "${pids[@]}"; do [ "$pid" = "$owner" ] || wait "$pid"; done
sleep 2
read -r after < "$lab/state/.watch.lock/pid"
[ "$after" = "$owner" ] && kill -0 "$owner"
printf 'all competitors completed; same owner still alive after two further poll cycles\n'
kill -TERM "$owner"
wait "$owner" || true
[ ! -e "$lab/state/.watch.lock" ] && [ ! -L "$lab/state/.watch.lock" ]
printf 'owner TERM removed only its own lock; disposable home will be removed\n'
