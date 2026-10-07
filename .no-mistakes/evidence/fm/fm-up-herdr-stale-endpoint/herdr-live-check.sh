#!/usr/bin/env bash
# Bounded real-product validation; every Herdr call uses the guarded lab helper.
set -euo pipefail
ROOT=$PWD
HELPER="$ROOT/bin/fm-herdr-lab.sh"
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
SESSION=$("$HELPER" name stale-endpoint)
export FM_HERDR_LAB_STATE_DIR="$LAB/lab-state"
prepared=0
cleanup() {
  local rc=$?
  trap - EXIT
  if [ "$prepared" = 1 ]; then
    if "$HELPER" teardown "$SESSION"; then
      echo 'TEARDOWN: named lab removed; default-session tripwire unchanged'
    else
      echo "TEARDOWN FAILED: retained scratch $LAB for safe inspection"
      exit 2
    fi
  fi
  rm -rf -- "$LAB"
  exit "$rc"
}
trap cleanup EXIT
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_PROC_ROOT_OVERRIDE FM_BACKEND_HERDR_BIN FM_BACKEND_HERDR_CLIENT_SESSION
unset HERDR_ENV HERDR_PANE_ID HERDR_WORKSPACE_ID HERDR_TAB_ID HERDR_SOCKET_PATH
"$ROOT/bin/fm-lab-home.sh" create "$LAB/home"
export FM_HOME="$LAB/home" HERDR_SESSION="$SESSION"
echo "LAB SESSION: $SESSION"
# provision calls prepare itself for an absent session.
prepared=1
"$HELPER" provision "$SESSION"
lab() { "$HELPER" run "$SESSION" "$@"; }
lab status --json
# Route transport through the mandatory helper, without changing ownership logic.
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
fm_backend_herdr_cli() {
  local session=$1
  shift
  [ "$session" = "$SESSION" ] || return 1
  "$HELPER" run "$session" "$@"
}
created=$(lab workspace create --cwd "$FM_HOME" --label fm-live-check --no-focus)
printf 'WORKSPACE CREATE: %s\n' "$created"
ws=$(printf '%s' "$created" | jq -er '.result.workspace.workspace_id')
panes=$(lab pane list --workspace "$ws")
printf 'PANES: %s\n' "$panes"
pane=$(printf '%s' "$panes" | jq -er '.result.panes[0].pane_id')
target="$SESSION:$pane"
identity=$(fm_backend_herdr_pane_process_identity "$SESSION" "$pane")
pid=$(fm_backend_herdr_pane_shell_pid "$SESSION" "$pane")
write_record() {
  printf 'backend=herdr\nwindow=%s\nworktree=%s\nherdr_process_identity=%s\n' "$target" "$FM_HOME" "$1" > "$FM_HOME/state/mine.meta"
}
write_record "$identity"
printf 'INITIAL BINDING: target=%s identity=%s\n' "$target" "$identity"
fm_backend_target_exists herdr "$target" fm-mine
fm_backend_capture herdr "$target" 10 fm-mine
for i in 1 2 3; do
  current=$(fm_backend_herdr_pane_process_identity "$SESSION" "$pane")
  printf 'STABLE READ %s: %s\n' "$i" "$current"
  [ "$current" = "$identity" ]
  sleep 0.2
done
# Adversarial legacy bindings offset from the real shell start by one second.
# Actual ps, /proc, Herdr and Firstmate stay real; only persisted task data changes.
start=$(LC_ALL=C TZ=UTC0 ps -o lstart= -p "$pid")
for offset in -1 1; do
  shifted=$(python3 - "$start" "$offset" <<'PY'
import datetime, sys
value = datetime.datetime.strptime(sys.argv[1].strip(), '%a %b %d %H:%M:%S %Y')
print((value + datetime.timedelta(seconds=int(sys.argv[2]))).strftime('%a %b %d %H:%M:%S %Y'))
PY
)
  write_record "ps:$pid:$shifted"
  fm_backend_target_exists herdr "$target" fm-mine
  fm_backend_capture herdr "$target" 10 fm-mine
  state=$(fm_backend_agent_state herdr "$target" fm-mine)
  printf 'DRIFT OFFSET %s: recorded=%s state=%s exists=yes capture=allowed\n' "$offset" "$shifted" "$state"
  [ "$state" = dead ]
done
write_record "$identity"
echo 'RESTART: stopping only the named lab'
"$HELPER" stop "$SESSION"
"$HELPER" provision "$SESSION"
lab pane get "$pane"
new_identity=$(fm_backend_herdr_pane_process_identity "$SESSION" "$pane")
printf 'RECYCLED ADDRESS: target=%s before=%s after=%s\n' "$target" "$identity" "$new_identity"
[ "$identity" != "$new_identity" ]
# Leave an unsubmitted marker in the replacement shell to prove guarded input
# does not erase another pane's draft and guarded cleanup does not close it.
lab pane send-text "$pane" 'FOREIGN_DRAFT_DO_NOT_SEND'
sleep 0.2
before=$(lab pane read "$pane" --format text --lines 20)
printf 'FOREIGN PANE BEFORE:\n%s\n' "$before"
state=$(fm_backend_agent_state herdr "$target" fm-mine)
printf 'STALE LIVENESS: %s\n' "$state"
[ "$state" = missing ]
if fm_backend_target_exists herdr "$target" fm-mine; then echo 'FAIL: stale target exists'; exit 1; fi
if fm_backend_capture herdr "$target" 10 fm-mine; then echo 'FAIL: stale capture accepted'; exit 1; fi
echo 'STALE CAPTURE: refused'
if fm_backend_send_key herdr "$target" C-u fm-mine; then echo 'FAIL: stale input accepted'; exit 1; fi
echo 'STALE INPUT: refused'
fm_backend_kill herdr "$target" '' fm-mine
after=$(lab pane read "$pane" --format text --lines 20)
printf 'FOREIGN PANE AFTER GUARDED CLEANUP:\n%s\n' "$after"
[ "$before" = "$after" ]
[ "$(fm_backend_herdr_pane_process_identity "$SESSION" "$pane")" = "$new_identity" ]
echo 'PASS: recycled address reads missing; capture/input refused; foreign draft and shell preserved'
echo 'PASS: stable proc identity and both one-second portable start-time offsets accepted'
