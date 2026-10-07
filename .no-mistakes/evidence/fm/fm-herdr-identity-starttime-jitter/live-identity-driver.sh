#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EVID=/home/node/.no-mistakes/evidence/01M4A3BG1QYX4E134JQ4C4GJSF
SCRATCH="$ROOT/.identity-validation/live"
mkdir -p "$SCRATCH/tmp" "$SCRATCH/proxy"
export TMPDIR="$SCRATCH/tmp" FM_HERDR_LAB_STATE_DIR="$SCRATCH/lab-state"
for v in ${!FM_@}; do case "$v" in *_OVERRIDE) unset "$v" ;; esac; done
unset FM_GATE_REFUSE_BYPASS
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
BASE_PATH=$PATH
REAL_HERDR=$(command -v herdr)
SESSION=$(bin/fm-herdr-lab.sh name identity)
export SESSION HERDR_SESSION="$SESSION" BASE_PATH REAL_HERDR ROOT
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
export FM_HOME="$LAB"
bin/fm-lab-home.sh create "$LAB"
cleanup() {
  rc=$?
  PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" teardown "$SESSION" && echo 'Lab removed; default-session fleet tripwire unchanged.' || rc=1
  rm -rf "$LAB" "$SCRATCH"
  exit "$rc"
}
trap cleanup EXIT
# provision owns prepare for a fresh session; a separate prepare would duplicate its tripwire.
bin/fm-herdr-lab.sh provision "$SESSION"
# Transparent transport proxy: invokes the real lab helper, never canned Herdr responses.
cat > "$SCRATCH/proxy/herdr" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = --version ] || [ "${1:-}" = --help ]; then exec "$REAL_HERDR" "$@"; fi
args=()
while [ "$#" -gt 0 ]; do
  if [ "$1" = --session ]; then
    [ "$2" = "$SESSION" ] || { echo 'cross-session refused' >&2; exit 1; }
    shift 2
  else args+=("$1"); shift; fi
