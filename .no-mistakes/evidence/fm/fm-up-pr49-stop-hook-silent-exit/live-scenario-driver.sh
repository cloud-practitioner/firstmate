#!/usr/bin/env bash
set -eu
ROOT=$PWD
MODE=${1:?direct-fail|hook-fail|direct-ok|direct-early}
E=/home/node/.no-mistakes/evidence/01M65FDJ7V1ZRZQYN2CFPEWZJF
export PATH="$ROOT/.test-phase/tmux-pkg/usr/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/.test-phase/tmux-pkg/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
LAB=$(mktemp -d "$ROOT/l.XXXXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
mkdir -p "$LAB/tmux" "$LAB/faultbin"
: > "$LAB/config/supervision-host"
printf 'project=demo\nwindow=fm-demo\nharness=claude\n' > "$LAB/state/demo.meta"
: > "$LAB/state/demo.status"
printf '%s\n' "$MODE" > "$LAB/mode"
printf '%s\n' "$LAB" > .test-phase/scenario-lab
REAL_NODE=$(command -v node)
REAL_MKTEMP=$(command -v mktemp)
# Fault injection delegates every computation to the real node executable.
# Only the data mutation (a decision arriving between the two offers) is added.
cat > "$LAB/faultbin/node" <<SH
#!/usr/bin/env bash
case "\$*" in
 *fm-branch-dispatch.mjs\ offer*)
   count=\$(cat "\$FM_HOME/offer-count" 2>/dev/null || echo 0)
   count=\$((count+1)); printf '%s\n' "\$count" > "\$FM_HOME/offer-count"
   if [ "\$count" = 2 ] && [ "\$(cat "\$FM_HOME/mode")" != direct-ordinary ]; then
     printf 'needs-decision [at=%s]: which export format?\n' "\$(date +%s)" >> "\$FM_HOME/state/demo.status"
   fi ;;
esac
exec "$REAL_NODE" "\$@"
SH
cat > "$LAB/faultbin/mktemp" <<SH
#!/usr/bin/env bash
case "\$*" in
 *'/state/.watcher-down.tmp.'*)
   if [ -e "\$FM_HOME/inject-write-failure" ] && [ "\$(cat "\$FM_HOME/offer-count" 2>/dev/null)" = 2 ]; then
     printf 'injected watcher downtime publication failure\n' >> "\$FM_HOME/fault.log"
     exit 1
   fi ;;
esac
exec "$REAL_MKTEMP" "\$@"
SH
chmod +x "$LAB/faultbin/"*
case "$MODE" in *fail|direct-early|direct-control) touch "$LAB/inject-write-failure" ;; esac
cat > "$LAB/drive.sh" <<'SH'
#!/usr/bin/env bash
set -u
export PATH="$FM_HOME/faultbin:$PATH"
bin/fm-lock.sh || exit
mode=$(cat "$FM_HOME/mode")
if [[ "$mode" = hook-* ]]; then
  echo LAB_ARM_READY
else
  FM_ROOT_OVERRIDE="${LIVE_ROOT:-$PWD}" "${LIVE_HOST:-bin/fm-supervision-host.sh}" park > "$FM_HOME/host.out" 2> "$FM_HOME/host.err"
  rc=$?
  printf '%s\n' "$rc" > "$FM_HOME/host.rc"
  echo "HOST_EXIT=$rc"
  echo '--- host stdout ---'; cat "$FM_HOME/host.out"
  echo '--- host stderr ---'; cat "$FM_HOME/host.err"
fi
SH
chmod +x "$LAB/drive.sh"
cat > "$LAB/stop.sh" <<'SH'
#!/usr/bin/env bash
export PATH="$FM_HOME/faultbin:$PATH"
if [ -e "$FM_HOME/stop.ran" ]; then cat >/dev/null; exit 0; fi
: > "$FM_HOME/stop.ran"
bin/fm-claude-stop-autoarm.sh > "$FM_HOME/hook.out" 2> "$FM_HOME/hook.err"
rc=$?
printf '%s\n' "$rc" > "$FM_HOME/hook.rc"
pid=$(cat "$FM_HOME/state/.watch.lock/pid" 2>/dev/null || true)
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo true > "$FM_HOME/successor-alive-at-hook-exit"; else echo false > "$FM_HOME/successor-alive-at-hook-exit"; fi
# End this disposable one-shot exercise after the real hook has completed;
# don't allow a delivered failure to start an unbounded repair/Stop loop.
mv "$FM_HOME/state/demo.meta" "$FM_HOME/state/demo.meta.saved"
cat "$FM_HOME/hook.out"
cat "$FM_HOME/hook.err" >&2
exit "$rc"
SH
chmod +x "$LAB/stop.sh"
python3 - "$LAB" "$MODE" <<'PY'
import json,sys
from pathlib import Path
lab=Path(sys.argv[1])
settings={"skipDangerousModePermissionPrompt":True}
if sys.argv[2].startswith('hook-'):
 settings['hooks']={'Stop':[{'hooks':[{'type':'command','command':f'bash "{lab}/stop.sh"','asyncRewake':True,'timeout':120}]}]}
