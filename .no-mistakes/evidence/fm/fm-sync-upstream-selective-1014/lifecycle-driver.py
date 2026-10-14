import os,pathlib,subprocess,tempfile,shutil,json,threading,time,http.server
root=pathlib.Path.cwd();ev=pathlib.Path('/home/node/.no-mistakes/evidence/01M4WAKYZW6KFBK2B9EM3WJZX5')
lab=pathlib.Path(tempfile.mkdtemp(prefix='l.',dir=root));mates=root/'.validation/live-mates';mates.mkdir(exist_ok=True)
product=pathlib.Path(os.environ.get('LAB_PRODUCT',str(root/'.validation/product')));tmux=root/'.validation/tools/root/usr/bin/tmux'; transcript=[]
logname='secondmate-lifecycle-baseline.log' if os.environ.get('LAB_BASELINE') else 'secondmate-lifecycle.log'
class Endpoint(http.server.BaseHTTPRequestHandler):
 def do_POST(self):
  data=json.loads(self.rfile.read(int(self.headers['Content-Length'])));transcript.append('Local HTTP model request: '+data.get('model','unknown'))
  chunk=lambda delta,finish=None: 'data: '+json.dumps({'id':'local-idle','object':'chat.completion.chunk','created':1,'model':'lab-model','choices':[{'index':0,'delta':delta,'finish_reason':finish}]})+'\n\n'
  self.send_response(200);self.send_header('Content-Type','text/event-stream');self.end_headers();self.wfile.write((chunk({'role':'assistant','content':'Idle in the isolated lab; no tool operations requested.'})+chunk({},'stop')+'data: [DONE]\n\n').encode())
 def log_message(self,*args): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Endpoint);threading.Thread(target=server.serve_forever,daemon=True).start()
env=os.environ.copy()
for k in list(env):
 if k.startswith('FM_') or k.startswith('HERDR_') or k in ['TMUX','TMUX_PANE','TASKS_AXI_FILE','TASKS_AXI_BACKEND','PI_SESSION_ID']:env.pop(k,None)
