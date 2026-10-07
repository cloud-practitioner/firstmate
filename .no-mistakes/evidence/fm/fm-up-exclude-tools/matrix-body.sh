RUN=$$
SPAWN="$ROOT/bin/fm-spawn.sh"
CONTROL="$ROOT/bin/fm-control.sh"
TOOLS_FILE="$LAB/config/crew-exclude-tools"
write_exclusions() {
  printf '# Hide issue writes\r\n\r\n mcp__tracker__createIssue \r\nmcp__tracker__editIssue\r\nmcp__tracker__transitionIssue\r\nmcp__tracker__deleteIssue\r\nmissing_tool_for_live_check' > "$TOOLS_FILE"
}
brief() {
  local home=$1 id=$2 kind=$3
  if [ "$kind" = scout ]; then FM_HOME="$home" bin/fm-brief.sh "$id" tracker-demo --scout; else FM_HOME="$home" bin/fm-brief.sh "$id" tracker-demo --mode local-only; fi
  python3 - "$home/data/$id/brief.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); p.write_text(p.read_text().replace('{TASK}','Confirm tracker reads and comments remain available while writes are hidden. Do not edit files or run any pipeline.').replace('{FIRSTMATE_SPEC}','Use only the disposable tracker.'))
PY
}
field() {
  python3 - "$1" "$2" <<'PY'
from pathlib import Path
import sys
print(dict(line.split('=',1) for line in Path(sys.argv[1]).read_text().splitlines() if '=' in line).get(sys.argv[2],''))
PY
}
wait_worker() {
  local home=$1 id=$2 expect=$3 t i n
  t=$(field "$home/state/$id.meta" window)
  for i in $(seq 1 80); do
    if tmux -L fm-lab capture-pane -p -t "$t" | grep -q 'Trust project folder'; then
      tmux -L fm-lab send-keys -t "$t" Enter
    fi
    n=$(request_count)
    if [ "$n" -ge "$expect" ] && [ -f "$home/state/$id.busy-state" ] && grep -q 'state=idle' "$home/state/$id.busy-state"; then break; fi
    sleep .2
  done
  [ "$n" -ge "$expect" ] || { tmux -L fm-lab capture-pane -p -t "$t"; return 1; }
  sleep .5
}
request_count() { if [ -f "$ROOT/.validation-tmp/model-requests.jsonl" ]; then wc -l < "$ROOT/.validation-tmp/model-requests.jsonl"; else echo 0; fi; }
assert_registry() {
  local label=$1 expected=$2 home=$3 id=$4
  python3 - "$ROOT/.validation-tmp/model-requests.jsonl" "$ROOT/.validation-tmp/mcp-calls.jsonl" "$label" "$expected" "$home" "$id" <<'PY'
import json,sys
from pathlib import Path
requests,calls,label,expected,home,tid=sys.argv[1:]
r=json.loads(Path(requests).read_text().splitlines()[-1])
visible=set(r['tools'])
writes={'mcp__tracker__'+n for n in ['createIssue','editIssue','transitionIssue','deleteIssue']}
if expected=='excluded':
    assert not writes & visible,(label,visible)
    assert {'mcp__tracker__readIssue','mcp__tracker__addComment'} <= visible
elif expected=='comment-hidden':
    assert not (writes|{'mcp__tracker__addComment'}) & visible
    assert 'mcp__tracker__readIssue' in visible
elif expected=='all': assert writes|{'mcp__tracker__readIssue','mcp__tracker__addComment'} <= visible
elif expected=='one-hidden':
    assert 'mcp__tracker__createIssue' not in visible
    assert (writes-{'mcp__tracker__createIssue'})|{'mcp__tracker__readIssue','mcp__tracker__addComment'} <= visible
print('\nOBSERVED '+label+': model-visible tools = '+', '.join(sorted(visible)))
print('Tool results:', json.dumps([m.get('content') for m in r['messages'] if m['role']=='tool'][-2:]))
s=Path(home)/'state'/f'{tid}.status'
if s.exists(): print('Supervisor status:',s.read_text())
if expected=='excluded':
    assert s.exists()
    status=s.read_text(); assert 'unverified' in status and 'missing_tool_for_live_check' in status
    assert str(Path(home)/'config/crew-exclude-tools') in status
    assert 'Ã' not in status
state=Path(home)/'state'/f'{tid}.busy-state'
if state.exists(): print('Persisted lifecycle:',state.read_text().strip())
PY
}
write_exclusions
SHIP="xcl-ship-$RUN"; SCOUT="xcl-scout-$RUN"
for kind in ship scout; do
  if [ "$kind" = ship ]; then id=$SHIP; args=(--mode local-only --yolo off); else id=$SCOUT; args=(--scout); fi
  brief "$LAB" "$id" "$kind"
  before=$(request_count)
  printf '\nSCENARIO: Pi %s launches with per-home write exclusions\n' "$kind"
  FM_SPAWN_NO_GUARD=1 "$SPAWN" "$id" "$PROJ" "${args[@]}" --model lab/fixture
  wait_worker "$LAB" "$id" "$((before+2))"
  assert_registry "$kind launch (CRLF, whitespace, comment, blank, no-final-newline, UTF-8 home)" excluded "$LAB" "$id"
