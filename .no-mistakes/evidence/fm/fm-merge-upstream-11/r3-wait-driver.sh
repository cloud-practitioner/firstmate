#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
export PATH="$ROOT/.test-live/bin:$PATH" TMPDIR="$ROOT/.test-live/tmp" FM_BACKEND=tmux GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 FM_CREW_STATE_NO_FORGE=1 DISABLE_AUTOUPDATER=1
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS NM_HOME
LAB=$(mktemp -d "$ROOT/.l.XXXXXX")
export FM_HOME="$LAB" TMUX_TMPDIR="$LAB/tmux"
cleanup() { for f in armed unarmed; do [ ! -f "$LAB/$f.out" ] || cp "$LAB/$f.out" "/home/node/.no-mistakes/evidence/01M5GMXRP8TEGYK8ZJPXTCW65Z/r3-wait-$f.txt"; done; tmux -L fm-lab kill-server 2>/dev/null || true; rm -rf "$LAB"; }
trap cleanup EXIT

bin/fm-lab-home.sh create "$LAB"
export HOME="$LAB/user-home" CLAUDE_CONFIG_DIR="$LAB/claude-config" XDG_CONFIG_HOME="$LAB/xdg-config" XDG_DATA_HOME="$LAB/xdg-data" XDG_STATE_HOME="$LAB/xdg-state" XDG_CACHE_HOME="$LAB/xdg-cache" DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
mkdir -p "$HOME" "$CLAUDE_CONFIG_DIR"

mkdir -p "$LAB/tmux" "$LAB/projects/disposable"
touch "$LAB/config/supervision-host"
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab new-session -d -x 120 -y 40 -s primary -c "$ROOT" -e FM_HOME="$LAB" "$ROOT/.test-live/bin/claude"
sleep 8
tmux -L fm-lab rename-window -t primary:0 fm-head-probe
export TMUX="$(tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')"
[ "$(tmux -L fm-lab display-message -p -t primary '#{pane_dead}')" = 0 ]

mkdir -p "$LAB/projects/empty"
gen=$(bin/fm-busy-event.sh arm "$LAB/state" wait-probe --state busy --source fm-recovery --event fixture-active-job)
printf 'window=primary:fm-head-probe\nkind=scout\nharness=claude\nworktree=%s\nbusy_gen=%s\n' "$LAB/projects/empty" "$gen" > "$LAB/state/wait-probe.meta"
printf 'blocked [key=fixture-api]: waiting for a disposable API dependency\n' > "$LAB/state/wait-probe.status"
touch -d '30 seconds ago' "$LAB/state/wait-probe.status"
touch -d '60 seconds ago' "$LAB/state/wait-probe.meta"
bash -c '. bin/fm-wake-lib.sh; fm_wake_status_mark_current "$1" "$2"' _ "$LAB/state" "$LAB/state/wait-probe.status"
printf 'export FM_POLL=1 FM_BUSY_TURN_MAX_SECS=1 FM_STALE_ESCALATE_SECS=1 FM_PAUSE_RESURFACE_SECS=10 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 FM_SIGNAL_GRACE=0\n' > "$LAB/config/watch.env"
touch "$LAB/config/wedge-defer-worker-wait"
printf '%s\n' "$(( $(date +%s) - 60 ))" > "$LAB/state/.stale-since-primary_fm-head-probe"
printf '\n=== Endpoint has a declared active-job recovery record ===\n'
bin/fm-crew-state.sh wait-probe
printf '\n=== Home watch.env overrides the ambient 30-second poll; worker-wait is armed ===\n'
start=$(date +%s)
FM_POLL=30 timeout 25 bin/fm-watch-arm.sh > "$LAB/armed.out" 2>&1
elapsed=$(( $(date +%s) - start ))
while IFS= read -r l; do printf '%s\n' "$l"; done < "$LAB/armed.out"
printf 'elapsed_seconds=%s\n' "$elapsed"
grep -Fq 'declared blocker' "$LAB/armed.out"
grep -Fq 'clear the reported blocker' "$LAB/armed.out"
! grep -Fq 'possible wedge' "$LAB/armed.out"
[ "$elapsed" -lt 25 ]
bin/fm-wake-drain.sh > "$LAB/drain.out" 2> "$LAB/drain.err"
read -r seq generation < <(python3 - "$LAB/drain.err" <<'PY'
import re,sys
s=open(sys.argv[1]).read();m=re.search(r'--ack-through ([0-9]+) --recovery-generation ([A-Za-z0-9._-]+)',s)
if not m: raise SystemExit('missing acknowledgement')
print(*m.groups())
PY
)
bin/fm-wake-drain.sh --ack-through "$seq" --recovery-generation "$generation"
rm "$LAB/config/wedge-defer-worker-wait"
printf '%s\n' "$(( $(date +%s) - 60 ))" > "$LAB/state/.stale-since-primary_fm-head-probe"
printf '\n=== Adversarial: removing the opt-in restores the wedge ladder ===\n'
FM_POLL=30 timeout 25 bin/fm-watch-arm.sh > "$LAB/unarmed.out" 2>&1
while IFS= read -r l; do printf '%s\n' "$l"; done < "$LAB/unarmed.out"
grep -Fq 'possible wedge, escalation 1' "$LAB/unarmed.out"
printf '\nThe semantic active-job event was disposable input data, not a model-execution claim. Both watcher runs used real commands and a real live CLI endpoint.\n'
