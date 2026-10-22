#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M5GMXRP8TEGYK8ZJPXTCW65Z
export PATH="$ROOT/.test-live/bin:$PATH" TMPDIR="$ROOT/.test-live/tmp" FM_BACKEND=tmux
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS NM_HOME
LAB=$(mktemp -d "$ROOT/.l.XXXXXX")
export FM_HOME="$LAB" TMUX_TMPDIR="$LAB/tmux"
wpid=
cleanup() { [ -z "$wpid" ] || { kill "$wpid" 2>/dev/null || true; wait "$wpid" 2>/dev/null || true; }; tmux -L fm-lab kill-server 2>/dev/null || true; rm -rf "$LAB"; }
trap cleanup EXIT
bin/fm-lab-home.sh create "$LAB"
mkdir -p "$LAB/tmux" "$LAB/projects/fixture"
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab new-session -d -x 120 -y 40 -s primary -n fm-monitor -c "$ROOT" -e FM_HOME="$LAB" claude
export TMUX="$(tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')"
sleep 8
window=primary:fm-monitor
key=primary_fm-monitor
printf 'window=%s\nkind=scout\nharness=claude\nworktree=%s\n' "$window" "$LAB/projects/fixture" > "$LAB/state/monitor.meta"
printf 'working: validation fixture updated the task progress record\n' > "$LAB/state/monitor.status"
bash -c '. bin/fm-wake-lib.sh; fm_wake_status_mark_current "$1" "$2"' _ "$LAB/state" "$LAB/state/monitor.status"
printf '\n=== Real endpoint semantic state ===\n'
bin/fm-crew-state.sh monitor
printf '\n=== First unknown-but-alive sight remains actionable ===\n'
FM_POLL=1 FM_SIGNAL_GRACE=1 FM_STALE_ESCALATE_SECS=600 FM_PAUSE_RESURFACE_SECS=999 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 timeout 30 bin/fm-watch.sh > "$EVIDENCE/watch-first.txt" 2>&1 & wpid=$!
set +e; wait "$wpid"; rc=$?; set -e; wpid=
printf 'watch_first_exit=%s\n' "$rc"
while IFS= read -r line; do printf '%s\n' "$line"; done < "$EVIDENCE/watch-first.txt"
[ "$rc" = 0 ]
[ -s "$LAB/state/.paused-resurfaced-$key" ]
bin/fm-wake-drain.sh > "$EVIDENCE/watch-drain.txt" 2> "$LAB/drain.err"
python3 - "$LAB/drain.err" > "$LAB/ack-args" <<'PY'
import re,sys
s=open(sys.argv[1]).read();m=re.search(r'--ack-through ([0-9]+) --recovery-generation ([A-Za-z0-9._-]+)',s)
if not m: raise SystemExit('Missing drain acknowledgement')
print(*m.groups())
PY
read -r sequence generation < "$LAB/ack-args"
bin/fm-wake-drain.sh --ack-through "$sequence" --recovery-generation "$generation"
printf '\n=== New rendered hash while progress is recent: repeat alarm bounded ===\n'
tmux -L fm-lab send-keys -t "$window" -l 'validation text not submitted'
sleep 1
printf 'prior-rendered-hash' > "$LAB/state/.hash-$key"
printf '0\n' > "$LAB/state/.count-$key"
FM_POLL=1 FM_SIGNAL_GRACE=1 FM_STALE_ESCALATE_SECS=600 FM_PAUSE_RESURFACE_SECS=999 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 bin/fm-watch.sh > "$EVIDENCE/watch-repeat.txt" 2>&1 & wpid=$!
for ((i=0; i<90; i++)); do
  kill -0 "$wpid" 2>/dev/null || break
  n=$(cat "$LAB/state/.count-$key" 2>/dev/null || echo 0)
  [ "$n" -lt 3 ] || break
  sleep 0.5
done
printf 'repeat_observation: pid=%s count=%s output_bytes=%s beacon_exists=%s\n' "$wpid" "$(cat "$LAB/state/.count-$key" 2>/dev/null || echo missing)" "$(wc -c < "$EVIDENCE/watch-repeat.txt")" "$([ -f "$LAB/state/.last-watcher-beat" ] && echo yes || echo no)"
kill -0 "$wpid"
[ ! -s "$EVIDENCE/watch-repeat.txt" ]
[ -f "$LAB/state/.last-watcher-beat" ]
[ "$(<"$LAB/state/.count-$key")" -ge 3 ]
printf 'repeat_watcher_still_running=yes completed_polls=%s repeat_output_empty=yes\n' "$(<"$LAB/state/.count-$key")"
kill "$wpid"; wait "$wpid" || true; wpid=
bin/fm-wake-drain.sh > "$LAB/repeat-drain.out" 2> "$LAB/drain.err"
python3 - "$LAB/drain.err" > "$LAB/ack-args" <<'PY'
import re,sys
s=open(sys.argv[1]).read();m=re.search(r'--ack-through ([0-9]+) --recovery-generation ([A-Za-z0-9._-]+)',s)
if not m: raise SystemExit('Missing repeat-stop drain acknowledgement')
print(*m.groups())
PY
read -r sequence generation < "$LAB/ack-args"
bin/fm-wake-drain.sh --ack-through "$sequence" --recovery-generation "$generation"
printf '\n=== Adversarial: liveness without recent progress must alarm again ===\n'
touch -d '1000 seconds ago' "$LAB/state/monitor.status"
bash -c '. bin/fm-wake-lib.sh; fm_wake_status_mark_current "$1" "$2"' _ "$LAB/state" "$LAB/state/monitor.status"
tmux -L fm-lab send-keys -t "$window" -l ' changed viewport'
printf 'older-rendered-hash' > "$LAB/state/.hash-$key"
printf '0\n' > "$LAB/state/.count-$key"
FM_POLL=1 FM_SIGNAL_GRACE=1 FM_STALE_ESCALATE_SECS=600 FM_PAUSE_RESURFACE_SECS=999 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 timeout 30 bin/fm-watch.sh > "$EVIDENCE/watch-no-progress.txt" 2>&1 & wpid=$!
set +e; wait "$wpid"; rc=$?; set -e; wpid=
printf 'no_progress_exit=%s\n' "$rc"
while IFS= read -r line; do printf '%s\n' "$line"; done < "$EVIDENCE/watch-no-progress.txt"
[ "$rc" = 0 ]
grep -Fq "stale: $window" "$EVIDENCE/watch-no-progress.txt"
printf '\n=== Actual terminal inspected ===\n'
tmux -L fm-lab capture-pane -p -t "$window" | tee "$EVIDENCE/watch-terminal.txt"