done
T=$(field "$LAB/state/$SHIP.meta" window)
BASE_WARNINGS=$(grep -c 'warning:' "$LAB/state/$SHIP.status")
for marker in ADVERSARIAL_DIRECT ADVERSARIAL_CODEMODE; do
  before=$(request_count)
  printf '\nSCENARIO: model attempts excluded createIssue using %s\n' "$marker"
  tmux -L fm-lab send-keys -t "$T" -l "$marker"
  tmux -L fm-lab send-keys -t "$T" Enter
  wait_worker "$LAB" "$SHIP" "$((before+2))"
  python3 - "$ROOT/.validation-tmp/model-requests.jsonl" "$ROOT/.validation-tmp/mcp-calls.jsonl" <<'PY'
from pathlib import Path
import json,sys
r=json.loads(Path(sys.argv[1]).read_text().splitlines()[-1])
results=[m.get('content','') for m in r['messages'] if m['role']=='tool']
print('Real Pi rejected attempted tool invocation:',json.dumps(results[-1:]))
assert results and ('not found' in str(results[-1]).lower() or 'not available' in str(results[-1]).lower() or 'unknown' in str(results[-1]).lower() or 'does not exist' in str(results[-1]).lower()),results[-1:]
calls=[json.loads(l) for l in Path(sys.argv[2]).read_text().splitlines()]
assert not any(c['tool']=='createIssue' for c in calls),'Excluded write reached MCP fixture'
print('MCP side effects: no createIssue call reached disposable tracker')
PY
  [ "$(grep -c 'warning:' "$LAB/state/$SHIP.status")" = "$BASE_WARNINGS" ]
