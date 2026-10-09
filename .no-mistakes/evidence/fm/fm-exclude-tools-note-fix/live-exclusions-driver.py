import contextlib, http.server, json, os, pathlib, select, shlex, shutil, subprocess, threading, time
ROOT = pathlib.Path.cwd()
LAB = ROOT / '.l'
TMP = ROOT / '.gate-test-tmp'
EVID = pathlib.Path('/home/node/.no-mistakes/evidence/01M4FG5JQ32H5W33X2X33GG2DC')
TMUX = TMP / 'tmux-local/bin/tmux'
PI = shutil.which('pi')
log = (EVID / 'live-exclusions.log').open('w', buffering=1)
def say(s):
    print(s, flush=True); print(s, file=log, flush=True)
def run(args, **kw):
    p = subprocess.run([str(x) for x in args], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kw)
    return p.returncode, p.stdout
plan = {'tool': 'codemode', 'arguments': {'code': 'text("lab ready")'}}
class Model(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        user = next((m for m in reversed(req['messages']) if m['role'] == 'user'), {})
        last = req['messages'][-1]
        self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.end_headers()
        base = {'id':'chatcmpl-lab', 'object':'chat.completion.chunk', 'created':int(time.time()), 'model':'fixture'}
        if last['role'] == 'tool' or plan.get('tool') is None:
            delta = {'role':'assistant', 'content':'Disposable scenario complete.'}
            finish = 'stop'
        else:
            delta = {'role':'assistant', 'tool_calls':[{'index':0, 'id':'lab-call', 'type':'function', 'function':{'name':plan['tool'], 'arguments':json.dumps(plan['arguments'])}}]}
            finish = 'tool_calls'
        for d, f in [(delta, None), ({}, finish)]:
            chunk = dict(base, choices=[{'index':0,'delta':d,'finish_reason':f}])
            self.wfile.write(('data: '+json.dumps(chunk)+'\n\n').encode())
        self.wfile.write(b'data: [DONE]\n\n'); self.wfile.flush()
server = http.server.ThreadingHTTPServer(('127.0.0.1',0), Model)
threading.Thread(target=server.serve_forever, daemon=True).start()
port = server.server_address[1]
env = os.environ.copy()
for k in list(env):
    if (k.startswith('FM_') and k.endswith('_OVERRIDE')) or k in ['FM_GATE_REFUSE_BYPASS', 'PI_SESSION_ID', 'FM_TASK_ID', 'TASKS_AXI_FILE', 'TASKS_AXI_BACKEND']:
        env.pop(k, None)
env.update({'PATH':str(TMUX.parent)+':'+env['PATH'], 'HOME':str(LAB/'user'), 'FM_HOME':str(LAB), 'FM_BACKEND':'tmux', 'PI_CODING_AGENT_DIR':str(LAB/'pi'), 'PI_CODING_AGENT_SESSION_DIR':str(LAB/'pi/sessions'), 'PI_OFFLINE':'1', 'PI_TELEMETRY':'0', 'LAB_ROOT':str(LAB), 'TMPDIR':str(TMP), 'TREEHOUSE_ROOT':str(LAB), 'TMUX_TMPDIR':str(LAB/'tmux')})
(LAB/'pi/models.json').write_text(json.dumps({'providers':{'gate':{'baseUrl':f'http://127.0.0.1:{port}/v1','api':'openai-completions','apiKey':'local-disposable-not-a-credential','models':[{'id':'fixture','name':'Deterministic tool-driving fixture','reasoning':False,'input':['text'],'contextWindow':128000,'maxTokens':4096,'compat':{'supportsStore':False,'supportsDeveloperRole':False}}]}}}))
(LAB/'pi/settings.json').write_text(json.dumps({'defaultProvider':'gate','defaultModel':'fixture','defaultThinkingLevel':'off','defaultTools':['read','bash','edit','write','+codemode'],'quietStartup':True}))
(LAB/'pi/mcp.json').write_text(json.dumps({'mcpServers':{'lab':{'command':shutil.which('python3'),'args':[str(TMP/'mcp-fixture.py')], 'env':{'LAB_ROOT':str(LAB)},'exposure':'codemode','timeout':60}}}))
(LAB/'pi/extensions').mkdir(exist_ok=True)
shutil.copyfile(TMP/'observer.ts', LAB/'pi/extensions/observer.ts')
status = LAB/'state/exclusion-scout.status'
exclude = LAB/'config/crew-exclude-tools'
exclude.write_text('mcp__lab__editIssue\nmcp__lab__createIssue\nmcp__offline__typo\n')
registry = LAB/'registry.jsonl'
def clear(release=False, declaration='working: disposable task\n'):
    status.write_text(declaration)
    registry.write_text('')
    (LAB/'mcp-side-effects.log').write_text('')
    (LAB/'release').unlink(missing_ok=True)
    if release: (LAB/'release').touch()
def consume(fn, *args):
    code = '. "$1/bin/fm-classify-lib.sh"; '+fn+' "$2"'+''.join(' '+shlex.quote(str(a)) for a in args)
    rc, out = run(['bash','-c',code,'_',ROOT,status], env=env, timeout=30)
    assert rc == 0, (code,out)
    return out.rstrip('\n')
def unread():
    rc,out = run(['bash','-c','. "$1/bin/fm-classify-lib.sh"; scan_unread_surface_lines "$2"','_',ROOT,LAB/'state'],env=env,timeout=30)
    assert rc == 0, out
    return out
class Rpc:
    def __init__(self, native_exclude=False, label='scenario'):
        args = [PI,'--mode','rpc','--model','gate/fixture','--thinking','off','--offline','--no-context-files','--no-skills','--no-prompt-templates','--no-approve','--session-dir',str(LAB/'pi/sessions'),'-e',str(LAB/'state/exclusion-scout.pi-ext.ts')]
        if native_exclude: args += ['--exclude-tools',','.join(exclude.read_text().split())]
        self.p = subprocess.Popen(args,cwd=ROOT,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
        self.label=label; self.messages=[]; self.stdout=[]
        self.queue=[]
        self.errorlog=(EVID / (label+'-stderr.log')).open('w')
        def drain(stream):
            for line in stream:
                self.stdout.append(line)
                try: self.queue.append(json.loads(line))
                except ValueError: pass
        def errors():
            for line in self.p.stderr: self.errorlog.write(line); self.errorlog.flush()
        threading.Thread(target=drain,args=(self.p.stdout,),daemon=True).start()
        threading.Thread(target=errors,daemon=True).start()
    def command(self,obj):
        self.p.stdin.write(json.dumps(obj)+'\n'); self.p.stdin.flush()
    def prompt(self,label):
        start = len(self.queue)
        self.command({'type':'prompt','message':label})
        until=time.monotonic()+45
        while time.monotonic()<until:
            new=self.queue[start:]
            if any(x.get('type')=='agent_end' for x in new):
                self.messages += new
                return new
            if self.p.poll() is not None: raise AssertionError('Pi exited: '+''.join(self.stdout))
            time.sleep(.02)
        raise AssertionError('Pi prompt timed out: '+''.join(self.stdout)[-4000:])
    def close(self):
        self.p.terminate()
        try: self.p.wait(timeout=5)
        except subprocess.TimeoutExpired: self.p.kill(); self.p.wait()
        time.sleep(.1); self.errorlog.close()
        (EVID / (self.label+'-rpc.jsonl')).write_text(''.join(self.stdout))
    def __enter__(self): return self
    def __exit__(self,*a): self.close()
def tool_results(events):
    return [x for x in events if x.get('type')=='tool_execution_end']
def connect_plan(declaration=None, resolution=None):
    cmd = ''
    if declaration: cmd += 'printf %s '+shlex.quote(declaration+'\n')+' >> '+shlex.quote(str(status))+'; '
    cmd += 'touch '+shlex.quote(str(LAB/'release'))+'; sleep 0.4; '
    if resolution: cmd += 'printf %s '+shlex.quote(resolution+'\n')+' >> '+shlex.quote(str(status))+'; '
    return {'tool':'bash','arguments':{'command':cmd,'timeout':10}}
results=[]
try:
    # Real spawn, real pool, real Pi worker on the private socket.
    plan.clear(); plan.update(connect_plan())
    clear()
    (LAB/'state/.last-watcher-beat').touch()
    rc,out=run([TMUX,'-L','fm-lab','new-session','-d','-s','primary','-x','120','-y','40','-c',ROOT,'bash --noprofile --norc'],env=env)
    assert rc==0,out
    run([TMUX,'-L','fm-lab','set-option','-g','default-shell','/bin/bash'],env=env)
    run([TMUX,'-L','fm-lab','set-option','-g','default-command','bash --noprofile --norc'],env=env)
    socket=(LAB/'tmux/tmux-1000/fm-lab')
    env['TMUX']=str(socket)+',1,0'
    briefdir=LAB/'data/exclusion-scout'; briefdir.mkdir(exist_ok=True)
    (briefdir/'brief.md').write_text('# Task\n## Captain\'s intent\nValidate disposable tool exclusion behavior.\n## Firstmate spec\nPerform only the local disposable observation requested; do not touch real projects, credentials, or pipeline state.\n')
    rc,out=run([ROOT/'bin/fm-spawn.sh','exclusion-scout',LAB/'project','--scout','--harness','pi','--model','gate/fixture','--backend','tmux'],env=env,timeout=100)
    say('REAL SPAWN EXIT='+str(rc)+'\n'+out)
    if rc:
        _, pane = run([TMUX,'-L','fm-lab','capture-pane','-p','-S','-200','-t','primary:fm-exclusion-scout'],env=env)
        say('FAILED SPAWN PANE\n'+pane)
    assert rc==0,out
    until = time.monotonic() + 30
    while time.monotonic() < until:
        _, trust = run([TMUX,'-L','fm-lab','capture-pane','-p','-t','primary:fm-exclusion-scout'],env=env)
        if 'Trust project folder?' in trust:
            run([TMUX,'-L','fm-lab','send-keys','-t','primary:fm-exclusion-scout','Enter'],env=env)
            break
        if registry.exists() and registry.read_text(): break
        time.sleep(.2)
    until = time.monotonic() + 30
    while time.monotonic() < until:
        if registry.exists() and 'turn_end' in registry.read_text(): break
        time.sleep(.1)
    rc,pane=run([TMUX,'-L','fm-lab','capture-pane','-p','-S','-200','-t','firstmate:exclusion-scout'],env=env)
    if rc:
        rc,windows=run([TMUX,'-L','fm-lab','list-windows','-a','-F','#{session_name}:#{window_name}'],env=env)
        say('windows '+windows)
        target=next(x for x in windows.splitlines() if 'exclusion-scout' in x)
        rc,pane=run([TMUX,'-L','fm-lab','capture-pane','-p','-S','-200','-t',target],env=env)
    (EVID/'spawned-pi-pane.txt').write_text(pane)
    say('WORKER PANE\n'+pane)
    say('STATUS AFTER NATIVE EXCLUSION\n'+status.read_text())
    say('LIVE REGISTRY\n'+registry.read_text())
    assert 'exclusion not in effect' not in status.read_text()
    snapshots=[json.loads(l) for l in registry.read_text().splitlines()]
    assert any('mcp__lab__readIssue' in s['tools'] for s in snapshots), snapshots
    assert all('mcp__lab__editIssue' not in s['tools'] for s in snapshots),snapshots
    results.append('absent names quiet during real spawned worker')
    # The generated extension is now run by the real CLI in RPC mode. Omit the
    # native denylist deliberately to inject a genuine registry-presence fault.
    run([TMUX,'-L','fm-lab','kill-server'],env=env)
    clear()
    plan.clear(); plan.update(connect_plan('done: completed disposable scout'))
    with Rpc(label='late-terminal') as p:
        events=p.prompt('Connect during the turn and finish the scout.')
        first=status.read_text()
        say('LATE TERMINAL STATUS\n'+first)
        say('DECLARATION '+consume('last_status_line')+'\nUNREAD\n'+unread())
        assert consume('last_status_line')=='done: completed disposable scout'
        assert first.count('exclusion not in effect')==1
        assert 'mcp__offline__typo' not in first
        assert 'mcp__lab__editIssue' in unread()
        plan.clear(); plan.update({'tool':None})
        p.prompt('Another agent start must not repeat the warning.')
        assert status.read_text()==first
        results.append('late presence warning deduplicated and terminal preserved')
    # Initial presence, direct and codemode backstop, unlisted call allowed.
    clear(True)
    mcp_config=json.loads((LAB/'pi/mcp.json').read_text())
    mcp_config['mcpServers']['lab']['exposure']='direct'
    (LAB/'pi/mcp.json').write_text(json.dumps(mcp_config))
    plan.clear(); plan.update({'tool':'mcp__lab__editIssue','arguments':{}})
    with Rpc(label='backstop') as p:
        time.sleep(1)
        events=p.prompt('Attempt a listed tool directly.')
        say('DIRECT CALL RESULTS '+json.dumps(tool_results(events)))
        assert any(x.get('isError') and 'excluded by config/crew-exclude-tools' in json.dumps(x) for x in tool_results(events)), events
        plan.clear(); plan.update({'tool':'codemode','arguments':{'code':'for (const n of ["mcp__lab__editIssue","mcp__lab__createIssue","mcp__lab__readIssue"]) { try { text({name:n,result:await tools[n]({})}); } catch(e) { text({name:n,error:String(e)}); } }'}})
        events=p.prompt('Attempt the same listed tools through codemode, then read an unlisted tool.')
        say('CODEMODE RESULTS '+json.dumps(tool_results(events)))
        assert 'excluded by config/crew-exclude-tools' in json.dumps(tool_results(events))
        assert (LAB/'mcp-side-effects.log').read_text()=='readIssue\n'
        assert status.read_text().count('exclusion not in effect')==1
        results.append('direct and codemode excluded calls blocked; unlisted MCP read executed')
    mcp_config['mcpServers']['lab']['exposure']='codemode'
    (LAB/'pi/mcp.json').write_text(json.dumps(mcp_config))
    # Actual resolution written by an independent bash process before warning.
    for event in ['turn_end','agent_start']:
        clear(declaration='working: starting\nblocked [key=dependency]: waiting for access\n')
        if event=='turn_end':
            plan.clear(); plan.update(connect_plan(resolution='resolved [key=dependency]: access granted'))
        else:
            plan.clear(); plan.update({'tool':None})
        with Rpc(label='resolved-'+event) as p:
            if event=='agent_start':
                p.prompt('Still disconnected; keep the decision open.')
                assert consume('status_open_decisions')
                with status.open('a') as f: f.write('resolved [key=dependency]: access granted\n')
                (LAB/'release').touch(); time.sleep(1)
            p.prompt('Observe a resolved decision while the server connects.')
            say('RESOLVED '+event+'\n'+status.read_text()+'CURRENT '+consume('status_current_line','scout')+'\nOPEN '+consume('status_open_decisions'))
            assert consume('status_open_decisions')==''
            assert consume('last_status_line')=='resolved [key=dependency]: access granted'
            assert status.read_text().count('blocked [key=dependency]')==1
            assert 'exclusion not in effect' in status.read_text()
            results.append('resolved decision not reopened at '+event)
    # Later connection after the old 200-check budget.
    clear()
    plan.clear(); plan.update({'tool':None})
    with Rpc(label='after-210-turns') as p:
        for n in range(105): p.prompt('Disconnected turn '+str(n))
        assert 'exclusion not in effect' not in status.read_text()
        snapshots=[json.loads(l) for l in registry.read_text().splitlines()]
        assert sum(s['event'] in ['agent_start','turn_end'] for s in snapshots)>=210
        plan.clear(); plan.update(connect_plan())
        p.prompt('Connect after 210 lifecycle scans.')
        say('AFTER 210 SCANS\n'+status.read_text())
        assert status.read_text().count('exclusion not in effect')==1
        results.append('warning still active after more than 200 lifecycle scans')
    # Public status readers remain correct for all state classes and fallback,
    # using genuine warnings emitted above rather than synthesized source text.
    warning=next(l for l in status.read_text().splitlines() if 'exclusion not in effect' in l)
    for declaration in ['failed: failed disposable task','working: continuing','paused [key=release]: waiting for release','needs-decision [key=choice]: choose','captain-held [key=choice]: waiting for captain','note: ordinary state note','']:
        status.write_text((declaration+'\n' if declaration else '')+warning+'\n')
        latest=consume('last_status_line')
        say('READER declaration='+repr(declaration)+' latest='+repr(latest)+' current='+repr(consume('status_current_line','scout'))+' wait='+repr(consume('status_declared_wait_line')))
        assert latest==declaration
    status.write_text('paused [key=release]: waiting for release\nresolved [key=choice]: answered choice\n'+(warning+'\n')*210)
    assert consume('status_declared_wait_line')=='paused [key=release]: waiting for release'
    results.append('public declaration readers preserve waiting/working/decision state and no-event fallback')
    # Live public launch refusal before endpoint/metadata/worktree allocation.
    for name in ['mcp__lab-server__editIssue','mcp__lab.server__editIssue']:
        exclude.write_text(name+'\n')
        before=set((LAB/'state').iterdir())
        rc,out=run([ROOT/'bin/fm-spawn.sh','invalid-prefix',LAB/'project','--scout','--harness','pi','--model','gate/fixture','--backend','tmux'],env=env,timeout=30)
        say('INVALID PREFIX '+name+' exit='+str(rc)+'\n'+out)
        assert rc!=0 and 'can never match' in out
        assert not (LAB/'state/invalid-prefix.meta').exists()
        assert not (LAB/'state/invalid-prefix.status').exists()
    results.append('invalid server spelling refused by real spawn before task publication')
    say('LIVE RESULTS\n'+'\n'.join(results))
    (EVID/'live-results.json').write_text(json.dumps({'results':results},indent=2))
finally:
    run([TMUX,'-L','fm-lab','kill-server'],env=env)
    server.shutdown(); server.server_close(); log.close()
