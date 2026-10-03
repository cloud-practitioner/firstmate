#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EV=/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C
export TMPDIR="$ROOT/.test-phase-tmp" XDG_CONFIG_HOME=.h XDG_STATE_HOME=.h/state FM_HERDR_LAB_STATE_DIR="$ROOT/.test-phase-tmp/herdr-private"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null
export FM_HOME="$LAB"
NAME=fm-lab-round2
cleanup() { "$ROOT/bin/fm-herdr-lab.sh" teardown "$NAME" >> "$EV/claude-composer.log" 2>&1; rm -rf "$LAB"; }
trap cleanup EXIT
hr() { "$ROOT/bin/fm-herdr-lab.sh" run "$NAME" "$@"; }
"$ROOT/bin/fm-herdr-lab.sh" teardown "$NAME"
"$ROOT/bin/fm-herdr-lab.sh" provision "$NAME"
hr workspace create --cwd "$ROOT" --label lab-primary --env "FM_HOME=$LAB" --focus > "$LAB/workspace.json"
PANE=$(jq -r '.result.root_pane.pane_id' "$LAB/workspace.json")
[ -n "$PANE" ] && [ "$PANE" != null ]
printf 'Named lab=%s pane=%s; normal Claude login, isolated FM_HOME; no model prompts\n' "$NAME" "$PANE" > "$EV/claude-composer.log"
"$ROOT/bin/fm-herdr-lab.sh" viewer start "$NAME" >> "$EV/claude-composer.log" 2>&1
hr pane run "$PANE" "env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT claude --setting-sources ''" >> "$EV/claude-composer.log"
for i in $(seq 1 80); do hr pane read "$PANE" --source visible > "$LAB/screen"; if grep -q 'Claude Code' "$LAB/screen" && grep -q '❯' "$LAB/screen"; then break; fi; sleep .5; done
sleep 2
hr pane read "$PANE" --source visible > "$EV/claude-initial.txt"
. "$ROOT/bin/backends/herdr.sh"
# Route the unchanged adapter's CLI through the sole authorized lab transport.
fm_backend_herdr_cli() { local name=$1; shift; "$ROOT/bin/fm-herdr-lab.sh" run "$name" "$@"; }
TARGET="$NAME:$PANE"
hr pane send-text "$PANE" '/rename upstream-live-lab' >/dev/null
hr pane send-keys "$PANE" enter >/dev/null
sleep 2
hr pane read "$PANE" --source visible --format ansi > "$EV/claude-titled.ansi"
STATE=$(fm_backend_herdr_composer_state "$TARGET")
printf 'Named-session idle composer state=%s\n' "$STATE" >> "$EV/claude-composer.log"
[ "$STATE" = empty ]
hr pane send-text "$PANE" '/exit' >/dev/null
sleep .5
hr pane read "$PANE" --source visible --format ansi > "$EV/claude-slash.ansi"
CONTENT=$(fm_backend_herdr_composer_content "$TARGET")
printf 'Visible typed slash-command payload=%s\n' "$CONTENT" >> "$EV/claude-composer.log"
[ "$CONTENT" = /exit ]
REFUSED=$(fm_backend_herdr_send_text_submit "$TARGET" /exit 3 .15 .15)
printf 'Attempt to inject over an existing draft=%s\n' "$REFUSED" >> "$EV/claude-composer.log"
[ "$REFUSED" = send-failed ]
[ "$(fm_backend_herdr_composer_content "$TARGET")" = /exit ]
fm_backend_herdr_composer_clear "$TARGET" /exit
DELIVERY=$(fm_backend_herdr_send_text_submit "$TARGET" '/rename slash-proof-landed' 3 .15 .15)
printf 'Submit a grey slash command from empty=%s\n' "$DELIVERY" >> "$EV/claude-composer.log"
[ "$DELIVERY" = empty ]
sleep 1
hr pane read "$PANE" --source visible > "$EV/claude-slash-delivered.txt"
grep -q 'Session renamed to: slash-proof-landed' "$EV/claude-slash-delivered.txt"
DELIVERY=$(fm_backend_herdr_send_text_submit "$TARGET" /exit 3 .15 .15)
printf 'Exit submit verdict=%s (a closed agent may read unknown)\n' "$DELIVERY" >> "$EV/claude-composer.log"
sleep 2
hr pane read "$PANE" --source visible > "$EV/claude-after-exit.txt"
hr pane process-info --pane "$PANE" > "$EV/claude-after-exit-process.json"
jq -e '.result.process_info.foreground_processes | length==1 and .[0].name=="zsh"' "$EV/claude-after-exit-process.json" >/dev/null
printf 'Grey slash delivered and /exit returned to the pane shell (real process-info confirms zsh).\n' >> "$EV/claude-composer.log"
