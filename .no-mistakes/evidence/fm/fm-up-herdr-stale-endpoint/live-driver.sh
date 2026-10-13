#!/usr/bin/env bash
set -eu
ROOT=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M4VCZ5SABZQ0DS1NRJYTK9W3
SCRATCH=$(mktemp -d "$ROOT/.test-live.XXXXXX")
ORIGINAL_PATH=$PATH
REAL_HERDR=$(command -v herdr)
HELPER=$ROOT/bin/fm-herdr-lab.sh
SESSION=$($HELPER name ownership)
export ROOT EVIDENCE SCRATCH ORIGINAL_PATH REAL_HERDR HELPER SESSION
mkdir -p "$SCRATCH/xdg/herdr" "$SCRATCH/tmp" "$SCRATCH/tools" "$SCRATCH/owned" "$SCRATCH/other"
$HELPER run "$SESSION" session list --json | jq -c '[.sessions[] | select(.default == true)]' > "$EVIDENCE/default-before.json"
DEFAULT_SOCKET=$(jq -r '.[0].socket_path' "$EVIDENCE/default-before.json")
# This alias only lets the helper observe the real default for its read-only
# tripwire. All named session files, config, homes and logs are worktree-local.
ln -s "$DEFAULT_SOCKET" "$SCRATCH/xdg/herdr/herdr.sock"
exec 9<"$SCRATCH/xdg"
export XDG_CONFIG_HOME="/proc/$$/fd/9" TMPDIR="$SCRATCH/tmp" FM_HERDR_LAB_STATE_DIR="$SCRATCH/tripwires"
# Herdr passes its startup environment into new shells, so set these before
# provision, not only around the later spawn subprocess.
export TREEHOUSE_ROOT="$SCRATCH/pool" PI_CODING_AGENT_DIR="$SCRATCH/pi" PI_OFFLINE=1
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE HERDR_ENV HERDR_PANE_ID HERDR_SOCKET_PATH HERDR_TAB_ID HERDR_WORKSPACE_ID FM_GATE_REFUSE_BYPASS
cleanup() {
  set +e
  PATH="$ORIGINAL_PATH" "$HELPER" teardown "$SESSION"
  echo "lab_teardown_exit=$?"
  env -u XDG_CONFIG_HOME PATH="$ORIGINAL_PATH" "$HELPER" run "$SESSION" session list --json | jq -c '[.sessions[] | select(.default == true)]' > "$EVIDENCE/default-after.json"
  cmp "$EVIDENCE/default-before.json" "$EVIDENCE/default-after.json" && echo 'real default tripwire unchanged'
  exec 9<&-
  find "$SCRATCH" -type d -exec chmod u+w {} +
  rm -rf "$SCRATCH"
}
trap cleanup EXIT
lab() { PATH="$ORIGINAL_PATH" "$HELPER" run "$SESSION" "$@"; }
PATH="$ORIGINAL_PATH" "$HELPER" provision "$SESSION"
cat > "$SCRATCH/tools/herdr" <<'SH'
#!/usr/bin/env bash
set -eu
args=("$@")
logical=${HERDR_SESSION:-$SESSION}
last=$((${#args[@]} - 1)); flag=$((last - 1))
if [ "$flag" -ge 0 ] && [ "${args[$flag]}" = --session ]; then
  logical=${args[$last]}; unset 'args[$flag]' 'args[$last]'
fi
[ "$logical" = "$SESSION" ] || [ "$logical" = fm-remote ] || { echo 'refused unexpected session' >&2; exit 1; }
set -- "${args[@]}"
if [ "${1:-}" = --version ]; then exec "$REAL_HERDR" --version; fi
printf '%s\t%s\n' "$logical" "$*" >> "$SCRATCH/calls.log"
if [ -f "$SCRATCH/stop-native" ] && [ "${1:-} ${2:-}" = 'agent get' ]; then
  rm "$SCRATCH/stop-native"
  PATH="$ORIGINAL_PATH" "$HELPER" stop "$SESSION" >/dev/null
  echo 'RACE: real server stopped before native agent lookup' >> "$SCRATCH/races.log"
fi
out=$(PATH="$ORIGINAL_PATH" "$HELPER" run "$SESSION" "$@") || exit $?
if [ -f "$SCRATCH/stop-viewport" ] && [ "${1:-} ${2:-}" = 'pane read' ]; then
  rm "$SCRATCH/stop-viewport"
  PATH="$ORIGINAL_PATH" "$HELPER" stop "$SESSION" >/dev/null
  echo 'RACE: real server stopped after returning real viewport' >> "$SCRATCH/races.log"
fi
printf '%s\n' "$out"
SH
chmod +x "$SCRATCH/tools/herdr"
export PATH="$SCRATCH/tools:$ORIGINAL_PATH" HERDR_SESSION="$SESSION"
bin/fm-lab-home.sh create "$SCRATCH/home" >/dev/null
export FM_HOME="$SCRATCH/home"
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
check() { if ! "$@"; then echo "FAIL: $*" >&2; exit 1; fi; }
fm_write_meta() { local file=$1; shift; printf '%s\n' "$@" > "$file"; }
meta() { # path task pane identity cwd [session]
  fm_write_meta "$1" backend=herdr "window=${6:-$SESSION}:$3" "endpoint_task_id=$2" kind=secondmate harness=pi "worktree=$5" "project=$5" "home=$5" "herdr_session=${6:-$SESSION}" "herdr_workspace_id=${3%%:*}" "herdr_tab_id=${3%%:*}:t1" "herdr_pane_id=$3" "herdr_process_identity=$4"
}
NEW=$(lab workspace create --cwd "$SCRATCH/owned" --label isolated-ownership --no-focus)
PANE=$(printf '%s' "$NEW" | jq -r '.result.root_pane.pane_id')
TAB=$(printf '%s' "$NEW" | jq -r '.result.tab.tab_id')
WS=$(printf '%s' "$NEW" | jq -r '.result.workspace.workspace_id')
lab tab rename "$TAB" fm-mine >/dev/null
IDENTITY=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
meta "$FM_HOME/state/mine.meta" mine "$PANE" "$IDENTITY" "$SCRATCH/owned"
TARGET="$SESSION:$PANE"
echo '=== stable owning-shell identity and portable drift ==='
echo "initial_target=$TARGET initial_identity=$IDENTITY"
for i in 1 2 3 4 5; do CUR=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE"); echo "identity_sample_$i=$CUR"; check test "$CUR" = "$IDENTITY"; sleep 0.2; done
PID=$(fm_backend_herdr_pane_shell_pid "$SESSION" "$PANE")
LSTART=$(fm_backend_herdr_ps_lstart "$PID")
for DELTA in -1 1 3; do
  SHIFT=$(python3 - "$LSTART" "$DELTA" <<'PY'
import datetime,sys
print((datetime.datetime.strptime(sys.argv[1],'%a %b %d %H:%M:%S %Y')+datetime.timedelta(seconds=int(sys.argv[2]))).strftime('%a %b %d %H:%M:%S %Y'))
PY
)
  meta "$FM_HOME/state/mine.meta" mine "$PANE" "ps:$PID:$SHIFT" "$SCRATCH/owned"
  if fm_backend_target_exists herdr "$TARGET" fm-mine; then EXISTS=yes; else EXISTS=no; fi
  echo "recorded_ps_offset=$DELTA exists=$EXISTS"
  if [ "$DELTA" = 3 ]; then check test "$EXISTS" = no; else check test "$EXISTS" = yes; fi
done
meta "$FM_HOME/state/mine.meta" mine "$PANE" "$IDENTITY" "$SCRATCH/owned"
STATE_UNREADABLE=$(FM_PROC_ROOT_OVERRIDE="$SCRATCH/unavailable-proc" fm_backend_agent_state herdr "$TARGET" fm-mine)
echo "unavailable_proc_liveness=$STATE_UNREADABLE"; check test "$STATE_UNREADABLE" = unreadable
# Destroy only the owned lab session, losing its real saved state, then reuse
# the same name with fresh server counters while durable Firstmate state survives.
PATH="$ORIGINAL_PATH" "$HELPER" teardown "$SESSION"
PATH="$ORIGINAL_PATH" "$HELPER" provision "$SESSION"
NEW=$(lab workspace create --cwd "$SCRATCH/owned" --label isolated-ownership --no-focus)
NEW_PANE=$(printf '%s' "$NEW" | jq -r '.result.root_pane.pane_id')
NEW_TAB=$(printf '%s' "$NEW" | jq -r '.result.tab.tab_id')
lab tab rename "$NEW_TAB" fm-mine >/dev/null
NEW_ID=$(fm_backend_herdr_pane_process_identity "$SESSION" "$NEW_PANE")
echo '=== session reset: same id, label and cwd but a different process ==='
echo "old_pane=$PANE recycled_pane=$NEW_PANE old_identity=$IDENTITY current_identity=$NEW_ID"
check test "$PANE" = "$NEW_PANE"; check test "$IDENTITY" != "$NEW_ID"
STATE_NOW=$(fm_backend_agent_state herdr "$TARGET" fm-mine)
echo "recorded_task_liveness=$STATE_NOW"; check test "$STATE_NOW" = missing
if fm_backend_capture herdr "$TARGET" 20 fm-mine; then echo 'FAIL foreign capture succeeded'; exit 1; else echo 'foreign capture refused'; fi
if fm_backend_send_text_submit herdr "$TARGET" "printf FOREIGN_INPUT > '$SCRATCH/foreign-written'" 0 0 0 fm-mine; then echo 'FAIL foreign submit succeeded'; exit 1; else echo 'foreign submit refused'; fi
if fm_backend_send_key herdr "$TARGET" Enter fm-mine; then echo 'FAIL foreign key succeeded'; exit 1; else echo 'foreign key refused'; fi
fm_backend_kill herdr "$TARGET" '' fm-mine
echo 'guarded cleanup completed without closing the unrelated pane'
lab pane get "$PANE"
check test ! -e "$SCRATCH/foreign-written"
echo "recovery_recheck=$(fm_backend_herdr_endpoint_absence_recheck "$TARGET" fm-mine)"
mkdir -p "$SCRATCH/child/state"
meta "$SCRATCH/child/state/mine.meta" mine "$PANE" "$NEW_ID" "$SCRATCH/owned"
CHILD_STATE=$(FM_STATE_OVERRIDE="$SCRATCH/child/state" fm_backend_agent_state herdr "$TARGET" fm-mine)
echo "owning_child_home_liveness=$CHILD_STATE"; check test "$CHILD_STATE" = dead
FM_STATE_OVERRIDE="$SCRATCH/child/state" fm_backend_capture herdr "$TARGET" 20 fm-mine >/dev/null
# Old compatibility records have no process field. Best effort same-label
# husk replacement must create first, remove only the old pane and retain new.
echo '=== legacy dead husk replacement ==='
LEGACY=$(lab tab create --workspace "$WS" --cwd "$SCRATCH/other" --label fm-legacy --no-focus)
LEGACY_PANE=$(printf '%s' "$LEGACY" | jq -r '.result.root_pane.pane_id')
LEGACY_TAB=$(printf '%s' "$LEGACY" | jq -r '.result.tab.tab_id')
fm_write_meta "$FM_HOME/state/legacy.meta" backend=herdr "window=$SESSION:$LEGACY_PANE" "worktree=$SCRATCH/other"
REPLACEMENT=$(fm_backend_herdr_create_task "$SESSION:$WS" fm-legacy "$SCRATCH/other" '')
read -r REPLACEMENT_TAB REPLACEMENT_PANE <<< "$REPLACEMENT"
echo "old_husk=$LEGACY_PANE new_tab=$REPLACEMENT_TAB new_pane=$REPLACEMENT_PANE"
check test "$REPLACEMENT_PANE" != "$LEGACY_PANE"
if lab pane get "$LEGACY_PANE"; then echo 'FAIL old legacy husk remains'; exit 1; fi
lab pane get "$REPLACEMENT_PANE"
# Remote control's fixed fm-remote namespace is remapped by the transparent
# CLI transport to this real lab, never to the host's shared remote session.
echo '=== remote parent-route owns endpoint reads rather than ordinary state ==='
REMOTE="$SCRATCH/remote-home"; bin/fm-lab-home.sh create "$REMOTE" >/dev/null; mkdir -p "$REMOTE/state/parent-route"
git archive HEAD | tar -x -C "$REMOTE"
printf 'mate\n' > "$REMOTE/.fm-secondmate-home"
meta "$REMOTE/state/mate.meta" mate "$PANE" "$NEW_ID" "$SCRATCH/owned" fm-remote
meta "$REMOTE/state/parent-route/mate.meta" mate "$PANE" "$IDENTITY" "$SCRATCH/owned" fm-remote
REMOTE_STATE=$(FM_HOME="$REMOTE" "$ROOT/bin/fm-remote-secondmate-control.sh" state mate)
echo "parent_route_stale_state=$REMOTE_STATE"; check test "$REMOTE_STATE" = missing
REMOTE_CAPTURE=$(FM_HOME="$REMOTE" "$ROOT/bin/fm-remote-secondmate-control.sh" capture mate 20)
check test -z "$REMOTE_CAPTURE"; echo 'remote capture returned no foreign output'
REMOTE_KEY_RC=0
FM_HOME="$REMOTE" "$ROOT/bin/fm-remote-secondmate-control.sh" key mate Enter > "$SCRATCH/remote-key.out" 2> "$SCRATCH/remote-key.err" || REMOTE_KEY_RC=$?
if grep -Fq 'no-mistakes gate agent must not drive the fleet' "$SCRATCH/remote-key.err"; then
  echo "remote_key_live=untested (gate refusal before endpoint access; exit=$REMOTE_KEY_RC)"
else
  check test "$REMOTE_KEY_RC" != 0
  echo 'remote key refused on endpoint ownership'
fi
meta "$REMOTE/state/parent-route/mate.meta" mate "$PANE" "$NEW_ID" "$SCRATCH/owned" fm-remote
REMOTE_STATE=$(FM_HOME="$REMOTE" "$ROOT/bin/fm-remote-secondmate-control.sh" state mate)
echo "parent_route_bound_state=$REMOTE_STATE"; check test "$REMOTE_STATE" = dead
FM_HOME="$REMOTE" "$ROOT/bin/fm-remote-secondmate-control.sh" capture mate 20
echo '=== real spawn publishes its root process identity ==='
PROJECT="$SCRATCH/project"; mkdir -p "$PROJECT"; git -C "$PROJECT" init -q
printf 'isolated spawn fixture\n' > "$PROJECT/README.md"
git -C "$PROJECT" add README.md
git -C "$PROJECT" -c user.name=Lab -c user.email=lab@example.invalid commit -qm initial
git clone -q --bare "$PROJECT" "$SCRATCH/origin.git"
git -C "$PROJECT" remote add origin "file://$SCRATCH/origin.git"
printf 'off\n' > "$FM_HOME/config/herdr-presentation-spaces"
printf 'manual\n' > "$FM_HOME/config/backlog-backend"
export TREEHOUSE_ROOT="$SCRATCH/pool" GIT_CEILING_DIRECTORIES="$SCRATCH"
FM_HOME="$FM_HOME" "$ROOT/bin/fm-brief.sh" worker project --mode local-only --herdr-lab > "$SCRATCH/scaffold.log"
python3 - "$FM_HOME/data/worker/brief.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); s=s.replace('{TASK}','Observe the isolated terminal and make no changes.').replace('{FIRSTMATE_SPEC}','Do not modify files or access shared services.'); p.write_text(s)
PY
PI_LAUNCH="PI_CODING_AGENT_DIR=$SCRATCH/pi pi --no-session --offline --no-mcp --no-context-files --no-extensions --no-skills --no-prompt-templates --no-themes --no-tools --tui-mode regular"
FM_HOME="$FM_HOME" "$ROOT/bin/fm-spawn.sh" worker "$PROJECT" "$PI_LAUNCH" --mode local-only --yolo off --backend herdr > "$SCRATCH/spawn.log" 2>&1 || { head -70 "$SCRATCH/spawn.log"; exit 1; }
head -40 "$SCRATCH/spawn.log"
PI_PANE=$(fm_backend_herdr_meta_value "$FM_HOME/state/worker.meta" herdr_pane_id)
PI_ID=$(fm_backend_herdr_meta_value "$FM_HOME/state/worker.meta" herdr_process_identity)
PI_TARGET="$SESSION:$PI_PANE"
CURRENT_PI_ID=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PI_PANE")
echo "published_worker_target=$PI_TARGET published_identity=$PI_ID current_identity=$CURRENT_PI_ID"
check test -n "$PI_ID"; check test "$PI_ID" = "$CURRENT_PI_ID"
sleep 1
PI_LIVENESS=$(fm_backend_agent_state herdr "$PI_TARGET" fm-worker)
echo "real_pi_process_liveness=$PI_LIVENESS"
check test "$PI_LIVENESS" != missing
check fm_backend_target_exists herdr "$PI_TARGET" fm-worker
for i in 1 2 3; do check test "$(fm_backend_herdr_pane_process_identity "$SESSION" "$PI_PANE")" = "$PI_ID"; done
cp "$FM_HOME/state/worker.meta" "$EVIDENCE/spawned-worker.meta"
sleep 2
lab pane read "$PI_PANE" --lines 200 > "$EVIDENCE/pi-viewport.json"
lab agent get "$PI_PANE" || true
# A reset destroys the pane process without losing the task's worktree.
PATH="$ORIGINAL_PATH" "$HELPER" stop "$SESSION" >/dev/null
PATH="$ORIGINAL_PATH" "$HELPER" provision "$SESSION"
FM_HOME="$FM_HOME" "$ROOT/bin/fm-spawn.sh" worker --relaunch > "$SCRATCH/relaunch.log" 2>&1 || { head -70 "$SCRATCH/relaunch.log"; exit 1; }
head -35 "$SCRATCH/relaunch.log"
NEW_PI_PANE=$(fm_backend_herdr_meta_value "$FM_HOME/state/worker.meta" herdr_pane_id)
NEW_PI_ID=$(fm_backend_herdr_meta_value "$FM_HOME/state/worker.meta" herdr_process_identity)
echo "relaunch_old_pane=$PI_PANE relaunch_new_pane=$NEW_PI_PANE old_identity=$PI_ID republished_identity=$NEW_PI_ID"
check test "$PI_ID" != "$NEW_PI_ID"
check test "$NEW_PI_ID" = "$(fm_backend_herdr_pane_process_identity "$SESSION" "$NEW_PI_PANE")"
cp "$FM_HOME/state/worker.meta" "$EVIDENCE/relaunched-worker.meta"
PI_PANE=$NEW_PI_PANE; PI_ID=$NEW_PI_ID; PI_TARGET="$SESSION:$PI_PANE"
sleep 2
lab pane read "$PI_PANE" --source visible > "$SCRATCH/relaunch-screen"
if grep -Fq 'Trust project folder?' "$SCRATCH/relaunch-screen"; then
  lab pane send-keys "$PI_PANE" down down down down enter >/dev/null
  sleep 2
fi
lab pane read "$PI_PANE" --source visible > "$EVIDENCE/pi-relaunched-viewport.txt"
echo '=== bound push claimant beats a stale paused claimant ==='
meta "$FM_HOME/state/a.meta" a "$PI_PANE" "$IDENTITY" "$SCRATCH/owned"
meta "$FM_HOME/state/b.meta" b "$PI_PANE" "$PI_ID" "$SCRATCH/owned"
printf 'paused: waiting on a release\n' > "$FM_HOME/state/a.status"
printf 'blocked: explicit approval needed\n' > "$FM_HOME/state/b.status"
STATE="$FM_HOME/state"; export STATE
. "$ROOT/bin/fm-push-transition-lib.sh"
SESSION_REF=$(lab agent get "$PI_PANE" | jq -r '.result.agent.agent_session.value // empty')
REPORT_SEQ=$(date +%s)
if [ -n "$SESSION_REF" ]; then
  lab pane report-agent --source herdr:pi --agent pi --state blocked --seq "$REPORT_SEQ" --agent-session-path "$SESSION_REF" "$PI_PANE"
else
  lab pane report-agent --source lab:integration --agent pi --state blocked "$PI_PANE"
fi
lab agent get "$PI_PANE"
TRANSITION=$(fm_backend_wait_transition herdr "$SESSION" 3 "$STATE" "$PI_TARGET") || { echo "FAIL no real blocked transition rc=$?"; exit 1; }
echo "native_transition=$TRANSITION"
(handle_push_transition herdr "$SESSION" "$TRANSITION")
echo "bound_status_surfaced=$(hb_surfaced_offset b) stale_status_surfaced=$(hb_surfaced_offset a)"
check test "$(hb_surfaced_offset b)" = "$(wc -c < "$STATE/b.status" | tr -d '[:space:]')"
check test "$(hb_surfaced_offset a)" = 0
printf 'wake_queue='; head -5 "$STATE/.wake-queue"
# Remove adversarial push aliases so passive probes select only worker.
rm "$STATE/a.meta" "$STATE/b.meta"
if [ -n "$SESSION_REF" ]; then
  lab pane report-agent --source herdr:pi --agent pi --state idle --seq "$((REPORT_SEQ+1))" --agent-session-path "$SESSION_REF" "$PI_PANE" >/dev/null
else
  lab pane report-agent --source lab:integration --agent pi --state idle "$PI_PANE" >/dev/null
fi
BASE_COMPOSER=$(fm_backend_composer_state herdr "$PI_TARGET" fm-worker)
echo "live_pi_composer_baseline=$BASE_COMPOSER"
echo '=== passive composer stop after the real viewport capture ==='
: > "$SCRATCH/stop-viewport"
COMPOSER=$(fm_backend_composer_state herdr "$PI_TARGET" fm-worker)
echo "composer_after_stop=$COMPOSER server_state=$(fm_backend_herdr_server_running_state "$SESSION")"
check test ! -e "$SCRATCH/stop-viewport"
check test "$COMPOSER" = unknown
check test "$(fm_backend_herdr_server_running_state "$SESSION")" = stopped
PATH="$ORIGINAL_PATH" "$HELPER" provision "$SESSION"
# Server restore changes worker's process, so rebind this test record explicitly
# to the currently observed pane before exercising its passive native lookup.
PI_ID=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PI_PANE")
python3 - "$STATE/worker.meta" "$PI_ID" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text().splitlines(); p.write_text('\n'.join(('herdr_process_identity='+sys.argv[2]) if l.startswith('herdr_process_identity=') else l for l in s)+'\n')
PY
echo '=== passive busy stop before native status lookup ==='
: > "$SCRATCH/stop-native"
BUSY=$(fm_backend_busy_state herdr "$PI_TARGET" fm-worker)
echo "busy_after_stop=$BUSY server_state=$(fm_backend_herdr_server_running_state "$SESSION")"
check test ! -e "$SCRATCH/stop-native"
check test "$BUSY" = unknown
check test "$(fm_backend_herdr_server_running_state "$SESSION")" = stopped
head -10 "$SCRATCH/races.log"
cp "$SCRATCH/races.log" "$EVIDENCE/passive-races.log"
cp "$SCRATCH/calls.log" "$EVIDENCE/live-herdr-calls.log"
echo 'ALL LIVE SCENARIOS COMPLETE'
