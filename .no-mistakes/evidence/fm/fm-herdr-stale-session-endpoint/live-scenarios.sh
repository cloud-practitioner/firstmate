#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
E=${1:?evidence directory}
mkdir -p "$E" .live-validation/bin .live-validation/tmp
ORIGINAL_PATH=$PATH
REAL_HERDR=$(command -v herdr)
export FM_HERDR_LAB_STATE_DIR="$ROOT/.live-validation/tripwires"
export HERDR_CONFIG_PATH="$ROOT/.live-validation/config.toml"
export LIVE_ROOT="$ROOT" LIVE_PATH="$ORIGINAL_PATH" LIVE_REAL_HERDR="$REAL_HERDR"
# The real Treehouse consumer will reject a file as its pool directory. This
# supplies a deterministic, isolated allocation failure for projected abort.
export TREEHOUSE_ROOT="$ROOT/.live-validation/blocked-pool"
printf 'not a directory\n' > "$TREEHOUSE_ROOT"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_CLIENT_SOCKET_PATH
# The lab's relative socket paths avoid AF_UNIX's 108-byte limit. Only the
# read-only default-session tripwire uses the symlink to the real default socket.
[ -L .live-validation/user/.config/herdr/herdr.sock ] || ln -s /home/node/.config/herdr/herdr.sock .live-validation/user/.config/herdr/herdr.sock
lab() { (cd "$ROOT"; HOME=.live-validation/user XDG_CONFIG_HOME=.live-validation/user/.config PATH="$ORIGINAL_PATH" bin/fm-herdr-lab.sh "$@"); }
SESSION=$(lab name stale)
export LIVE_SESSION="$SESSION" HERDR_SESSION="$SESSION"
cat > .live-validation/bin/herdr <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$LIVE_ROOT"
export HOME=.live-validation/user XDG_CONFIG_HOME=.live-validation/user/.config PATH="$LIVE_PATH"
unset HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_CLIENT_SOCKET_PATH HERDR_ENV
args=(); selected=${HERDR_SESSION:-$LIVE_SESSION}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) selected=$2; shift 2 ;;
    --session=*) selected=${1#*=}; shift ;;
    *) args+=("$1"); shift ;;
  esac
done
# fm-remote is a logical alias into this owned fm-lab session, never a shared server.
[ "$selected" = fm-remote ] && selected=$LIVE_SESSION
[ "$selected" = "$LIVE_SESSION" ] || { echo "test transport refuses non-lab session $selected" >&2; exit 1; }
case "${args[0]:-} ${args[1]:-}" in
  '--version '|'-V ') exec "$LIVE_REAL_HERDR" --version ;;
  'server '*) exec bin/fm-herdr-lab.sh provision "$selected" ;;
  'session list')
    # Canonicalize real relative socket paths for the product's lock owner.
    # No response is synthesized: all pane/process reads are the real server's.
    bin/fm-herdr-lab.sh run "$selected" "${args[@]}" | jq --arg root "$LIVE_ROOT" '
      .sessions |= map(.socket_path |= (if startswith("/") then . else $root + "/" + . end))'
    ;;
  *) exec bin/fm-herdr-lab.sh run "$selected" "${args[@]}" ;;
