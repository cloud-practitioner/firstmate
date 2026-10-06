#!/usr/bin/env bash
# Real Herdr / real Firstmate public entrypoints; no fake CLI or login.
set -euo pipefail
ROOT=/home/node/.no-mistakes/worktrees/450411b3e67c/01M47HX8Y8BQRSDDHWXNW190JH
E=/home/node/.no-mistakes/evidence/01M47HX8Y8BQRSDDHWXNW190JH
REAL_HERDR=$(command -v herdr)
BASE_PATH=$PATH
SESSION="fm-lab-stale-$$"
export HERDR_SESSION="$SESSION"
LAB="$FM_TASK_TMP/main"
CHILD="$FM_TASK_TMP/child"
PROJECT="$FM_TASK_TMP/project"
mkdir -p "$FM_TASK_TMP/router"
# Routing shim delegates every operation to the unmodified real binary through
# the supported lab helper. It does not synthesize any product response.
cat > "$FM_TASK_TMP/router/herdr" <<'SH'
#!/usr/bin/env bash
set -eu
args=()
session=$HERDR_SESSION
while [ "$#" -gt 0 ]; do
  if [ "$1" = --session ]; then session=$2; shift 2; else args+=("$1"); shift; fi
done
if [ "${args[0]:-}" = --version ]; then
  exec "$REAL_HERDR" --version --session "$session"
