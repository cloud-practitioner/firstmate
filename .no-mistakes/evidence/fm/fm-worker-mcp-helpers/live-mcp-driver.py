import os, json, pathlib, subprocess, tempfile, time, threading, http.server, shutil, traceback
ROOT=pathlib.Path.cwd()
EVID=pathlib.Path('/home/node/.no-mistakes/evidence/01M61A8HYS7FQRYSG1TFAMDT49')
LOG=EVID/'live-mcp-scenarios.log'
logfile=LOG.open('w')
def log(s):
    print(s, flush=True); logfile.write(s+'\n'); logfile.flush()
LAB=pathlib.Path(tempfile.mkdtemp(prefix='L.',dir=ROOT))
ENV={k:v for k,v in os.environ.items() if not (k.startswith(('FM_', 'HERDR_', 'PI_', 'CLAUDE', 'OPENAI', 'ANTHROPIC', 'CODEX', 'NO_MISTAKES')) or k in ('TMUX','TMUX_PANE'))}
ENV.update(HOME=str(LAB), FM_HOME=str(LAB), FM_BACKEND='tmux', SHELL='/bin/bash', TERM='xterm-256color', TMPDIR=str(LAB/'tmp'), TMUX_TMPDIR=str(LAB/'tmux'), TREEHOUSE_ROOT=str(LAB/'treehouse'), PI_CODING_AGENT_DIR=str(LAB/'.pi/agent'), PATH=str(ROOT/'.test-phase/tools/tmux-3.5a')+':'+os.environ['PATH'], XDG_CACHE_HOME=str(LAB/'.cache'), XDG_CONFIG_HOME=str(LAB/'.config'), XDG_DATA_HOME=str(LAB/'.local/share'), DISABLE_AUTOUPDATER='1')
requests=[]
(EVID/'local-provider-requests.jsonl').write_text('')
results=[]
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_POST(self):
        data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        tools=[t['function']['name'] for t in data.get('tools',[])]
        messages=data.get('messages',[])
        last=messages[-1] if messages else {}
        record={'tools':tools,'last_role':last.get('role'),'last_content':str(last.get('content',''))[-2500:]}
        requests.append(record)
        with (EVID/'local-provider-requests.jsonl').open('a') as f: f.write(json.dumps(record)+'\n')
        # A disposable deterministic provider, not a harness/login substitute.
        # It asks real Pi to execute codemode once, then acknowledges the result.
        fn=next((t['function'] for t in data.get('tools',[]) if t['function']['name']=='codemode'),None)
        tool_seen=any(m.get('role')=='tool' for m in messages)
        if fn and not tool_seen:
            props=fn.get('parameters',{}).get('properties',{})
            key=next((k for k in ('code','script','input') if k in props), next(iter(props),'code'))
            args={key:'text({probe: "codemode-ran", mcpTools: ALL_TOOLS.filter(t => t.name.startsWith("mcp__")).map(t => t.name)});'}
            delta={'role':'assistant','tool_calls':[{'index':0,'id':'call_lab_probe','type':'function','function':{'name':'codemode','arguments':json.dumps(args)}}]}
            finish='tool_calls'
        else:
            delta={'role':'assistant','content':'Disposable MCP startup probe complete. No repository changes requested.'}
            finish='stop'
        self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.end_headers()
        for chunk in [{'id':'probe','object':'chat.completion.chunk','created':1,'model':'probe','choices':[{'index':0,'delta':delta,'finish_reason':None}]},{'id':'probe','object':'chat.completion.chunk','created':1,'model':'probe','choices':[{'index':0,'delta':{},'finish_reason':finish}]}]:
            self.wfile.write(('data: '+json.dumps(chunk)+'\n\n').encode())
        self.wfile.write(b'data: [DONE]\n\n'); self.wfile.flush()
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
def cmd(args, timeout=90, check=True, env=None, capture=True):
    log('$ '+subprocess.list2cmdline([str(x) for x in args]))
    r=subprocess.run([str(x) for x in args],cwd=ROOT,env=env or ENV,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    if capture and r.stdout: log(r.stdout.rstrip())
    if capture or r.returncode: log('exit='+str(r.returncode))
    if check and r.returncode: raise RuntimeError('command failed')
    return r

def tm(*args,check=True,capture=True): return cmd(['tmux','-L','fm-lab',*args],check=check,capture=capture)
def brief(id,scout=False):
    args=['bin/fm-brief.sh',id,'notes']+(['--scout'] if scout else ['--mode','local-only','--project',str(PROJ)])
    cmd(args)
    p=LAB/'data'/id/'brief.md'; p.write_text(p.read_text().replace('{TASK}','Observe the disposable MCP launch configuration; do not change files.').replace('{FIRSTMATE_SPEC}','Report the startup probe only. No shell actions, network calls, commits or cleanup are requested.'))
def spawn(id,*args,scout=False,check=True):
    brief(id,scout)
    r=cmd(['bin/fm-spawn.sh',id,str(PROJ)]+(['--scout'] if scout else ['--mode','local-only','--yolo','off'])+['--harness','pi','--model','lab/probe',*args],timeout=130,check=check)
    if r.returncode==0:
        ready(id)
    return r

def ready(id):
    m=meta(id)
    for i in range(60):
        screen=tm('capture-pane','-p','-t',m['window'],'-S','-80',capture=False).stdout
        if 'Trust project folder?' in screen:
            log('Accepting project trust in disposable lab only: '+id)
            tm('send-keys','-t',m['window'],'Enter')
        if 'Disposable MCP startup probe complete.' in screen:
            time.sleep(2)
            return
        time.sleep(0.5)
    raise RuntimeError('Worker not ready: '+id+'\n'+screen)

def meta(id):
    p=LAB/'state'/f'{id}.meta'
    return dict(line.split('=',1) for line in p.read_text().splitlines() if '=' in line)
def events():
    p=LAB/'mcp-events.jsonl'; return [json.loads(l) for l in p.read_text().splitlines()] if p.exists() else []
def active(pid):
    try: os.kill(pid,0); return True
    except ProcessLookupError: return False

def observations(id):
    path=LAB/'tool-observations.jsonl'
    obs=[json.loads(l) for l in path.read_text().splitlines()] if path.exists() else []
    return [o for o in obs if o['cwd']==meta(id)['worktree']]

def check_worker(id,posture,expected_servers,exclude_read=False):
    records=observe(id)
    assert meta(id).get('mcp')==posture, (id,meta(id).get('mcp'),posture)
    pids={e['pid'] for e in records if e['event']=='start' and active(e['pid'])}
    assert len(pids)==expected_servers, (id,pids)
    obs=observations(id)[-1]
    assert 'codemode' in obs['tools'],obs
    if exclude_read: assert 'read' not in obs['tools'],obs
    brief=(LAB/'data'/id/'launch-brief.md').read_text()
    if posture=='off': assert 'needs MCP <server>' in brief
    else: assert 'This worker was launched without MCP servers' not in brief
    log('PROVEN '+id+': active MCP helpers='+str(len(pids))+' active tools='+json.dumps(obs['tools']))
    return obs

def passed(name):
    results.append({'name':name,'result':'pass'})
    log('SCENARIO PASS: '+name)

def refuse_spawn(id,args,expected,scout=False):
    brief(id,scout)
    windows=tm('list-windows','-a','-F','#{window_id}',capture=False).stdout
    n=len(events())
    r=cmd(['bin/fm-spawn.sh',id,str(PROJ)]+(['--scout'] if scout else ['--mode','local-only','--yolo','off'])+args,check=False)
    assert r.returncode==1 and expected in r.stdout,r.stdout
    assert not (LAB/'state'/f'{id}.meta').exists()
    assert tm('list-windows','-a','-F','#{window_id}',capture=False).stdout==windows
    assert len(events())==n
    log('PROVEN refusal before endpoint/metadata/helper creation: '+id)

def observe(id):
    m=meta(id); wt=m['worktree']; records=[e for e in events() if e.get('cwd')==wt]
    log('OBSERVE '+id+' meta='+json.dumps({k:m.get(k) for k in ('harness','mcp','window','worktree','kind')}))
    pids=sorted(set(e['pid'] for e in records if e.get('event')=='start'))
    log('MCP starts for '+id+': '+json.dumps(records))
    total_rss=0; alive=[]
    for pid in pids:
        measurement=cmd(['ps','-p',str(pid),'-o','pid=,ppid=,rss=,args='],check=False)
        if measurement.returncode==0:
            total_rss+=int(measurement.stdout.split()[2]); alive.append(pid)
    log('MEASUREMENT '+json.dumps({'task':id,'posture':m.get('mcp','unconfigured'),'fixture_helper_count':len(alive),'fixture_helper_rss_kib':total_rss,'scope':'disposable Python MCP servers, not production SAP/browser helpers'}))
    tm('capture-pane','-p','-t',m['window'],'-S','-80')
    (EVID/(id+'-meta.txt')).write_text('\n'.join(f'{k}={v}' for k,v in m.items())+'\n')
    return records
PROJ=LAB/'projects/notes'
try:
    cmd(['bin/fm-lab-home.sh','create',str(LAB)])
    for name in ('tmux','tmp','.pi/agent/extensions','.cache','.config','.local/share'): (LAB/name).mkdir(parents=True,exist_ok=True)
    (LAB/'config/backend').write_text('tmux\n')
    (LAB/'config/crew-harness').write_text('pi\n')
    (LAB/'config/backlog-backend').write_text('manual\n')
    # No user login/configuration is copied; every harness uses this local endpoint.
    (LAB/'.pi/agent/models.json').write_text(json.dumps({'providers':{'lab':{'baseUrl':f'http://127.0.0.1:{server.server_port}/v1','api':'openai-completions','apiKey':'disposable-local-probe','models':[{'id':'probe','contextWindow':200000,'maxTokens':1000}]}}}))
    (LAB/'.pi/agent/settings.json').write_text(json.dumps({'defaultProvider':'lab','defaultModel':'probe','defaultThinkingLevel':'off','checkForUpdates':False,'quietStartup':True}))
    (LAB/'mcp-server.py').write_text('''import sys,json,os,time\nfrom pathlib import Path\nname=sys.argv[1]; out=Path(sys.argv[2]); memory=bytearray(8*1024*1024)\ndef log(event,**kw):\n with out.open("a") as f: f.write(json.dumps(dict(event=event,name=name,pid=os.getpid(),cwd=os.getcwd(),**kw))+"\\n")\nlog("start")\nfor line in sys.stdin:\n msg=json.loads(line); method=msg.get("method"); log("request",method=method)\n if "id" not in msg: continue\n if method=="initialize": result={"protocolVersion":msg["params"]["protocolVersion"],"capabilities":{"tools":{}},"serverInfo":{"name":name,"version":"1.0"}}\n elif method=="tools/list": result={"tools":[{"name":"ping","description":"Disposable startup probe","inputSchema":{"type":"object","properties":{}}}]}\n elif method=="tools/call": result={"content":[{"type":"text","text":"pong"}]}\n else: result={}\n print(json.dumps({"jsonrpc":"2.0","id":msg["id"],"result":result}),flush=True)\nlog("stdin-closed")\n''')
    (LAB/'.pi/agent/mcp.json').write_text(json.dumps({'mcpServers':{name:{'command':'python3','args':[str(LAB/'mcp-server.py'),name,str(LAB/'mcp-events.jsonl')]} for name in ('sap-lab','browser-lab')}}))
    # Observer extension records the actual enabled tool set in the running Pi.
    (LAB/'.pi/agent/extensions/observe.ts').write_text('import {appendFileSync} from "node:fs";\nexport default function(pi:any) { const save=()=>appendFileSync('+json.dumps(str(LAB/'tool-observations.jsonl'))+', JSON.stringify({pid:process.pid,cwd:process.cwd(),tools:pi.getActiveTools()})+"\\n"); pi.on("session_start",()=>{setTimeout(save,1500)}); pi.on("agent_end",save); }\n')
    cmd(['git','init','-q','-b','main',str(PROJ)])
    cmd(['git','-C',str(PROJ),'config','user.name','Disposable Probe'])
    cmd(['git','-C',str(PROJ),'config','user.email','probe@example.invalid'])
    (PROJ/'README.md').write_text('Disposable MCP launch laboratory.\n')
    cmd(['git','-C',str(PROJ),'add','README.md'])
    cmd(['git','-C',str(PROJ),'commit','-qm','Initial fixture'])
    cmd(['git','init','--bare','-q',str(LAB/'origin.git')])
    cmd(['git','-C',str(PROJ),'remote','add','origin',str(LAB/'origin.git')])
    cmd(['git','-C',str(PROJ),'push','-q','origin','main'])
    cmd(['git','-C',str(LAB/'origin.git'),'symbolic-ref','HEAD','refs/heads/main'])
    # Real Pi primary on the lab-only tmux socket, from this gate worktree.
    tm('-f','/dev/null','new-session','-d','-s','primary','-x','120','-y','40','-c',str(ROOT),'-e','FM_HOME='+str(LAB),'pi --approve --no-extensions --no-skills --no-mcp --tools +codemode --model lab/probe')
    ENV['TMUX']=tm('display-message','-p','-t','primary','#{socket_path},#{pid},0',capture=False).stdout.strip()
    ENV['TMUX_PANE']=tm('display-message','-p','-t','primary','#{pane_id}',capture=False).stdout.strip()
    tm('set-option','-g','default-shell','/bin/bash')
    time.sleep(2)
    tm('capture-pane','-p','-t','primary','-S','-30')
    spawn('lab-default')
    check_worker('lab-default',None,2)
    default_pids={e['pid'] for e in events() if e['event']=='start'}
    (LAB/'config/crew-mcp').write_text('on\n')
    spawn('lab-on')
    check_worker('lab-on','on',2)
    passed('Absent and on home settings preserve configured MCP helpers')
    tm('kill-window','-t',meta('lab-on')['window'])

    (LAB/'config/crew-mcp').write_text(' \t off \n')
    spawn('lab-off')
    off_observation=check_worker('lab-off','off',0)
    assert all(active(pid) for pid in default_pids),'off spawn killed an existing helper'
    (LAB/'config/crew-exclude-tools').write_text('read\n')
    spawn('lab-scout',scout=True)
    check_worker('lab-scout','off',0,exclude_read=True)
    (LAB/'config/crew-exclude-tools').unlink()
    passed('MCP off suppresses helpers for ship and scout while codemode and exclusions work')
    tm('kill-window','-t',meta('lab-scout')['window'])

    spawn('lab-override-on','--mcp=on')
    check_worker('lab-override-on','on',2)
    tm('kill-window','-t',meta('lab-override-on')['window'])
    (LAB/'config/crew-mcp').write_text('on\n')
    spawn('lab-override-off','--mcp','off')
    check_worker('lab-override-off','off',0)
    tm('kill-window','-t',meta('lab-override-off')['window'])
    for id in ('lab-batch-a','lab-batch-b'): brief(id,True)
    cmd(['bin/fm-spawn.sh','lab-batch-a='+str(PROJ),'lab-batch-b='+str(PROJ),'--scout','--harness','pi','--model','lab/probe','--mcp','off'],timeout=160)
    for id in ('lab-batch-a','lab-batch-b'):
        ready(id); check_worker(id,'off',0); tm('kill-window','-t',meta(id)['window'])
    passed('Per-task overrides work in both directions and batch forwards MCP off')

    (LAB/'config/crew-mcp').write_text('off\n')
    refuse_spawn('lab-refuse-claude',['--harness','claude'],'claude runtime cannot start without MCP servers')
    refuse_spawn('lab-refuse-raw',['pi Verify this adapter'],'raw launch command cannot start without MCP servers')
    (LAB/'config/crew-mcp').write_text('off on\n')
    refuse_spawn('lab-refuse-malformed',['--harness','pi'],'config/crew-mcp holds')
    (LAB/'config/crew-mcp').unlink(); (LAB/'config/crew-mcp').mkdir()
    refuse_spawn('lab-refuse-directory',['--harness','pi'],'readable regular file')
    (LAB/'config/crew-mcp').rmdir(); (LAB/'config/crew-mcp').write_text('off\n')
    refuse_spawn('lab-refuse-flag',['--harness','pi','--mcp','maybe'],'--mcp must be on or off')
    r=cmd(['bin/fm-spawn.sh','lab-secondmate','--secondmate','--mcp','off'],check=False)
    assert r.returncode==1 and 'applies only to ship and scout workers' in r.stdout
    passed('Invalid settings and unsupported launch kinds refuse before provisioning')

    before=observations('lab-off')[-1]['pid']; window=meta('lab-off')['window']
    for config,args,expected in [('maybe\n',[],'config/crew-mcp holds'),('off\n',['--harness','claude'],'claude runtime cannot start without MCP servers')]:
        (LAB/'config/crew-mcp').write_text(config)
        r=cmd(['bin/fm-control.sh','lab-off','relaunch',*args,'--note','Disposable guard probe'],check=False,timeout=100)
        assert r.returncode==1 and expected in r.stdout,r.stdout
        assert active(before) and observations('lab-off')[-1]['pid']==before
        assert meta('lab-off')['window']==window
    passed('Malformed setting and unsupported replacement preserve the running worker')

    (LAB/'config/crew-mcp').write_text('on\n')
    cmd(['bin/fm-control.sh','lab-off','relaunch','--note','Verify recorded off survives changed home setting'],timeout=150)
    ready('lab-off'); check_worker('lab-off','off',0)
    assert not active(before)
    cmd(['bin/fm-control.sh','lab-off','relaunch','--mcp','on','--note','Enable helpers for this existing task'],timeout=150)
    ready('lab-off'); check_worker('lab-off','on',2)
    assert meta('lab-off')['window']==window
    (LAB/'config/crew-mcp').write_text('off\n')
    cmd(['bin/fm-control.sh','lab-default','relaunch','--note','Legacy task with no MCP record retains helpers'],timeout=150)
    ready('lab-default'); check_worker('lab-default',None,2)
    passed('Relaunch preserves recorded or legacy posture and explicit on enables helpers')
    log('COMPLETE all live scenarios')
except Exception:
    log(traceback.format_exc())
    try: tm('list-panes','-a','-F','#{session_name}:#{window_name} #{pane_current_command} #{pane_current_path}'); tm('capture-pane','-p','-t','firstmate','-S','-80',check=False)
    except Exception: pass
finally:
    for filename in ('tool-observations.jsonl','mcp-events.jsonl'):
        if (LAB/filename).exists(): (EVID/filename).write_text((LAB/filename).read_text())
    (EVID/'live-scenario-results.json').write_text(json.dumps(results,indent=2)+'\n')
    owned_helpers={e['pid'] for e in events() if e['event']=='start'}
    tm('kill-server',check=False)
    time.sleep(2)
    for pid in owned_helpers:
        if active(pid): log('WARNING helper still alive after tmux teardown: '+str(pid))
    server.shutdown(); server.server_close()
    for root,dirs,files in os.walk(LAB):
        os.chmod(root,0o700)
    shutil.rmtree(LAB)
    log('CLEANUP removed disposable lab '+str(LAB))
    logfile.close()