esac
SH
chmod +x .live-validation/bin/herdr
export PATH="$ROOT/.live-validation/bin:$ORIGINAL_PATH"
export HOME="$ROOT/.live-validation/user" TMPDIR="$ROOT/.live-validation/tmp"
export CLAUDE_CONFIG_DIR="$ROOT/.live-validation/claude"
mkdir -p "$CLAUDE_CONFIG_DIR"
# No fleet-path overrides or inherited crew-state overrides reach lifecycle calls.
for v in "${!FM_@}"; do case "$v" in *_OVERRIDE) unset "$v" ;; esac; done
unset FM_GATE_REFUSE_BYPASS
FM_HOME="$ROOT/.live-validation/home"; export FM_HOME
bin/fm-lab-home.sh create "$FM_HOME" >/dev/null
printf 'off\n' > "$FM_HOME/config/herdr-presentation-spaces"
printf 'manual\n' > "$FM_HOME/config/backlog-backend"
printf 'claude\n' > "$FM_HOME/config/crew-harness"
PROJ="$ROOT/.live-validation/project" WT="$ROOT/.live-validation/worktree"
mkdir -p "$PROJ"
git -C "$PROJ" init -q
printf 'validation fixture\n' > "$PROJ/README.md"
git -C "$PROJ" add README.md
git -C "$PROJ" -c user.name=Validation -c user.email=validation@example.invalid commit -qm fixture
git -C "$PROJ" worktree add --quiet -b fm/mine "$WT"
printf 'uncommitted work to preserve\n' > "$WT/preserved.txt"
. bin/fm-backend.sh
. bin/fm-lock-lib.sh
fm_backend_source herdr
cleanup() {
  rc=$?
  echo "TEARDOWN: named lab $SESSION"
  lab teardown "$SESSION" || rc=1
  echo "TEARDOWN: default-session tripwire unchanged and lab absent"
  # Ephemeral product launch files are removed using the repository's owner.
  . "$ROOT/tests/fixture-tree-helpers.sh"
  fm_test_remove_spawn_launch_dirs "$ROOT/.live-validation"
  exit "$rc"
}
trap cleanup EXIT
check() { [ "$1" = "$2" ] || { echo "FAILED: $3: expected=$2 actual=$1"; exit 1; }; echo "$3 => $1"; }
refused() { if "$@"; then echo "FAILED: expected refusal: $*"; exit 1; else echo "REFUSED: $*"; fi; }
write_meta() {
  local file=$1 session=$2 pane=$3 tab=$4 identity=$5 id=$6 wt=${7:-$WT}
  mkdir -p "${file%/*}"
  cat > "$file" <<EOF
backend=herdr
window=$session:$pane
endpoint_task_id=$id
herdr_session=$session
herdr_workspace_id=${pane%%:*}
herdr_tab_id=$tab
herdr_pane_id=$pane
herdr_process_identity=$identity
worktree=$wt
project=$PROJ
harness=claude
kind=ship
mode=direct-PR
yolo=off
branch=fm/mine
model=default
effort=default
EOF
}
lab provision "$SESSION"
lab run "$SESSION" status --json
W=$(lab run "$SESSION" workspace create --cwd "$WT" --label firstmate --no-focus)
WS=$(jq -r .result.workspace.workspace_id <<< "$W")
IDS=$(fm_backend_herdr_create_task "$SESSION:$WS" fm-mine "$WT")
read -r TAB PANE <<< "$IDS"
TARGET="$SESSION:$PANE"
IDENTITY=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
write_meta "$FM_HOME/state/mine.meta" "$SESSION" "$PANE" "$TAB" "$IDENTITY" mine
lab run "$SESSION" pane run "$PANE" "printf 'OWNED_ENDPOINT_SENTINEL\\n'" >/dev/null
sleep .4
printf '\nSCENARIO: owned process, exec, rename and cwd drift retain ownership\n'
check "$(fm_backend_agent_state herdr "$TARGET" fm-mine)" dead owned-shell-state
bin/fm-peek.sh mine 20
lab run "$SESSION" pane run "$PANE" "exec env HISTFILE=/dev/null PS1='lab$ ' bash --noprofile --norc" >/dev/null
sleep .3
check "$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")" "$IDENTITY" exec-preserves-identity
lab run "$SESSION" tab rename "$TAB" renamed-owned >/dev/null
lab run "$SESSION" pane run "$PANE" "cd '$PROJ'" >/dev/null
sleep .3
check "$(fm_backend_agent_state herdr "$TARGET" fm-mine)" dead identity-allows-label-and-cwd-drift
fm_backend_capture herdr "$TARGET" 20 fm-mine
printf '\nSCENARIO: fresh session recycles same cwd, label and address but is missing\n'
lab teardown "$SESSION"
lab provision "$SESSION"
lab run "$SESSION" workspace create --cwd "$WT" --label firstmate --no-focus >/dev/null
# Build the same physical tab/pane counter address with matching task label/cwd.
FRESH=$(lab run "$SESSION" tab create --workspace "$WS" --cwd "$WT" --label fm-mine --no-focus)
check "$(jq -r .result.root_pane.pane_id <<< "$FRESH")" "$PANE" recycled-pane-id
check "$(jq -r .result.tab.tab_id <<< "$FRESH")" "$TAB" recycled-tab-id
NEW_IDENTITY=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
[ "$NEW_IDENTITY" != "$IDENTITY" ] || { echo 'FAILED: fresh process has old identity'; exit 1; }
echo "recorded identity=$IDENTITY; fresh identity=$NEW_IDENTITY"
lab run "$SESSION" pane run "$PANE" "printf 'FOREIGN_ENDPOINT_SENTINEL\\n'" >/dev/null
sleep .3
check "$(fm_backend_agent_state herdr "$TARGET" fm-mine)" missing recycled-same-label-and-cwd
check "$(fm_backend_agent_alive herdr "$TARGET" fm-mine)" dead recycled-alive-probe
refused bin/fm-peek.sh mine 20
refused bin/fm-send.sh mine --key C-c
refused fm_backend_send_text_submit herdr "$TARGET" 'touch SHOULD_NOT_EXIST' 1 0 0 fm-mine
check "$(fm_backend_busy_state herdr "$TARGET")" unknown foreign-busy
check "$(fm_backend_composer_state herdr "$TARGET" fm-mine)" unknown foreign-composer
[ ! -e "$WT/SHOULD_NOT_EXIST" ]
fm_backend_kill herdr "$TARGET" '' fm-mine
lab run "$SESSION" pane get "$PANE"
check "$(fm_backend_herdr_endpoint_confirmed_gone "$TARGET" fm-mine && echo absent)" absent foreign-removal-verdict
printf '\nSCENARIO: secondmate home and task-specific claimant cannot borrow ownership\n'
CHILD="$ROOT/.live-validation/child-home"
bin/fm-lab-home.sh create "$CHILD" >/dev/null
printf 'child\n' > "$CHILD/.fm-secondmate-home"
write_meta "$CHILD/state/mine.meta" "$SESSION" "$PANE" "$TAB" "$IDENTITY" mine
write_meta "$CHILD/state/other.meta" "$SESSION" "$PANE" "$TAB" "$NEW_IDENTITY" other
check "$(FM_HOME="$CHILD" fm_backend_agent_state herdr "$TARGET" fm-mine)" missing child-home-stale-task
refused env FM_HOME="$CHILD" bin/fm-peek.sh mine 20
check "$(FM_HOME="$CHILD" fm_backend_agent_state herdr "$TARGET" fm-other)" dead child-home-owned-other
(
  export FM_HOME="$CHILD"
  . bin/fm-secondmate-liveness-lib.sh
  for mode in full poll; do
    fm_secondmate_liveness_probe "$CHILD/state/mine.meta" mine "$mode"
    check "$FM_SM_LIVE_STATE:$FM_SM_LIVE_STATUS" missing:relaunchable "secondmate-$mode-recovery-probe"
  done
)
printf '\nSCENARIO: stopped server cannot bypass active-operation ownership guard\n'
lab stop "$SESSION" >/dev/null
refused bin/fm-send.sh mine --key C-c
check "$(fm_backend_herdr_server_running_state "$SESSION")" running active-call-restored-server
check "$(fm_backend_agent_state herdr "$TARGET" fm-mine)" missing restored-server-stale-binding
lab run "$SESSION" pane get "$PANE"
printf '\nSCENARIO: real relaunch binds new endpoint and preserves work and foreign pane\n'
bin/fm-brief.sh mine "$PROJ" --mode direct-PR --herdr-lab >/dev/null
# Replace the generated task body but retain the scaffold's lab authority.
python3 - "$FM_HOME/data/mine/brief.md" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read().replace('{TASK}', 'Do not edit files, run tools, change configuration, contact services, or start any pipeline. Respond VALIDATION_READY then wait.').replace('{FIRSTMATE_SPEC}', 'Preserve all files. This is isolated endpoint validation, not a coding assignment.')
open(p, 'w').write(s)
PY
# Real Claude CLI, isolated config: no operator trust/config or credential writes.
# Endpoint recovery and CLI-process handoff are tested, not authenticated task completion.
bin/fm-spawn.sh mine --relaunch --harness claude
NEW_TARGET=$(fm_backend_target_of_meta "$FM_HOME/state/mine.meta")
NEW_PANE=${NEW_TARGET#*:}
[ "$NEW_TARGET" != "$TARGET" ] || { echo 'FAILED: relaunch adopted foreign pane'; exit 1; }
echo "relaunch target=$NEW_TARGET; old foreign target=$TARGET"
check "$(fm_backend_herdr_meta_value "$FM_HOME/state/mine.meta" herdr_process_identity)" "$(fm_backend_herdr_pane_process_identity "$SESSION" "$NEW_PANE")" published-new-identity
check "$(< "$WT/preserved.txt")" 'uncommitted work to preserve' preserved-uncommitted-work
sleep 2
lab run "$SESSION" pane process-info --pane "$NEW_PANE"
lab run "$SESSION" pane read "$NEW_PANE" --format text --lines 40
lab run "$SESSION" pane get "$PANE"
cp "$FM_HOME/state/mine.meta" "$E/recovered-endpoint.meta"
printf '\nSCENARIO: owned endpoint removal confirms absence after process disappears\n'
# Stop only this named lab pane; removal is through the product close boundary.
fm_backend_kill herdr "$NEW_TARGET" '' fm-mine
check "$(fm_backend_herdr_endpoint_confirmed_gone "$NEW_TARGET" fm-mine && echo absent)" absent owned-removal-confirmed
printf '\nSCENARIO: legacy records retain best-effort cwd-or-label compatibility\n'
LEGACY=$(lab run "$SESSION" tab create --workspace "$WS" --cwd "$WT" --label fm-legacy --no-focus)
LP=$(jq -r .result.root_pane.pane_id <<< "$LEGACY"); LT=$(jq -r .result.tab.tab_id <<< "$LEGACY")
write_meta "$FM_HOME/state/legacy.meta" "$SESSION" "$LP" "$LT" '' legacy
check "$(fm_backend_agent_state herdr "$SESSION:$LP" fm-legacy)" dead legacy-owned-shell
lab run "$SESSION" tab rename "$LT" different-label >/dev/null
check "$(fm_backend_agent_state herdr "$SESSION:$LP" fm-legacy)" dead legacy-cwd-match
lab run "$SESSION" pane run "$LP" "cd '$PROJ'" >/dev/null
sleep .3
check "$(fm_backend_agent_state herdr "$SESSION:$LP" fm-legacy)" missing legacy-both-label-and-cwd-mismatch
printf '\nSCENARIO: failed portable ps read still launches legacy relaunch without identity\n'
FALLBACK=$(lab run "$SESSION" tab create --workspace "$WS" --cwd "$WT" --label fm-fallback --no-focus)
FP=$(jq -r .result.root_pane.pane_id <<< "$FALLBACK"); FT=$(jq -r .result.tab.tab_id <<< "$FALLBACK")
write_meta "$FM_HOME/state/fallback.meta" "$SESSION" "$FP" "$FT" '' fallback
bin/fm-brief.sh fallback "$PROJ" --mode direct-PR --herdr-lab >/dev/null
python3 - "$FM_HOME/data/fallback/brief.md" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read().replace('fm/fallback', 'fm/mine').replace('{TASK}', 'Do not run tools or edit files. Await teardown.').replace('{FIRSTMATE_SPEC}', 'Disposable endpoint validation only.')
open(p, 'w').write(s)
PY
export LIVE_REAL_PS=$(command -v ps)
cat > .live-validation/bin/ps <<'SH'
#!/usr/bin/env bash
case "$*" in '-o lstart= -p '*) exit 1 ;; *) exec "$LIVE_REAL_PS" "$@" ;; esac
SH
chmod +x .live-validation/bin/ps
bin/fm-spawn.sh fallback --relaunch --harness claude
check "$(fm_backend_herdr_meta_value "$FM_HOME/state/fallback.meta" herdr_process_identity)" '' failed-ps-identity-omitted
check "$(fm_backend_target_of_meta "$FM_HOME/state/fallback.meta")" "$SESSION:$FP" legacy-relaunch-adopts-owned-endpoint
rm .live-validation/bin/ps
sleep 1
lab run "$SESSION" pane process-info --pane "$FP"
fm_backend_kill herdr "$SESSION:$FP" '' fm-fallback
check "$(fm_backend_herdr_endpoint_confirmed_gone "$SESSION:$FP" fm-fallback && echo absent)" absent fallback-removal
printf '\nSCENARIO: abort before publication removes response-owned projection despite stale address claimant\n'
# Herdr's next workspace is w2; A survives from a prior session naming the
# response-owned B pane that the real failed spawn is about to create.
write_meta "$FM_HOME/state/a.meta" "$SESSION" w2:p2 w2:t2 "$IDENTITY" a
printf 'on\n' > "$FM_HOME/config/herdr-presentation-spaces"
bin/fm-brief.sh b "$PROJ" --mode local-only --herdr-lab >/dev/null
python3 - "$FM_HOME/data/b/brief.md" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read().replace('{TASK}', 'Do not run tools or edit files. Await teardown.').replace('{FIRSTMATE_SPEC}', 'Disposable allocation-failure validation only.')
open(p, 'w').write(s)
PY
if bin/fm-spawn.sh b "$PROJ" --backend herdr --harness claude --mode local-only --yolo off > "$E/projected-abort.log" 2>&1; then
  echo 'FAILED: invalid Treehouse pool unexpectedly allocated a worktree'; exit 1