done
printf '\nSCENARIO: malformed and unsupported replacement refuses BEFORE stopping live Pi\n'
cp "$LAB/state/$SHIP.meta" "$LAB/meta-before"
PID_BEFORE=$(tmux -L fm-lab display-message -p -t "$T" '#{pane_pid}:#{pane_current_command}')
printf 'two words\n' > "$TOOLS_FILE"
set +e
OUT=$(FM_SPAWN_NO_GUARD=1 "$CONTROL" "$SHIP" relaunch --note 'malformed-list safety check' 2>&1); RC=$?
set -e
printf '%s\nexit=%s\n' "$OUT" "$RC"
[ "$RC" = 1 ]; [[ "$OUT" == *'malformed entry'* ]]
cmp "$LAB/meta-before" "$LAB/state/$SHIP.meta"
[ "$PID_BEFORE" = "$(tmux -L fm-lab display-message -p -t "$T" '#{pane_pid}:#{pane_current_command}')" ]
write_exclusions
set +e
OUT=$(FM_SPAWN_NO_GUARD=1 "$CONTROL" "$SHIP" relaunch --harness codex --note 'unsupported replacement safety check' 2>&1); RC=$?
set -e
printf '%s\nexit=%s\n' "$OUT" "$RC"
[ "$RC" = 1 ]; [[ "$OUT" == *'codex runtime cannot hide tools'* ]]
cmp "$LAB/meta-before" "$LAB/state/$SHIP.meta"
[ "$PID_BEFORE" = "$(tmux -L fm-lab display-message -p -t "$T" '#{pane_pid}:#{pane_current_command}')" ]
printf 'Running worker retained: %s; durable metadata byte-identical after both refusals\n' "$PID_BEFORE"
printf '\nSCENARIO: unsupported runtimes and raw commands refuse BEFORE provisioning\n'
WINDOWS_BEFORE=$(tmux -L fm-lab list-windows -a -F '#{window_id}')
for runtime in claude codex grok opencode cursor omp gemini kimi muse devin agy rovo; do
  id="xcl-refuse-$runtime-$RUN"; brief "$LAB" "$id" ship
  set +e
  OUT=$(FM_SPAWN_NO_GUARD=1 "$SPAWN" "$id" "$PROJ" --mode local-only --yolo off --harness "$runtime" 2>&1); RC=$?
  set -e
  printf '%s: exit=%s\n%s\n' "$runtime" "$RC" "$OUT"
  [ "$RC" = 1 ]; [[ "$OUT" == *'runtime cannot hide tools'* ]]; [ ! -e "$LAB/state/$id.meta" ]
done
id="xcl-refuse-raw-$RUN"; brief "$LAB" "$id" ship
set +e
OUT=$(FM_SPAWN_NO_GUARD=1 "$SPAWN" "$id" "$PROJ" 'pi Verify this adapter' --mode local-only --yolo off 2>&1); RC=$?
set -e
printf 'raw command: exit=%s\n%s\n' "$RC" "$OUT"
[ "$RC" = 1 ]; [[ "$OUT" == *'raw launch command cannot hide tools'* ]]; [ ! -e "$LAB/state/$id.meta" ]
printf '\nSCENARIO: invalid syntax and unreadable/nonregular files refuse before provisioning\n'
i=0
for bad in 'two words' 'a,b' '*' 'mcp__tracker__*Issue' 'name;touch pwned' "quote'd" 'name$VAR' 'tool # trailing comment'; do
  i=$((i+1)); id="xcl-malformed-$i-$RUN"; brief "$LAB" "$id" ship
  printf 'mcp__tracker__readIssue\n%s\n' "$bad" > "$TOOLS_FILE"
  set +e
  OUT=$(FM_SPAWN_NO_GUARD=1 "$SPAWN" "$id" "$PROJ" --mode local-only --yolo off 2>&1); RC=$?
  set -e
  printf 'entry=%s: exit=%s\n%s\n' "$bad" "$RC" "$OUT"
  [ "$RC" = 1 ]; [[ "$OUT" == *'malformed entry'* ]]; [ ! -e "$LAB/state/$id.meta" ]
done
for invalid in unreadable directory dangling-symlink; do
  rm -f "$TOOLS_FILE"; id="xcl-invalid-$invalid-$RUN"; brief "$LAB" "$id" ship
  case "$invalid" in unreadable) printf 'read\n' > "$TOOLS_FILE"; chmod 000 "$TOOLS_FILE";; directory) mkdir "$TOOLS_FILE";; dangling-symlink) ln -s "$LAB/nonexistent" "$TOOLS_FILE";; esac
  set +e
  OUT=$(FM_SPAWN_NO_GUARD=1 "$SPAWN" "$id" "$PROJ" --mode local-only --yolo off 2>&1); RC=$?
  set -e
  printf '%s: exit=%s\n%s\n' "$invalid" "$RC" "$OUT"
  [ "$RC" = 1 ]; [[ "$OUT" == *'readable regular file'* ]]; [ ! -e "$LAB/state/$id.meta" ]
  if [ "$invalid" = directory ]; then rmdir "$TOOLS_FILE"; else rm -f "$TOOLS_FILE"; fi
