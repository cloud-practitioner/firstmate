#!/usr/bin/env bash
# Run from the exact gate worktree. All runtime files stay beneath .v/.
set -eu
ROOT=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M4X6RD5MP249BGX9S29RM3DF
: > "$EVIDENCE/live-herdr-calls.log"
ORIGINAL_PATH=$PATH
REAL_HERDR=$(command -v herdr)
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION FM_HOME FM_BACKEND FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_PROC_ROOT_OVERRIDE
# Link only the default socket for the helper's read-only before/after tripwire.
# Named-session state and all logs/config remain in the disposable worktree.
mkdir -p "$ROOT/.v/herdr"
if [ ! -L "$ROOT/.v/herdr/herdr.sock" ]; then
  DEFAULT_SOCKET=$(env -u XDG_CONFIG_HOME PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" run fm-lab-e session list --json | jq -er '.sessions[] | select(.default == true and .running == true) | .socket_path')
  ln -s "$DEFAULT_SOCKET" "$ROOT/.v/herdr/herdr.sock"
fi
export XDG_CONFIG_HOME=.v
export FM_HERDR_LAB_STATE_DIR="$ROOT/.v/lab-state"
export TMPDIR="$ROOT/.v/tmp" TREEHOUSE_ROOT="$ROOT/.v/pool"
mkdir -p "$TMPDIR" "$TREEHOUSE_ROOT" "$ROOT/.v/bridge"
# Short physical session directory keeps absolute AF_UNIX paths below 108 bytes.
mkdir -p "$ROOT/s"
[ -L "$ROOT/.v/herdr/sessions" ] || ln -s "$ROOT/s" "$ROOT/.v/herdr/sessions"
SESSION=fm-lab-e
export SESSION ROOT ORIGINAL_PATH REAL_HERDR EVIDENCE
LAB=$(mktemp -d "$ROOT/.v/fm-lab.XXXXXX")
bin/fm-lab-home.sh create "$LAB"
export FM_HOME=$LAB
lab(){ env PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" "$@"; }
cleanup(){
  local rc=$?
  trap - EXIT
  lab teardown "$SESSION" || rc=1
  chmod -R u+w "$LAB"
  rm -rf "$LAB" "$ROOT/.v/bridge" "$ROOT/.v/pool"
  printf 'cleanup exit=%s; named lab removed; default-session tripwire verified\n' "$rc"
  exit "$rc"
}
trap cleanup EXIT
# provision owns prepare for a new session; do not prepare twice.
lab provision "$SESSION"
cat > "$ROOT/.v/bridge/herdr" <<'SH'
#!/usr/bin/env bash
set -eu
cd "$ROOT"
if [ "${1:-}" = --version ]; then exec "$REAL_HERDR" --version; fi
args=(); requested=${HERDR_SESSION:-}; skip=0
for arg in "$@"; do
  if [ "$skip" = 1 ]; then requested=$arg; skip=0; continue; fi
  if [ "$arg" = --session ]; then skip=1; continue; fi
  args+=("$arg")
done
[ "$requested" = "$SESSION" ] || { echo 'bridge refused a non-lab session' >&2; exit 2; }
printf '%q ' "${args[@]}" >> "$EVIDENCE/live-herdr-calls.log"; printf '\n' >> "$EVIDENCE/live-herdr-calls.log"
if [ -n "${LIVE_STREAM_READY:-}" ] && [ "${args[0]:-} ${args[1]:-}" = 'agent get' ]; then
  out=$(env PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}")
  touch "$LIVE_STREAM_READY"
  printf '%s\n' "$out"; exit 0
fi
if [ "${args[0]:-}" = server ]; then
  printf 'SERVER_START_REQUEST\n' >> "$EVIDENCE/live-herdr-calls.log"
  exec env PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" provision "$SESSION"
fi
if [ -f "$ROOT/.v/race-kind" ]; then
  kind=$(< "$ROOT/.v/race-kind")
  if [ "$kind" = composer ] && [ "${args[0]:-} ${args[1]:-}" = 'pane read' ]; then
    out=$(env PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}")
    rm "$ROOT/.v/race-kind"
    env PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" stop "$SESSION" >/dev/null
    printf 'RACE_STOP after viewport, before lazy identity read\n' >> "$EVIDENCE/live-herdr-calls.log"
    printf '%s\n' "$out"; exit 0
  fi
  if [ "$kind" = busy ] && [ "${args[0]:-} ${args[1]:-}" = 'pane process-info' ]; then
    n=0; [ ! -f "$ROOT/.v/race-count" ] || n=$(< "$ROOT/.v/race-count")
    n=$((n+1)); printf '%s\n' "$n" > "$ROOT/.v/race-count"
    if [ "$n" -eq 2 ]; then
      out=$(env PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}")
      rm "$ROOT/.v/race-kind"
      env PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" stop "$SESSION" >/dev/null
      printf 'RACE_STOP after second ownership process read\n' >> "$EVIDENCE/live-herdr-calls.log"
      printf '%s\n' "$out"; exit 0
    fi
  fi
fi
if [ "${args[0]:-} ${args[1]:-}" = 'session list' ]; then
  env PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}" | python3 -c 'import json,os,sys; x=json.load(sys.stdin); [(s.update(socket_path=os.path.realpath(s["socket_path"]))) for s in x["sessions"] if not s.get("default")]; print(json.dumps(x))'
else
  exec env PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}"
