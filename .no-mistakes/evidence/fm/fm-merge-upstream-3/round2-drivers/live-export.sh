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
mkdir -p "$LAB/tmux" "$LAB/agent-dir" "$LAB/sessions" "$LAB/projects/probe"
printf 'alpha from the live fixture\n' > "$LAB/projects/probe/fixture.txt"
printf 'on\n' > "$LAB/config/calm"
cleanup() {
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server 2>/dev/null || true
  FM_HOME="$LAB" bin/fm-watch-arm.sh --stop >/dev/null 2>&1 || true
  rm -rf "$LAB"
}
trap cleanup EXIT
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
  TMUX_TMPDIR="$LAB/tmux" PI_CODING_AGENT_DIR="$LAB/agent-dir" BASH_ENV="$ROOT/.validation/lab-shell-env.sh" PROOF_ROOT="$ROOT" \
  FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
  tmux -L fm-lab -f /dev/null new-session -d -s primary -n fm-primary -x 120 -y 40 -c "$PWD" -e FM_HOME="$LAB" \
  "node '$ROOT/.validation/pi101/dist/cli.js' --offline --approve --no-context-files --no-extensions --no-skills --no-prompt-templates --no-themes --extension '$ROOT/.validation/export-provider.ts' --extension '$ROOT/.pi/extensions/fm-calm.ts' --extension '$ROOT/.pi/extensions/fm-primary-pi-watch.ts' --model export-proof/local --tools grep,find,fm_watch_arm_pi --session-dir '$LAB/sessions' --tui-mode regular"
export TMUX_TMPDIR="$LAB/tmux"
export TMUX=$(tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')
export FM_HOME="$LAB"
for i in $(seq 1 200); do
  tmux -L fm-lab capture-pane -p -t primary > "$LAB/screen.txt"
  grep -q 'export-proof' "$LAB/screen.txt" && break
  sleep 0.1
done
tmux -L fm-lab send-keys -t primary -l 'Run the disposable grep, find and watcher proof.'
tmux -L fm-lab send-keys -t primary Enter
for i in $(seq 1 500); do
  tmux -L fm-lab capture-pane -p -t primary > "$LAB/screen.txt"
  grep -q 'The real grep, find and watcher checks are complete.' "$LAB/screen.txt" && break
  sleep 0.1
done
grep -q 'The real grep, find and watcher checks are complete.' "$LAB/screen.txt" || { cp "$LAB/screen.txt" "$E/native-pi101-failure.txt"; exit 1; }
tmux -L fm-lab send-keys -t primary -l "/export $E/native-pi101-calm-export.html"
tmux -L fm-lab send-keys -t primary Enter
for i in $(seq 1 200); do
  [ -s "$E/native-pi101-calm-export.html" ] && break
  sleep 0.1
done
[ -s "$E/native-pi101-calm-export.html" ]
FILE=$(ls "$LAB/sessions"/*.jsonl | head -1)
cp "$FILE" "$E/native-pi101-calm-session.jsonl"
python3 - "$FILE" <<'PY'
import json,sys
entries=[json.loads(s) for s in open(sys.argv[1])]
results=[e['message'] for e in entries if e.get('type')=='message' and e['message'].get('role')=='toolResult']
assert {r['toolName'] for r in results}=={'grep','find','fm_watch_arm_pi'}, results
assert all(not r.get('isError') for r in results), results
assert any('alpha from the live fixture' in str(r['content']) for r in results if r['toolName']=='grep')
assert any('fixture.txt' in str(r['content']) for r in results if r['toolName']=='find')
print('Native Pi 1.0.1 executed the real tools, retained their results, and exported the Calm transcript.')
PY
sleep 0.2
tmux -L fm-lab capture-pane -p -t primary > "$E/native-pi101-calm-pane.txt"
! grep -q 'alpha from the live fixture' "$E/native-pi101-calm-pane.txt"
