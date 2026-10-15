#!/usr/bin/env bash
set -eu
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M4ZWHVKH10H7VQ0P4VH5RD51
export PATH="$ROOT/.live-test-lab/tools/tmux-local/usr/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/.live-test-lab/tools/tmux-local/usr/lib/x86_64-linux-gnu"
LAB=$(mktemp -d "$PWD/.pXXXX")
cleanup() {
  if TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab capture-pane -p -t primary 2>/dev/null | grep -q '^[[:space:]]*Background work is running'; then
    TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab send-keys -t primary Enter >/dev/null 2>&1 || true
    sleep 1
  fi
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server >/dev/null 2>&1 || true
  rm -rf "$LAB"
}
trap cleanup EXIT
bin/fm-lab-home.sh create "$LAB"
mkdir -p "$LAB/tmux"
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE TMUX_TMPDIR="$LAB/tmux" DISABLE_AUTOUPDATER=1 tmux -L fm-lab new-session -d -s primary -c "$PWD" -x 120 -y 40 -e FM_HOME="$LAB" claude
T() { TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab "$@"; }
capture() { T capture-pane -p -t primary; }
sleep 8
T send-keys -t primary -l '! sleep 120'
T send-keys -t primary Enter
sleep 4
capture > "$E/claude-bash-running.txt"
T send-keys -t primary C-b
sleep 3
capture > "$E/claude-bash-background.txt"
T send-keys -t primary -l '/exit'
sleep 1
T send-keys -t primary Enter
sleep 3
capture > "$E/claude-exit-picker.txt"
T capture-pane -p -e -t primary > "$E/claude-exit-picker.ansi"
printf 'Real Claude exit picker surface:\n'
cat "$E/claude-exit-picker.txt"
# Only a real rendered picker is evidence; do not manufacture one if this CLI has changed.
if ! grep -q '^[[:space:]]*Background work is running' "$E/claude-exit-picker.txt"; then
  printf 'Picker was not reproduced; inspect actual capture.\n'
  exit 4
fi
printf 'window=primary:0\nworktree=%s\nproject=%s\nkind=ship\nmode=direct-PR\nharness=claude\n' "$ROOT" "$ROOT" > "$LAB/state/picker.meta"
chmod 600 "$LAB/state/picker.meta"
SOCKET=$(T display-message -p '#{socket_path},#{pid},0')
# The real watcher inherits this private socket just as a script in the primary pane does.
set +e
env -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE FM_HOME="$LAB" FM_BACKEND=tmux TMUX="$SOCKET" FM_POLL=1 FM_SIGNAL_GRACE=0 FM_HEARTBEAT=300 bin/fm-watch-checkpoint.sh --seconds 18 > "$E/claude-picker-watcher.txt" 2>&1
rc=$?
set -e
printf 'Watcher checkpoint exit=%s\n' "$rc"
cat "$E/claude-picker-watcher.txt"
[ "$rc" -eq 0 ]
grep -q 'blocked-on-prompt: Claude background-task exit picker' "$E/claude-picker-watcher.txt"
printf 'Live watcher named the rendered blocking prompt. Lab and private tmux server removed by EXIT trap.\n'
