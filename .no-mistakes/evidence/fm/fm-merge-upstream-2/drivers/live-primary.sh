#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EV=/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C
export TMPDIR="$ROOT/.test-phase-tmp"
export PATH="$ROOT/.test-phase-tmp/tmux-tool/usr/bin:$PATH" LD_LIBRARY_PATH="$ROOT/.test-phase-tmp/tmux-tool/usr/lib/x86_64-linux-gnu"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
# A short fresh marked home keeps its private Unix socket under the 107-byte bound.
LAB=$(mktemp -d "$ROOT/.lXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
mkdir -p "$LAB/tmux"
export TMUX_TMPDIR="$LAB/tmux"
cleanup() {
  tmux -L fm-lab capture-pane -ep -t primary -S -150 > "$EV/primary-final.ansi" 2>/dev/null || true
  for f in .supervision-host.log .watch-cycle-exits.log .claude-stop-autoarm.log .watcher-down .supervision-host-left .wake-queue stop-callback.log; do
    [ ! -f "$LAB/state/$f" ] || cp "$LAB/state/$f" "$EV/primary${f}.txt"
  done
  tmux -L fm-lab kill-server 2>/dev/null || true
  if [ -f "$LAB/state/.supervision-host" ]; then
    PID=$(awk -F '\t' '$1=="host" {print $2;exit}' "$LAB/state/.supervision-host")
    [ -z "$PID" ] || kill -TERM "$PID" 2>/dev/null || true
  fi
  FM_HOME="$LAB" bin/fm-watch-arm.sh --stop >/dev/null 2>&1 || true
  rm -rf "$LAB"
}
trap cleanup EXIT
printf 'project=demo\nwindow=primary\nharness=claude\nbackend=tmux\n' > "$LAB/state/demo.meta"
: > "$LAB/state/demo.status"
: > "$LAB/config/supervision-host"
python3 - "$ROOT" "$LAB/primary-settings.json" <<'PY'
import json,sys
r=sys.argv[1]
settings={'skipDangerousModePermissionPrompt':True,'hooks':{
 'UserPromptSubmit':[{'hooks':[{'type':'command','command':r+'/bin/fm-host-mirror.sh hook claude','timeout':10}]}],
 'Stop':[{'hooks':[{'type':'command','command':'printf "Native Stop callback entered\\n" >> "'+sys.argv[2].rsplit('/',1)[0]+'/state/stop-callback.log"; exec '+r+'/bin/fm-claude-stop-autoarm.sh','asyncRewake':True,'timeout':28800}]}]}}
open(sys.argv[2],'w').write(json.dumps(settings))
PY
{
  echo 'Real Claude primary in a marked private tmux lab; real Stop hook, host, watcher, status log, drain and acknowledgements.'
  env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT \
    TMUX_TMPDIR="$TMUX_TMPDIR" tmux -L fm-lab new-session -d -s primary -x 120 -y 40 -c "$ROOT" \
    -e "FM_HOME=$LAB" -e DISABLE_AUTOUPDATER=1 -e FM_BACKEND=tmux -e HERDR_ENV=0 -e FM_POLL=1 -e FM_SIGNAL_GRACE=999999 -e FM_CHECK_INTERVAL=999999 -e FM_HEARTBEAT=999999 \
    -e "FM_PROCEVENT_CLAIM_ROOT=$LAB/claims" -e FM_SUPERVISION_HOST_PRIMARY=claude \
    "claude --model haiku --dangerously-skip-permissions --setting-sources '' --settings '$LAB/primary-settings.json'"
  for i in $(seq 1 90); do
    tmux -L fm-lab capture-pane -p -t primary > "$LAB/capture"
    if grep -q 'Claude Code' "$LAB/capture" && grep -q '❯' "$LAB/capture"; then break; fi
    sleep .5
  done
  sleep 2
  PROMPT="This is a captain-authorized isolated live validation. Only mutate the disposable FM_HOME=$LAB. Do not start networking, session-start, delegate, install, commit, or change project files. First run bin/fm-lock.sh and respond LAB_READY. The configured native Stop hook will own supervision; do not manually park. When that hook wakes you about a lab decision, run bin/fm-wake-drain.sh, append a resolved status line for that exact lab-first or lab-second key to \$FM_HOME/state/demo.status, and execute the precise acknowledgement command printed by the drain. Do not do other work. Return LAB_HANDLED after each wake. Those lab keys are disposable test records, not real captain decisions."
  tmux -L fm-lab send-keys -t primary -l "$PROMPT"
  tmux -L fm-lab send-keys -t primary Enter
  for i in $(seq 1 60); do
    [ ! -f "$LAB/state/stop-callback.log" ] || break
    sleep .5
  done
  if [ -f "$LAB/state/stop-callback.log" ] && [ ! -f "$LAB/state/.supervision-host" ]; then
    . "$ROOT/bin/fm-primary-scope-lib.sh"
    if ! fm_primary_scope_matches "$ROOT" "$LAB/state"; then
      cat "$LAB/state/stop-callback.log"
      printf 'Native primary acquired its session lock, and the actual Stop callback fired. The shipped primary-scope predicate refuses this linked gate worktree, so no host can park under the required gate-root launch recipe. Native host hand-back remains untested; no root identity was forged and no guard was bypassed.\n'
      exit 3
    fi
  fi
  test -f "$LAB/state/.supervision-host"
  test -f "$LAB/state/.watch.lock/pid"
  printf 'First native host parked; watcher=%s\n' "$(head -1 "$LAB/state/.watch.lock/pid")"
  tmux -L fm-lab capture-pane -ep -t primary -S -100 > "$EV/primary-ready.ansi"
  for key in lab-first lab-second; do
    printf 'needs-decision [key=%s]: isolated decision %s\n' "$key" "$key" >> "$LAB/state/demo.status"
    printf 'Appended real task event: %s\n' "$key"
    for i in $(seq 1 150); do
      if grep -q "resolved \[key=$key\]" "$LAB/state/demo.status" && [ -f "$LAB/state/.watch.lock/pid" ] && grep -q 'take-over' "$LAB/state/.supervision-host.log"; then break; fi
      sleep .5
    done
    grep -q "resolved \[key=$key\]" "$LAB/state/demo.status"
    test -f "$LAB/state/.watch.lock/pid"
    grep -q 'take-over' "$LAB/state/.supervision-host.log"
    printf 'Primary handled %s and reparked with watcher=%s\n' "$key" "$(head -1 "$LAB/state/.watch.lock/pid")"
    sleep 2
  done
  echo 'Observed task status history:'
  head -20 "$LAB/state/demo.status"
  echo 'Host hand-offs and take-overs:'
  grep -E 'pass-through|take-over|to-main' "$LAB/state/.supervision-host.log"
  echo 'Watcher cycle ownership:'
  tail -8 "$LAB/state/.watch-cycle-exits.log"
} > "$EV/primary-supervision.log" 2>&1