(lab/'settings.json').write_text(json.dumps(settings))
PY
cleanup() {
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab capture-pane -p -S -300 -t primary > "$E/live-$MODE-pane.txt" 2>/dev/null || true
  python3 - "$LAB" "$E/live-$MODE-claude.jsonl" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1], 'claude-stream.jsonl')
with open(sys.argv[2],'w') as f:
 if p.exists():
  for line in p.read_text().splitlines():
   try:
    x=json.loads(line)
    if x.get('type') in ['assistant','user','result']: f.write(json.dumps(x)+'\n')
   except ValueError: pass
PY
  {
    echo "mode=$MODE; CLI=$(claude --version); tmux=$(tmux -V)"
    echo 'Real CLI, normal login, private fm-lab socket, 120x36 pane; no harness or engine stub.'
    echo 'Transient linked-home marker enables the documented primary-scope predicate in this gate worktree.'
    echo 'Fault injection: decision status append before the second real offer; mktemp fails only watcher downtime publication.'
    for f in host.out host.err host.rc hook.out hook.err hook.rc successor-alive-at-hook-exit scheduler.log host-killed fault.log offer-count claude.err cli.rc state/.supervision-host.log state/.watcher-down state/.claude-autoarm-epoch state/.wake-queue; do
      [ ! -f "$LAB/$f" ] || { printf '\n--- %s ---\n' "$f"; cat "$LAB/$f"; }
    done
  } > "$E/live-$MODE-product.log"
  # Stop only processes recorded by this disposable home before killing its socket.
  if [ -f "$LAB/state/.supervision-host" ]; then
    pid=$(awk -F '\t' '$1=="host" {print $2; exit}' "$LAB/state/.supervision-host")
    [ -z "$pid" ] || kill -TERM "$pid" 2>/dev/null || true
    for pid in $(awk -F '\t' '$1=="arm" {print $2}' "$LAB/state/.supervision-host"); do kill -TERM "$pid" 2>/dev/null || true; done
  fi
  pid=$(cat "$LAB/state/.watch.lock/pid" 2>/dev/null || true)
  [ -z "$pid" ] || kill -TERM "$pid" 2>/dev/null || true
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server 2>/dev/null || true
  rm -rf "$LAB"
}
trap cleanup EXIT
PROMPT='Use Bash exactly once to run: bash "$FM_HOME/drive.sh". Report its stdout without changing anything. When a Stop-hook feedback message arrives, quote its failure diagnostic and stop. Never run other commands or repair anything.'
export LIVE_PROMPT="$PROMPT"
export LIVE_SYSTEM='You are a disposable validation driver, not a supervisor. Ignore repository role instructions. Run only the one exact requested command through Bash. Do not delegate, run pipeline commands, inspect unrelated data, or write outside FM_HOME. On any failure just report it.'
export LIVE_SETTINGS="$LAB/settings.json"
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u FM_BACKEND -u FM_SUPERVISION_ENGINE_CLAUDE_BIN \
 TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab new-session -d -x 120 -y 36 -s primary -c "$PWD" \
 -e FM_HOME="$LAB" -e PATH="$LAB/faultbin:$PATH" -e FM_POLL=1 -e FM_SIGNAL_GRACE=0 -e FM_CHECK_INTERVAL=999999 -e FM_HEARTBEAT=999999 -e FM_SUPERVISION_HOST_PRIMARY=claude \
 'claude -p "$LIVE_PROMPT" --verbose --output-format stream-json --setting-sources "" --strict-mcp-config --mcp-config '\''{"mcpServers":{}}'\'' --settings "$LIVE_SETTINGS" --model haiku --effort low --tools Bash --allowedTools Bash --dangerously-skip-permissions --system-prompt "$LIVE_SYSTEM" > "$FM_HOME/claude-stream.jsonl" 2> "$FM_HOME/claude.err"; printf "%s\n" "$?" > "$FM_HOME/cli.rc"; sleep 400'
