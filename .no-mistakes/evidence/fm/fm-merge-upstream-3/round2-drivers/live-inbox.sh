#!/usr/bin/env bash
set -eu
umask 022
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M467Y2KVPY0ZYM8V5V6DQB86
export PATH="$ROOT/.validation/tools/usr/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/.validation/tools/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset FM_HOME FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
LAB=$(mktemp -d "$ROOT/l.XXXXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
mkdir -p "$LAB/tmux" "$LAB/agent-dir" "$LAB/sessions"
WATCHPID=
cleanup() {
  [ -z "$WATCHPID" ] || { kill "$WATCHPID" 2>/dev/null || true; wait "$WATCHPID" 2>/dev/null || true; }
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server 2>/dev/null || true
  rm -rf "$LAB"
}
trap cleanup EXIT
GEN=$(bin/fm-busy-event.sh arm "$LAB/state" steer)
ln -s "$ROOT/.validation/pi101/node_modules" "$ROOT/.validation/node_modules" 2>/dev/null || true
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
  TMUX_TMPDIR="$LAB/tmux" PI_CODING_AGENT_DIR="$LAB/agent-dir" PROOF_BUSY_GEN="$GEN" \
  tmux -L fm-lab -f /dev/null new-session -d -s primary -n fm-steer -x 120 -y 40 -c "$PWD" -e FM_HOME="$LAB" \
  "pi --offline --approve --no-context-files --no-extensions --no-skills --no-prompt-templates --no-themes --no-builtin-tools --extension '$ROOT/.validation/hold-provider.ts' --model merge-proof/hold --session-dir '$LAB/sessions' --tui-mode regular"
export TMUX_TMPDIR="$LAB/tmux"
export TMUX=$(tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')
export FM_HOME="$LAB"
for i in $(seq 1 100); do
  tmux -L fm-lab capture-pane -p -t primary > "$LAB/screen.txt"
  grep -q 'merge-proof' "$LAB/screen.txt" && break
  sleep 0.1
done
tmux -L fm-lab send-keys -t primary -l 'Hold this provider turn open for the busy-inbox proof.'
tmux -L fm-lab send-keys -t primary Enter
for i in $(seq 1 100); do
  grep -q 'state=busy source=pi-ext' "$LAB/state/steer.busy-state" && break
  sleep 0.1
done
grep -q 'state=busy source=pi-ext' "$LAB/state/steer.busy-state" || { tmux -L fm-lab capture-pane -p -t primary; exit 1; }
printf 'window=primary:fm-steer\nbackend=tmux\nkind=ship\nharness=pi\n' > "$LAB/state/steer.meta"
. "$ROOT/bin/fm-task-inbox-lib.sh"
REC=$(fm_task_inbox_write "$LAB/state" steer 'Acknowledge this durable instruction at the next safe boundary.')
export FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 FM_TASK_INBOX_GRACE_SECS=0 FM_TASK_INBOX_BUSY_MAX=2
bin/fm-watch.sh > "$LAB/watch.out" 2> "$LAB/watch.err" &
WATCHPID=$!
for i in $(seq 1 300); do
  grep -q 'stuck-busy' "$LAB/watch.out" && break
  kill -0 "$WATCHPID" 2>/dev/null || break
  sleep 0.1
done
wait "$WATCHPID"; WATCHPID=
grep -q 'stuck-busy after 2 consecutive busy-deferred due doorbells' "$LAB/watch.out"
[ -f "$REC" ]
cp "$LAB/watch.out" "$E/live-inbox-wake.txt"
cp "$LAB/state/.wake-queue" "$E/live-inbox-queue.txt"
cp "$LAB/state/steer.busy-state" "$E/live-inbox-busy-state.txt"
tmux -L fm-lab capture-pane -p -t primary > "$E/live-inbox-pane.txt"
! grep -q 'Firstmate instruction waiting' "$E/live-inbox-pane.txt"
bin/fm-wake-drain.sh > "$LAB/drain.out" 2> "$LAB/drain.err"
ACK=$(python3 - "$LAB/drain.err" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
m=re.search(r'WAKE_ACK_REQUIRED:.*--ack-through (\d+) --recovery-generation ([A-Za-z0-9._-]+)',s)
if not m: raise SystemExit('drain did not offer its generation-bound acknowledgement')
print(m.group(1),m.group(2))
PY
)
read -r SEQ RECOVERY <<< "$ACK"
bin/fm-wake-drain.sh --ack-through "$SEQ" --recovery-generation "$RECOVERY"
cp "$LAB/drain.err" "$E/live-inbox-ack.txt"
FIRST=$(wc -l < "$LAB/state/.wake-queue")
bin/fm-watch.sh > "$LAB/successor.out" 2> "$LAB/successor.err" &
WATCHPID=$!
sleep 3
[ "$FIRST" -eq "$(wc -l < "$LAB/state/.wake-queue")" ]
[ ! -s "$LAB/successor.out" ]
kill "$WATCHPID"; wait "$WATCHPID" 2>/dev/null || true; WATCHPID=
printf 'Busy primary remained in its live provider turn; instruction persisted, no doorbell appeared, and a successor watcher did not duplicate the escalation.\n'