fi
exec env PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$session" "${args[@]}"
SH
chmod +x "$FM_TASK_TMP/router/herdr"
export REAL_HERDR BASE_PATH ROOT
export PATH="$FM_TASK_TMP/router:$BASE_PATH"
export FM_HOME="$LAB" FM_SPAWN_NO_GUARD=1
unset FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
lab() { PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" "$@"; }
run() { printf '\n$ lab run %s\n' "$*"; lab run "$SESSION" "$@"; }
backend() { bash -c '. "$1/bin/fm-backend.sh"; fm_backend_source herdr; shift; "$@"' bash "$ROOT" "$@"; }
value() { awk -F= -v key="$2" '$1==key {v=substr($0,length(key)+2)} END {print v}' "$1"; }
check() { [ "$1" = "$2" ] || { printf 'FAIL %s: expected %s got %s\n' "$3" "$2" "$1"; exit 1; }; printf 'VERIFIED %s: %s\n' "$3" "$1"; }
cleanup() {
  lab teardown "$SESSION"
  . "$ROOT/tests/fixture-tree-helpers.sh"
  fm_test_remove_spawn_launch_dirs "$LAB"
  fm_test_remove_spawn_launch_dirs "$CHILD"
  find "$LAB" "$CHILD" -type d -exec chmod u+w {} + 2>/dev/null || true
}
trap cleanup EXIT
lab provision "$SESSION"
"$ROOT/bin/fm-lab-home.sh" create "$LAB"
"$ROOT/bin/fm-lab-home.sh" create "$CHILD"
printf 'kid\n' > "$CHILD/.fm-secondmate-home"
printf 'off\n' > "$LAB/config/herdr-presentation-spaces"
touch "$LAB/state/.last-watcher-beat" "$CHILD/state/.last-watcher-beat"
mkdir -p "$PROJECT"
git -C "$PROJECT" init -q
printf '# Disposable endpoint-validation project\n' > "$PROJECT/README.md"
git -C "$PROJECT" add README.md
git -C "$PROJECT" -c user.name=Tests -c user.email=tests@example.invalid commit -qm initial
git clone -q --bare "$PROJECT" "$FM_TASK_TMP/origin.git"
git -C "$PROJECT" remote add origin "file://$FM_TASK_TMP/origin.git"
# Explicitly opt this disposable scenario into the supported Herdr lab brief.
"$ROOT/bin/fm-brief.sh" mine fixture --scout --herdr-lab
python3 - "$LAB/data/mine/brief.md" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); s=p.read_text()
s=s.replace('{TASK}','Validate this disposable Herdr endpoint. Do not edit files or invoke any lifecycle or pipeline commands. Respond READY only.')
s=s.replace('{FIRSTMATE_SPEC}','This is a passive harness-start proof. Do not use tools, spawn workers, or initialize no-mistakes. Wait for the external validator to stop this lab.')
p.write_text(s)
PY
printf '\n$ fm-spawn mine --scout --backend herdr (raw shell workload)\n'
"$ROOT/bin/fm-spawn.sh" mine "$PROJECT" "sh -c 'while :; do sleep 60; done'" --scout --backend herdr
META="$LAB/state/mine.meta"
TARGET=$(value "$META" window)
OLD_PANE=$(value "$META" herdr_pane_id)
OLD_TAB=$(value "$META" herdr_tab_id)
WT=$(value "$META" worktree)
OLD_ID=$(value "$META" herdr_process_identity)
[ -n "$OLD_ID" ] || { echo 'FAIL spawn did not publish identity'; exit 1; }
printf 'PUBLISHED target=%s identity=%s worktree=%s\n' "$TARGET" "$OLD_ID" "$WT"
cp "$META" "$E/live-original.meta"
printf 'unlanded sentinel\n' > "$WT/UNLANDED.txt"
# Foreground churn must not invalidate the persistent root process.
run pane send-keys "$OLD_PANE" C-c
sleep 0.3
run pane run "$OLD_PANE" "exec bash --noprofile --norc"
sleep 0.3
NEW_ID=$(backend fm_backend_herdr_pane_process_identity "$SESSION" "$OLD_PANE")
check "$NEW_ID" "$OLD_ID" 'exec preserves the root process binding'
# Recreate the same named session without saved layout, as a rebuild does.
lab teardown "$SESSION"
lab provision "$SESSION"
WS_JSON=$(lab run "$SESSION" workspace create --cwd "$WT" --label firstmate --no-focus)
WS=$(printf '%s' "$WS_JSON" | jq -r '.result.workspace.workspace_id')
TAB_JSON=$(lab run "$SESSION" tab create --workspace "$WS" --cwd "$WT" --label fm-mine --no-focus)
PANE=$(printf '%s' "$TAB_JSON" | jq -r '.result.root_pane.pane_id')
check "$PANE" "$OLD_PANE" 'fresh session actually reuses the recorded pane address'
FOREIGN_ID=$(backend fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
[ "$FOREIGN_ID" != "$OLD_ID" ] || { echo 'FAIL new process inherited old identity'; exit 1; }
printf 'RECREATED same-label/same-cwd target=%s:%s old=%s new=%s\n' "$SESSION" "$PANE" "$OLD_ID" "$FOREIGN_ID"
run pane run "$PANE" "printf 'UNRELATED-PANE-DO-NOT-STEER\\n'"
check "$(backend fm_backend_agent_state herdr "$TARGET" fm-mine)" missing 'main-home stale liveness'
# A surviving child's independently owned task record names the same recycled id.
# A child owns its own independently managed worktree, not the parent's slot.
CHILD_WT=$(cd "$PROJECT" && TREEHOUSE_ROOT="$FM_TASK_TMP/child-pools" treehouse get --lease --no-fetch)
awk -F= -v wt="$CHILD_WT" '$1=="worktree" {$0="worktree=" wt} {print}' "$META" > "$CHILD/state/mine.meta"
check "$(FM_HOME="$CHILD" backend fm_backend_agent_state herdr "$TARGET" fm-mine)" missing 'secondmate-home stale liveness'
for home in "$LAB" "$CHILD"; do
  export FM_HOME="$home"
  if backend fm_backend_capture herdr "$TARGET" 20 fm-mine; then echo 'FAIL stale capture allowed'; exit 1; else echo 'REFUSED stale capture'; fi
  if "$ROOT/bin/fm-send.sh" mine --key C-c; then echo 'FAIL stale key allowed'; exit 1; else echo 'REFUSED stale key'; fi
  if backend fm_backend_send_text_submit herdr "$TARGET" "touch '$FM_TASK_TMP/steered'" 1 0 0 fm-mine; then echo 'FAIL stale text allowed'; exit 1; else echo 'REFUSED stale text'; fi
  backend fm_backend_kill herdr "$TARGET" '' fm-mine
  lab run "$SESSION" pane get "$PANE" >/dev/null
  printf 'VERIFIED stale close left the unrelated pane present (%s)\n' "$home"
done
[ ! -e "$FM_TASK_TMP/steered" ] || { echo 'FAIL stale command reached foreign pane'; exit 1; }
run pane read "$PANE" --source recent --lines 12 --format text
export FM_HOME="$LAB"
printf '\n$ fm-spawn mine --relaunch --harness claude\n'
mkdir -p "$LAB/claude-config"
CLAUDE_CONFIG_DIR="$LAB/claude-config" "$ROOT/bin/fm-spawn.sh" mine --relaunch --harness claude
REBOUND=$(value "$META" window)
REBOUND_PANE=$(value "$META" herdr_pane_id)
[ "$REBOUND" != "$TARGET" ] || { echo 'FAIL relaunch reused stale endpoint'; exit 1; }
check "$(value "$META" worktree)" "$WT" 'relaunch preserves the recorded worktree'
check "$(< "$WT/UNLANDED.txt")" 'unlanded sentinel' 'relaunch preserves unlanded user data'
check "$(value "$META" herdr_process_identity)" "$(backend fm_backend_herdr_pane_process_identity "$SESSION" "$REBOUND_PANE")" 'relaunch publishes the new process binding'
lab run "$SESSION" pane get "$PANE" >/dev/null
printf 'VERIFIED rebind selected %s and retained unrelated %s\n' "$REBOUND" "$TARGET"
cp "$META" "$E/live-rebound.meta"
sleep 3
run pane read "$REBOUND_PANE" --source recent --lines 30 --format text
run pane process-info --pane "$REBOUND_PANE"
# Register the actual running Claude CLI through Herdr's real public registry;
# this checks process-backed liveness, not model authentication or completion.
run pane report-agent "$REBOUND_PANE" --source live-validation --agent claude --state idle
check "$(backend fm_backend_agent_state herdr "$REBOUND" fm-mine)" alive 'the new owned record recognizes the real running CLI'
cp "$META" "$FM_TASK_TMP/rebound.saved"
awk -F= -v old="$OLD_ID" '$1=="herdr_process_identity" {$0="herdr_process_identity=" old} {print}' "$META" > "$META.tmp"
mv "$META.tmp" "$META"
check "$(backend fm_backend_agent_state herdr "$REBOUND" fm-mine)" missing 'stale identity rejects a real live CLI despite matching label and cwd'
cp "$FM_TASK_TMP/rebound.saved" "$META"
# Retire the child's stale record without removing the current foreign pane.
FM_HOME="$CHILD" "$ROOT/bin/fm-teardown.sh" mine --force
[ ! -e "$CHILD/state/mine.meta" ] || { echo 'FAIL stale child record retained'; exit 1; }
lab run "$SESSION" pane get "$PANE" >/dev/null
printf 'VERIFIED stale child teardown removed its record, not the unrelated pane\n'
# A response-owned fresh projected spawn must clean itself up even if an old
# ambient record claims its newly minted address. A real Treehouse configuration
# with an unresolvable base forces acquisition to abort before B's publication.
printf 'on\n' > "$LAB/config/herdr-presentation-spaces"
printf 'base_branch = "missing-live-validation-base"\n' > "$PROJECT/treehouse.toml"
"$ROOT/bin/fm-brief.sh" b fixture --scout --herdr-lab
python3 - "$LAB/data/b/brief.md" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); p.write_text(p.read_text().replace('{TASK}','Exercise disposable failed worktree acquisition.').replace('{FIRSTMATE_SPEC}','Do not execute tools; this spawn should abort before launch.'))
PY
printf 'backend=herdr\nwindow=%s:w2:p2\nworktree=%s\nherdr_process_identity=%s\n' "$SESSION" "$WT" "$OLD_ID" > "$LAB/state/a.meta"
BEFORE=$(lab run "$SESSION" workspace list | jq -c '[.result.workspaces[].workspace_id] | sort')
if "$ROOT/bin/fm-spawn.sh" b "$PROJECT" "sh -c 'while :; do sleep 60; done'" --scout --backend herdr; then
  echo 'FAIL invalid Treehouse base did not abort spawn'; exit 1
