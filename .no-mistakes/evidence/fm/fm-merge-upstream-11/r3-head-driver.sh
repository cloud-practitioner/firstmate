#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
export PATH="$ROOT/.test-live/bin:$PATH" TMPDIR="$ROOT/.test-live/tmp" FM_BACKEND=tmux GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 FM_CREW_STATE_NO_FORGE=1 DISABLE_AUTOUPDATER=1
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS NM_HOME
LAB=$(mktemp -d "$ROOT/.l.XXXXXX")
export FM_HOME="$LAB" TMUX_TMPDIR="$LAB/tmux"
cleanup() { tmux -L fm-lab kill-server 2>/dev/null || true; rm -rf "$LAB"; }
trap cleanup EXIT

bin/fm-lab-home.sh create "$LAB"
export HOME="$LAB/user-home" CLAUDE_CONFIG_DIR="$LAB/claude-config" XDG_CONFIG_HOME="$LAB/xdg-config" XDG_DATA_HOME="$LAB/xdg-data" XDG_STATE_HOME="$LAB/xdg-state" XDG_CACHE_HOME="$LAB/xdg-cache" DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
mkdir -p "$HOME" "$CLAUDE_CONFIG_DIR"

mkdir -p "$LAB/tmux" "$LAB/projects/disposable"
touch "$LAB/config/supervision-host"
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab new-session -d -x 120 -y 40 -s primary -c "$ROOT" -e FM_HOME="$LAB" "$ROOT/.test-live/bin/claude"
sleep 8
tmux -L fm-lab rename-window -t primary:0 fm-head-probe
export TMUX="$(tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')"
[ "$(tmux -L fm-lab display-message -p -t primary '#{pane_dead}')" = 0 ]
project="$LAB/projects/disposable"
git -C "$project" init -q -b main
git -C "$project" -c user.name=Test -c user.email=test@example.invalid commit -qm 'Disposable baseline' --allow-empty
git init -q --bare "$LAB/bare.git"
git -C "$project" remote add origin "$LAB/bare.git"
git -C "$project" push -q origin main
git -C "$project" worktree add -q --detach "$LAB/task" HEAD
git -C "$LAB/task" -c user.name=Test -c user.email=test@example.invalid commit -qm 'Unpublished fix' --allow-empty
head=$(git -C "$LAB/task" rev-parse HEAD)
gen=$(bin/fm-busy-event.sh arm "$LAB/state" head-probe --state idle --source fm-recovery --event live-inspection)
printf 'window=primary:fm-head-probe\nkind=ship\nharness=claude\nmode=direct-PR\nworktree=%s\nproject=%s\nbusy_gen=%s\n' "$LAB/task" "$project" "$gen" > "$LAB/state/head-probe.meta"
printf 'done: PR https://bitbucket.org/iqxbusiness/disposable/pull-requests/1 CI-ready, checks green\n' > "$LAB/state/head-probe.status"
printf '\n=== Real idle endpoint, explicitly reconciled through the recovery event writer ===\n'
bash -c '. bin/fm-backend.sh; fm_backend_agent_alive tmux primary:fm-head-probe'
printf '\n=== Adversarial: a green Bitbucket report must not hide an unpreserved head ===\n'
out=$(bin/fm-crew-state.sh head-probe)
printf '%s\n' "$out"
[[ "$out" = 'state: blocked'* ]] && [[ "$out" = *"named head $head is unreachable outside the worker copy"* ]]
printf '\n=== Preserve the named head to a disposable local bare remote ===\n'
git -C "$LAB/task" push -q origin HEAD:refs/heads/probe
out=$(bin/fm-crew-state.sh head-probe)
printf '%s\n' "$out"
[[ "$out" = 'state: done'* ]] && [[ "$out" = *CI-ready* ]]
printf '\nNo real forge read, write, PR, or pipeline was used. The task remained detached, so crew-state had no pipeline branch to query.\n'
