#!/usr/bin/env bash
set -eu
umask 022
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M467Y2KVPY0ZYM8V5V6DQB86
export PATH="$ROOT/.validation/tools/usr/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/.validation/tools/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset FM_HOME FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
for MODE in default optin; do
  LAB=$(mktemp -d "$ROOT/l.XXXXXX")
  bin/fm-lab-home.sh create "$LAB" >/dev/null
  mkdir -p "$LAB/tmux" "$LAB/agent-dir" "$LAB/sessions"
  : > "$LAB/state/probe.status"
  PID=
  cleanup() {
    [ -z "$PID" ] || kill -CONT "$PID" 2>/dev/null || true
    TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server 2>/dev/null || true
    FM_HOME="$LAB" bin/fm-watch-arm.sh --stop >/dev/null 2>&1 || true
    rm -rf "$LAB"
  }
  trap cleanup EXIT
  unset FM_WATCH_EXTENSION_LOG_KEEP_LINES
  [ "$MODE" != optin ] || export FM_WATCH_EXTENSION_LOG_KEEP_LINES=20
  env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
    TMUX_TMPDIR="$LAB/tmux" PI_CODING_AGENT_DIR="$LAB/agent-dir" BASH_ENV="$ROOT/.validation/lab-shell-env.sh" PROOF_ROOT="$ROOT" FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
    tmux -L fm-lab -f /dev/null new-session -d -s primary -n fm-primary -x 120 -y 40 -c "$PWD" -e FM_HOME="$LAB" \
    "pi --offline --approve --no-context-files --no-extensions --no-skills --no-prompt-templates --no-themes --no-builtin-tools --extension '$ROOT/.validation/quick-provider.ts' --extension '$ROOT/.pi/extensions/fm-primary-pi-watch.ts' --model watch-proof/quick --session-dir '$LAB/sessions' --tui-mode regular"
  export TMUX_TMPDIR="$LAB/tmux"
  export TMUX=$(tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')
  export FM_HOME="$LAB"
  for i in $(seq 1 200); do
    [ -f "$LAB/state/.watch.lock/pid" ] && [ -f "$LAB/state/.last-watcher-beat" ] && break
    sleep 0.1
  done
  if [ ! -f "$LAB/state/.watch.lock/pid" ]; then tmux -L fm-lab capture-pane -p -t primary; exit 1; fi
  PID=$(< "$LAB/state/.lock")
  OWNER=$(< "$LAB/state/.watch.lock/pid")
  kill -STOP "$PID"
  printf 'done: event published while the primary was stopped\n' >> "$LAB/state/probe.status"
  for i in $(seq 1 300); do
    [ -f "$LAB/state/.watch-deliveries.log" ] && grep -q 'signal:' "$LAB/state/.watch-deliveries.log" && break
    sleep 0.1
  done
  grep -q 'signal:' "$LAB/state/.watch-deliveries.log"
  sleep 3
  printf 'mode=%s primary_pid=%s predecessor_watcher=%s\n' "$MODE" "$PID" "$OWNER" > "$E/live-watcher-$MODE.txt"
  printf 'Primary paused across predecessor exit; successor intentionally unavailable for 3 seconds.\n' >> "$E/live-watcher-$MODE.txt"
  kill -CONT "$PID"
  for i in $(seq 1 500); do
    if [ -f "$LAB/state/.watch.lock/pid" ] && [ "$(< "$LAB/state/.watch.lock/pid")" != "$OWNER" ] && [ -s "$LAB/provider-inputs.jsonl" ]; then break; fi
    sleep 0.1
  done
  [ -s "$LAB/provider-inputs.jsonl" ]
  NEXT=$(< "$LAB/state/.watch.lock/pid")
  [ "$NEXT" != "$OWNER" ]
  printf 'successor_watcher=%s\n' "$NEXT" >> "$E/live-watcher-$MODE.txt"
  printf 'done: second event after successor readiness\n' >> "$LAB/state/probe.status"
  for i in $(seq 1 500); do
    if [ "$(wc -l < "$LAB/provider-inputs.jsonl")" -ge 2 ] && [ -f "$LAB/state/.watch.lock/pid" ] && [ "$(< "$LAB/state/.watch.lock/pid")" != "$NEXT" ]; then break; fi
    sleep 0.1
  done
  [ "$(wc -l < "$LAB/provider-inputs.jsonl")" -ge 2 ]
  printf 'next_successor_watcher=%s\n' "$(< "$LAB/state/.watch.lock/pid")" >> "$E/live-watcher-$MODE.txt"
  cp "$LAB/provider-inputs.jsonl" "$E/live-watcher-$MODE-provider-inputs.jsonl"
  cp "$LAB/state/.watch-deliveries.log" "$E/live-watcher-$MODE-deliveries.txt"
  tmux -L fm-lab capture-pane -p -t primary > "$E/live-watcher-$MODE-pane.txt"
  if [ "$MODE" = default ]; then
    [ ! -e "$LAB/state/.watch-extension.log" ]
    printf 'Diagnostic extension log absent without opt-in.\n' >> "$E/live-watcher-$MODE.txt"
  else
    [ -s "$LAB/state/.watch-extension.log" ]
    [ "$(wc -l < "$LAB/state/.watch-extension.log")" -le 20 ]
    cp "$LAB/state/.watch-extension.log" "$E/live-watcher-optin-extension-log.txt"
    printf 'Opt-in diagnostic log exists and respects its 20-line bound.\n' >> "$E/live-watcher-$MODE.txt"
  fi
  FILE=$(ls "$LAB/sessions"/*.jsonl | head -1)
  cp "$FILE" "$E/live-watcher-$MODE-session.jsonl"
  cleanup
  trap - EXIT
  printf 'mode=%s: real Pi primary recovered both watcher events across the successor gap\n' "$MODE"
done
