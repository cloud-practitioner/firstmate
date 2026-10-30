#!/usr/bin/env bash
set -eu
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M64ZPT5AJ4390HHRPB92ZDZC
LAB=$(mktemp -d "$PWD/l.XXXXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
export PATH="$ROOT/.test-validation/tools/tmux/usr/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/.test-validation/tools/tmux/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p "$LAB/tmux" "$LAB/user"
export TMUX_TMPDIR=$LAB/tmux
cleanup() { tmux -L fm-lab kill-server >/dev/null 2>&1 || true; rm -rf "$LAB"; }
trap cleanup EXIT
printf 'set -g remain-on-exit on\n' > "$LAB/tmux.conf"
printf -v CMD 'env -i HOME=%q PATH=%q TERM=xterm-256color TMPDIR=%q FM_HOME=%q %q -p %q --effort low' "$LAB/user" "$PATH" "$LAB" "$LAB" "$(command -v agy)" 'Reply FM_MERGE15_AGY_READY. Do not call tools.'
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u TMUX -u HERDR_ENV -u HERDR_SESSION -u HERDR_SOCKET_PATH TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab -f "$LAB/tmux.conf" new-session -d -s primary -x 120 -y 40 -c "$PWD" -e FM_HOME="$LAB" "$CMD"
sleep 12
tmux -L fm-lab capture-pane -p -S - -t primary > "$E/round3-agy-auth-probe.log"
printf '\nwindow_grid=' >> "$E/round3-agy-auth-probe.log"
tmux -L fm-lab display-message -p -t primary '#{pane_width}x#{pane_height}; dead=#{pane_dead}; exit=#{pane_dead_status}' >> "$E/round3-agy-auth-probe.log"