done
exec env PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}"
SH
chmod +x "$SCRATCH/proxy/herdr"
export PATH="$SCRATCH/proxy:$PATH"
lab() { PATH="$BASE_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "$@"; }
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
WS=$(lab workspace create --label identity-lab --cwd "$LAB")
printf '%s\n' "$WS"
PANE=$(jq -er '.result.root_pane.pane_id' <<< "$WS")
TAB=$(jq -er '.result.default_tab.tab_id // .result.tab.tab_id // .result.root_pane.tab_id' <<< "$WS")
TARGET="$SESSION:$PANE"
lab pane process-info --pane "$PANE" | tee "$EVID/identity-process-info.json"
ID=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
PID=$(fm_backend_herdr_pane_shell_pid "$SESSION" "$PANE")
printf 'Real pane root identity: %s\n' "$ID"
for n in $(seq 1 12); do
  READ=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
  printf 'Read %02d: %s\n' "$n" "$READ"
  [ "$READ" = "$ID" ]
done
write_meta() {
  printf 'backend=herdr\nwindow=%s\nworktree=%s\nkind=secondmate\nharness=pi\nherdr_session=%s\nherdr_tab_id=%s\nherdr_pane_id=%s\nherdr_process_identity=%s\n' "$TARGET" "$LAB" "$SESSION" "$TAB" "$PANE" "$1" > "$LAB/state/identity.meta"
}
write_meta "$ID"
echo 'Starting the real Pi CLI in the real Herdr pane.'
lab pane run "$PANE" 'pi --no-session --no-mcp --no-skills --no-prompt-templates'
STATE=''
for n in $(seq 1 90); do
  STATE=$(fm_backend_agent_state herdr "$TARGET" fm-identity)
  [ "$STATE" != alive ] || break
  sleep 0.5
done
lab pane read "$PANE" > "$EVID/live-pi-pane.txt"
lab agent get "$PANE" | tee "$EVID/live-pi-agent.json"
printf 'Real Pi process liveness: %s\n' "$STATE"
[ "$STATE" = alive ]
# Public persisted metadata contract: previous-release ps identity with a controlled ±1-second drift.
for OFFSET in -1 0 1; do
  PS=$(LC_ALL=C TZ=UTC0 ps -o lstart= -p "$PID")
  LEGACY=$(PS="$PS" PID="$PID" OFFSET="$OFFSET" python3 - <<'PY'
import os,datetime
when=datetime.datetime.strptime(os.environ['PS'].strip(), '%a %b %d %H:%M:%S %Y')
when+=datetime.timedelta(seconds=int(os.environ['OFFSET']))
print('ps:'+os.environ['PID']+':'+when.strftime('%a %b %e %H:%M:%S %Y'))
PY
)
  write_meta "$LEGACY"
  STATE=$(fm_backend_agent_state herdr "$TARGET" fm-identity)
  printf 'Legacy %+d second record: %s -> agent_state=%s\n' "$OFFSET" "$LEGACY" "$STATE"
  [ "$STATE" = alive ]
  if [ "$OFFSET" = 1 ]; then
    env TARGET="$TARGET" FM_HOME="$LAB" OLD="$SCRATCH/base-herdr.sh" bash -c '. "$ROOT/bin/fm-backend.sh"; fm_backend_source herdr; . "$OLD"; printf "Pre-fix liveness against the SAME real pane and +1-second legacy record: "; fm_backend_agent_state herdr "$TARGET" fm-identity; echo'
  fi
done
# Execute the real secondmate sweep probe, not a fake harness or registry.
. "$ROOT/bin/fm-secondmate-liveness-lib.sh"
STATE="$LAB/state"
fm_secondmate_liveness_probe "$STATE/identity.meta" identity poll
printf 'Secondmate sweep: status=%s state=%s kill=%s\n' "$FM_SM_LIVE_STATUS" "$FM_SM_LIVE_STATE" "$FM_SM_LIVE_KILL"
[ "$FM_SM_LIVE_STATUS" = alive ] && [ "$FM_SM_LIVE_KILL" = 0 ]
# Exercise the no-/proc compatibility route against real Herdr and the real ps utility.
(
  export FM_PROC_ROOT_OVERRIDE="$SCRATCH/no-proc"
  FALLBACK=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
  printf 'No-/proc fallback identity from real ps: %s\n' "$FALLBACK"
  [[ "$FALLBACK" == ps:* ]]
  for offset in -1 0 1; do
    LEGACY=$(FALLBACK="$FALLBACK" OFFSET="$offset" python3 - <<'PY'
import os,datetime
_,pid,start=os.environ['FALLBACK'].split(':',2)
when=datetime.datetime.strptime(start, '%a %b %d %H:%M:%S %Y')+datetime.timedelta(seconds=int(os.environ['OFFSET']))
print('ps:'+pid+':'+when.strftime('%a %b %e %H:%M:%S %Y'))
PY
)
    write_meta "$LEGACY"
    result=$(fm_backend_agent_state herdr "$TARGET" fm-identity)
    printf 'Real ps fallback, legacy %+d second record -> %s\n' "$offset" "$result"
    [ "$result" = alive ]
  done
)
# Make both identity readers unavailable without replacing any product or ps with a stub.
mkdir -p "$SCRATCH/no-ps"
for tool in bash jq cat grep awk sed tr head tail dirname sleep python3 env; do
  ln -s "$(command -v "$tool")" "$SCRATCH/no-ps/$tool"
done
ln -s "$SCRATCH/proxy/herdr" "$SCRATCH/no-ps/herdr"
write_meta "$ID"
(
  export FM_PROC_ROOT_OVERRIDE="$SCRATCH/no-proc" PATH="$SCRATCH/no-ps"
  result=$(fm_backend_agent_state herdr "$TARGET" fm-identity)
  printf 'Both identity readers unavailable (no proc root, ps absent from PATH): %s\n' "$result"
  [ "$result" = unreadable ]
  if fm_backend_send_key herdr "$TARGET" C-c fm-identity; then
    echo 'Unreadable identity incorrectly authorized an active key' >&2; exit 1
  fi
  echo 'Unreadable identity refused active Ctrl+C; duplicate recovery is not authorized.'
)
# More than one second and mismatched exact process identities must remain foreign.
for BAD in "ps:$PID:Wed Oct  7 02:03:32 2020" "${ID%:*}:0" "proc:2:bad-boot:0"; do
  write_meta "$BAD"
  RESULT=$(fm_backend_agent_state herdr "$TARGET" fm-identity)
  printf 'Adversarial identity %s -> %s\n' "$BAD" "$RESULT"
  [ "$RESULT" = missing ]
  if fm_backend_send_key herdr "$TARGET" C-c fm-identity; then
    echo 'Foreign identity incorrectly authorized an active key' >&2; exit 1
  fi
  echo 'Foreign ownership refused active Ctrl+C.'
  lab pane get "$PANE" >/dev/null
  RAW=$(lab agent get "$PANE" | jq -r '.result.agent.agent')
  printf 'Unrelated real agent retained: %s on %s\n' "$RAW" "$TARGET"
done
write_meta "$ID"
printf 'Final real pane liveness: %s\n' "$(fm_backend_agent_state herdr "$TARGET" fm-identity)"
lab pane read "$PANE" > "$EVID/live-pi-pane.txt"
