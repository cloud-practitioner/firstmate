#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
E=${1:?}
export LIVE_ROOT="$ROOT" LIVE_PATH="$PATH" LIVE_REAL_HERDR="$(command -v herdr)"
export FM_HERDR_LAB_STATE_DIR="$ROOT/.live-validation/tripwires" HERDR_CONFIG_PATH="$ROOT/.live-validation/config.toml"
lab() { (cd "$ROOT"; HOME=.live-validation/user XDG_CONFIG_HOME=.live-validation/user/.config PATH="$LIVE_PATH" bin/fm-herdr-lab.sh "$@"); }
SESSION=$(lab name ownership)
export LIVE_SESSION="$SESSION" HERDR_SESSION="$SESSION" PATH="$ROOT/.live-validation/bin:$PATH"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_CLIENT_SOCKET_PATH
for v in "${!FM_@}"; do case "$v" in *_OVERRIDE) unset "$v" ;; esac; done
unset FM_GATE_REFUSE_BYPASS
export TMPDIR="$ROOT/.live-validation/tmp" HOME="$ROOT/.live-validation/user" CLAUDE_CONFIG_DIR="$ROOT/.live-validation/claude"
export FM_HOME="$ROOT/.live-validation/more-home"
bin/fm-lab-home.sh create "$FM_HOME" >/dev/null
. bin/fm-backend.sh
. bin/fm-lock-lib.sh
fm_backend_source herdr
cleanup() { rc=$?; rm -f "$ROOT/.live-validation/bin/ps"; lab teardown "$SESSION" || rc=1; echo 'TEARDOWN: lab absent; default-session tripwire unchanged'; exit "$rc"; }
trap cleanup EXIT
check() { [ "$1" = "$2" ] || { echo "FAILED: $3 expected=$2 actual=$1"; exit 1; }; echo "$3 => $1"; }
lab provision "$SESSION"
lab run "$SESSION" workspace create --cwd "$ROOT/.live-validation/worktree" --label firstmate --no-focus >/dev/null
printf '\nSCENARIO: live Claude process is alive only for its bound owner\n'
PANE=w1:p1; TAB=w1:t1
IDENTITY=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
cat > "$FM_HOME/state/owned.meta" <<EOF
backend=herdr
window=$SESSION:$PANE
worktree=$ROOT/.live-validation/worktree
herdr_process_identity=$IDENTITY
EOF
lab run "$SESSION" pane run "$PANE" "env CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' HOME='$HOME' claude --setting-sources project,local" >/dev/null
sleep 2
lab run "$SESSION" pane process-info --pane "$PANE"
lab run "$SESSION" pane report-agent "$PANE" --source firstmate-live-validation --agent claude --state idle >/dev/null
check "$(fm_backend_agent_state herdr "$SESSION:$PANE" fm-owned)" alive bound-live-claude
printf '\nSCENARIO: unreadable recorded identity refuses capture, keys and close\n'
export LIVE_REAL_PS=$(command -v ps)
cat > .live-validation/bin/ps <<'SH'
#!/usr/bin/env bash
case "$*" in '-o lstart= -p '*) exit 1 ;; *) exec "$LIVE_REAL_PS" "$@" ;; esac
SH
chmod +x .live-validation/bin/ps
check "$(fm_backend_agent_state herdr "$SESSION:$PANE" fm-owned)" unreadable identity-unavailable-not-missing
if fm_backend_capture herdr "$SESSION:$PANE" 20 fm-owned; then echo 'FAILED: capture with unreadable identity'; exit 1; fi
if fm_backend_send_key herdr "$SESSION:$PANE" Escape fm-owned; then echo 'FAILED: key with unreadable identity'; exit 1; fi
# The kill API is best-effort; its return is not proof of closure. Assert
# authoritative continued presence and unchanged live process instead.
fm_backend_kill herdr "$SESSION:$PANE" '' fm-owned || true
lab run "$SESSION" pane process-info --pane "$PANE"
if fm_backend_herdr_endpoint_confirmed_gone "$SESSION:$PANE" fm-owned; then echo 'FAILED: unreadable present endpoint declared absent'; exit 1; fi
rm .live-validation/bin/ps
check "$(fm_backend_agent_state herdr "$SESSION:$PANE" fm-owned)" alive unreadable-probe-left-agent-intact
cat > "$FM_HOME/state/stale.meta" <<EOF
backend=herdr
window=$SESSION:$PANE
worktree=$ROOT/.live-validation/worktree
herdr_process_identity=ps:99:Tue Mar 19 10:11:12 2024
EOF
# Compare the real baseline product against the same running pane and record.
BASE="$ROOT/.live-validation/baseline"
mkdir -p "$BASE"
git archive 06a89438bead6193fd300248c5366941a30789d9 bin | tar -x -C "$BASE"
BEFORE=$(bash -c '. "$1/bin/fm-backend.sh"; fm_backend_agent_state herdr "$2" fm-stale' _ "$BASE" "$SESSION:$PANE")
check "$BEFORE" alive baseline-misattributed-live-agent
check "$(fm_backend_agent_state herdr "$SESSION:$PANE" fm-stale)" missing recycled-live-claude-is-not-stale-task
if fm_backend_capture herdr "$SESSION:$PANE" 20 fm-stale; then echo 'FAILED: captured unrelated live agent'; exit 1; fi
fm_backend_kill herdr "$SESSION:$PANE" '' fm-stale
lab run "$SESSION" pane process-info --pane "$PANE"
echo 'live foreign Claude remains present and unsteered'
printf '\nSCENARIO: forced recursive stale secondmate cleanup preserves all foreign panes\n'
MATE="$ROOT/.live-validation/more-mate" NESTED="$ROOT/.live-validation/more-nested"
bin/fm-lab-home.sh create "$MATE" >/dev/null
bin/fm-lab-home.sh create "$NESTED" >/dev/null
printf 'parent\n' > "$MATE/.fm-secondmate-home"
printf 'branch\n' > "$NESTED/.fm-secondmate-home"
for label in branch leaf; do lab run "$SESSION" tab create --workspace w1 --cwd "$ROOT/.live-validation/worktree" --label "foreign-$label" --no-focus >/dev/null; done
write_record() {
  file=$1 id=$2 pane=$3 tab=$4 wt=$5 kind=$6
  cat > "$file" <<EOF
backend=herdr
window=$SESSION:$pane
endpoint_task_id=$id
herdr_session=$SESSION
herdr_workspace_id=w1
herdr_tab_id=$tab
herdr_pane_id=$pane
herdr_process_identity=ps:99:Tue Mar 19 10:11:12 2024
worktree=$wt
project=$wt
home=$wt
kind=$kind
harness=claude
mode=secondmate
yolo=off
EOF
}
write_record "$FM_HOME/state/parent.meta" parent w1:p1 w1:t1 "$MATE" secondmate
write_record "$MATE/state/branch.meta" branch w1:p2 w1:t2 "$NESTED" secondmate
write_record "$NESTED/state/leaf.meta" leaf w1:p3 w1:t3 "$ROOT/.live-validation/missing-worktree" scout
# Run an unchanged disposable product copy so its guarded code root is not
# an ancestor of the disposable homes (the normal installed-home topology).
CODE="$ROOT/.live-validation/code"
mkdir -p "$CODE"
cp -R "$ROOT/bin" "$CODE/bin"
"$CODE/bin/fm-teardown.sh" parent --force
[ ! -e "$FM_HOME/state/parent.meta" ]
[ ! -e "$MATE" ] && [ ! -e "$NESTED" ]
for pane in w1:p1 w1:p2 w1:p3; do lab run "$SESSION" pane get "$pane"; done
lab run "$SESSION" pane process-info --pane w1:p1
printf 'recursive records/homes removed; every unrelated endpoint survived\n'
