#!/usr/bin/env bash
set -eu
. /home/node/.no-mistakes/evidence/01M65NDEZRAT81MFEX2NMZGR4B/live-lab-common.sh
lab workspace create --label firstmate --no-focus >/dev/null
out=$(lab tab create --workspace w1 --label fm-pi --cwd "$LAB" --env "PI_CODING_AGENT_DIR=$LAB/pi-config" --focus)
PANE=$(printf '%s' "$out" | jq -r .result.root_pane.pane_id)
TARGET="$LAB_SESSION:$PANE"
IDENT=$(fm_backend_herdr_pane_process_identity "$LAB_SESSION" "$PANE")
printf 'backend=herdr\nwindow=%s\nherdr_process_identity=%s\nworktree=%s\n' "$TARGET" "$IDENT" "$LAB" > "$LAB/state/pi.meta"
# Herdr's actual terminal is 40x120 (its real pane response records viewport_rows=40).
# No model request, login, config mutation, or replacement CLI is involved.
lab agent start composer-proof --kind pi --pane "$PANE" --timeout 15000 -- \
  --no-extensions --no-mcp --no-skills --no-prompt-templates --no-context-files --no-session --offline --no-approve
sleep .5
lab pane get "$PANE"
lab pane read "$PANE" --lines 200
lab agent get "$PANE"
: > "$LAB/operations.log"
state=$(fm_backend_composer_state herdr "$TARGET" fm-pi)
echo "REAL PI COMPOSER BASELINE: $state"
[ "$state" = empty ]
# Verify the baseline actually entered the lazy native identity path, using
# emitted transport operations rather than inspecting implementation source.
grep '^agent get' "$LAB/operations.log"
: > "$LAB/operations.log"
: > "$LAB/stop-after-read"
state=$(fm_backend_composer_state herdr "$TARGET" fm-pi)
echo "REAL PI COMPOSER after server stopped between viewport and lazy identity: $state"
[ "$state" = unknown ]
[ "$(lab status --json | jq -r .server.running)" = false ]
if grep -q '^server ' "$LAB/operations.log"; then exit 31; fi
cat "$LAB/fault.log"
echo 'PASS: passive inspection of the actual Pi TUI did not restart the server after capture'
