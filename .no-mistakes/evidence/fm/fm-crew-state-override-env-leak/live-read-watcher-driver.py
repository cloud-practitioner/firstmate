import os, pathlib, subprocess, json, time, shlex
R=pathlib.Path.cwd(); E=pathlib.Path('/home/node/.no-mistakes/evidence/01M48AGCET15Z951PCQ4YNDYRJ')
base=os.environ.copy(); operator=base['HOME']; real=subprocess.check_output(['which','herdr'],text=True).strip(); oldpath=base['PATH']
for k in list(base):
 if k.startswith('HERDR_') or k.startswith('FM_'): base.pop(k,None)
base.update(V_ROOT=str(R),V_OPERATOR_HOME=operator,V_REAL_HERDR=real,V_BASE_PATH=oldpath,V_SESSION='fm-lab-e',V_EVIDENCE=str(E),FM_HERDR_LAB_STATE_DIR=str(R/'.v/lab-state'),HOME=str(R/'.v/home'),XDG_CONFIG_HOME='.v',TMPDIR=str(R/'.v/tmp'),SHELL='/bin/bash',HERDR_SESSION='fm-lab-e',FM_BACKEND='herdr',DISABLE_AUTOUPDATER='1')
base['PATH']=str(R/'.v/adapter')+':'+oldpath
raw=base.copy(); raw['PATH']=str(R/'.v/raw')+':'+oldpath
names=['FM_SNAPSHOT_SCOPED_ENV','FM_CREW_STATE_META_OVERRIDE','FM_CREW_STATE_STATUS_OVERRIDE','FM_HOME_SUMMARY_IF_IDLE','FM_HOME_SUMMARY_WORKER_BEST_EFFORT','FM_HOME_SUMMARY_PARENT_ERROR','FM_HOME_SUMMARY_PARENT_STAMP','FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_PROJECTS_OVERRIDE','FM_CONFIG_OVERRIDE']
trans=[]
def cmd(args,env=None,check=True,timeout=60):
 trans.append('$ '+shlex.join(map(str,args)))
 p=subprocess.run(list(map(str,args)),cwd=R,env=env or base,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
 trans.append(p.stdout); print(p.stdout,end='',flush=True)
 if check and p.returncode: raise RuntimeError(f'exit {p.returncode}: {args}')
 return p.stdout
helper=R/'bin/fm-herdr-lab.sh'
def lab(*args,env=None):return cmd([helper,*args],env or raw)
def readenv(pid):
 data=pathlib.Path(f'/proc/{pid}/environ').read_bytes().split(b'\0'); vals={}
 for row in data:
  if b'=' in row:
   k,v=row.split(b'=',1); k=k.decode();
   if k in names or k in ['FM_HOME','FM_TASK_INBOX']:vals[k]=v.decode(errors='replace')
 return vals
arm=None
try:
 # provision owns prepare on a not-yet-created session.
 home=R/'.v/fm';cmd([R/'bin/fm-lab-home.sh','create',home]);base['FM_HOME']=str(home);raw['FM_HOME']=str(home)
 leak=base.copy(); leak.update({n:'snapshot-sentinel-'+n for n in names});leak['FM_SNAPSHOT_SCOPED_ENV']='1';leak['FM_ROOT_OVERRIDE']=str(R);leak['FM_STATE_OVERRIDE']=str(home/'state')
 cmd(['bash','-c','. bin/fm-backend.sh; fm_backend_source herdr; fm_backend_herdr_cli "$HERDR_SESSION" server'],leak)
 lab('run','fm-lab-e','status','--json')
 ws=json.loads(lab('run','fm-lab-e','workspace','create','--cwd',R,'--label','clean-start','--no-focus'))
 (E/'workspace-create.json').write_text(json.dumps(ws,indent=2))
 panes=json.loads(lab('run','fm-lab-e','pane','list'));print('PANES',panes)
 # Shell environment is an observable descendant of the real named server.
 pane=panes['result']['panes'][0]['pane_id']
 proc=json.loads(lab('run','fm-lab-e','pane','process-info','--pane',pane))
 pid=proc['result']['process_info']['shell_pid']; vals=readenv(pid)
 (E/'clean-server-descendant.json').write_text(json.dumps({'pane':pane,'shell_pid':pid,'environment':vals},indent=2))
 assert not any(n in vals for n in names), vals
 trans.append('Clean server descendant environment: '+json.dumps(vals))
 # A captured read must keep its own records while CLI subprocesses strip all overrides.
 captured=R/'.v/captured'; captured.mkdir(exist_ok=True)
 wt=R/'.v/read-project';wt.mkdir(exist_ok=True)
 cmd(['git','-C',wt,'init','-q','-b','main'])
 cmd(['git','-C',wt,'-c','user.name=Lab','-c','user.email=lab@example.invalid','commit','--allow-empty','-qm','fixture'])
 (captured/'task.meta').write_text(f'window=fm-lab-e:{pane}\nworktree={wt}\nkind=ship\nbackend=herdr\nharness=claude\n')
 (captured/'task.status').write_text('paused: captured-record-is-authoritative\n')
 leak.update(FM_CREW_STATE_META_OVERRIDE=str(captured/'task.meta'),FM_CREW_STATE_STATUS_OVERRIDE=str(captured/'task.status'),FM_DATA_OVERRIDE=str(home/'data'),FM_PROJECTS_OVERRIDE=str(home/'projects'),FM_CONFIG_OVERRIDE=str(home/'config'))
 out=cmd([R/'bin/fm-crew-state.sh','captured-task'],leak)
 assert 'source: pane' in out and 'no metadata' not in out, out
 # Empty captured status forces a live Herdr read rather than a status-only short circuit.
 (captured/'task.status').write_text('')
 before=(E/'client-boundary.log').stat().st_size
 out=cmd([R/'bin/fm-crew-state.sh','captured-task'],leak)
 new=(E/'client-boundary.log').read_text()[before:]
 (E/'captured-crew-state.log').write_text(out+'\nHerdr subprocess environments:\n'+new)
 assert 'HERDR command:' in new, 'read did not reach Herdr'
 assert not any(n+'=' in new for n in names),new
 # The actual watcher must own a lock/beacon and run with no inherited record overrides.
 watcher_env=base.copy();watcher_env.update({n:'watcher-sentinel-'+n for n in names[:7] if not n.endswith('_OVERRIDE')});watcher_env['FM_SNAPSHOT_SCOPED_ENV']='1';watcher_env['FM_POLL']='1';watcher_env['FM_ARM_CONFIRM_TIMEOUT']='10'
 arm_log=(E/'watcher-arm.log').open('w')
 arm=subprocess.Popen([R/'bin/fm-watch-arm.sh'],cwd=R,env=watcher_env,stdout=arm_log,stderr=subprocess.STDOUT)
 lock=home/'state/.watch.lock/pid'
 for _ in range(120):
  if lock.exists() and (home/'state/.last-watcher-beat').exists():break
  if arm.poll() is not None:raise RuntimeError('watcher exited before becoming live: '+(E/'watcher-arm.log').read_text())
  time.sleep(.1)
 pid=int(lock.read_text()); vals=readenv(pid)
 (E/'watcher-process-environment.json').write_text(json.dumps({'pid':pid,'environment':vals,'beacon':(home/'state/.last-watcher-beat').read_text()},indent=2))
 assert not any(n in vals for n in names),vals
 cmd([R/'bin/fm-watch-arm.sh','--stop']);arm.wait(timeout=20);arm=None;arm_log.close()
 trans.append('Real watcher environment: '+json.dumps(vals))
 # Remaining spawn scenarios run in a separate evidence turn below.
except Exception as ex:
 trans.append('FAIL: '+repr(ex));print('FAIL',repr(ex),flush=True);raise
finally:
 if arm is not None:
  cmd([R/'bin/fm-watch-arm.sh','--stop'],check=False)
  try:arm.wait(timeout=10)
  except subprocess.TimeoutExpired:arm.terminate();arm.wait(timeout=10)
 lab('teardown','fm-lab-e')
 (E/'live-read-watcher-transcript.log').write_text('\n'.join(trans))