env.update(FM_HOME=str(lab),FM_BACKEND='tmux',TMPDIR=str(root/'.validation/tmp'),TMUX_TMPDIR=str(lab/'tmux'),PATH=str(tmux.parent)+':'+env['PATH'],LD_LIBRARY_PATH=str(root/'.validation/tools/root/usr/lib/x86_64-linux-gnu'),PI_CODING_AGENT_DIR=str(lab/'pi-agent'),FM_BOOTSTRAP_NETWORK='all',HOME=str(lab/'user-home'),GH_CONFIG_DIR=str(lab/'gh-config'),FM_BOOTSTRAP_VERBOSE_FACTS='1',FM_SPAWN_NO_GUARD='1',SHELL='/bin/bash',TREEHOUSE_ROOT=str(lab/'treehouse'))
def cmd(args,check=True,timeout=60,log=True):
 p=subprocess.run([str(x) for x in args],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
 if log:transcript.extend(['$ '+' '.join(map(str,args)),p.stdout.rstrip(),f'exit={p.returncode}']);(ev/logname).write_text('\n'.join(transcript)+'\n')
 if check and p.returncode!=0:
  if any('fm-spawn.sh' in str(x) for x in args):
   pane=subprocess.run([str(tmux),'-L','fm-lab','capture-pane','-p','-t','primary:fm-ship-grant','-S','-100'],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT).stdout
   transcript.append('Failed launch pane:\n'+pane);(ev/logname).write_text('\n'.join(transcript)+'\n')
  raise AssertionError(p.stdout)
 return p
raw=lambda *args,**kw:cmd(['env','-u','NO_MISTAKES_GATE','-u','FM_GATE_REFUSE_BYPASS','-u','FM_ROOT_OVERRIDE','-u','FM_STATE_OVERRIDE','-u','FM_DATA_OVERRIDE','-u','FM_CONFIG_OVERRIDE','-u','FM_PROJECTS_OVERRIDE',tmux,'-L','fm-lab',*args],**kw)
try:
 cmd([root/'bin/fm-lab-home.sh','create',lab]);(lab/'tmux').mkdir();(lab/'pi-agent').mkdir();(lab/'user-home').mkdir()
 (lab/'pi-agent/models.json').write_text(json.dumps({'providers':{'lab-provider':{'baseUrl':f'http://127.0.0.1:{server.server_port}/v1','api':'openai-completions','apiKey':'disposable-local','models':[{'id':'lab-model','name':'Local lab model','reasoning':False,'input':['text'],'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0},'contextWindow':128000,'maxTokens':2048}]}}}))
 (lab/'pi-agent/settings.json').write_text(json.dumps({'defaultProvider':'lab-provider','defaultModel':'lab-model','packages':[],'extensions':[],'skills':[],'themes':[],'defaultTools':[]}))
 (lab/'config/secondmate-harness').write_text('pi\n');(lab/'config/crew-harness').write_text('pi\n')
 (lab/'config/firstmate-role').write_text('maintainer github.com/cloud-practitioner/firstmate\n')
 # The real primary is idle on the exact private socket and 120x40 grid.
 raw('new-session','-d','-x','120','-y','40','-s','primary','-c',root,'-e','FM_HOME='+str(lab),'pi --no-extensions --no-skills --no-prompt-templates')
 time.sleep(2)
 raw('set-option','-g','default-command','/bin/bash --noprofile --norc')
 raw('display-message','-p','-t','primary','pid=#{pane_pid} width=#{pane_width} height=#{pane_height} command=#{pane_current_command}')
 env['TMUX']=raw('display-message','-p','-t','primary','#{socket_path},#{pid},0',log=False).stdout.strip()
 env['TMUX_PANE']=raw('display-message','-p','-t','primary','#{pane_id}',log=False).stdout.strip()
 for ident in ['mate-a','mate-b']:
  h=mates/ident;cmd([root/'bin/fm-lab-home.sh','create',h]);shutil.copytree(product/'bin',h/'bin');shutil.copytree(product/'.pi',h/'.pi')
  (h/'.fm-secondmate-home').write_text(ident+'\n');(h/'AGENTS.md').write_text('Disposable lab secondmate. Stay idle. Never publish or call tools.\n');(h/'data/charter.md').write_text('Stay idle in this disposable validation lab.\n')
  (h/'.gitignore').write_text('config/\ndata/\nstate/\nprojects/\n')
  cmd(['git','-C',h,'init','-q','-b','main']);cmd(['git','-C',h,'add','bin','.pi','AGENTS.md','.fm-secondmate-home','.gitignore']);cmd(['git','-C',h,'-c','user.name=lab','-c','user.email=lab@example.invalid','commit','-qm','Disposable lab fixture'])
  (lab/'state'/f'{ident}.meta').write_text(f'window=primary:fm-{ident}\nkind=secondmate\nharness=pi\nhome={h}\nbackend=tmux\n')
 # Actual bootstrap launches parallel recovery episodes for two missing mates.
 p=cmd([product/'bin/fm-bootstrap.sh'],timeout=100)
 assert 'task set is locked' not in p.stdout,p.stdout
 for ident in ['mate-a','mate-b']:
  ledger=(lab/'state'/f'.secondmate-relaunch-{ident}').read_text();transcript.append('Persisted '+ident+' relaunch ledger:\n'+ledger)
  assert 'relaunched' in ledger and 'failed' not in ledger,ledger
 time.sleep(3)
 raw('list-windows','-t','primary','-F','#{window_name} pid=#{pane_pid} command=#{pane_current_command} width=#{pane_width} height=#{pane_height}')
 windows=raw('list-windows','-t','primary','-F','#{window_name}',log=False).stdout.splitlines()
 for ident in ['mate-a','mate-b']:
  assert windows.count('fm-'+ident)==1,windows
  p=raw('capture-pane','-p','-t','primary:fm-'+ident,'-S','-70');(ev/(ident+'-pane.txt')).write_text(p.stdout)
  probe=cmd(['bash','-c','. "$1/bin/fm-backend.sh"; fm_backend_agent_state tmux "$2"', '_',product,'primary:fm-'+ident])
  assert probe.stdout.strip()=='alive',probe.stdout
 # Report the real role inherited through spawn's config convergence.
 for ident in ['mate-a','mate-b']:
  role=subprocess.run([str(product/'bin/fm-role.sh'),'report'],env={**env,'FM_HOME':str(mates/ident)},text=True,stdout=subprocess.PIPE,check=True).stdout
  transcript.append(ident+' inherited role: '+role.strip());assert 'maintainer github.com/cloud-practitioner/firstmate (inherited)' in role,role
 # Real ship dispatch on an offline clone of this product, under both authority forms.
 # The project fetches only its local fixture origin; that origin's origin supplies the publication identity.
 cmd(['git','-C',product,'remote','add','origin','https://github.com/cloud-practitioner/firstmate.git'],check=False)
 project=lab/'projects/firstmate-lab'
 cmd(['git','clone','-q',product,project])
 for ident in ['ship-grant','ship-consent']:
  if ident=='ship-consent': (lab/'config/firstmate-role').unlink()
  extra=['--upstream-consent','github.com/cloud-practitioner/firstmate'] if ident=='ship-consent' else []
  cmd([product/'bin/fm-brief.sh',ident,'firstmate-lab','--mode','direct-PR','--project',project,*extra])
  brief=lab/'data'/ident/'brief.md';brief.write_text(brief.read_text().replace('{TASK}','Stay idle in the disposable test. Do not publish.').replace('{FIRSTMATE_SPEC}','No tool operations requested.'))
  cmd([product/'bin/fm-spawn.sh',ident,project,'pi','--mode','direct-PR','--yolo','off',*extra],timeout=80)
  meta=dict(line.split('=',1) for line in (lab/'state'/f'{ident}.meta').read_text().splitlines() if '=' in line)
  assert meta['kind']=='ship' and meta['mode']=='direct-PR',meta
  if ident=='ship-consent':assert meta['upstream_consent']=='github.com/cloud-practitioner/firstmate',meta
  transcript.append('Authorized live ship metadata: '+json.dumps({k:v for k,v in meta.items() if k in ['kind','mode','window','upstream_consent','worktree']}))
  trusted=False
  for _ in range(200):
   pane=raw('capture-pane','-p','-t','primary:fm-'+ident,'-S','-100',log=False).stdout
   if 'Idle in the isolated lab; no tool operations requested.' in pane:break
   if not trusted and 'This allows pi to load .pi settings and resources' in pane:
    raw('send-keys','-t','primary:fm-'+ident,'Enter');trusted=True
   time.sleep(.1)
  (ev/(ident+'-pane.txt')).write_text(pane)
  assert 'Idle in the isolated lab; no tool operations requested.' in pane,pane
  probe=cmd(['bash','-c','. "$1/bin/fm-backend.sh"; fm_backend_agent_state tmux "$2"','_',product,'primary:fm-'+ident]);assert probe.stdout.strip()=='alive',probe.stdout
 cmd([product/'bin/fm-brief.sh','ship-denied','firstmate-lab','--mode','direct-PR'])
 denied=lab/'data/ship-denied/brief.md';denied.write_text(denied.read_text().replace('{TASK}','No authority.').replace('{FIRSTMATE_SPEC}','Refuse dispatch.'))
 refused=cmd([product/'bin/fm-spawn.sh','ship-denied',project,'pi','--mode','direct-PR','--yolo','off'],check=False)
 assert refused.returncode==1 and 'spawn refused for ship-denied' in refused.stdout,refused.stdout
 assert not (lab/'state/ship-denied.meta').exists()
 transcript.append('The preceding consented ship did not authorize a later ship on the same offline fork.')
 # A second bootstrap sweep must leave both live Pi processes untouched and revoke inherited authority.
 ids1={i:raw('display-message','-p','-t','primary:fm-'+i,'#{pane_pid}',log=False).stdout.strip() for i in ['mate-a','mate-b']}
 old={i:(lab/'state'/f'.secondmate-relaunch-{i}').read_bytes() for i in ids1}
 cmd([product/'bin/fm-bootstrap.sh'],timeout=80)
 for i in ids1:
  assert raw('display-message','-p','-t','primary:fm-'+i,'#{pane_pid}',log=False).stdout.strip()==ids1[i]
  assert (lab/'state'/f'.secondmate-relaunch-{i}').read_bytes()==old[i]
 transcript.append('Idempotent second sweep preserved both real Pi process IDs and both relaunch ledgers.')
 for ident in ids1:
  role=subprocess.run([str(product/'bin/fm-role.sh'),'report'],env={**env,'FM_HOME':str(mates/ident)},text=True,stdout=subprocess.PIPE,check=True).stdout
  transcript.append(ident+' after parent revocation: '+role.strip());assert role.strip()=='fm-role: user (inherited)',role
  (mates/ident/'config/firstmate-role').write_text('maintainer github.com/cloud-practitioner/firstmate\n')
  role=subprocess.run([str(product/'bin/fm-role.sh'),'report'],env={**env,'FM_HOME':str(mates/ident)},text=True,stdout=subprocess.PIPE,check=True).stdout
  transcript.append(ident+' after local grant planting: '+role.strip());assert 'fm-role: user' in role and 'unverified inherited grant' in role,role
 transcript.append('Inherited maintainer grants were revoked by parent convergence; locally replanted grants remained unauthorized.')
 # Adversarial bounded wait: the real per-home lock is held by a separate process.
 holder=subprocess.Popen(['bash','-c','. "$1/bin/fm-wake-lib.sh"; fm_lock_try_acquire "$STATE/.secondmate-relaunch.lock" || exit; trap \'fm_lock_release "$STATE/.secondmate-relaunch.lock"\' EXIT; sleep 20','_',str(product)],env={**env,'STATE':str(lab/'state')})
 try:
  for _ in range(100):
   if (lab/'state/.secondmate-relaunch.lock').exists():break
   time.sleep(.03)
  script='. "$1/bin/fm-secondmate-liveness-lib.sh"; fm_secondmate_liveness_probe "$STATE/mate-a.meta" mate-a poll; fm_secondmate_liveness_relaunch "$STATE/mate-a.meta" mate-a 1; rc=$?; printf "rc=%s status=%s reason=%s\\n" "$rc" "$FM_SM_LIVE_STATUS" "$FM_SM_LIVE_REASON"; test "$rc" = 1 && test "$FM_SM_LIVE_STATUS" = skipped'
  env['STATE']=str(lab/'state');env['FM_ROOT']=str(product)
  p=cmd(['bash','-c',script,'_',product],timeout=8);assert 'after 1s' in p.stdout
  assert (lab/'state/.secondmate-relaunch-mate-a').read_bytes()==old['mate-a']
  assert raw('display-message','-p','-t','primary:fm-mate-a','#{pane_pid}',log=False).stdout.strip()==ids1['mate-a']
 finally:holder.terminate();holder.wait(timeout=25)
 transcript.append('Bounded per-home contention left the endpoint and attempt ledger unchanged.')
finally:
 raw('kill-server',check=False);server.shutdown()
 shutil.rmtree(lab,ignore_errors=True)
 if mates.exists():
  for h in mates.rglob('*'):
   if h.is_dir():h.chmod(h.stat().st_mode|0o700)
  shutil.rmtree(mates)
 transcript.append('Private tmux lab and disposable secondmate homes removed.');(ev/logname).write_text('\n'.join(transcript)+'\n')