fi
cat "$E/projected-abort.log"
[ ! -e "$FM_HOME/state/b.meta" ] || { echo 'FAILED: aborted B published metadata'; exit 1; }
[ -f "$FM_HOME/state/a.meta" ]
LAYOUT=$(lab run "$SESSION" workspace list)
echo "$LAYOUT"
check "$(jq -c '[.result.workspaces[].workspace_id]' <<< "$LAYOUT")" '["w1"]' response-owned-abort-removed-workspace
printf '\nSCENARIO: host-local remote control uses parent-route, not ordinary home records\n'
REMOTE="$ROOT/.live-validation/remote-home"
bin/fm-lab-home.sh create "$REMOTE" >/dev/null
mkdir -p "$REMOTE/bin" "$REMOTE/state/parent-route"
printf 'ios\n' > "$REMOTE/.fm-secondmate-home"
# Required remote-home marker surface; no agent memory files are created or changed.
ln -s "$ROOT/AGENTS.md" "$REMOTE/AGENTS.md"
write_meta "$REMOTE/state/parent-route/ios.meta" fm-remote "$PANE" "$TAB" "$IDENTITY" ios
write_meta "$REMOTE/state/ios.meta" fm-remote "$PANE" "$TAB" "$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")" ios
check "$(FM_HOME="$REMOTE" bin/fm-remote-secondmate-control.sh state ios)" missing remote-owning-route-stale
REMOTE_CAPTURE=$(FM_HOME="$REMOTE" bin/fm-remote-secondmate-control.sh capture ios)
check "$REMOTE_CAPTURE" '' remote-foreign-capture-empty
check "$(FM_HOME="$REMOTE" bin/fm-remote-secondmate-control.sh observe ios)" unknown remote-foreign-observe
refused env FM_HOME="$REMOTE" bin/fm-remote-secondmate-control.sh key ios C-c
FM_HOME="$REMOTE" bin/fm-remote-secondmate-control.sh send ios 'record without steering foreign pane'
[ -n "$(ls "$REMOTE/state/parent-route/ios.inbox/"*.msg)" ]
lab run "$SESSION" pane get "$PANE"
echo 'ALL LIVE ENDPOINT SCENARIOS PASSED'
