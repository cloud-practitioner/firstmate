import http.server, json, os, shlex, subprocess, threading, time, traceback
from pathlib import Path
ROOT=Path.cwd()
WORK=ROOT/'.test-exclusions'
EVIDENCE=Path('/home/node/.no-mistakes/evidence/01M4FATPH1GGTGPYHJS1Q4J58G/baseline')
record=(WORK/'case-base').read_text().strip().split('|')
home, project, wt = map(Path, record[1:4])
ext=home/'state/live-exclusions.pi-ext.ts'
status=home/'state/live-exclusions.status'
SCENARIOS={}
SCRIPT=r'''text({names:ALL_TOOLS.filter(t=>t.name.startsWith('mcp__')).map(t=>t.name), search:(await searchTools('editIssue')).map(t=>t.name), described:!!(await describeTool('mcp__lab_tracker__editIssue'))});
try { text(await tools.mcp__lab_tracker__editIssue({})); } catch(e) { text({editBlocked:String(e)}); }
text(await tools.mcp__lab_tracker__readIssue({}));
'''
def bash_call(command):
    return 'text(await tools.bash('+json.dumps({'command':command,'timeout':10})+'));'
class Model(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_POST(self):
        req=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        scenario=SCENARIOS[req['model']]
        scenario['requests']+=1
        n=scenario['requests']
        with scenario['requests_log'].open('a') as f: f.write(json.dumps({'model':req['model'],'requestNumber':n,'toolNames':[t.get('function',{}).get('name') for t in req.get('tools',[])],'lastMessage':req['messages'][-1]})+'\n')
        delayed=scenario['name']=='after-210-turns'
        if not delayed or n>210: scenario['release'].touch()
        # Every message is handled by the real Pi agent loop and real codemode.
        if n <= (211 if delayed else 2):
            if delayed and n<=210: code='text({turn:'+str(n)+'});'
            elif n==1 or delayed:
                code=SCRIPT
                state=scenario['state']
                command="printf '%s\\n' "+shlex.quote(state)+' >> '+shlex.quote(str(status))
                if scenario['resolution']=='before':
                    command+='; for i in $(seq 1 500); do test -e '+shlex.quote(str(scenario['resolved']))+' && break; sleep 0.01; done'
                code+=bash_call(command)
            else: code="text(ALL_TOOLS.filter(t=>t.name.startsWith('mcp__'))); text(await tools.mcp__lab_tracker__readIssue({}));"
            delta={'role':'assistant','tool_calls':[{'index':0,'id':'call_'+str(n),'type':'function','function':{'name':'codemode','arguments':json.dumps({'code':code})}}]}
            finish='tool_calls'
        else:
            delta={'role':'assistant','content':'Disposable worker verification complete.'}; finish='stop'
        self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.end_headers()
        for d,f in [(delta,None),({},finish)]:
            obj={'id':'lab-response-'+str(n),'object':'chat.completion.chunk','created':int(time.time()),'model':req['model'],'choices':[{'index':0,'delta':d,'finish_reason':f}]}
            self.wfile.write(('data: '+json.dumps(obj)+'\n\n').encode()); self.wfile.flush()
        self.wfile.write(b'data: [DONE]\n\n'); self.wfile.flush()
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Model)
threading.Thread(target=server.serve_forever,daemon=True).start()
results=[]
try:
  for name, excluded, ready, declaration, resolution in [
    ('correctly-excluded',True,False,'done: excluded-worker completed',None),
  ]:
    config=WORK/name; config.mkdir(exist_ok=True)
    release=config/'release'; release.unlink(missing_ok=True)
    if ready: release.touch()
    observations=EVIDENCE/(name+'-lifecycle.jsonl'); observations.unlink(missing_ok=True)
    mcp_log=EVIDENCE/(name+'-mcp.jsonl'); mcp_log.unlink(missing_ok=True)
    requests_log=EVIDENCE/(name+'-requests.jsonl'); requests_log.unlink(missing_ok=True)
    resolved=config/'resolved'; resolved.unlink(missing_ok=True)
    scenario={'name':name,'state':declaration,'resolution':resolution,'release':release,'resolved':resolved,'requests':0,'requests_log':requests_log}
    SCENARIOS[name]=scenario
    (config/'models.json').write_text(json.dumps({'providers':{'lab':{'baseUrl':'http://127.0.0.1:'+str(server.server_port)+'/v1','api':'openai-completions','apiKey':'disposable','models':[{'id':name,'contextWindow':1000000,'maxTokens':1024,'compat':{'supportsDeveloperRole':False}}]}}}))
    (config/'mcp.json').write_text(json.dumps({'mcpServers':{'lab_tracker':{'command':'python3','args':[str(WORK/'mcp_server.py'),str(release),str(mcp_log)],'exposure':'codemode'}}}))
    (config/'settings.json').write_text(json.dumps({'defaultTools':['+codemode'],'enableTelemetry':False,'compaction':{'enabled':False}}))
    status.write_text('working: disposable worker started\n')
    def resolve(s=scenario):
        deadline=time.monotonic()+90
        while time.monotonic()<deadline:
            text=status.read_text()
            matched=('blocked [key=dependency]' in text) if s['resolution']=='before' else ('note [state=none]' in text)
            if matched:
                with status.open('a') as f: f.write('resolved [key=dependency]: access granted by concurrent supervisor\n')
                s['resolved'].touch(); return
            time.sleep(.001)
    resolver=None
    if resolution: resolver=threading.Thread(target=resolve); resolver.start()
    env=os.environ.copy()
    for key in list(env):
        if key.startswith('FM_') and key.endswith('_OVERRIDE'): del env[key]
    env.update({'PI_CODING_AGENT_DIR':str(config),'PI_CODING_AGENT_SESSION_DIR':str(config/'sessions'),'PI_OFFLINE':'1','PI_TELEMETRY':'0','LIVE_OBSERVATIONS':str(observations),'LIVE_READY':str(int(ready)),'FM_HOME':str(home),'TMPDIR':str(WORK)})
    cmd=['pi','--print','--mode','json','--no-context-files','--no-skills','--no-prompt-templates','--no-themes','--no-extensions','--approve','--no-session','-e','builtin:mcp','-e','builtin:codemode','-e',str(WORK/'observe.ts'),'-e',str(ext),'--provider','lab','--model',name,'--thinking','off']
    if excluded: cmd+=['--exclude-tools','mcp__lab_tracker__editIssue,mcp__lab_tracker__createIssue,mcp__offline__write,mcp__lab_tracker__typo']
    cmd+=['Exercise the disposable tracker scenario.']
    logfile=EVIDENCE/(name+'-pi.jsonl')
    errfile=EVIDENCE/(name+'-stderr.log')
    with logfile.open('w') as out,errfile.open('w') as err:
        proc=subprocess.run(cmd,cwd=wt,env=env,stdout=out,stderr=err,timeout=120)
    if resolver: resolver.join(5)
    text=status.read_text()
    events=[json.loads(l) for l in observations.read_text().splitlines()]
    queries={}
    for key,query in [('latest','last_status_line "$2"'),('current','status_current_line "$2" scout'),('decisions','status_open_decisions "$2" scout'),('unread','scan_unread_surface_lines "$3"')]:
        r=subprocess.run(['bash','-c','. "$1"; '+query,'_',str(ROOT/'bin/fm-classify-lib.sh'),str(status),str(home/'state')],capture_output=True,text=True,env=env)
        queries[key]=r.stdout.strip()
    (EVIDENCE/(name+'-status.txt')).write_text(text+'\n--- public status consumers ---\n'+json.dumps(queries,indent=2)+'\n')
    messages=[json.loads(l) for l in logfile.read_text().splitlines() if l.startswith('{')]
    tool_results=[m for m in messages if m.get('type')=='tool_execution_end']
    checks={'exit':proc.returncode,'agent_start_names':next(e['names'] for e in events if e['event']=='agent_start'),'turn_ends':sum(e['event']=='turn_end' for e in events),'warning_lines':[l for l in text.splitlines() if l.startswith('note ')],'declarations':queries,'tool_results':tool_results}
    try:
        assert proc.returncode==0,errfile.read_text()
        assert tool_results and all(not m.get('isError') for m in tool_results if not m.get('parentToolCallId')),tool_results
        tool_output=json.dumps(tool_results)
        if excluded:
            assert 'does not exist' in tool_output,tool_output
            first_root=next(m for m in tool_results if not m.get('parentToolCallId'))
            chunks=first_root['result']['content']
            first_json=next(line for chunk in chunks for line in chunk.get('text','').splitlines() if line.startswith('{"names"'))
            surfaces=json.loads(first_json)
            assert surfaces['names']==['mcp__lab_tracker__readIssue'] and not surfaces['described'],surfaces
            assert 'mcp__lab_tracker__editIssue' not in surfaces['search'],surfaces
        else:
            assert 'is excluded by config/crew-exclude-tools' in tool_output,tool_output
        assert any(e['event']=='agent_settled' for e in events),events[-3:]
        if excluded:
            assert not checks['warning_lines'],checks
            assert 'mcp__lab_tracker__editIssue' not in events[-1]['names'],checks
        else:
            assert len(checks['warning_lines'])==1,checks
            assert all(tool in checks['warning_lines'][0] for tool in ['mcp__lab_tracker__editIssue','mcp__lab_tracker__createIssue']),checks
            assert 'mcp__offline__write' not in checks['warning_lines'][0] and 'mcp__lab_tracker__typo' not in checks['warning_lines'][0],checks
            assert 'still present' in queries['unread'],queries
            executions=[json.loads(l) for l in mcp_log.read_text().splitlines()]
            assert not any(m.get('executed') in ['editIssue','createIssue'] for m in executions),executions
            assert any(m.get('executed')=='readIssue' for m in executions),executions
        if not ready: assert not any(n.startswith('mcp__') for n in checks['agent_start_names']),checks
        if ready: assert 'mcp__lab_tracker__editIssue' in checks['agent_start_names'],checks
        if name=='after-210-turns':
            assert checks['turn_ends']>210,checks
            assert not any(n.startswith('mcp__') for e in events if e['event']=='turn_end' and e['turns']<=210 for n in e['names']),checks
        expected='resolved [key=dependency]: access granted by concurrent supervisor' if resolution else declaration
        assert queries['latest']==expected and queries['current']==expected,queries
        assert not queries['decisions'],queries
        outcome='pass'; reason=''
    except AssertionError as e:
        outcome='fail'; reason=str(e)
    result={'name':name,'result':outcome,'reason':reason,'command':shlex.join(cmd),'observations':checks}
    results.append(result)
    print(json.dumps({'name':name,'result':outcome,'reason':reason[:500],'turn_ends':checks['turn_ends']}),flush=True)
    (EVIDENCE/'live-results.json').write_text(json.dumps(results,indent=2))
    if outcome=='fail': break
finally:
    server.shutdown(); server.server_close()
