#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EVID=/home/node/.no-mistakes/evidence/01M4A3BG1QYX4E134JQ4C4GJSF
SCRATCH="$ROOT/.identity-validation/recovery"
mkdir -p "$SCRATCH/tmp" "$SCRATCH/proxy" "$SCRATCH/code"
export TMPDIR="$SCRATCH/tmp" FM_HERDR_LAB_STATE_DIR="$SCRATCH/lab-state"
for v in ${!FM_@}; do case "$v" in *_OVERRIDE) unset "$v" ;; esac; done
unset FM_GATE_REFUSE_BYPASS
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
BASE_PATH=$PATH
REAL_HERDR=$(command -v herdr)
SESSION=$(bin/fm-herdr-lab.sh name recovery)
export SESSION HERDR_SESSION="$SESSION" BASE_PATH REAL_HERDR ROOT
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
export FM_HOME="$LAB" FM_SPAWN_NO_GUARD=1 FM_CONTROL_POLL=0.3 FM_CONTROL_LAUNCH_WAIT=30 FM_CONTROL_EXIT_WAIT=15
export PI_CODING_AGENT_SESSION_DIR="$SCRATCH/pi-sessions" PI_OFFLINE=1
bin/fm-lab-home.sh create "$LAB"
cleanup() {
  rc=$?
  PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" teardown "$SESSION" && echo 'Recovery lab removed; default-session fleet tripwire unchanged.' || rc=1
  # Product launch staging is an incidental toolchain temp output; remove only this fixture home's own paths.
  TOKEN=$(printf '%s' "$LAB" | sha256sum | awk '{print $1}')
  for task in identity-worker identity-mate; do
    launch="/tmp/fm-$task+$TOKEN"
    if [ -d "$launch" ]; then rm -rf "$launch"; fi
  done
  chmod -R u+w "$LAB" "$SCRATCH" 2>/dev/null || true
  rm -rf "$LAB" "$SCRATCH"
  exit "$rc"
}
trap cleanup EXIT
# An unchanged archive gives the product a disposable code root, with sibling secondmate homes
# inside this gate worktree rather than outside its write boundary.
git archive HEAD | tar -x -C "$SCRATCH/code"
CODE="$SCRATCH/code"
git -C "$CODE" init -q -b main
git -C "$CODE" add .
git -C "$CODE" -c user.name='Live Validation' -c user.email='live@example.invalid' commit -qm 'Disposable product fixture'
printf 'off\n' > "$LAB/config/herdr-presentation-spaces"
printf 'pi\n' > "$LAB/config/crew-harness"
printf 'pi\n' > "$LAB/config/secondmate-harness"
bin/fm-herdr-lab.sh provision "$SESSION"
cat > "$SCRATCH/proxy/herdr" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = --version ] || [ "${1:-}" = --help ]; then exec "$REAL_HERDR" "$@"; fi
args=()
while [ "$#" -gt 0 ]; do
  if [ "$1" = --session ]; then
    [ "$2" = "$SESSION" ] || { echo 'cross-session refused' >&2; exit 1; }
    shift 2
  else args+=("$1"); shift; fi