fi
AFTER=$(lab run "$SESSION" workspace list | jq -c '[.result.workspaces[].workspace_id] | sort')
check "$AFTER" "$BEFORE" 'response-owned abort removes the disposable workspace'
[ ! -e "$LAB/state/b.meta" ] && [ -e "$LAB/state/a.meta" ] || { echo 'FAIL abort record isolation'; exit 1; }
if lab run "$SESSION" pane get w2:p2; then echo 'FAIL aborted B pane remains'; exit 1; fi
printf 'VERIFIED stale ambient A did not prevent cleanup of newly created B at w2:p2\n'
rm "$PROJECT/treehouse.toml" "$LAB/state/a.meta"
# Worktree teardown legitimately reaps all its cwd residents. Park the foreign
# shell outside that disposable worktree before testing exact endpoint cleanup.
mkdir -p "$FM_TASK_TMP/unrelated"
run pane run "$PANE" "cd '$FM_TASK_TMP/unrelated'"
sleep 0.3
# Exact close must permit record retirement after process-info becomes unavailable.
"$ROOT/bin/fm-teardown.sh" mine --force
[ ! -e "$META" ] || { echo 'FAIL owned record retained after close'; exit 1; }
if lab run "$SESSION" pane get "$REBOUND_PANE"; then echo 'FAIL owned pane survived teardown'; exit 1; fi
lab run "$SESSION" pane get "$PANE" >/dev/null
printf 'VERIFIED owned teardown removed endpoint and record, retained unrelated pane\n'
