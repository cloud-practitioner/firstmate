#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/node/.no-mistakes/worktrees/450411b3e67c/01M55ZEBSTEQDE51HBJ3XNZ6TR
D="$ROOT/.test-herdr-runtime"
SESSION=fm-lab-empty
export ORIGINAL_PATH="$PATH"
export PATH="$D/tools:$PATH" HERDR_SESSION="$SESSION" FM_HOME="$D/main" FM_STATE_OVERRIDE="$D/main/state"
export FM_CONFIG_OVERRIDE="$D/main/config" FM_BACKEND=herdr
unset FM_ROOT_OVERRIDE FM_DATA_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
lab() { PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" "$@"; }
cli() { lab run "$SESSION" "$@"; }
cleanup() {
  rc=$?
  trap - EXIT
  echo "=== Guarded lab teardown ==="
  lab teardown "$SESSION" || rc=1
  echo "teardown_exit=$rc"
  exit "$rc"
}
trap cleanup EXIT
mkdir -p "$FM_HOME/state" "$FM_HOME/config" "$D/crew"
printf 'off\n' > "$FM_HOME/config/herdr-presentation-spaces"
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
lab provision "$SESSION"
echo '=== Initial Herdr session ==='
cli status --json
raw=$(fm_backend_herdr_container_ensure "$D/crew")
container=${raw%%$'\t'*}
seed=${raw#*$'\t'}
ids=$(fm_backend_herdr_create_task "$container" fm-recorded-worker "$D/crew" "$seed")
read -r tab pane <<< "$ids"
identity=$(fm_backend_herdr_pane_process_identity "$SESSION" "$pane")
cat > "$FM_HOME/state/recorded-worker.meta" <<EOF
backend=herdr
window=$SESSION:$pane
worktree=$D/crew
herdr_process_identity=$identity
EOF
printf 'old_container=%s old_tab=%s old_pane=%s identity=%s\n' "$container" "$tab" "$pane" "$identity"
cli workspace list
cli pane process-info --pane "$pane"

echo '=== Stop lab; move saved layout and snapshots aside ==='
lab stop "$SESSION"
sleep 0.5
session_dir="$D/config/herdr/sessions/$SESSION"
mkdir -p "$D/layout-aside"
for name in session.json session-snapshots; do
  if [[ -e "$session_dir/$name" ]]; then
    mv "$session_dir/$name" "$D/layout-aside/$name"
    printf 'moved_aside=%s\n' "$name"
  else
    printf 'already_absent=%s\n' "$name"
  fi
done
[[ -f "$D/layout-aside/session.json" ]]
lab provision "$SESSION"
echo '=== Empty session after restart ==='
layout=$(cli workspace list)
printf '%s\n' "$layout"
printf '%s' "$layout" | jq -e '.result.workspaces | length == 0'
state=$(fm_backend_agent_state herdr "$SESSION:$pane" fm-recorded-worker)
printf 'recorded_missing_pane_state=%s\n' "$state"
[[ "$state" == missing ]]

echo '=== Adversary: recycle the exact pane ID, label, and cwd ==='
raw=$(fm_backend_herdr_container_ensure "$D/crew")
new_container=${raw%%$'\t'*}
new_seed=${raw#*$'\t'}
ws=${new_container#*:}
[[ "$ws" == w1 ]]
out=$(cli tab create --workspace "$ws" --cwd "$D/crew" --label fm-recorded-worker --no-focus)
printf '%s\n' "$out"
foreign_pane=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')
[[ "$foreign_pane" == "$pane" ]]
foreign_identity=$(fm_backend_herdr_pane_process_identity "$SESSION" "$foreign_pane")
printf 'recycled_pane=%s new_identity=%s\n' "$foreign_pane" "$foreign_identity"
[[ "$foreign_identity" != "$identity" ]]
state=$(fm_backend_agent_state herdr "$SESSION:$pane" fm-recorded-worker)
printf 'foreign_same_label_same_cwd_state=%s\n' "$state"
[[ "$state" == missing ]]
if fm_backend_send_key herdr "$SESSION:$pane" Enter fm-recorded-worker; then
  echo 'ERROR: send-key accepted foreign pane'; exit 1
else
  echo 'send_key=refused_for_foreign_pane'
fi
if fm_backend_capture herdr "$SESSION:$pane" 20 fm-recorded-worker; then
  echo 'ERROR: captured foreign pane'; exit 1
else
  echo 'capture=refused_for_foreign_pane'
fi
fm_backend_kill herdr "$SESSION:$pane"
echo '=== Foreign pane survives guarded close ==='
cli pane get "$foreign_pane"
ids=$(fm_backend_herdr_create_task "$new_container" fm-recorded-worker "$D/crew")
read -r replacement_tab replacement_pane <<< "$ids"
[[ "$replacement_pane" != "$foreign_pane" ]]
printf 'replacement_tab=%s replacement_pane=%s preserved_foreign_pane=%s\n' "$replacement_tab" "$replacement_pane" "$foreign_pane"
cli pane get "$foreign_pane"
cli tab list --workspace "$ws"
echo 'SCENARIO_PASS: absent recorded pane reads missing; layout is empty and IDs restart at w1; recycled address rejects input/capture/close and replacement preserves the foreign pane.'
