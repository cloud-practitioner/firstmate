#!/usr/bin/env bash
# Root-cause probe: how Herdr 0.9.3 treats a pane report-agent registration,
# and how firstmate's Herdr backend classifies/handles each shape.
set -u
ROOT=$1
. "$ROOT/tests/herdr-test-safety.sh"
herdr_forget_inherited_pane
SESSION="fm-lab-radprobe-$$"
export HERDR_SESSION="$SESSION"
SCR=$(mktemp -d "${TMPDIR:-/tmp}/fm-radprobe.XXXXXX")
trap 'rm -rf "$SCR"; herdr_safe_stop_and_delete "$SESSION"' EXIT
fm_herdr_lab_prepare "$SESSION" || exit 1
. "$ROOT/bin/fm-backend.sh"; fm_backend_source herdr
herdr --version
C=$(fm_backend_herdr_container_ensure /tmp); C=${C%%$'\t'*}
st() { echo "  agent_state=$(fm_backend_herdr_pane_agent_state "$SESSION" "$1") process_state=$(fm_backend_herdr_pane_process_state "$SESSION" "$1") agent_get=$(herdr agent get "$1" --session "$SESSION" 2>&1 | jq -c '.result.agent|{agent,agent_status}? // .error.code' 2>/dev/null)"; }
dup() { if out=$(fm_backend_herdr_create_task "$C" "$1" /tmp 2>&1); then echo "  create_task same label: REPLACED (new ids: $out)"; else echo "  create_task same label: REFUSED ($(printf '%s' "$out" | tail -1))"; fi; }

echo "== A: report-agent on a pane idling at its own top shell"
read -r _ PA <<<"$(fm_backend_herdr_create_task "$C" fm-probe-a /tmp)"
herdr pane report-agent "$PA" --source fm-probe --agent probe-agent --state idle --session "$SESSION" >/dev/null
echo " t=0s:"; st "$PA"
sleep 2; echo " t=2s:"; st "$PA"
dup fm-probe-a

echo "== B: report-agent on a pane running an agent-named foreground process (claude -> sleep)"
read -r _ PB <<<"$(fm_backend_herdr_create_task "$C" fm-probe-b /tmp)"
ln -s "$(command -v sleep)" "$SCR/claude"
fm_backend_herdr_send_text_line "$SESSION:$PB" "$SCR/claude 900"
for i in $(seq 50); do [ "$(fm_backend_herdr_pane_process_state "$SESSION" "$PB")" = agent ] && break; sleep 0.1; done
herdr pane report-agent "$PB" --source fm-probe --agent probe-agent --state idle --session "$SESSION" >/dev/null
echo " t=0s:"; st "$PB"
sleep 3; echo " t=3s (past the ~1s release window):"; st "$PB"
dup fm-probe-b

echo "== C: same pane after the agent-named foreground process exits (Ctrl-C)"
fm_backend_herdr_send_key "$SESSION:$PB" C-c
sleep 3; echo " t=3s after exit:"; st "$PB"
dup fm-probe-b