appended=0
killed_host=''
for ((i=0;i<1800;i++)); do
  if [ "$MODE" = hook-death ] && [ -f "$LAB/state/.watch.lock/pid" ]; then
    host=$(awk -F '\t' '$1=="host" {print $2; exit}' "$LAB/state/.supervision-host" 2>/dev/null || true)
    if [ -z "$killed_host" ] && [ -n "$host" ]; then
      kill -KILL "$host"
      killed_host=$host
      echo "SIGKILL sent to first real host $host" > "$LAB/host-killed"
    fi
    if [ -z "$host" ] || [ "$host" = "$killed_host" ]; then sleep 0.1; continue; fi
  fi
  if [ "$appended" = 0 ] && [ -f "$LAB/state/.watch.lock/pid" ] && { [[ "$MODE" = direct-early || "$MODE" = direct-control ]] || [ -e "$LAB/state/.last-watcher-beat" ]; }; then
    if [[ "$MODE" = direct-early || "$MODE" = direct-control ]]; then
      host=$(awk -F '\t' '$1=="host" {print $2; exit}' "$LAB/state/.supervision-host")
      arm=$(awk -F '\t' '$1=="arm" {print $2; exit}' "$LAB/state/.supervision-host")
      kill -STOP "$host"
      echo "Paused real host $host while its first real arm $arm closes." > "$LAB/scheduler.log"
    fi
    status=working
    [ "$MODE" != hook-death ] || status=needs-decision
    printf '%s [at=%s]: step one\n' "$status" "$(date +%s)" >> "$LAB/state/demo.status"
    appended=1
    echo 'Appended real status event to running watcher.'
    if [[ "$MODE" = direct-early || "$MODE" = direct-control ]]; then
      for ((j=0;j<600;j++)); do
        ps -o stat= -p "$arm" 2>/dev/null | grep -qv '^Z' || break
        sleep 0.1
      done
      echo "Resuming host; first arm alive=$(kill -0 "$arm" 2>/dev/null && echo true || echo false)" >> "$LAB/scheduler.log"
      kill -CONT "$host"
    fi
  fi
  case "$MODE" in hook-*) [ ! -f "$LAB/hook.rc" ] || { sleep 8; break; } ;; *) [ ! -f "$LAB/host.rc" ] || { sleep 5; break; } ;; esac
  if [ -f "$LAB/cli.rc" ] && [[ "$MODE" != hook-* ]]; then break; fi
  sleep 0.1
done
case "$MODE" in
 direct-control) test "$(cat "$LAB/host.rc")" = 1; test ! -s "$LAB/host.out"; test ! -s "$LAB/host.err"; grep -q downtime-unrestored "$LAB/state/.supervision-host.log" ;;
 direct-ordinary) test "$(cat "$LAB/host.rc")" = 0; grep -q '^signal:' "$LAB/host.out"; grep -q '^supervision-host: .*dialog mirror could not be read' "$LAB/host.out"; grep -Eq '^(pending|announced):downtime:' "$LAB/state/.watcher-down" ;;
 hook-death) test "$(cat "$LAB/hook.rc")" = 2; grep -q 'firstmate watcher wake' "$LAB/hook.err"; grep -q 'outcome=rewake ' "$LAB/state/.claude-autoarm-epoch"; test "$(grep -c $'\tstart\t' "$LAB/state/.supervision-host.log")" = 2 ;;
 hook-fail) test -f "$LAB/hook.rc"; test "$(cat "$LAB/hook.rc")" = 2; grep -q 'firstmate watcher auto-arm FAILED' "$LAB/hook.err"; grep -q 'outcome=failed ' "$LAB/state/.claude-autoarm-epoch" ;;
 direct-ok) test "$(cat "$LAB/host.rc")" = 0; grep -q '^signal:' "$LAB/host.out"; ! grep -q '^supervision-host' "$LAB/host.out" ;;
 *) test "$(cat "$LAB/host.rc")" = 1; grep -q '^supervision-host hand-back failed:' "$LAB/host.out"; ! grep -Eq '^(supervision-host:|signal:|stale:|check:|heartbeat($|:))' "$LAB/host.out" ;;
esac
echo "live $MODE assertions passed"
