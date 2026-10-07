import http.server,json,os,pathlib,subprocess,tempfile,threading,time,shlex,sys
kind=sys.argv[1] if len(sys.argv)>1 else 'scout'
root=pathlib.Path.cwd()
scratch=pathlib.Path('/home/node/.treehouse/firstmate-35d3d0/1/firstmate/state/fm-spawn-pi-exclude-tools.tasktmp')
ev=pathlib.Path('/home/node/.no-mistakes/evidence/01M49W3M79ENYHYMK104A317EC')
lab=pathlib.Path(tempfile.mkdtemp(prefix='fm-lab.',dir=scratch))
subprocess.run(['bin/fm-lab-home.sh','create',str(lab)],check=True,stdout=subprocess.DEVNULL)
requests=[]
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_POST(self):
  requests.append(json.loads(self.rfile.read(int(self.headers['Content-Length']))))
  self.send_response(200);self.send_header('Content-Type','text/event-stream');self.end_headers()
  for delta,finish in [({'role':'assistant','content':'Local live validation completed.'},None),({},'stop')]:
   obj={'id':'lab-turn','object':'chat.completion.chunk','created':1,'model':'lab-model','choices':[{'index':0,'delta':delta,'finish_reason':finish}]}
   self.wfile.write(('data: '+json.dumps(obj)+'\n\n').encode())
  self.wfile.write(b'data: [DONE]\n\n')
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
(lab/'agent').mkdir();(lab/'user').mkdir();(lab/'herdr-lab-state').mkdir()
(lab/'agent/models.json').write_text(json.dumps({'providers':{'exclusion-lab':{'baseUrl':f'http://127.0.0.1:{server.server_port}/v1','api':'openai-completions','apiKey':'disposable-local-only','models':[{'id':'lab-model','name':'Local validation endpoint','reasoning':False,'input':['text'],'contextWindow':32000,'maxTokens':1024,'compat':{'supportsDeveloperRole':False,'supportsStore':False}}]}}}))
(lab/'tools.ts').write_text('''export default function(pi:any){for(const name of ['mcp__iqx_jira__editJiraIssue','mcp__iqx_jira__getJiraIssue','mcp__iqx_jira__addOrEditJiraIssueComment']){pi.registerTool({name,label:name,description:'Local disposable tool, no MCP connection',parameters:{type:'object',properties:{}},async execute(){return {content:[{type:'text',text:'local'}],details:{}}}})}}''')
(lab/'agent/settings.json').write_text(json.dumps({'defaultProvider':'exclusion-lab','defaultModel':'lab-model','defaultThinkingLevel':'off','quietStartup':True,'extensions':[str(lab/'tools.ts')]}))
(lab/'config/supervision-host').touch();(lab/'state/.last-watcher-beat').touch();(lab/'config/herdr-presentation-spaces').write_text('off\n')
(lab/'config/crew-exclude-tools').write_text('mcp__iqx_jira__editJiraIssue\n')
env={k:v for k,v in os.environ.items() if not k.startswith('HERDR_') and not(k.startswith('FM_') and (k.endswith('_OVERRIDE') or k in ('FM_HOME','FM_BACKEND','FM_ROOT','FM_GATE_REFUSE_BYPASS','FM_TASK_TMP','FM_TASK_ID')))}
env.update(TMPDIR=str(scratch),FM_HERDR_LAB_STATE_DIR=str(lab/'herdr-lab-state'),PI_CODING_AGENT_DIR=str(lab/'agent'),PI_OFFLINE='1',PI_TELEMETRY='0',TREEHOUSE_ROOT=str(lab/'treehouse'),HOME=str(lab/'user'),SHELL='/usr/bin/bash',XDG_CONFIG_HOME=os.environ.get('XDG_CONFIG_HOME','/home/node/.config'))
log=(ev/('live-herdr-'+kind+'-exclusions.log')).open('w')
def call(args,timeout=20,check=True):
 p=subprocess.run(args,cwd=root,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
 log.write('$ '+shlex.join(args)+'\n'+p.stdout+'\nExit: '+str(p.returncode)+'\n');log.flush()
 if check and p.returncode:raise RuntimeError(p.stdout)
 return p
session=call(['bin/fm-herdr-lab.sh','name','exclude-live']).stdout.strip()
provisioned=False
try:
 call(['bin/fm-herdr-lab.sh','provision',session],timeout=70);provisioned=True
 # Inspect actual consumer contracts before attempting a spawn.
 call(['bin/fm-herdr-lab.sh','run',session,'pane','run','--help'])
 call(['bin/fm-herdr-lab.sh','run',session,'workspace','create','--help'])
 call(['bin/fm-herdr-lab.sh','run',session,'pane','list'])
 project=lab/'projects/probe';project.mkdir()
 call(['git','-C',str(project),'init','-q','-b','main'])
 (project/'README.md').write_text('Disposable tool-exclusion validation project.\n')
 call(['git','-C',str(project),'add','README.md'])
 call(['git','-C',str(project),'-c','user.name=Validation','-c','user.email=validation@example.invalid','commit','-qm','initial'])
 # Run Firstmate itself from the gate worktree against the marked lab home.
 worker_env=env.copy();worker_env.update(FM_HOME=str(lab),FM_BACKEND='herdr',HERDR_SESSION=session)
 kind_args=['--scout'] if kind=='scout' else ['--mode','local-only']
 p=subprocess.run(['bin/fm-brief.sh','live-excl','probe']+kind_args+['--herdr-lab'],env=worker_env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=15)
 log.write('Scaffold\n'+p.stdout+'\n');log.flush();assert p.returncode==0,p.stdout
 brief=lab/'data/live-excl/brief.md'
 brief.write_text(brief.read_text().replace('{TASK}','Verify configured tool exclusions; do not call MCP servers.').replace('{FIRSTMATE_SPEC}','Return a short confirmation without tools, and remain idle.'))
 spawn_kind_args=kind_args if kind=='scout' else kind_args+['--yolo','off']
 p=subprocess.run(['bin/fm-spawn.sh','live-excl',str(project)]+spawn_kind_args+['--harness','pi','--model','exclusion-lab/lab-model'],env=worker_env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
 log.write('Actual spawn\n'+p.stdout+'\nExit: '+str(p.returncode)+'\n');log.flush()
 call(['bin/fm-herdr-lab.sh','run',session,'pane','read','w1:p2'],check=False)
 assert p.returncode==0,p.stdout
 time.sleep(2)
 call(['bin/fm-herdr-lab.sh','run',session,'pane','read','w1:p2'],check=False)
 call(['bin/fm-herdr-lab.sh','run',session,'pane','send-keys','w1:p2','Enter'])
 deadline=time.monotonic()+30
 while not requests and time.monotonic()<deadline:time.sleep(.2)
 assert requests,'Worker did not reach the disposable endpoint'
 log.write('Model-facing tools: '+json.dumps(requests[-1].get('tools',[]))+'\n');log.flush()
 names=[x['function']['name'] for x in requests[-1].get('tools',[])]
 assert 'mcp__iqx_jira__editJiraIssue' not in names,names
 assert 'mcp__iqx_jira__getJiraIssue' in names and 'mcp__iqx_jira__addOrEditJiraIssueComment' in names,names
 meta=lab/'state/live-excl.meta';log.write('Task metadata\n'+meta.read_text()+'\n')
 status=lab/'state/live-excl.status';log.write('Task status\n'+status.read_text()+'\n');log.flush()
 assert 'unverified' in status.read_text()
 # Keep a nonempty current list across a real replacement, preserving identity.
 time.sleep(3)
 requests.clear(); before_meta=meta.read_text()
 p=subprocess.run(['bin/fm-control.sh','live-excl','relaunch','--note','keep current exclusions'],env=worker_env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
 log.write('Actual relaunch retaining exclusions\n'+p.stdout+'\nExit: '+str(p.returncode)+'\n');log.flush();assert p.returncode==0,p.stdout
 deadline=time.monotonic()+30
 while not requests and time.monotonic()<deadline:time.sleep(.2)
 assert requests,'Retained-list replacement did not reach disposable endpoint'
 names=[x['function']['name'] for x in requests[-1].get('tools',[])]
 log.write('Retained-list replacement tools: '+json.dumps(names)+'\n');log.flush()
 assert 'mcp__iqx_jira__editJiraIssue' not in names and 'mcp__iqx_jira__getJiraIssue' in names,names
 assert next(x for x in before_meta.splitlines() if x.startswith('window=')) in meta.read_text().splitlines()
 time.sleep(3)
 # Refusal must leave the existing real worker intact.
 for content,args in [('two words\n',[]),('mcp__iqx_jira__editJiraIssue\n',['--harness','codex'])]:
  (lab/'config/crew-exclude-tools').write_text(content)
  before=meta.read_bytes()
  p=subprocess.run(['bin/fm-control.sh','live-excl','relaunch','--note','test pre-stop refusal']+args,env=worker_env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=25)
  log.write('Actual relaunch refusal\n'+p.stdout+'\nExit: '+str(p.returncode)+'\n');log.flush()
  assert p.returncode==1 and 'config/crew-exclude-tools' in p.stdout,p.stdout
  assert meta.read_bytes()==before,'Refusal changed task metadata'
 # Remove the list and actually replace the worker.
 (lab/'config/crew-exclude-tools').unlink();requests.clear()
 p=subprocess.run(['bin/fm-control.sh','live-excl','relaunch','--note','remove tool exclusions'],env=worker_env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
 log.write('Actual relaunch without exclusions\n'+p.stdout+'\nExit: '+str(p.returncode)+'\n');log.flush();assert p.returncode==0,p.stdout
 deadline=time.monotonic()+30
 while not requests and time.monotonic()<deadline:time.sleep(.2)
 assert requests,'Replacement did not reach disposable endpoint'
 names=[x['function']['name'] for x in requests[-1].get('tools',[])]
 log.write('Replacement model-facing tools: '+json.dumps(names)+'\n');log.flush()
 assert 'mcp__iqx_jira__editJiraIssue' in names,names
 print('Live Herdr spawn, pre-stop refusals, and relaunch passed.')
finally:
 if provisioned:
  call(['bin/fm-herdr-lab.sh','run',session,'pane','read','w1:p2'],check=False)
  p=call(['bin/fm-herdr-lab.sh','teardown',session],timeout=30,check=False)
  print('Lab teardown:',p.returncode)
 else:
  p=call(['bin/fm-herdr-lab.sh','teardown',session],timeout=20,check=False)
 server.shutdown();server.server_close();log.close()
 if p.returncode==0:
  # Firstmate itself stages launch shell files in /tmp, keyed by this exact lab home.
  import hashlib
  launch_dir=pathlib.Path('/tmp')/('fm-live-excl+'+hashlib.sha256(str(lab).encode()).hexdigest())
  if launch_dir.is_dir(): subprocess.run(['rm','-rf',str(launch_dir)],check=True)
  subprocess.run(['chmod','-R','u+w',str(lab)],check=True)
  subprocess.run(['rm','-rf',str(lab)],check=True)
