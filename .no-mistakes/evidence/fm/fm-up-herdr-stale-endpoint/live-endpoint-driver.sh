#!/usr/bin/env bash
# Real Firstmate adapter + real Herdr, disposable task records; no mocked responses.
set -eu
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M65NDEZRAT81MFEX2NMZGR4B
export TMPDIR="$ROOT/.test-live/tmp" FM_HERDR_LAB_STATE_DIR="$ROOT/.test-live/lab-state" TREEHOUSE_ROOT="$ROOT/.test-live/treehouse"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
LAB=$(mktemp -d "$ROOT/.test-live/endpoint.XXXXXX")
export LAB ROOT REAL_PATH=$PATH REAL_HERDR=$(command -v herdr)
export LAB_HELPER="$ROOT/bin/fm-herdr-lab.sh"
export LAB_SESSION=$("$LAB_HELPER" name endpoints)
cleanup() {
  env PATH="$REAL_PATH" "$LAB_HELPER" teardown "$LAB_SESSION" || return 1
  rm -rf "$LAB"
  echo 'TEARDOWN: named lab deleted; default-session tripwire unchanged; disposable home removed'
}
trap cleanup EXIT
"$ROOT/bin/fm-lab-home.sh" create "$LAB"
export FM_HOME="$LAB"
mkdir -p "$LAB/bin" "$LAB/wt" "$LAB/no-proc"
cat > "$LAB/bin/herdr" <<'SH'
#!/usr/bin/env bash
set -eu
printf '%q ' "$@" >> "$LAB/operations.log"; printf '\n' >> "$LAB/operations.log"
args=("$@")
n=${#args[@]}
if [ "$n" -ge 2 ] && [ "${args[n-2]}" = --session ] && [ "${args[n-1]}" = "$LAB_SESSION" ]; then
  unset 'args[n-1]' 'args[n-2]'
fi
if [ "${args[0]:-}" = --version ]; then
  exec env PATH="$REAL_PATH" "$REAL_HERDR" --version --session "$LAB_SESSION"
fi
out=$(env PATH="$REAL_PATH" "$LAB_HELPER" run "$LAB_SESSION" "${args[@]}") || { r=$?; printf '%s\n' "$out"; exit "$r"; }
if [ -f "$LAB/stop-after-read" ] && [ "${args[0]:-} ${args[1]:-}" = 'pane read' ]; then
  rm "$LAB/stop-after-read"
  env PATH="$REAL_PATH" "$LAB_HELPER" stop "$LAB_SESSION" >/dev/null
  echo 'FAULT: real named server stopped after viewport capture' >> "$LAB/fault.log"
fi
if [ -f "$LAB/stop-after-status" ] && [ "${args[0]:-}" = status ]; then
  read -r n < "$LAB/stop-after-status"
  n=$((n - 1))
  if [ "$n" = 0 ]; then
    rm "$LAB/stop-after-status"
    env PATH="$REAL_PATH" "$LAB_HELPER" stop "$LAB_SESSION" >/dev/null
    echo 'FAULT: real named server stopped before native status lookup' >> "$LAB/fault.log"
  else
    printf '%s\n' "$n" > "$LAB/stop-after-status"
  fi
fi
printf '%s\n' "$out"
SH
chmod +x "$LAB/bin/herdr"
export PATH="$LAB/bin:$REAL_PATH"
lab() { env PATH="$REAL_PATH" "$LAB_HELPER" run "$LAB_SESSION" "$@"; }
provision() { env PATH="$REAL_PATH" "$LAB_HELPER" provision "$LAB_SESSION"; }
provision
lab status --json
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
write_meta() {
  local task=$1 ident=$2
  printf 'backend=herdr\nwindow=%s:%s\nendpoint_task_id=%s\nworktree=%s/wt\nproject=%s/wt\nkind=scout\nharness=claude\nherdr_session=%s\nherdr_workspace_id=w1\nherdr_tab_id=w1:t1\nherdr_pane_id=%s\nherdr_process_identity=%s\n' \
    "$LAB_SESSION" "$PANE" "$task" "$LAB" "$LAB" "$LAB_SESSION" "$PANE" "$ident" > "$LAB/state/$task.meta"
}
created=$(lab workspace create --label firstmate --no-focus)
printf '%s\n' "$created"
PANE=$(printf '%s' "$created" | jq -r .result.root_pane.pane_id)
TARGET="$LAB_SESSION:$PANE"
lab tab rename w1:t1 fm-mine >/dev/null
lab pane run "$PANE" "cd '$LAB/wt'; printf 'OWNED-ENDPOINT\\n'" >/dev/null
sleep 0.3
IDENT=$(fm_backend_herdr_pane_process_identity "$LAB_SESSION" "$PANE")
write_meta mine "$IDENT"
echo "BOUND: $TARGET $IDENT"
fm_backend_capture herdr "$TARGET" 15 fm-mine
fm_backend_send_key herdr "$TARGET" Escape fm-mine
PID=$(fm_backend_herdr_pane_shell_pid "$LAB_SESSION" "$PANE")
START=$(fm_backend_herdr_ps_lstart "$PID")
DRIFT=$(python3 - "$START" <<'PY'
import datetime,sys
print((datetime.datetime.strptime(sys.argv[1],'%a %b %d %H:%M:%S %Y')-datetime.timedelta(seconds=1)).strftime('%a %b %d %H:%M:%S %Y'))
PY
)
write_meta mine "ps:$PID:$DRIFT"
fm_backend_capture herdr "$TARGET" 5 fm-mine >/dev/null
printf 'PORTABLE DRIFT: recorded=%s; current=%s; capture accepted\n' "$DRIFT" "$START"
FALLBACK=$(FM_PROC_ROOT_OVERRIDE="$LAB/no-proc" fm_backend_herdr_pane_process_identity "$LAB_SESSION" "$PANE")
echo "PORTABLE FALLBACK without /proc: $FALLBACK"
[[ "$FALLBACK" = ps:* ]]
write_meta mine "$IDENT"
state=$(FM_PROC_ROOT_OVERRIDE="$LAB/no-proc" fm_backend_agent_state herdr "$TARGET" fm-mine)
echo "Unreadable proc binding: $state"
[ "$state" = unreadable ]
if FM_PROC_ROOT_OVERRIDE="$LAB/no-proc" fm_backend_capture herdr "$TARGET" 5 fm-mine; then exit 31; fi
echo 'PASS: stable and portable identity checks execute against a real pane'

# Delete only the lab session through the helper, then reuse the same name:
# this discards saved ids while leaving the task record intact.
env PATH="$REAL_PATH" "$LAB_HELPER" teardown "$LAB_SESSION"
provision
new=$(lab workspace create --label firstmate --no-focus)
NEWPANE=$(printf '%s' "$new" | jq -r .result.root_pane.pane_id)
[ "$NEWPANE" = "$PANE" ]
lab tab rename w1:t1 fm-mine >/dev/null
lab pane run "$PANE" "cd '$LAB/wt'; printf 'FOREIGN-DO-NOT-TOUCH\\n'" >/dev/null
sleep 0.3
NEWIDENT=$(fm_backend_herdr_pane_process_identity "$LAB_SESSION" "$PANE")
printf 'RESET: recycled=%s; old=%s; new=%s\n' "$TARGET" "$IDENT" "$NEWIDENT"
[ "$NEWIDENT" != "$IDENT" ]
write_meta other "$NEWIDENT"
state=$(fm_backend_agent_state herdr "$TARGET" fm-mine)
echo "STALE TASK LIVENESS despite matching cwd, label, and competing bound claimant: $state"
[ "$state" = missing ]
for op in capture visible key submit; do
  case "$op" in
    capture) if fm_backend_capture herdr "$TARGET" 5 fm-mine; then exit 32; fi ;;
    visible) if fm_backend_visible_capture herdr "$TARGET" fm-mine; then exit 33; fi ;;
    key) if fm_backend_send_key herdr "$TARGET" C-c fm-mine; then exit 34; fi ;;
    submit) if fm_backend_send_text_submit herdr "$TARGET" "touch '$LAB/foreign-hit'" 1 0 0 fm-mine; then exit 35; fi ;;
  esac
  echo "STALE $op: refused"
