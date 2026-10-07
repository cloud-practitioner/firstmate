#!/usr/bin/env bash
set -eu
ROOT=$PWD
EVID=/home/node/.no-mistakes/evidence/01M4ADJ9R8AD3453670KZJM8HE
export PATH="$ROOT/.validation-tools/usr/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/.validation-tools/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset HERDR_ENV HERDR_SESSION HERDR_SOCKET_PATH HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
unset PI_CODING_AGENT FM_TASK_ID TMUX TMUX_PANE
export FM_BACKEND=tmux
LAB=$(mktemp -d "$ROOT/.é.XXXX")
SERVER=
OTHER=
SM=
cleanup() {
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server 2>/dev/null || true
  [ -z "$SERVER" ] || kill "$SERVER" 2>/dev/null || true
  chmod -R u+w "$LAB" 2>/dev/null || true
  rm -rf "$LAB"
  for d in "${OTHER:-}" "${SM:-}"; do [ -z "$d" ] || { chmod -R u+w "$d" 2>/dev/null || true; rm -rf "$d"; }; done
}
trap cleanup EXIT
bin/fm-lab-home.sh create "$LAB"
mkdir -p "$LAB/tmux" "$LAB/user-home" "$LAB/pi" "$LAB/pool"
export HOME="$LAB/user-home" FM_HOME="$LAB" PI_CODING_AGENT_DIR="$LAB/pi" PI_CODING_AGENT_SESSION_DIR="$LAB/pi/sessions"
export PI_OFFLINE=1 PI_TELEMETRY=0 TMPDIR="$LAB" TREEHOUSE_ROOT="$LAB/pool"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
python3 "$ROOT/.validation-tmp/services.py" & SERVER=$!
for i in $(seq 1 40); do [ -f "$ROOT/.validation-tmp/port" ] && break; sleep 0.1; done
python3 - "$LAB" "$ROOT" <<'PY'
import json,sys
from pathlib import Path
lab,root=map(Path,sys.argv[1:])
port=(root/'.validation-tmp/port').read_text()
(lab/'pi/models.json').write_text(json.dumps({'providers':{'lab':{'baseUrl':f'http://127.0.0.1:{port}/v1','api':'openai-completions','apiKey':'disposable-local-service','models':[{'id':'fixture','name':'Disposable test endpoint','reasoning':False,'input':['text'],'contextWindow':65536,'maxTokens':2048,'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0}}]}}}))
(lab/'pi/settings.json').write_text(json.dumps({'defaultProvider':'lab','defaultModel':'fixture','defaultThinkingLevel':'off','extensions':['-builtin:telemetry'],'defaultTools':['+codemode'],'skills':[],'promptTemplates':[]}))
(lab/'pi/mcp.json').write_text(json.dumps({'mcpServers':{'tracker':{'command':'python3','args':[str(root/'.validation-tmp/services.py'),'mcp'],'exposure':'direct'}}}))
PY
printf 'pi\n' > "$LAB/config/crew-harness"
printf 'manual\n' > "$LAB/config/backlog-backend"
printf 'tmux\n' > "$LAB/config/backend"
# The primary is a real Pi CLI, isolated from operator data and configuration.
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab new-session -d -s primary -x 120 -y 40 -c "$ROOT" -e FM_HOME="$LAB" 'pi --offline --no-mcp --no-extensions --no-skills --no-prompt-templates --no-context-files --approve --model lab/fixture'
export TMUX_TMPDIR="$LAB/tmux"
tmux -L fm-lab set-option -g default-shell /bin/bash
export TMUX="$(tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')"
PROJ="$LAB/projects/tracker-demo"
mkdir -p "$PROJ"
git -C "$PROJ" init -q -b main
printf 'Disposable tracker demo\n' > "$PROJ/README.md"
git -C "$PROJ" add README.md
git -C "$PROJ" -c user.name='Lab' -c user.email='lab@example.invalid' commit -qm 'fixture'

. "$ROOT/.validation-tmp/matrix-body.sh"