done
[ "$WINDOWS_BEFORE" = "$(tmux -L fm-lab list-windows -a -F '#{window_id}')" ]
printf 'All rejected spawns left private tmux endpoint inventory unchanged and created no task metadata\n'
printf '\nSCENARIO: ship relaunch reads NEW exclusions; scout relaunch reads REMOVED exclusions\n'
write_exclusions; printf '\nmcp__tracker__addComment\n' >> "$TOOLS_FILE"
for kind in ship scout; do
  if [ "$kind" = ship ]; then id=$SHIP; expected=comment-hidden; else id=$SCOUT; expected=all; rm "$TOOLS_FILE"; fi
  t_before=$(field "$LAB/state/$id.meta" window)
  wt_before=$(field "$LAB/state/$id.meta" worktree)
  gen_before=$(field "$LAB/state/$id.meta" busy_gen)
  before=$(request_count)
  FM_SPAWN_NO_GUARD=1 FM_CONTROL_POLL=.2 "$CONTROL" "$id" relaunch --note "Recheck $kind with changed per-home exclusion configuration"
  wait_worker "$LAB" "$id" "$((before+2))"
  [ "$t_before" = "$(field "$LAB/state/$id.meta" window)" ]
  [ "$wt_before" = "$(field "$LAB/state/$id.meta" worktree)" ]
  [ "$gen_before" != "$(field "$LAB/state/$id.meta" busy_gen)" ]
  assert_registry "$kind relaunch" "$expected" "$LAB" "$id"
  printf 'Replacement kept endpoint=%s and worktree=%s; minted new busy generation\n' "$t_before" "$wt_before"
