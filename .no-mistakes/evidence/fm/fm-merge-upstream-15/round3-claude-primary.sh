#!/usr/bin/env bash
set -eu
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M64ZPT5AJ4390HHRPB92ZDZC
LAB=$(mktemp -d "$PWD/l.XXXXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
export PATH="$ROOT/.test-validation/tools/tmux/usr/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/.test-validation/tools/tmux/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p "$LAB/tmux"
export TMUX_TMPDIR=$LAB/tmux
SHIM=$(bin/fm-live-claude.sh shim "$LAB/claude-shim")
BEFORE=$(readlink "$(command -v claude)")
cleanup() {
 rc=$?
 set +e
 tmux -L fm-lab kill-server >/dev/null 2>&1
 AFTER=$(readlink "$(command -v claude)")
 printf 'launcher_before=%s\nlauncher_after=%s\n' "$BEFORE" "$AFTER" >> "$E/round3-claude-primary.log"
 [ "$BEFORE" = "$AFTER" ] || rc=1
 rm -rf "$LAB"
 exit "$rc"
}
trap cleanup EXIT
printf 'set -g remain-on-exit on\n' > "$LAB/tmux.conf"
touch "$LAB/config/supervision-host"
printf -v CMD '%q --print --model sonnet --effort low --setting-sources project,local --output-format json %q' "$SHIM/claude" 'Reply exactly FM_MERGE15_ROUND3_READY. Do not call tools.'
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u TMUX -u HERDR_ENV -u HERDR_SESSION -u HERDR_SOCKET_PATH TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab -f "$LAB/tmux.conf" new-session -d -s primary -x 120 -y 40 -c "$PWD" -e FM_HOME="$LAB" "$CMD"
for i in $(seq 1 100); do
 dead=$(tmux -L fm-lab display-message -p -t primary '#{pane_dead}')
 [ "$dead" = 1 ] && break
 sleep 1
done
tmux -L fm-lab capture-pane -p -S - -t primary > "$E/round3-claude-primary.log"
printf '\nwindow_grid=' >> "$E/round3-claude-primary.log"
tmux -L fm-lab display-message -p -t primary '#{pane_width}x#{pane_height}; dead=#{pane_dead}; exit=#{pane_dead_status}' >> "$E/round3-claude-primary.log"
python3 - "$E/round3-claude-primary.log" <<'PY'
import sys
s=open(sys.argv[1]).read()
assert 'FM_MERGE15_ROUND3_READY' in s,s
assert 'exit=0' in s,s
PY
