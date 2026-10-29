#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EV=/home/node/.no-mistakes/evidence/01M643TH9MB3MKY9CTY96RSFYG
export TMPDIR="$ROOT/.test-phase/tmp" FM_HERDR_LAB_STATE_DIR="$ROOT/.test-phase/herdr-state"
unset FM_HOME FM_BACKEND FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS FM_TASK_ID FM_TASK_INBOX FM_SUPERVISION_ACTOR
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
SESSION=$(bin/fm-herdr-lab.sh name read-native)
REAL_PATH=$PATH
cleanup() {
 rc=$?
 PATH="$REAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" teardown "$SESSION" || rc=1
 find "$LAB" -type d -exec chmod u+rwx {} +
 rm -rf "$LAB"
 echo "native read lab removed; fleet tripwire verified; exit=$rc"
 exit "$rc"
}
trap cleanup EXIT
bin/fm-herdr-lab.sh provision "$SESSION"
export SESSION REAL_PATH REAL_HERDR=$(command -v herdr) LAB_HELPER="$ROOT/bin/fm-herdr-lab.sh"
mkdir -p "$LAB/transport"
cat > "$LAB/transport/herdr" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
args=()
while [ $# -gt 0 ]; do
 case "$1" in
 --session) [ "$2" = "$SESSION" ] || exit 78; shift 2 ;;
 --session=*) [ "${1#*=}" = "$SESSION" ] || exit 78; shift ;;
 --version|-V) exec "$REAL_HERDR" "$@" ;;
 *) args+=("$1"); shift ;;
 esac
