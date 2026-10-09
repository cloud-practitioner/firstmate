import http.server,json,os,queue,shlex,subprocess,threading,time
from pathlib import Path
ROOT=Path.cwd(); WORK=ROOT/'.test-exclusions'; EVIDENCE=Path('/home/node/.no-mistakes/evidence/01M4FATPH1GGTGPYHJS1Q4J58G')
r=(WORK/'case').read_text().strip().split('|'); home=Path(r[1]); wt=Path(r[3]); status=home/'state/live-exclusions.status'
class Model(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_POST(self):
  req=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  self.send_response(200);self.send_header('Content-Type','text/event-stream');self.end_headers()
  for delta,finish in [({'role':'assistant','content':'Disposable worker is idle.'},None),({},'stop')]:
   obj={'id':'lab-agent-start','object':'chat.completion.chunk','created':int(time.time()),'model':req['model'],'choices':[{'index':0,'delta':delta,'finish_reason':finish}]}
   self.wfile.write(('data: '+json.dumps(obj)+'\n\n').encode());self.wfile.flush()
  self.wfile.write(b'data: [DONE]\n\n');self.wfile.flush()
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Model);threading.Thread(target=server.serve_forever,daemon=True).start()
results=[]
try:
 for name,state in [('later-agent-start-done','done: task completed between agent runs'),('later-agent-start-resolved','blocked [key=dependency]: waiting for access\nresolved [key=dependency]: concurrent access grant')]:
  config=WORK/name;config.mkdir(exist_ok=True);release=config/'release';release.unlink(missing_ok=True)
  observations=EVIDENCE/(name+'-lifecycle.jsonl');observations.unlink(missing_ok=True)
  mcp_log=EVIDENCE/(name+'-mcp.jsonl');mcp_log.unlink(missing_ok=True)
  (config/'models.json').write_text(json.dumps({'providers':{'lab':{'baseUrl':'http://127.0.0.1:'+str(server.server_port)+'/v1','api':'openai-completions','apiKey':'disposable','models':[{'id':name}]}}}))
  (config/'mcp.json').write_text(json.dumps({'mcpServers':{'lab_tracker':{'command':'python3','args':[str(WORK/'mcp_server.py'),str(release),str(mcp_log)],'exposure':'codemode'}}}))
  status.write_text('working: waiting for MCP connection\n')
  env=os.environ.copy();env.update({'PI_CODING_AGENT_DIR':str(config),'PI_OFFLINE':'1','PI_TELEMETRY':'0','LIVE_READY':'0','LIVE_SECOND_START':'1','LIVE_OBSERVATIONS':str(observations),'TMPDIR':str(WORK)})
  cmd=['pi','--mode','rpc','--no-context-files','--no-skills','--no-prompt-templates','--no-themes','--no-extensions','--approve','--no-session','-e','builtin:mcp','-e','builtin:codemode','-e',str(WORK/'observe.ts'),'-e',str(home/'state/live-exclusions.pi-ext.ts'),'--provider','lab','--model',name]
  transcript=EVIDENCE/(name+'-pi.jsonl');err=EVIDENCE/(name+'-stderr.log');records=queue.Queue()
  with transcript.open('w') as log,err.open('w') as errors:
   proc=subprocess.Popen(cmd,cwd=wt,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=errors,text=True)
   def drain():
    for line in proc.stdout:
     log.write(line);log.flush();records.put(json.loads(line))
   reader=threading.Thread(target=drain);reader.start()
   try:
    for prompt in range(3):
     if prompt==1:
      with status.open('a') as f:f.write(state+'\n')
      release.touch()
     proc.stdin.write(json.dumps({'id':str(prompt),'type':'prompt','message':'Acknowledge the disposable worker state.'})+'\n');proc.stdin.flush()
     while True:
      record=records.get(timeout=30)
      if record.get('type')=='agent_settled':break
     if prompt==0:
      assert not any(l.startswith('note ') for l in status.read_text().splitlines()),status.read_text()
   finally:
    proc.stdin.close();proc.wait(timeout=10);reader.join(10)
  events=[json.loads(l) for l in observations.read_text().splitlines()];starts=[e for e in events if e['event']=='agent_start'];text=status.read_text()
  queries={}
  for key,query in [('latest','last_status_line "$2"'),('current','status_current_line "$2" scout'),('decisions','status_open_decisions "$2" scout'),('unread','scan_unread_surface_lines "$3"')]:
   queries[key]=subprocess.run(['bash','-c','. "$1"; '+query,'_',str(ROOT/'bin/fm-classify-lib.sh'),str(status),str(home/'state')],capture_output=True,text=True).stdout.strip()
  (EVIDENCE/(name+'-status.txt')).write_text(text+'\n--- public status consumers ---\n'+json.dumps(queries,indent=2)+'\n')
  assert len(starts)==3 and not any(n.startswith('mcp__') for n in starts[0]['names']),starts
  assert all('mcp__lab_tracker__editIssue' in s['names'] for s in starts[1:]),starts
  assert len([l for l in text.splitlines() if l.startswith('note ')])==1,text
  expected=state.splitlines()[-1]; assert queries['latest']==expected and queries['current']==expected and not queries['decisions'],queries
  assert 'still present' in queries['unread'],queries
  assert proc.returncode==0,err.read_text()
  results.append({'name':name,'result':'pass','command':shlex.join(cmd),'initialStartNames':starts[0]['names'],'laterStartNames':starts[1]['names'],'declarations':queries})
  print(json.dumps({'name':name,'result':'pass','agentRuns':len(starts)}),flush=True)
 (EVIDENCE/'agent-start-results.json').write_text(json.dumps(results,indent=2))
finally:server.shutdown();server.server_close()
