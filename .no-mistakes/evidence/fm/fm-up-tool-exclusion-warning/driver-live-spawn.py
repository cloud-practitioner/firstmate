import os, json, subprocess, threading, time, shutil
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
ROOT=Path.cwd()
EVIDENCE=Path('/home/node/.no-mistakes/evidence/01M65MFBQHY7METR56JHMH28BV')
BASE=ROOT/'.test-phase/spawn-lab'
HOME=BASE/'home'
HELPER=ROOT/'bin/fm-herdr-lab.sh'
BASE.mkdir(exist_ok=True)
requests=[]
class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers['content-length'])))
        requests.append(body)
        content={'id':'chatcmpl-fixture','object':'chat.completion.chunk','created':int(time.time()),'model':'exclusion-fixture','choices':[{'index':0,'delta':{'role':'assistant','content':'Disposable worker completed its isolated launch.'},'finish_reason':None}]}
        end=dict(content,choices=[{'index':0,'delta':{},'finish_reason':'stop'}])
        data=('data: '+json.dumps(content)+'\n\ndata: '+json.dumps(end)+'\n\ndata: [DONE]\n\n').encode()
        self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
pi_home=BASE/'pi-home'
pi_home.mkdir(exist_ok=True)
(pi_home/'models.json').write_text(json.dumps({'providers':{'lab':{'baseUrl':f'http://127.0.0.1:{server.server_port}/v1','api':'openai-completions','apiKey':'local-disposable','models':[{'id':'exclusion-fixture','input':['text'],'reasoning':False,'contextWindow':128000,'maxTokens':2048,'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0}}]}}}))
(pi_home/'settings.json').write_text(json.dumps({'defaultProvider':'lab','defaultModel':'exclusion-fixture','installTelemetry':False,'checkForUpdates':False}))
env=dict(os.environ)
for key in ('FM_HOME','FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE','TMUX','HERDR_ENV','HERDR_PANE_ID','HERDR_TAB_ID','HERDR_WORKSPACE_ID','HERDR_SOCKET_PATH','FM_GATE_REFUSE_BYPASS','FM_TEST_SEAM','PI_PROVIDER','PI_MODEL'):
    env.pop(key,None)
env.update(FM_HERDR_LAB_STATE_DIR=str(BASE/'tripwire'), PI_CODING_AGENT_DIR=str(pi_home), PI_OFFLINE='1', PI_TELEMETRY='0', TREEHOUSE_ROOT=str(BASE/'pool'), TMPDIR=str(ROOT/'.test-phase/tmp'))
transcript=[]
def run(cmd,check=True,timeout=90):
    p=subprocess.run([str(x) for x in cmd],env=env,cwd=ROOT,capture_output=True,text=True,timeout=timeout)
    record={'command':[str(x) for x in cmd],'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr}
    transcript.append(record)
    if check and p.returncode: raise RuntimeError(record)
    return p
session=run([HELPER,'name','excl-spawn']).stdout.strip()
provisioned=False
try:
    run([ROOT/'bin/fm-lab-home.sh','create',HOME])
    env.update(FM_HOME=str(HOME),FM_BACKEND='herdr',HERDR_SESSION=session)
    (HOME/'config/supervision-host-off').touch()
    (HOME/'state/.last-watcher-beat').touch()
    origin=BASE/'origin.git'
    project=HOME/'projects/fixture'
    run(['git','init','--bare','-q','-b','main',origin])
    run(['git','clone','-q',origin,project])
    (project/'fixture.txt').write_text('Disposable launch fixture\n')
    run(['git','-C',project,'add','fixture.txt'])
    run(['git','-C',project,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','Fixture'])
    run(['git','-C',project,'push','-q','origin','main'])
    task=f'excl-live-{os.getpid()}'
    run([ROOT/'bin/fm-brief.sh',task,'fixture','--scout','--herdr-lab'])
    brief=HOME/f'data/{task}/brief.md'
    brief.write_text(brief.read_text().replace('{TASK}','Exercise the isolated tool-exclusion launch with no project changes.').replace('{FIRSTMATE_SPEC}','Reply with a short completion response. Do not execute tools.'))
    cfg=HOME/'config/crew-exclude-tools'
    invalid=[]
    for name in ['mcp__iqx-jira__editJiraIssue','mcp__my.srv__tool','mcp__a-b']:
        cfg.write_text('mcp__srv__good\n'+name+'\n')
        p=run([ROOT/'bin/fm-spawn.sh',task,project,'--scout','--harness','pi','--backend','herdr'],check=False)
        assert p.returncode==1 and f"entry '{name}' can never match" in p.stdout+p.stderr,p
        assert not (HOME/f'state/{task}.meta').exists()
        assert not (BASE/'pool').exists()
        invalid.append({'name':name,'stdout':p.stdout,'stderr':p.stderr,'exit':p.returncode})
    (EVIDENCE/'spawn-invalid-entries.json').write_text(json.dumps(invalid,indent=2))
    # Positive shape boundary: '-' and '.' in a TOOL name must be accepted.
    cfg.write_text('mcp__srv__tool-x.v2\n')
    run([HELPER,'provision',session]); provisioned=True
    run([HELPER,'viewer','start',session])
    p=run([ROOT/'bin/fm-spawn.sh',task,project,'--scout','--harness','pi','--backend','herdr','--model','lab/exclusion-fixture'],timeout=120)
    meta=(HOME/f'state/{task}.meta').read_text()
    (EVIDENCE/'spawn-valid-meta.txt').write_text(meta)
    fields=dict(line.split('=',1) for line in meta.splitlines() if '=' in line)
    pane=fields['herdr_pane_id']
    for attempt in range(80):
        if requests: break
        if attempt in (5, 15, 30):
            screen=run([HELPER,'run',session,'pane','read',pane,'--source','visible','--format','text']).stdout
            if 'Trust project folder?' in screen:
                # Select session-only trust; never mutate a global trust store.
                run([HELPER,'run',session,'pane','send-keys',pane,'down','down','enter'])
        time.sleep(.2)
    time.sleep(1)
    pane_text=run([HELPER,'run',session,'pane','read',pane,'--source','recent','--lines','70','--format','text']).stdout
    (EVIDENCE/'spawn-valid-pane.txt').write_text(pane_text)
    assert requests,'Real Pi worker never reached local model endpoint: '+pane_text
    status=(HOME/f'state/{task}.status').read_text() if (HOME/f'state/{task}.status').exists() else ''
    assert 'unmatched exclusion' not in status and 'exclusion not in effect' not in status,status
    (EVIDENCE/'spawn-valid-status.txt').write_text(status or '(No worker status warnings were appended.)\n')
    print('Invalid MCP server spellings refused before allocation; valid dashed/dotted tool name launched real Pi under isolated Herdr and reached local endpoint without false warning.')
finally:
    server.shutdown()
    if provisioned: run([HELPER,'teardown',session])
    (EVIDENCE/'spawn-live-commands.json').write_text(json.dumps(transcript,indent=2))
    (EVIDENCE/'spawn-local-endpoint-requests.json').write_text(json.dumps(requests,indent=2))
    if HOME.exists():
        for path in HOME.rglob('*'):
            if path.is_dir() and not path.is_symlink(): path.chmod(path.stat().st_mode | 0o700)
        shutil.rmtree(HOME)