done
out=$("$ROOT/bin/fm-teardown.sh" mine --force 2>&1) && { echo "$out"; exit 36; }
printf '%s\n' "$out"
[ -f "$LAB/state/mine.meta" ] && [ -d "$LAB/wt" ] && [ ! -e "$LAB/foreign-hit" ]
lab pane get "$PANE"
[ "$(fm_backend_herdr_pane_process_identity "$LAB_SESSION" "$PANE")" = "$NEWIDENT" ]
echo 'PASS: foreign pane, its process, worktree and durable task record survived active cleanup'

# Portable no-identity legacy husk replacement: real create and close, not a canned CLI.
rm "$LAB/state/other.meta"
write_meta mine "$NEWIDENT"
python3 - "$LAB/state/mine.meta" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read();open(p,'w').write(''.join(x for x in s.splitlines(True) if not x.startswith('herdr_process_identity=')))
PY
# Add a non-target focused tab, so the exact close is focus-safe.
anchor=$(lab tab create --workspace w1 --label anchor --cwd "$LAB" --focus)
printf '%s\n' "$anchor"
REPLACEMENT=$(fm_backend_herdr_create_task "$LAB_SESSION:w1" fm-mine "$LAB/wt" '')
echo "LEGACY HUSK REPLACEMENT: $REPLACEMENT"
[ -n "$REPLACEMENT" ]
if lab pane get "$PANE"; then exit 37; fi
NEWPANE=${REPLACEMENT##* }
lab pane get "$NEWPANE"
echo 'PASS: legacy no-agent husk replaced without closing the new endpoint'

# Real stopped-server checks, including a stop between readiness and native status.
PANE=$NEWPANE; TARGET="$LAB_SESSION:$PANE"
NEWIDENT=$(fm_backend_herdr_pane_process_identity "$LAB_SESSION" "$PANE")
write_meta mine "$NEWIDENT"
: > "$LAB/operations.log"
printf '2\n' > "$LAB/stop-after-status"
state=$(fm_backend_busy_state herdr "$TARGET" fm-mine)
echo "PASSIVE BUSY after mid-probe stop: $state"
[ "$state" = unknown ]
[ "$(lab status --json | jq -r .server.running)" = false ]
if grep -q '^server ' "$LAB/operations.log"; then exit 38; fi
printf 'PASSIVE COMPOSER stopped: %s\n' "$(fm_backend_composer_state herdr "$TARGET" fm-mine)"
if fm_backend_visible_capture herdr "$TARGET" fm-mine; then exit 39; fi
printf 'FAULT DETAILS: '; cat "$LAB/fault.log"
echo 'PASS: passive busy, composer and viewport left the stopped server stopped'
