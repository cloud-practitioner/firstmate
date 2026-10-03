#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EV=/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C
export TMPDIR="$ROOT/.test-phase-tmp"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
export FM_HOME="$LAB" FM_BACKEND=tmux FM_POLL=1 FM_SIGNAL_GRACE=999999 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999
export PATH="$ROOT/.test-phase-tmp/tmux-tool/usr/bin:$PATH" LD_LIBRARY_PATH="$ROOT/.test-phase-tmp/tmux-tool/usr/lib/x86_64-linux-gnu"
A= B=
cleanup() { bin/fm-watch-arm.sh --stop >/dev/null 2>&1 || true; [ -z "$A" ] || kill -TERM "$A" 2>/dev/null || true; [ -z "$B" ] || kill -TERM "$B" 2>/dev/null || true; wait 2>/dev/null || true; rm -rf "$LAB"; }
trap cleanup EXIT
. "$ROOT/bin/fm-wake-lib.sh"
ack_drain() {
  bin/fm-wake-drain.sh > "$LAB/drain" 2>&1
  cat "$LAB/drain"
  ACK=$(awk '/^WAKE_ACK_REQUIRED: after handling completes run / {sub(/^WAKE_ACK_REQUIRED: after handling completes run /,"");print;exit}' "$LAB/drain")
  [ -n "$ACK" ]
  bash -c "$ACK"
}
{
  echo 'Real arm/watcher/wake queue and drain in a marked home; no stubs or native-primary impersonation.'
  fm_recovery_marker_publish "$STATE/.watcher-down" downtime
  ack_drain
  ACKED=$(head -1 "$STATE/.watcher-down")
  bin/fm-watch-arm.sh > "$LAB/owner.out" 2>&1 & A=$!
  for i in $(seq 1 100); do if [ -f "$STATE/.watch.lock/pid" ] && grep -q 'watcher: started pid=' "$LAB/owner.out"; then break; fi; sleep .1; done
  OWNER_WATCHER=$(head -1 "$STATE/.watch.lock/pid")
  printf 'Initial owner arm=%s watcher=%s\n' "$A" "$OWNER_WATCHER"
  bin/fm-watch-arm.sh --take-over "$A" > "$LAB/takeover.out" 2>&1 & B=$!
  for i in $(seq 1 100); do grep -q 'watcher: started pid=' "$LAB/takeover.out" && break; sleep .1; done
  NEW_WATCHER=$(head -1 "$STATE/.watch.lock/pid")
  printf 'Take-over arm=%s watcher=%s\n' "$B" "$NEW_WATCHER"
  test "$OWNER_WATCHER" != "$NEW_WATCHER"
  test "$(head -1 "$STATE/.watcher-down")" = "$ACKED"
  sleep 2
  kill -0 "$B"
  printf 'Handled downtime generation retained exactly: %s\n' "$ACKED"
  fm_wake_append check lab-live 'check: lab-live - new actionable test record'
  for i in $(seq 1 100); do grep -q '^check: rearm-resurface' "$LAB/takeover.out" && break; sleep .1; done
  grep -q '^check: rearm-resurface' "$LAB/takeover.out"
  printf 'New owning cycle emitted:\n'; head -12 "$LAB/takeover.out"
  ack_drain
  printf 'Ownership ledger:\n'; tail -8 "$STATE/.watch-cycle-exits.log"
  cp "$STATE/.watch-cycle-exits.log" "$EV/watcher-ownership.tsv"
} > "$EV/watcher-live.log" 2>&1