done
exec env PATH="$REAL_PATH" "$LAB_HELPER" run "$SESSION" "${args[@]}"
SH
chmod +x "$LAB/transport/herdr"
export PATH="$LAB/transport:$REAL_PATH" FM_HOME="$LAB" HERDR_SESSION="$SESSION"
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
# Exact production code, a marked home, real lock acquisition and real turn-end markers.
PRIMARY="$LAB/primary"
"$ROOT/bin/fm-lab-home.sh" create "$PRIMARY" >/dev/null
cp -a "$ROOT/bin" "$ROOT/.pi" "$ROOT/.agents" "$ROOT/.tasks.toml" "$PRIMARY/"
mkdir -p "$PRIMARY/agent" "$PRIMARY/os-home"
printf '{"enabled":true}\n' > "$PRIMARY/config/read-repetition.json"
printf '# Backlog\n\n## In flight\n\n## Queued\n\n## Done\n' > "$PRIMARY/data/backlog.md"
seq 1 50 > "$PRIMARY/fixture.txt"
cat > "$PRIMARY/workload.ts" <<'TS'
import {writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {createFauxCore, fauxAssistantMessage, fauxText, fauxToolCall} from '@earendil-works/pi-ai';
export default function(pi) {
 let requests=0;
 const save=()=>writeFileSync(process.env.READ_RECEIPT,JSON.stringify({requests}));
 const faux=createFauxCore({api:'controlled-read-api',provider:'controlled-read',models:[{id:'scripted',name:'Controlled workload (not a live model)',reasoning:false,input:['text'],cost:{input:0,output:0,cacheRead:0,cacheWrite:0},contextWindow:32768,maxTokens:128}],tokenSize:{min:1,max:1}});
 const command=`(cd '${process.env.FM_HOME}'\necho real-file-read\nsed -n '1,20p' fixture.txt | wc -l\nsed -n '1,20p' fixture.txt | head -c 500 | tail -c 80 | od -An -tx1c\n)`;
 const calls=(n)=>[...Array.from({length:n},(_,i)=>fauxAssistantMessage([fauxToolCall('bash',{command},{id:'read-'+requests+'-'+i})],{stopReason:'toolUse'})),fauxAssistantMessage([fauxText('Controlled workload complete')])];
 faux.setResponses(calls(6));
 pi.registerProvider('controlled-read',{baseUrl:'http://127.0.0.1/unused',apiKey:'explicitly-synthetic',api:faux.api,models:faux.models,streamSimple:(...args)=>{requests++;save();return faux.streamSimple(...args)}});
 pi.on('session_start',()=>{const r=spawnSync(process.env.FM_HOME+'/bin/fm-lock.sh',[],{encoding:'utf8'});writeFileSync(process.env.LOCK_RECEIPT,r.stdout+r.stderr);if(r.status!==0)throw new Error('Real primary lock acquisition failed: '+r.stdout+r.stderr)});
 pi.on('input',(event)=>{if(event.text==='RESET_ONCE')faux.setResponses(calls(1))});
}
TS
python3 - "$PRIMARY" "$(command -v pi)" <<'PY'
import pathlib,shlex,sys
p=pathlib.Path(sys.argv[1]);pi=sys.argv[2]
env=['env','-u','NO_MISTAKES_GATE','-u','FM_GATE_REFUSE_BYPASS','-u','FM_TASK_ID','-u','FM_TASK_INBOX','-u','FM_SUPERVISION_ACTOR','-u','FM_ROOT_OVERRIDE','-u','FM_STATE_OVERRIDE','-u','FM_DATA_OVERRIDE','-u','FM_CONFIG_OVERRIDE','-u','FM_PROJECTS_OVERRIDE',f'HOME={p}/os-home',f'FM_HOME={p}',f'PI_CODING_AGENT_DIR={p}/agent','PI_OFFLINE=1',f'READ_RECEIPT={p}/receipt.json',f'LOCK_RECEIPT={p}/lock-receipt.txt',pi,'--approve','--offline','--no-mcp','--no-context-files','--no-skills','--no-prompt-templates','--no-extensions','-e',str(p/'workload.ts'),'-e',str(p/'.pi/extensions/fm-primary-turnend-guard.ts'),'-e',str(p/'.pi/extensions/fm-primary-read-repetition.ts'),'--model','controlled-read/scripted','--thinking','off']
(p/'launch.sh').write_text(shlex.join(env)+'\n')
PY
RAW=$(fm_backend_herdr_container_ensure "$PRIMARY" '' "$SESSION")
CONTAINER=${RAW%%$'\t'*}
SEEDED=${RAW#*$'\t'}
IDS=$(fm_backend_herdr_create_task "$CONTAINER" fm-read-primary "$PRIMARY" "$SEEDED")
read -r TAB PANE <<< "$IDS"
TARGET="$SESSION:$PANE"
fm_backend_herdr_send_text_line "$TARGET" ". '$PRIMARY/launch.sh'"
sleep 4
fm_backend_herdr_send_text_line "$TARGET" 'Run the controlled file-read workload.'
check_state() {
 python3 - "$PRIMARY" "$1" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]);want=int(sys.argv[2]);receipt=p/'receipt.json'
if not receipt.exists():raise SystemExit(1)
entries=[]
for f in (p/'agent/sessions').rglob('*.jsonl'):
 for line in f.read_text().splitlines():
  try:entries.append(json.loads(line))
  except ValueError:pass
notices=[e for e in entries if e.get('customType')=='fm-read-repetition-stopped']
results=[e['message'] for e in entries if e.get('type')=='message' and e.get('message',{}).get('role')=='toolResult' and e['message'].get('toolName')=='bash' and not e['message'].get('isError')]
if len(results)!=want or len(notices)!=1:raise SystemExit(1)
if not all('real-file-read' in str(r) for r in results):raise SystemExit('Native bash did not return the real fixture output')
print(json.dumps({'nativeBashReads':len(results),'durableStopNotices':len(notices),'providerRequests':json.loads(receipt.read_text())['requests'],'source':'Real Pi, native bash, production locks/guards; scripted model workload only'}))
PY
}
OK=0
for _ in $(seq 1 70); do if check_state 3 > "$LAB/first.json"; then OK=1;break;fi;sleep 0.5;done
fm_backend_herdr_visible_capture "$TARGET" > "$EV/read-guard-pane.txt"
if [ "$OK" != 1 ];then
 fm_backend_herdr_capture "$TARGET" 150
 [ ! -f "$PRIMARY/lock-receipt.txt" ] || python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).read_text())' "$PRIMARY/lock-receipt.txt"
 echo 'Native read guard did not reach expected stopped state';exit 1
fi
cp "$LAB/first.json" "$EV/read-guard-native.json"
cat "$LAB/first.json"
BEFORE=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["requests"])' "$PRIMARY/receipt.json")
fm_backend_herdr_send_text_line "$TARGET" $'\u2063FIRSTMATE_OP: v1 watcher: controlled wake must not reset the stop'
sleep 2
AFTER=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["requests"])' "$PRIMARY/receipt.json")
[ "$BEFORE" = "$AFTER" ]
echo 'Operational wake did not reset latch or start model work'
fm_backend_herdr_send_text_line "$TARGET" RESET_ONCE
OK=0
for _ in $(seq 1 50);do if check_state 4 > "$LAB/reset.json";then OK=1;break;fi;sleep 0.5;done
[ "$OK" = 1 ]
cp "$LAB/reset.json" "$EV/read-guard-reset.json"
cat "$LAB/reset.json"
fm_backend_herdr_visible_capture "$TARGET" > "$EV/read-guard-reset-pane.txt"
echo 'Fresh interactive input reset the guard and one more native read completed'
