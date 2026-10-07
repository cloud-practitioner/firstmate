#!/usr/bin/env bash
# Diagnostic replay of the failing suite's exact serialized response contract.
# Not live evidence: the Herdr CLI is a canned fixture, Firstmate is real.
set -u
ROOT=$PWD
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/fm-husk-diagnostic.XXXXXX")
trap 'rm -rf -- "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/home/state" "$SCRATCH/responses" "$SCRATCH/fakebin"
export FM_HOME="$SCRATCH/home" FM_HERDR_LOG="$SCRATCH/calls" FM_HERDR_RESPONSES="$SCRATCH/responses"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE HERDR_ENV HERDR_PANE_ID HERDR_SOCKET_PATH
printf '%s\n' '{"result":{"tabs":[{"tab_id":"w1:t2","label":"fm-husk1","workspace_id":"w1"}]}}' > "$FM_HERDR_RESPONSES/1.out"
printf '%s\n' '{"result":{"panes":[{"pane_id":"w1:p2","tab_id":"w1:t2"}]}}' > "$FM_HERDR_RESPONSES/2.out"
printf '%s\n' '{"error":{"code":"pane_not_found","message":"pane w1:p2 not found"}}' > "$FM_HERDR_RESPONSES/3.out"
printf '%s\n' '{"result":{"tab":{"tab_id":"w1:t3"},"root_pane":{"pane_id":"w1:p3"}}}' > "$FM_HERDR_RESPONSES/4.out"
printf '%s\n' '{"result":{"tabs":[{"tab_id":"w1:t3","label":"fm-husk1","workspace_id":"w1"}]}}' > "$FM_HERDR_RESPONSES/6.out"
python3 - "$SCRATCH/fakebin/herdr" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_text('''#!/usr/bin/env bash
COUNT_FILE="$FM_HERDR_RESPONSES/.count"
n=$(( $(cat "$COUNT_FILE" 2>/dev/null || echo 0) + 1 ))
printf '%s' "$n" > "$COUNT_FILE"
printf '%s: ' "$n" >> "$FM_HERDR_LOG"
printf '%q ' "$@" >> "$FM_HERDR_LOG"
printf '\\n' >> "$FM_HERDR_LOG"
[ ! -f "$FM_HERDR_RESPONSES/$n.out" ] || cat "$FM_HERDR_RESPONSES/$n.out"
exit 0
''')
PY
chmod +x "$SCRATCH/fakebin/herdr"
export PATH="$SCRATCH/fakebin:$PATH"
. "$ROOT/bin/backends/herdr.sh"
set +e
out=$(fm_backend_herdr_create_task fmtest:w1 fm-husk1 /tmp/proj)
rc=$?
printf 'Original suite fixture: exit=%s output=%s\n' "$rc" "$out"
python3 - "$FM_HERDR_LOG" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).read_text())
PY
# Add only the extra read responses demanded by the close-boundary recheck.
# No Firstmate implementation or repository test file is modified.
rm -f "$FM_HERDR_RESPONSES/.count"
: > "$FM_HERDR_LOG"
printf '%s\n' '{"result":{"panes":[{"pane_id":"w1:p2","tab_id":"w1:t2"},{"pane_id":"w1:p3","tab_id":"w1:t3"}]}}' > "$FM_HERDR_RESPONSES/5.out"
printf '%s\n' '{"error":{"code":"pane_not_found","message":"pane w1:p2 not found"}}' > "$FM_HERDR_RESPONSES/6.out"
printf '%s\n' '{"result":{"tabs":[{"tab_id":"w1:t3","label":"fm-husk1","workspace_id":"w1"}]}}' > "$FM_HERDR_RESPONSES/8.out"
out=$(fm_backend_herdr_create_task fmtest:w1 fm-husk1 /tmp/proj)
rc=$?
printf 'Read-complete diagnostic fixture: exit=%s output=%s\n' "$rc" "$out"
python3 - "$FM_HERDR_LOG" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).read_text())
PY
[ "$rc" = 0 ] && [ "$out" = 'w1:t3 w1:p3' ]
