#!/usr/bin/env bash
# Probe Herdr report-agent registration lifetime in an isolated fm-lab session.
set -u
cd "$1"; L=bin/fm-herdr-lab.sh
unset HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID
S=$($L name raprobe)
echo "session=$S herdr=$(herdr --version)"
$L provision "$S" || { echo provision failed; exit 1; }
trap '$L teardown "$S"; echo "teardown exit=$?"' EXIT
$L run "$S" workspace create --cwd /tmp --label probe >/dev/null
P=$($L run "$S" pane list | jq -r '.result.panes[0].pane_id')
echo "pane=$P"; sleep 1
poll() { # label
  local t0=$(date +%s%N) d ms
  $L run "$S" pane report-agent "$P" --source fm-probe --agent probe-agent --state idle >/dev/null
  for d in 0 250 500 1000 1500 2000 3000 5000; do
    ms=$(( (t0 + d*1000000 - $(date +%s%N)) / 1000000 ))
    [ "$ms" -le 0 ] || sleep "$(printf '%d.%03d' $((ms/1000)) $((ms%1000)))"
    r=$($L run "$S" agent get "$P" 2>&1 | jq -c 'if .error then .error.code else (.result.agent|{agent,agent_status}) end' 2>/dev/null)
    printf '  %-28s t+%5sms %s\n' "$1" "$d" "$r"
  done
}
echo "--- A: pane idle at its own top shell"
poll idle-top-shell
echo "--- B: foreground = agent-named sleep (claude -> sleep symlink)"
D=$(mktemp -d); ln -s "$(command -v sleep)" "$D/claude"
$L run "$S" pane run "$P" "$D/claude 60" >/dev/null; sleep 1
$L run "$S" pane process-info --pane "$P" | jq -c '.result.process_info | {foreground: .foreground_process_group // .foreground // .}' 2>/dev/null | cut -c1-200
poll agent-named-foreground
$L run "$S" pane send-keys "$P" C-c >/dev/null; sleep 1
echo "--- C: back at top shell after the foreground process exits"
$L run "$S" agent get "$P" 2>&1 | jq -c 'if .error then .error.code else (.result.agent|{agent,agent_status}) end'
poll idle-top-shell-again
rm -rf "$D"
