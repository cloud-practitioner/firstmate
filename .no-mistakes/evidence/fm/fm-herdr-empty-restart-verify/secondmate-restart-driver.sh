#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/node/.no-mistakes/worktrees/450411b3e67c/01M55ZEBSTEQDE51HBJ3XNZ6TR
D="$ROOT/.test-herdr-runtime"
SESSION=fm-lab-empty
export ORIGINAL_PATH="$PATH"
export PATH="$D/tools:$PATH" HERDR_SESSION="$SESSION" FM_HOME=/fm-main
export FM_BACKEND=herdr FM_SPAWN_NO_GUARD=1 DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 CLAUDE_CODE_SAFE_MODE=1
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS NO_MISTAKES_GATE
lab() { PATH="$ORIGINAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" "$@"; }
cli() { lab run "$SESSION" "$@"; }
cleanup() {
  rc=$?
  trap - EXIT
  echo '=== Guarded secondmate lab teardown ==='
  if [[ -f "$FM_HERDR_LAB_STATE_DIR/$SESSION.fleet-state.json" ]]; then lab teardown "$SESSION" || rc=1; fi
  echo "teardown_exit=$rc"
  exit "$rc"
}
trap cleanup EXIT
# PRoot maps these virtual runtime homes to .test-herdr-runtime/virtual-*.
# All actual writes stay inside the run worktree. Source scripts run from the
# original gate worktree, with no root override or gate bypass.
"$ROOT/bin/fm-lab-home.sh" create "$FM_HOME"
printf 'claude\n' > "$FM_HOME/config/secondmate-harness"
printf 'herdr\n' > "$FM_HOME/config/backend"
printf 'off\n' > "$FM_HOME/config/herdr-presentation-spaces"
for id in alpha beta; do
  mate="/fm-$id"
  "$ROOT/bin/fm-lab-home.sh" create "$mate"
  git -C "$ROOT" archive df28e3fc7da62bbd42c0ba22c3d8927408b951ac | tar -x -C "$mate"
  git init -q "$mate"
  git -C "$mate" add .
  git -C "$mate" -c core.hooksPath=/dev/null -c user.name=Lab -c user.email=lab@example.invalid commit -qm 'Disposable secondmate code'
  FM_SECONDMATE_CHARTER="Isolated restart verification for $id. Read this charter, say LAB_READY_$id, then remain idle. Do not run any commands, create work, inspect other homes, or change any files. No projects are assigned." \
    "$ROOT/bin/fm-home-seed.sh" "$id" "$mate" --no-projects
 done
lab provision "$SESSION"
. "$ROOT/bin/fm-secondmate-liveness-lib.sh"
STATE="$FM_HOME/state"
FM_ROOT="$ROOT"
wait_alive() {
  local id=$1 target state
  target=$(fm_meta_get "$STATE/$id.meta" window)
  for ((i=0;i<90;i++)); do
    state=$(fm_backend_agent_state herdr "$target" "fm-$id")
    if [[ "$state" == alive ]]; then printf '%s: alive at %s\n' "$id" "$target"; return 0; fi
    sleep 1
  done
  cli pane read "${target#*:}" --lines 200 || true
  echo "ERROR: $id never became alive (last state=$state)"
  return 1
}
echo '=== Initial real Claude secondmates ==='
for id in alpha beta; do
  "$ROOT/bin/fm-spawn.sh" "$id" --secondmate
  wait_alive "$id"
  cp "$STATE/$id.meta" "$D/$id.before.meta"
 done
cli workspace list
for id in alpha beta; do
  target=$(fm_meta_get "$STATE/$id.meta" window)
  cli pane read "${target#*:}" --lines 200
 done

echo '=== Stop, move saved layout aside, restart empty ==='
lab stop "$SESSION"
sleep 0.5
mkdir -p "$D/secondmate-layout-aside"
for name in session.json session-snapshots; do
  if [[ -e "$D/config/herdr/sessions/$SESSION/$name" ]]; then
    mv "$D/config/herdr/sessions/$SESSION/$name" "$D/secondmate-layout-aside/$name"
    echo "moved_aside=$name"
  fi
done
lab provision "$SESSION"
layout=$(cli workspace list)
printf '%s\n' "$layout"
printf '%s' "$layout" | jq -e '.result.workspaces | length == 0'

echo '=== Recover every registered secondmate through the shared liveness owner ==='
for id in alpha beta; do
  meta="$STATE/$id.meta"
  fm_secondmate_liveness_lock "$id"
  fm_secondmate_liveness_probe "$meta" "$id" full
  printf '%s: status=%s state=%s kill=%s cause=%s\n' "$id" "$FM_SM_LIVE_STATUS" "$FM_SM_LIVE_STATE" "$FM_SM_LIVE_KILL" "$FM_SM_LIVE_CAUSE"
  [[ "$FM_SM_LIVE_STATUS" == relaunchable && "$FM_SM_LIVE_STATE" == missing && "$FM_SM_LIVE_KILL" == 0 ]]
  fm_secondmate_liveness_relaunch "$meta" "$id" 120 || { printf '%s\n' "$FM_SM_LIVE_OUT"; exit 1; }
  printf '%s\n' "$FM_SM_LIVE_OUT"
  fm_secondmate_liveness_unlock "$id"
  wait_alive "$id"
  old_identity=$(fm_meta_get "$D/$id.before.meta" herdr_process_identity)
  new_identity=$(fm_meta_get "$meta" herdr_process_identity)
  printf '%s: old_identity=%s new_identity=%s new_window=%s\n' "$id" "$old_identity" "$new_identity" "$(fm_meta_get "$meta" window)"
  [[ -n "$new_identity" && "$new_identity" != "$old_identity" ]]
 done
layout=$(cli workspace list)
printf '%s\n' "$layout"
printf '%s' "$layout" | jq -e '.result.workspaces | length == 2 and ([.[].label] | sort == ["2ndmate-alpha", "2ndmate-beta"]) and all(.[]; .tab_count == 1)'
for id in alpha beta; do
  fm_secondmate_liveness_lock "$id"
  fm_secondmate_liveness_probe "$STATE/$id.meta" "$id" full
  printf 'repeat_probe_%s=%s\n' "$id" "$FM_SM_LIVE_STATUS"
  [[ "$FM_SM_LIVE_STATUS" == alive ]]
  fm_secondmate_liveness_unlock "$id"
  target=$(fm_meta_get "$STATE/$id.meta" window)
  cli pane read "${target#*:}" --lines 200
 done
echo 'SCENARIO_PASS: every registered secondmate relaunches with a new process binding into a fresh workspace, with one tab per mate and no husks or duplicates.'
