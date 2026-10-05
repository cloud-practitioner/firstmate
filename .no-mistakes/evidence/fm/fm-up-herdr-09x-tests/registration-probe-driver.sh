#!/usr/bin/env bash
set -euo pipefail
E=/home/node/.no-mistakes/evidence/01M469KHGAXW3MXGQ83EVZD7E8
VERSION=$($FM_REAL_HERDR --version | awk '{print $2}')
SESSION=$(bin/fm-herdr-lab.sh name probe)
cleanup() { bin/fm-herdr-lab.sh teardown "$SESSION"; }
trap cleanup EXIT
bin/fm-herdr-lab.sh provision "$SESSION"
h() { printf '\n$ herdr'; printf ' %q' "$@"; printf ' --session %q\n' "$SESSION"; bin/fm-herdr-lab.sh run "$SESSION" "$@"; }
RAW=$(bin/fm-herdr-lab.sh run "$SESSION" workspace create --cwd "$PWD/.v/tmp" --label probe --no-focus)
printf '%s\n' "$RAW"
PANES=$(bin/fm-herdr-lab.sh run "$SESSION" pane list)
printf '%s\n' "$PANES"
PANE=$(printf '%s' "$PANES" | jq -r '.result.panes[0].pane_id')
[ -n "$PANE" ] && [ "$PANE" != null ]
h pane read "$PANE" --source visible > "$E/$VERSION-glyph-viewport.txt"
h pane run "$PANE" "exec env PS1='hsmoke\$ ' HISTFILE=/dev/null /usr/bin/bash --noprofile --norc"
h pane run "$PANE" clear
sleep 0.5
bin/fm-herdr-lab.sh run "$SESSION" pane read "$PANE" --source visible > "$E/$VERSION-neutral-viewport.txt"
h pane process-info --pane "$PANE"
h pane report-agent "$PANE" --source fm-probe --agent probe-agent --state idle
sleep 2
set +e
TOP=$(bin/fm-herdr-lab.sh run "$SESSION" agent get "$PANE" 2>&1); RC=$?
set -e
printf '\nTop-shell registration after two seconds (exit %s):\n%s\n' "$RC" "$TOP"
[ "$RC" -ne 0 ]
printf '%s' "$TOP" | jq -e '.error.code == "agent_not_found"' >/dev/null
h pane run "$PANE" '/usr/bin/bash --noprofile --norc'
sleep 0.5
h pane process-info --pane "$PANE"
h pane report-agent "$PANE" --source fm-probe --agent probe-agent --state idle
sleep 2
h agent get "$PANE"
ln -sf "$(command -v sleep)" .v/claude
printf -v Q '%q' "$PWD/.v/claude"
h pane run "$PANE" "$Q 900"
sleep 0.5
h pane report-agent "$PANE" --source fm-probe --agent probe-agent --state idle
sleep 2
h agent get "$PANE"
INFO=$(bin/fm-herdr-lab.sh run "$SESSION" pane process-info --pane "$PANE")
printf '\nLive process:\n%s\n' "$INFO"
PID=$(printf '%s' "$INFO" | jq -r '.result.process_info.foreground_processes[] | select(.name == "claude") | .pid')
[ -n "$PID" ]
kill "$PID"
sleep 2
h pane process-info --pane "$PANE"
h agent get "$PANE"
. bin/fm-backend.sh
fm_backend_source herdr
printf '\nClassifier after process exit: pane=%s recovery=%s\n' "$(fm_backend_herdr_pane_agent_state "$SESSION" "$PANE")" "$(fm_backend_agent_state herdr "$SESSION:$PANE")"
[ "$(fm_backend_herdr_pane_agent_state "$SESSION" "$PANE")" = stale-agent ]
[ "$(fm_backend_agent_state herdr "$SESSION:$PANE")" = dead ]
cleanup
trap - EXIT
printf '\nNamed lab deleted; default-session tripwire unchanged.\n'