done
exec env PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}"
SH
chmod +x "$SCRATCH/proxy/herdr"
export PATH="$SCRATCH/proxy:$PATH"
lab() { PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "$@"; }
. "$CODE/bin/fm-backend.sh"
fm_backend_source herdr
value() { awk -F= -v key="$2" '$1==key {sub(/^[^=]*=/, ""); v=$0} END {print v}' "$1"; }
wait_alive() {
  local target=$1 label=$2 state
  for n in $(seq 1 70); do
    state=$(fm_backend_agent_state herdr "$target" "$label")
    [ "$state" != alive ] || return 0
    sleep 0.4
  done
  echo "Expected live agent on $target; read $state" >&2
  return 1
}
# A genuine linked task worktree and a previous-release persisted record.
PROJ="$SCRATCH/project"
WT="$SCRATCH/worker"
mkdir -p "$PROJ"
git -C "$PROJ" init -q -b main
printf '# Disposable identity task\n' > "$PROJ/README.md"
git -C "$PROJ" add README.md
git -C "$PROJ" -c user.name='Live Validation' -c user.email='live@example.invalid' commit -qm initial
git -C "$PROJ" worktree add -q -b fm/identity-worker "$WT"
"$CODE/bin/fm-brief.sh" identity-worker project --mode local-only --herdr-lab
python3 - "$LAB/data/identity-worker/brief.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace('{TASK}', 'This is an isolated lifecycle validation fixture. Make no source changes, invoke no delivery pipeline, and remain idle.')
s=s.replace('{FIRSTMATE_SPEC}', 'Do not implement work. Wait for lifecycle control. All homes and endpoints are disposable.')
p.write_text(s)
PY
WS=$(lab workspace create --label firstmate --cwd "$WT")
PANE=$(jq -er '.result.root_pane.pane_id' <<< "$WS")
TAB=$(jq -er '.result.tab.tab_id' <<< "$WS")
WORKSPACE=$(jq -er '.result.workspace.workspace_id' <<< "$WS")
PID=$(fm_backend_herdr_pane_shell_pid "$SESSION" "$PANE")
LEGACY="ps:$PID:$(fm_backend_herdr_ps_lstart "$PID")"
META="$LAB/state/identity-worker.meta"
printf 'window=%s:%s\nendpoint_task_id=identity-worker\nworktree=%s\nproject=%s\nharness=pi\nkind=ship\nmode=local-only\nyolo=off\nmodel=default\neffort=default\nbackend=herdr\nherdr_session=%s\nherdr_workspace_id=%s\nherdr_tab_id=%s\nherdr_pane_id=%s\nherdr_process_identity=%s\n' "$SESSION" "$PANE" "$WT" "$PROJ" "$SESSION" "$WORKSPACE" "$TAB" "$PANE" "$LEGACY" > "$META"
cp "$META" "$EVID/worker-before.meta"
echo 'Public worker recovery: fm-control.sh identity-worker relaunch (legacy record, agent-free real pane)'
"$CODE/bin/fm-control.sh" identity-worker relaunch --note 'Disposable fixture; no open work. Remain idle; do not invoke any pipeline.'
cp "$META" "$EVID/worker-after-legacy.meta"
NEW=$(value "$META" herdr_process_identity)
ACTUAL=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
printf 'Worker identity refresh: %s -> %s; observed root=%s\n' "$LEGACY" "$NEW" "$ACTUAL"
[ "$NEW" = "$ACTUAL" ] && [[ "$NEW" == proc:* ]]
[ "$(grep -c '^herdr_process_identity=' "$META")" = 1 ]
lab pane read "$PANE" > "$EVID/worker-relaunch-pane.txt"
# Replace the pane process through a real named-session stop and reprovision.
PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" stop "$SESSION"
sleep 0.7
PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" provision "$SESSION"
CURRENT=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
printf 'After real lab restart: recorded=%s current=%s\n' "$NEW" "$CURRENT"
[ "$NEW" != "$CURRENT" ]
"$CODE/bin/fm-control.sh" identity-worker relaunch --note 'The disposable Herdr session restarted. Rebind to a new pane; preserve the worktree and remain idle.'
REBOUND=$(value "$META" window)
RPANE=${REBOUND#*:}
UPDATED=$(value "$META" herdr_process_identity)
OBSERVED=$(fm_backend_herdr_pane_process_identity "$SESSION" "$RPANE")
printf 'Worker rebind: old_endpoint=%s:%s new_endpoint=%s identity=%s observed=%s\n' "$SESSION" "$PANE" "$REBOUND" "$UPDATED" "$OBSERVED"
[ "$UPDATED" = "$OBSERVED" ] && [ "$UPDATED" != "$NEW" ]
[ "$(value "$META" worktree)" = "$WT" ] && [ -d "$WT" ]
cp "$META" "$EVID/worker-after-process-change.meta"
lab pane read "$RPANE" > "$EVID/worker-process-change-pane.txt"
# Real secondmate provisioning, in a sibling home within this worktree.
SMHOME="$SCRATCH/mate"
FM_SECONDMATE_CHARTER='Isolated lifecycle fixture with no projects and no open work. Remain idle. Do not edit source, create tasks, start a delivery pipeline, contact external systems, or change any credentials.' \
  "$CODE/bin/fm-home-seed.sh" identity-mate "$SMHOME" --no-projects
SMWS=$(lab workspace create --label 2ndmate-identity-mate --cwd "$SMHOME")
SMPANE=$(jq -er '.result.root_pane.pane_id' <<< "$SMWS")
SMTAB=$(jq -er '.result.tab.tab_id' <<< "$SMWS")
SMWORKSPACE=$(jq -er '.result.workspace.workspace_id' <<< "$SMWS")
SMPID=$(fm_backend_herdr_pane_shell_pid "$SESSION" "$SMPANE")
SMLEGACY="ps:$SMPID:$(fm_backend_herdr_ps_lstart "$SMPID")"
SMMETA="$LAB/state/identity-mate.meta"
printf 'window=%s:%s\nendpoint_task_id=identity-mate\nworktree=%s\nproject=%s\nhome=%s\nharness=pi\nkind=secondmate\nmode=secondmate\nyolo=off\nmodel=default\neffort=default\nbackend=herdr\nherdr_session=%s\nherdr_workspace_id=%s\nherdr_tab_id=%s\nherdr_pane_id=%s\nherdr_process_identity=%s\n' "$SESSION" "$SMPANE" "$SMHOME" "$SMHOME" "$SMHOME" "$SESSION" "$SMWORKSPACE" "$SMTAB" "$SMPANE" "$SMLEGACY" > "$SMMETA"
cp "$SMMETA" "$EVID/secondmate-before.meta"
# Start the actual Pi TUI with session-scoped trust, no synthetic harness or registration.
lab pane run "$SMPANE" "env FM_HOME='$SMHOME' PI_CODING_AGENT_SESSION_DIR='$SCRATCH/pi-sessions' pi --approve --no-session --no-mcp --no-skills --no-prompt-templates --no-extensions"
wait_alive "$SESSION:$SMPANE" fm-identity-mate
sleep 2
lab pane read "$SMPANE" > "$EVID/secondmate-before-pane.txt"
echo 'Public secondmate restart: real fm-secondmate-restart.sh; manually acknowledge the empty fixture through the public parent-report protocol.'
# Run the command from a real primary CLI, with the runbook's sanitized primary environment.
# The disposable unchanged code checkout keeps every seeded home inside the workspace boundary.
PRIMARYWS=$(lab workspace create --label fixture-primary --cwd "$CODE")
PRIMARYPANE=$(jq -er '.result.root_pane.pane_id' <<< "$PRIMARYWS")
lab pane run "$PRIMARYPANE" "env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE FM_HOME='$LAB' PI_CODING_AGENT_SESSION_DIR='$SCRATCH/pi-sessions' pi --approve --no-session --no-mcp --no-skills --no-prompt-templates --no-extensions"
sleep 3
PRIMARY_CMD="! FM_HOME='$LAB' FM_SPAWN_NO_GUARD=1 FM_CONTROL_POLL=0.3 FM_CONTROL_LAUNCH_WAIT=30 FM_CONTROL_EXIT_WAIT=15 FM_SECONDMATE_PERSIST_WAIT=60 FM_SECONDMATE_PERSIST_POLL=1 '$CODE/bin/fm-secondmate-restart.sh' identity-mate > '$EVID/secondmate-restart-output.log' 2>&1; rc=\$?; printf '%s' \"\$rc\" > '$SCRATCH/restart-exit'"
lab pane send-text "$PRIMARYPANE" "$PRIMARY_CMD"
lab pane send-keys "$PRIMARYPANE" Enter
# The protocol input is supplied explicitly as disposable data, not attributed to an LLM.
CORR=''
for n in $(seq 1 70); do
  for rec in "$LAB/state/pending-replies/"*; do
    [ -f "$rec" ] || continue
    CORR=$(value "$rec" corr_id)
    [ -z "$CORR" ] || break
  done
  [ -z "$CORR" ] || break
  sleep 0.3
done
[ -n "$CORR" ] || { echo 'No persist request found' >&2; lab pane read "$PRIMARYPANE" > "$EVID/restart-primary-pane.txt"; exit 1; }
printf 'Fixture acknowledgement: corr=%s; no open records exist in this empty secondmate.\n' "$CORR"
FM_HOME="$SMHOME" "$SMHOME/bin/fm-secondmate-report.sh" done "$CORR" 'Disposable empty fixture: no conversation-only work or open records to persist; acknowledged manually by the test driver.'
for n in $(seq 1 150); do [ ! -f "$SCRATCH/restart-exit" ] || break; sleep 0.4; done
lab pane read "$PRIMARYPANE" > "$EVID/restart-primary-pane.txt"
[ -f "$SCRATCH/restart-exit" ] || { echo 'Primary restart command did not complete' >&2; exit 1; }
cat "$EVID/secondmate-restart-output.log"
[ "$(< "$SCRATCH/restart-exit")" = 0 ]
SMNEW=$(value "$SMMETA" herdr_process_identity)
SMACTUAL=$(fm_backend_herdr_pane_process_identity "$SESSION" "$SMPANE")
printf 'Secondmate restart identity refresh: %s -> %s; actual=%s\n' "$SMLEGACY" "$SMNEW" "$SMACTUAL"
[ "$SMNEW" = "$SMACTUAL" ] && [[ "$SMNEW" == proc:* ]]
[ "$(grep -c '^herdr_process_identity=' "$SMMETA")" = 1 ]
cp "$SMMETA" "$EVID/secondmate-after.meta"
lab pane read "$SMPANE" > "$EVID/secondmate-after-pane.txt"
lab workspace list > "$EVID/recovery-layout.json"
echo 'All public recovery identity postconditions verified against real pane roots.'
