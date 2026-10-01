#!/usr/bin/env bash
# Drive firstmate's real Herdr backend (bin/backends/herdr.sh) against Herdr 0.9.3
# in an isolated fm-lab session: duplicate-label handling across agent lifecycle.
set -u
ROOT=$1; cd "$ROOT"
. tests/herdr-test-safety.sh; herdr_forget_inherited_pane
SESSION="fm-lab-livedup-adv-$$"; export HERDR_SESSION="$SESSION"
D=$(mktemp -d)
trap 'rm -rf "$D"; herdr_safe_stop_and_delete "$SESSION"; echo "teardown done"' EXIT
fm_herdr_lab_prepare "$SESSION" || exit 1
. bin/fm-backend.sh; fm_backend_source herdr
echo "herdr: $(herdr --version)  session: $SESSION"
C=$(fm_backend_herdr_container_ensure /tmp); SEED=${C#*$'\t'}; C=${C%%$'\t'*}
fm_backend_herdr_create_task "$C" fm-adv-anchor /tmp "$SEED" >/dev/null
st() { fm_backend_herdr_pane_agent_state "$SESSION" "$1"; }
dup() { # label old_pane
  local out; if out=$(fm_backend_herdr_create_task "$C" "$1" /tmp 2>&1); then echo "create_task(dup) -> REPLACED, new ids: $out"
  else echo "create_task(dup) -> REFUSED: $(printf '%s' "$out" | head -1 | cut -c1-140)"; fi
  herdr pane get "$2" --session "$SESSION" >/dev/null 2>&1 && echo "  old pane $2 still exists" || echo "  old pane $2 closed"
}
ln -s "$(command -v sleep)" "$D/claude"

echo "=== 1. live agent: agent-named foreground process + report-agent"
read -r T P <<<"$(fm_backend_herdr_create_task "$C" fm-adv-live /tmp)"
fm_backend_herdr_send_text_line "$SESSION:$P" "$D/claude 900"
for i in $(seq 50); do [ "$(fm_backend_herdr_pane_process_state "$SESSION" "$P")" = agent ] && break; sleep 0.1; done
herdr pane report-agent "$P" --source adv --agent adv-agent --state idle --session "$SESSION" >/dev/null
sleep 2; echo "after 2s: process_state=$(fm_backend_herdr_pane_process_state "$SESSION" "$P") agent_state=$(st "$P")"
dup fm-adv-live "$P"

echo "=== 2. same pane after the agent process exits (Ctrl-C)"
herdr pane send-keys "$P" C-c --session "$SESSION" >/dev/null; sleep 3
echo "after exit+3s: process_state=$(fm_backend_herdr_pane_process_state "$SESSION" "$P") agent_state=$(st "$P")"
dup fm-adv-live "$P"

echo "=== 3. report-agent on an idle top shell (the base test's stale setup), then wait 1s"
read -r T P <<<"$(fm_backend_herdr_create_task "$C" fm-adv-idle /tmp)"
herdr pane report-agent "$P" --source adv --agent adv-agent --state idle --session "$SESSION" >/dev/null
echo "immediately: agent_state=$(st "$P")"; sleep 1
echo "after 1s: process_state=$(fm_backend_herdr_pane_process_state "$SESSION" "$P") agent_state=$(st "$P")"
dup fm-adv-idle "$P"
