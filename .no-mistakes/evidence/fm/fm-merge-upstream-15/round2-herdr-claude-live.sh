#!/usr/bin/env bash
set -eu
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M64ZPT5AJ4390HHRPB92ZDZC
export TMPDIR="$ROOT/.test-validation/tmp"
export FM_HERDR_LAB_STATE_DIR="$ROOT/.test-validation/herdr-state"
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
S=$(bin/fm-herdr-lab.sh name merge15-r2)
SHIM=$(bin/fm-live-claude.sh shim "$LAB/claude-shim")
BEFORE=$(readlink "$(command -v claude)")
cleanup() {
 rc=$?
 set +e
 bin/fm-herdr-lab.sh teardown "$S"
 clean=$?
 AFTER=$(readlink "$(command -v claude)")
 printf 'launcher_before=%s\nlauncher_after=%s\nherdr_teardown_exit=%s\n' "$BEFORE" "$AFTER" "$clean"
 [ "$BEFORE" = "$AFTER" ] || rc=1
 [ "$clean" = 0 ] || rc=1
 rm -rf "$LAB"
 exit "$rc"
}
trap cleanup EXIT
bin/fm-herdr-lab.sh provision "$S"
bin/fm-herdr-lab.sh viewer start "$S"
OUT=$(bin/fm-herdr-lab.sh run "$S" workspace create --cwd "$PWD" --label validation-primary --no-focus --env "FM_HOME=$LAB")
printf '%s\n' "$OUT"
PANE=$(printf '%s' "$OUT" | jq -r '.result.root_pane.pane_id // empty')
[ -n "$PANE" ]
printf -v CMD 'env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE FM_HOME=%q %q --print --model sonnet --effort low --setting-sources project,local --output-format json %q > %q 2>&1; printf "\\nCLAUDE_EXIT=%%s\\n" "$?" >> %q' "$LAB" "$SHIM/claude" 'Reply exactly FM_MERGE15_ROUND2_READY. Do not call tools.' "$LAB/result" "$LAB/result"
bin/fm-herdr-lab.sh run "$S" pane run "$PANE" "$CMD"
for i in $(seq 1 100); do
 if [ -f "$LAB/result" ] && grep -q 'CLAUDE_EXIT=' "$LAB/result"; then break; fi
 sleep 1
done
[ -f "$LAB/result" ]
cp "$LAB/result" "$E/herdr-claude-round2-result.log"
bin/fm-herdr-lab.sh run "$S" pane read --lines 60 "$PANE" > "$E/herdr-claude-round2-terminal.txt"
python3 - "$LAB/result" <<'PY'
import sys,json
s=open(sys.argv[1]).read()
print(s)
assert 'CLAUDE_EXIT=0' in s,s
assert 'FM_MERGE15_ROUND2_READY' in json.loads(s.split('\nCLAUDE_EXIT=')[0])['result'],s
PY