fi
SH
chmod +x "$ROOT/.v/bridge/herdr"
export PATH="$ROOT/.v/bridge:$PATH" HERDR_SESSION=$SESSION
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
fail(){ printf 'FAIL: %s\n' "$*"; exit 1; }
expect_refusal(){ local rc=0; "$@" || rc=$?; printf 'operation=%s rc=%s\n' "$1" "$rc"; [ "$rc" -ne 0 ] || fail "unexpected acceptance: $*"; }
meta(){
  local home=$1 id=$2 identity=$3
  mkdir -p "$home/state"
  printf 'backend=herdr\nendpoint_task_id=%s\nwindow=%s:w1:p1\nherdr_session=%s\nherdr_workspace_id=w1\nherdr_tab_id=w1:t1\nherdr_pane_id=w1:p1\nworktree=%s\nproject=%s\nharness=claude\nkind=scout\nherdr_process_identity=%s\n' "$id" "$SESSION" "$SESSION" "$ROOT" "$ROOT" "$identity" > "$home/state/$id.meta"
}
create_first(){
  lab run "$SESSION" workspace create --label firstmate --cwd "$ROOT"
  lab run "$SESSION" tab rename w1:t1 fm-a
  lab run "$SESSION" pane process-info --pane w1:p1
}
create_first
TARGET="$SESSION:w1:p1"
OLD=$(fm_backend_herdr_pane_process_identity "$SESSION" w1:p1)
meta "$LAB" a "$OLD"
printf 'original target=%s identity=%s\n' "$TARGET" "$OLD"
fm_backend_target_exists herdr "$TARGET" fm-a || fail 'owned pane missing'
fm_backend_capture herdr "$TARGET" 5 fm-a
[ "$(fm_backend_agent_state herdr "$TARGET" fm-a)" = dead ] || fail 'owned shell was not dead/adoptable'
# Exercise the portable fallback against a real live pane and real ps reads.
PID=$(fm_backend_herdr_pane_shell_pid "$SESSION" w1:p1)
START=$(fm_backend_herdr_ps_lstart "$PID")
PORTABLE=$(FM_PROC_ROOT_OVERRIDE="$LAB/no-proc" fm_backend_herdr_pane_process_identity "$SESSION" w1:p1)
printf 'actual portable fallback with unavailable proc=%s\n' "$PORTABLE"
case "$PORTABLE" in "ps:$PID:"*) ;; *) fail 'real ps fallback failed';; esac
DRIFT=$(python3 - "$START" <<'PY'
import datetime,sys
x=datetime.datetime.strptime(sys.argv[1],'%a %b %d %H:%M:%S %Y')+datetime.timedelta(seconds=1)
print(x.strftime('%a %b %d %H:%M:%S %Y'))
PY
)
meta "$LAB" a "ps:$PID:$DRIFT"
fm_backend_target_exists herdr "$TARGET" fm-a || fail 'one-second ps drift rejected'
printf 'portable identity accepted: pid=%s ps=%s recorded=%s\n' "$PID" "$START" "$DRIFT"
meta "$LAB" a "$OLD"
printf '\nSCENARIO reset: destroy session state, keep durable task metadata, reuse address and label/cwd\n'
lab teardown "$SESSION"
lab provision "$SESSION"
create_first
NEW=$(fm_backend_herdr_pane_process_identity "$SESSION" w1:p1)
printf 'recycled target=%s old=%s new=%s\n' "$TARGET" "$OLD" "$NEW"
[ "$OLD" != "$NEW" ] || fail 'reset preserved root process unexpectedly'
STATE_NOW=$(fm_backend_agent_state herdr "$TARGET" fm-a)
printf 'selected old task recovery state=%s\n' "$STATE_NOW"
[ "$STATE_NOW" = missing ] || fail 'recycled address was adopted'
expect_refusal fm_backend_target_exists herdr "$TARGET" fm-a
[ "$(fm_backend_herdr_endpoint_absence_recheck "$TARGET" fm-a)" = missing ] || fail 'recovery recheck accepted recycled address'
# A second home really owns the replacement. Explicit task/home selection must win.
OTHER="$LAB/other-home"; meta "$OTHER" b "$NEW"
FM_HOME="$OTHER" fm_backend_target_exists herdr "$TARGET" fm-b || fail 'replacement not readable in its owning home'
lab run "$SESSION" pane send-text w1:p1 "touch '$LAB/forbidden-input'"
sleep 0.5
BEFORE=$(lab run "$SESSION" pane read w1:p1 --source visible)
expect_refusal fm_backend_capture herdr "$TARGET" 20 fm-a
expect_refusal fm_backend_visible_capture herdr "$TARGET" fm-a
expect_refusal fm_backend_send_key herdr "$TARGET" Enter fm-a
expect_refusal fm_backend_send_text_submit herdr "$TARGET" 'foreign text' 1 0.1 0 fm-a
expect_refusal env FM_HOME="$LAB" "$ROOT/bin/fm-send.sh" a --key Enter
fm_backend_kill herdr "$TARGET" '' fm-a || true
AFTER=$(lab run "$SESSION" pane read w1:p1 --source visible)
[ "$BEFORE" = "$AFTER" ] || fail 'foreign draft changed'
[ ! -e "$LAB/forbidden-input" ] || fail 'foreign draft executed'
[ "$(fm_backend_herdr_pane_process_identity "$SESSION" w1:p1)" = "$NEW" ] || fail 'foreign pane closed/replaced'
printf 'foreign draft unchanged and unexecuted; replacement identity preserved\n%s\n' "$AFTER"
FM_HOME="$OTHER" fm_backend_capture herdr "$TARGET" 5 fm-b
printf '\nSCENARIO push: stale paused claimant sorts before the bound blocked task\n'
meta "$LAB" b "$NEW"
printf 'paused: waiting on an upstream release\n' > "$LAB/state/a.status"
printf 'blocked: approval needed\n' > "$LAB/state/b.status"
. "$ROOT/bin/fm-push-transition-lib.sh"
lab run "$SESSION" pane report-agent w1:p1 --source fm-lab-validation --agent claude --state blocked
# Real reconnect-level read and production transition handler (wake exits).
RECORD=$(fm_backend_herdr_wait_transition "$SESSION" 1 "$LAB/state" "$TARGET")
printf 'accepted transition=%s\n' "$RECORD"
(handle_push_transition herdr "$SESSION" "$RECORD")
MARKER=$(fm_backend_herdr_escalation_marker "$LAB/state" "$TARGET")
[ -f "$MARKER" ] || fail 'dedupe not committed'
[ "$(hb_surfaced_offset b)" = "$(wc -c < "$LAB/state/b.status" | tr -d ' ')" ] || fail 'bound status not surfaced'
[ ! -e "$(_hb_surfaced_path a)" ] || fail 'stale status marked surfaced'
printf 'wake queue:\n'; while IFS= read -r line; do printf '%s\n' "$line"; done < "$LAB/state/.wake-queue"
printf 'bound status offset=%s; stale status marker absent\n' "$(hb_surfaced_offset b)"
printf '\nSCENARIO streamed push: subscribed idle pane later becomes blocked\n'
fm_backend_herdr_clear_transition "$LAB/state" "$TARGET"
lab run "$SESSION" pane report-agent w1:p1 --source fm-lab-validation --agent claude --state idle
LIVE_STREAM_READY="$LAB/stream-ready" fm_backend_herdr_wait_transition "$SESSION" 5 "$LAB/state" "$TARGET" > "$LAB/stream-record" &
WAITER=$!
for ((i=0;i<100;i++)); do [ ! -f "$LAB/stream-ready" ] || break; sleep 0.05; done
[ -f "$LAB/stream-ready" ] || fail 'real event reader did not subscribe and reconcile idle'
lab run "$SESSION" pane report-agent w1:p1 --source fm-lab-validation --agent claude --state blocked
wait "$WAITER" || fail 'real blocked edge not delivered'
RECORD=$(< "$LAB/stream-record")
printf 'streamed transition=%s\n' "$RECORD"
[ "$(fm_transition_workspace_id "$RECORD")" = w1 ] || fail 'transition did not originate from stream'
printf 'blocked: second approval needed\n' >> "$LAB/state/b.status"
(handle_push_transition herdr "$SESSION" "$RECORD")
[ -f "$MARKER" ] && [ ! -e "$(_hb_surfaced_path a)" ] || fail 'stream marker ownership wrong'
printf 'stream bound status offset=%s; stale status marker absent\n' "$(hb_surfaced_offset b)"
# Remove test registration and restore baseline shell composer.
lab run "$SESSION" pane send-keys w1:p1 ctrl+u
printf '\nSCENARIO legacy husk: close-and-replace an identity-free dead pane\n'
LEGACY=$(fm_backend_herdr_create_task "$SESSION:w1" fm-legacy "$ROOT")
read -r LEGACY_TAB LEGACY_PANE <<< "$LEGACY"
printf 'legacy pane=%s\n' "$LEGACY_PANE"
printf 'backend=herdr\nwindow=%s:%s\nworktree=%s\n' "$SESSION" "$LEGACY_PANE" "$ROOT" > "$LAB/state/legacy.meta"
REPLACEMENT=$(fm_backend_herdr_create_task "$SESSION:w1" fm-legacy "$ROOT")
read -r REPLACEMENT_TAB REPLACEMENT_PANE <<< "$REPLACEMENT"
printf 'replacement pane=%s\n' "$REPLACEMENT_PANE"
[ "$LEGACY_PANE" != "$REPLACEMENT_PANE" ] || fail 'husk not replaced'
lab run "$SESSION" pane get "$REPLACEMENT_PANE"
printf '\nSCENARIO spawn/relaunch: real custom shell worker publishes its pane root identity\n'
PROJECT="$LAB/project"
mkdir -p "$PROJECT"
git -C "$PROJECT" init -q -b main
printf '# Disposable endpoint publication project\n' > "$PROJECT/README.md"
git -C "$PROJECT" add README.md
git -C "$PROJECT" -c user.name=Validation -c user.email=validation@example.invalid commit -qm initial
git clone -q --bare "$PROJECT" "$LAB/origin.git"
git -C "$PROJECT" remote add origin "$LAB/origin.git"
"$ROOT/bin/fm-brief.sh" spawned project --scout --herdr-lab
python3 - "$LAB/data/spawned/brief.md" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); p.write_text(p.read_text().replace('{TASK}','Validate stable endpoint publication in a disposable lab.').replace('{FIRSTMATE_SPEC}','This custom shell worker has no project work to perform.'))
PY
printf 'off\n' > "$LAB/config/herdr-presentation-spaces"
timeout 90 "$ROOT/bin/fm-spawn.sh" spawned "$PROJECT" "sh -c 'while :; do sleep 60; done'" --scout --backend herdr
SPAWN_META="$LAB/state/spawned.meta"
SPAWN_TARGET=$(fm_backend_herdr_meta_value "$SPAWN_META" window)
SPAWN_PANE=${SPAWN_TARGET#*:}
SPAWN_IDENTITY=$(fm_backend_herdr_meta_value "$SPAWN_META" herdr_process_identity)
printf 'fresh target=%s published=%s live=%s\n' "$SPAWN_TARGET" "$SPAWN_IDENTITY" "$(fm_backend_herdr_pane_process_identity "$SESSION" "$SPAWN_PANE")"
[ -n "$SPAWN_IDENTITY" ] && [ "$SPAWN_IDENTITY" = "$(fm_backend_herdr_pane_process_identity "$SESSION" "$SPAWN_PANE")" ] || fail 'fresh spawn binding wrong'
# Explicitly discard only this throwaway endpoint, not its worktree or metadata.
lab run "$SESSION" pane close "$SPAWN_PANE"
sleep 0.3
timeout 90 "$ROOT/bin/fm-spawn.sh" spawned --relaunch --harness "sh -c 'while :; do sleep 60; done'"
REBOUND_TARGET=$(fm_backend_herdr_meta_value "$SPAWN_META" window)
REBOUND_IDENTITY=$(fm_backend_herdr_meta_value "$SPAWN_META" herdr_process_identity)
printf 'rebound target=%s published=%s live=%s\n' "$REBOUND_TARGET" "$REBOUND_IDENTITY" "$(fm_backend_herdr_pane_process_identity "$SESSION" "${REBOUND_TARGET#*:}")"
[ "$REBOUND_IDENTITY" != "$SPAWN_IDENTITY" ] && [ "$REBOUND_IDENTITY" = "$(fm_backend_herdr_pane_process_identity "$SESSION" "${REBOUND_TARGET#*:}")" ] || fail 'relaunch did not refresh binding'
printf '\nSCENARIO teardown: foreign process in recorded worktree blocks destructive cleanup\n'
WT="$LAB/cleanup-worktree"
git -C "$PROJECT" worktree add -q -b disposable-cleanup "$WT"
CLEAN_IDS=$(fm_backend_herdr_create_task "$SESSION:w1" fm-cleanup "$WT")
read -r CLEAN_TAB CLEAN_PANE <<< "$CLEAN_IDS"
CLEAN_IDENTITY=$(fm_backend_herdr_pane_process_identity "$SESSION" "$CLEAN_PANE")
printf 'backend=herdr\nendpoint_task_id=cleanup\nwindow=%s:%s\nherdr_session=%s\nherdr_workspace_id=w1\nherdr_tab_id=%s\nherdr_pane_id=%s\nworktree=%s\nproject=%s\nharness=sh\nkind=ship\nmode=local-only\nyolo=off\nherdr_process_identity=%s\n' "$SESSION" "$CLEAN_PANE" "$SESSION" "$CLEAN_TAB" "$CLEAN_PANE" "$WT" "$PROJECT" "$OLD" > "$LAB/state/cleanup.meta"
printf 'keep this unlanded file\n' > "$WT/unlanded.txt"
expect_refusal "$ROOT/bin/fm-teardown.sh" cleanup --force
[ -f "$WT/unlanded.txt" ] && [ -f "$LAB/state/cleanup.meta" ] || fail 'teardown erased foreign worktree or task record'
[ "$(fm_backend_herdr_pane_process_identity "$SESSION" "$CLEAN_PANE")" = "$CLEAN_IDENTITY" ] || fail 'teardown killed foreign process'
printf 'foreign pane=%s identity=%s; unlanded file and task metadata retained\n' "$CLEAN_PANE" "$CLEAN_IDENTITY"
printf '\nSCENARIO busy probe race: stop server after the running/ownership checks, before native status\n'
printf 'busy\n' > "$ROOT/.v/race-kind"
rm -f "$ROOT/.v/race-count"
VALUE=$(fm_backend_busy_state herdr "$TARGET" fm-b)
printf 'busy after stop-before-native-status=%s\n' "$VALUE"
[ "$VALUE" = unknown ] && [ ! -e "$ROOT/.v/race-kind" ] || fail 'busy race did not execute or returned native state'
[ "$(lab run "$SESSION" status --json | jq -r '.server.running')" = false ] || fail 'busy status race restarted server'
printf '\nSCENARIO passive probes: stopped server remains stopped\n'
for probe in composer busy; do
  value=$("fm_backend_${probe}_state" herdr "$TARGET" fm-b)
  printf '%s=%s\n' "$probe" "$value"
  [ "$value" = unknown ] || fail "stopped $probe probe borrowed state"
done
expect_refusal fm_backend_visible_capture herdr "$TARGET" fm-b
[ "$(lab run "$SESSION" status --json | jq -r '.server.running')" = false ] || fail 'passive probe restarted server'
printf 'server.running=false after all passive probes\n'
printf '\nSCENARIO composer race: Pi-shaped terminal fixture, stop after viewport capture\n'
lab provision "$SESSION"
CURRENT=$(fm_backend_herdr_pane_process_identity "$SESSION" w1:p1)
meta "$LAB" b "$CURRENT"
lab run "$SESSION" pane send-keys w1:p1 ctrl+u
lab run "$SESSION" pane send-text w1:p1 "printf '\\033[2J\\033[Htranscript\\n─────────────────────────────────────────────────────\\n\\n─────────────────────────────────────────────────────\\n'; sleep 120"
lab run "$SESSION" pane send-keys w1:p1 enter
lab run "$SESSION" pane report-agent w1:p1 --source fm-lab-validation --agent pi --state idle
sleep 0.5
BASELINE=$(fm_backend_composer_state herdr "$TARGET" fm-b)
printf 'composer fixture baseline=%s\n' "$BASELINE"
[ "$BASELINE" = empty ] || fail 'Pi-shaped fixture did not reach lazy identity baseline'
printf 'composer\n' > "$ROOT/.v/race-kind"
VALUE=$(fm_backend_composer_state herdr "$TARGET" fm-b)
printf 'composer after stop-after-viewport=%s\n' "$VALUE"
[ "$VALUE" = unknown ] && [ ! -e "$ROOT/.v/race-kind" ] || fail 'composer race did not execute or reused captured state'
[ "$(lab run "$SESSION" status --json | jq -r '.server.running')" = false ] || fail 'composer lazy read restarted server'
printf 'server.running=false after lazy composer identity read\n'
printf '\nALL CORE LIVE SCENARIOS PASSED\n'