done
printf '\nSCENARIO: another home without exclusions retains all tools\n'
write_exclusions
OTHER=$(mktemp -d "$ROOT/.b.XXXX")
bin/fm-lab-home.sh create "$OTHER"
printf 'pi\n' > "$OTHER/config/crew-harness"; printf 'manual\n' > "$OTHER/config/backlog-backend"; printf 'tmux\n' > "$OTHER/config/backend"
id="xcl-home-b-$RUN"; brief "$OTHER" "$id" scout
before=$(request_count)
FM_HOME="$OTHER" FM_SPAWN_NO_GUARD=1 "$SPAWN" "$id" "$PROJ" --scout --model lab/fixture
wait_worker "$OTHER" "$id" "$((before+2))"
assert_registry 'home B without file while home A still excludes writes' all "$OTHER" "$id"
[ ! -e "$OTHER/config/crew-exclude-tools" ]
printf '\nSCENARIO: comments-only list leaves real Pi tools unchanged\n'
printf '# empty by choice\n  \n' > "$TOOLS_FILE"
id="xcl-empty-$RUN"; brief "$LAB" "$id" scout
before=$(request_count)
FM_SPAWN_NO_GUARD=1 "$SPAWN" "$id" "$PROJ" --scout --model lab/fixture
wait_worker "$LAB" "$id" "$((before+2))"
assert_registry 'comments-only configuration' all "$LAB" "$id"
printf '\nSIGNED RUNTIME AVAILABILITY CHECK (not a feature pass):\n'
id="xcl-signed-missing-$RUN"; brief "$LAB" "$id" scout
set +e
OUT=$(FM_SPAWN_NO_GUARD=1 "$SPAWN" "$id" "$PROJ" --scout --harness pi-signed --model lab/fixture 2>&1); RC=$?
set -e
printf 'bin/fm-spawn.sh --harness pi-signed: exit=%s\n%s\n' "$RC" "$OUT"
[ "$RC" = 1 ]; [[ "$OUT" == *'pi-signed executable not found on PATH'* ]]; [ ! -e "$LAB/state/$id.meta" ]
printf 'pi-signed live exclusion validation UNTESTED: authentic signed wrapper not installed; no substituted CLI\n'
printf '\nSCENARIO: secondmate agent ignores malformed parent worker list and does not inherit it\n'
# A byte-for-byte disposable product copy avoids the intentional rule forbidding
# a secondmate inside the code root while keeping all fixtures in this worktree.
SM=$(mktemp -d "$ROOT/.m.XXXX")
bin/fm-lab-home.sh create "$SM"
cp -R "$ROOT/bin" "$ROOT/.pi" "$ROOT/.claude" "$ROOT/.agents" "$SM/"
cp "$ROOT/AGENTS.md" "$SM/AGENTS.md"
id="xcl-secondmate-$RUN"
printf '%s\n' "$id" > "$SM/.fm-secondmate-home"
printf 'Inspect only the disposable tracker read and comment tools. Do not start supervision or any fleet task.\n' > "$SM/data/charter.md"
printf 'config/\nstate/\ndata/\nprojects/\n' > "$SM/.gitignore"
git -C "$SM" init -q -b main
printf 'pi lab/fixture\n' > "$LAB/config/secondmate-harness"
printf 'two words\n' > "$TOOLS_FILE"
before=$(request_count)
FM_SPAWN_NO_GUARD=1 "$ROOT/.validation-tmp/product/bin/fm-spawn.sh" "$id" "$SM" --secondmate
# A primary extension owns secondmate lifecycle; no worker busy-state is required.
t=$(field "$LAB/state/$id.meta" window)
for i in $(seq 1 150); do
  if tmux -L fm-lab capture-pane -p -t "$t" | grep -q 'Trust project folder'; then tmux -L fm-lab send-keys -t "$t" Enter; fi
  [ "$(request_count)" -ge "$((before+2))" ] && break; sleep .2
done
tmux -L fm-lab capture-pane -p -t "$t"
[ "$(request_count)" -ge "$((before+2))" ]
assert_registry 'secondmate agent with malformed parent exclusions' all "$LAB" "$id"
[ ! -e "$SM/config/crew-exclude-tools" ]
printf 'Secondmate exclusion config absent after real spawn inheritance; parent malformed list did not refuse agent\n'
printf '\nSCENARIO: secondmate relaunch remains unaffected; its workers use only their OWN exclusion list\n'
printf 'mcp__tracker__createIssue\n' > "$SM/config/crew-exclude-tools"
before=$(request_count)
FM_SPAWN_NO_GUARD=1 FM_CONTROL_POLL=.2 "$ROOT/.validation-tmp/product/bin/fm-control.sh" "$id" relaunch
for i in $(seq 1 150); do [ "$(request_count)" -ge "$((before+2))" ] && break; sleep .2; done
[ "$(request_count)" -ge "$((before+2))" ]
assert_registry 'secondmate relaunch ignores parent and own worker lists' all "$LAB" "$id"
worker="xcl-secondmate-worker-$RUN"
brief "$SM" "$worker" scout
before=$(request_count)
FM_HOME="$SM" FM_SPAWN_NO_GUARD=1 "$SM/bin/fm-spawn.sh" "$worker" "$PROJ" --scout --model lab/fixture
wait_worker "$SM" "$worker" "$((before+2))"
assert_registry 'secondmate own worker hides only its locally configured createIssue' one-hidden "$SM" "$worker"
printf '\nREAL CLI END-USER RESULT (last worker viewport):\n'
tmux -L fm-lab capture-pane -p -t "${T:-$t}" | tail -24
printf '\nLIVE MATRIX COMPLETE; all marked homes and private tmux server removed by trap\n'
