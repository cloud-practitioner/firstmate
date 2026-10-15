#!/usr/bin/env bash
set -eu
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M4ZWHVKH10H7VQ0P4VH5RD51
export PATH="$ROOT/.live-test-lab/tools/tmux-local/usr/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/.live-test-lab/tools/tmux-local/usr/lib/x86_64-linux-gnu"
LAB=$(mktemp -d "$PWD/.pXXXX")
cleanup() { TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server >/dev/null 2>&1 || true; rm -rf "$LAB"; }
trap cleanup EXIT
bin/fm-lab-home.sh create "$LAB"
mkdir -p "$LAB/tmux"
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE TMUX_TMPDIR="$LAB/tmux" DISABLE_AUTOUPDATER=1 tmux -L fm-lab new-session -d -s primary -c "$PWD" -x 120 -y 40 -e FM_HOME="$LAB" claude
export TMUX=$(TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab display-message -p '#{socket_path},#{pid},0')
export FM_HOME="$LAB" FM_BACKEND=tmux FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
append() { bash -c '. "$1/bin/fm-wake-lib.sh"; fm_wake_append check "$2" "$3"' _ "$ROOT" "$1" "$2"; }
checkpoint() {
 set +e
 bin/fm-watch-checkpoint.sh --seconds "$1" > "$E/checkpoint-$2.txt" 2>&1
 rc=$?
 set -e
 printf 'Checkpoint %s exit=%s\n' "$2" "$rc"
 cat "$E/checkpoint-$2.txt"
}
checkpoint 2 quiet
[ "$rc" -eq 124 ]
[ ! -f "$LAB/state/.watch.lock/pid" ]
append retained 'check: real durable wake retained for the captain'
checkpoint 8 announced
[ "$rc" -eq 0 ]
grep -q '^check: rearm-resurface$' "$E/checkpoint-announced.txt"
marker=$(cat "$LAB/state/.watcher-down")
printf 'Announced recovery generation: %s\n' "$marker"
checkpoint 2 preserved
[ "$rc" -eq 124 ]
! grep -q 'rearm-resurface' "$E/checkpoint-preserved.txt"
[ "$(cat "$LAB/state/.watcher-down")" = "$marker" ]
[ ! -f "$LAB/state/.watch.lock/pid" ]
printf 'Still-unacknowledged real wake queue:\n'
cat "$LAB/state/.wake-queue"
cp "$LAB/state/.wake-queue" "$E/checkpoint-retained-queue.tsv"
( sleep 1; append concurrent 'check: appended during the next real checkpoint' ) &
append_pid=$!
checkpoint 8 appended
wait "$append_pid"
[ "$rc" -eq 0 ]
grep -q '^check: rearm-resurface$' "$E/checkpoint-appended.txt"
grep -q 'appended during the next real checkpoint' "$LAB/state/.wake-queue"
printf 'Real checkpoint retained the original generation without repeating recovery, then surfaced a new concurrent wake. Private primary and home removed.\n'
