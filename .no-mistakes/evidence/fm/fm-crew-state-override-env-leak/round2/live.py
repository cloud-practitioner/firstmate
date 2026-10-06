import os, pathlib, subprocess, json, time, shlex, shutil
R=pathlib.Path.cwd(); E=pathlib.Path('/home/node/.no-mistakes/evidence/01M48AGCET15Z951PCQ4YNDYRJ/round2')
base=os.environ.copy(); operator=base['HOME']; real=shutil.which('herdr'); oldpath=base['PATH']
for k in list(base):
 if k.startswith(('HERDR_','FM_','TASKS_AXI','TMUX')): base.pop(k,None)
base.update(V_ROOT=str(R),V_OPERATOR_HOME=operator,V_REAL_HERDR=real,V_BASE_PATH=oldpath,V_SESSION='fm-lab-e2',V_EVIDENCE=str(E),FM_HERDR_LAB_STATE_DIR=str(R/'.v/lab-state'),HOME=str(R/'.v/home'),XDG_CONFIG_HOME='.v',TMPDIR=str(R/'.v/tmp'),SHELL='/bin/bash',HERDR_SESSION='fm-lab-e2',FM_BACKEND='herdr',DISABLE_AUTOUPDATER='1')
base.pop('FM_GATE_REFUSE_BYPASS',None)
base['PATH']=str(R/'.v/adapter')+':'+oldpath
raw=base.copy();raw['PATH']=str(R/'.v/raw')+':'+oldpath
names=['FM_SNAPSHOT_SCOPED_ENV','FM_CREW_STATE_META_OVERRIDE','FM_CREW_STATE_STATUS_OVERRIDE','FM_HOME_SUMMARY_IF_IDLE','FM_HOME_SUMMARY_WORKER_BEST_EFFORT','FM_HOME_SUMMARY_PARENT_ERROR','FM_HOME_SUMMARY_PARENT_STAMP','FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_PROJECTS_OVERRIDE','FM_CONFIG_OVERRIDE']
trans=[]
def cmd(args,env=None,check=True,timeout=90):
 trans.append('$ '+shlex.join(map(str,args)))
 p=subprocess.run(list(map(str,args)),cwd=R,env=env or base,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
 trans.append(p.stdout);print(p.stdout,end='',flush=True)
 if check and p.returncode:raise RuntimeError(f'exit {p.returncode}: {args}')
 return p.stdout
def lab(*args,env=None):return cmd([R/'bin/fm-herdr-lab.sh',*args],env or raw)
def readenv(pid):
 rows=pathlib.Path(f'/proc/{pid}/environ').read_bytes().split(b'\0');vals={}
 for row in rows:
  if b'=' in row:
   k,v=row.split(b'=',1);k=k.decode()
   if k in names or k in ['FM_HOME','FM_TASK_INBOX']:vals[k]=v.decode(errors='replace')
 return vals
def repo(path):
 path.mkdir(exist_ok=True);cmd(['git','-C',path,'init','-q','-b','main']);cmd(['git','-C',path,'-c','user.name=Lab','-c','user.email=lab@example.invalid','commit','--allow-empty','-qm','fixture'])
def observe(pane):
 info=json.loads(lab('run','fm-lab-e2','pane','process-info','--pane',pane))
 pid=info['result']['process_info']['shell_pid'];return {'pane':pane,'shell_pid':pid,'environment':readenv(pid)}
def cleanup():lab('teardown','fm-lab-e2')

def main():
 home=R/'.v/read-home';cmd([R/'bin/fm-lab-home.sh','create',home]);base['FM_HOME']=str(home);raw['FM_HOME']=str(home)
 leak=base.copy();leak.update({n:'planted-'+n for n in names});leak['FM_SNAPSHOT_SCOPED_ENV']='1'
 # Real named server startup before the fix; run is forwarded through provision.
 try:
  cmd(['bash','-c','. .v/baseline/bin/fm-backend.sh; fm_backend_source herdr; fm_backend_herdr_cli "$HERDR_SESSION" server'],leak)
  ws=json.loads(lab('run','fm-lab-e2','workspace','create','--cwd',R,'--label','baseline','--no-focus'))
  obs=observe(ws['result']['root_pane']['pane_id']);(E/'baseline-server.json').write_text(json.dumps(obs,indent=2))
  assert obs['environment']['FM_CREW_STATE_META_OVERRIDE']==leak['FM_CREW_STATE_META_OVERRIDE'],obs
  trans.append('REPRODUCED: baseline server pane retained snapshot overrides '+json.dumps(obs))
 finally:cleanup()
 try:
  cmd(['bash','-c','. bin/fm-backend.sh; fm_backend_source herdr; fm_backend_herdr_cli "$HERDR_SESSION" server'],leak)
  ws=json.loads(lab('run','fm-lab-e2','workspace','create','--cwd',R,'--label','clean','--no-focus'))
  pane=ws['result']['root_pane']['pane_id'];obs=observe(pane)
  (E/'clean-server.json').write_text(json.dumps(obs,indent=2));assert not any(n in obs['environment'] for n in names),obs
  trans.append('CURRENT: server descendant has no snapshot overrides '+json.dumps(obs))
  project=R/'.v/read-project';repo(project);captured=R/'.v/captured';captured.mkdir()
  meta=f'window=fm-lab-e2:{pane}\nworktree={project}\nkind=scout\nbackend=herdr\nharness=claude\n'
  (captured/'task.meta').write_text(meta);(captured/'task.status').write_text('paused: captured-record-is-authoritative\n')
  leak.update(FM_ROOT_OVERRIDE=str(R),FM_STATE_OVERRIDE=str(home/'state'),FM_DATA_OVERRIDE=str(home/'data'),FM_CONFIG_OVERRIDE=str(home/'config'),FM_PROJECTS_OVERRIDE=str(home/'projects'),FM_CREW_STATE_META_OVERRIDE=str(captured/'task.meta'),FM_CREW_STATE_STATUS_OVERRIDE=str(captured/'task.status'))
  out=cmd([R/'bin/fm-crew-state.sh','captured-task'],leak);assert 'no metadata' not in out and 'source: pane' in out,out
  (captured/'task.status').write_text('');before=(E/'client-boundary.log').stat().st_size
  out=cmd([R/'bin/fm-crew-state.sh','captured-task'],leak);log=(E/'client-boundary.log').read_text()[before:]
  (E/'captured-read.log').write_text(out+'\nReal Herdr CLI boundary:\n'+log)
  assert 'HERDR command:' in log and not any(n+'=' in log for n in names),log
  # Exercise the actual producer, not just the single-command override interface.
  (home/'state/snapshot-task.meta').write_text(meta);(home/'state/snapshot-task.status').write_text('')
  before=(E/'client-boundary.log').stat().st_size
  snap=json.loads(cmd([R/'bin/fm-fleet-snapshot.sh','--json']));(E/'fleet-snapshot.json').write_text(json.dumps(snap,indent=2))
  log=(E/'client-boundary.log').read_text()[before:];(E/'fleet-snapshot-boundary.log').write_text(log)
  assert snap['tasks'] and 'no metadata' not in json.dumps(snap['tasks']),snap
  assert 'HERDR command:' in log and not any(n+'=' in log for n in names),log
  # Unmarked path seams remain legitimate at the client boundary.
  seam=base.copy();seam['FM_STATE_OVERRIDE']=str(home/'state');seam['FM_CREW_STATE_META_OVERRIDE']='unmarked-meta'
  before=(E/'client-boundary.log').stat().st_size
  cmd(['bash','-c','. bin/fm-backend.sh; fm_backend_source herdr; fm_backend_herdr_cli "$HERDR_SESSION" workspace list'],seam)
  log=(E/'client-boundary.log').read_text()[before:];(E/'unmarked-client.log').write_text(log)
  assert 'FM_STATE_OVERRIDE='+str(home/'state') in log and 'FM_CREW_STATE_META_OVERRIDE=' not in log,log
 finally:cleanup()
 (E/'read-server-transcript.log').write_text('\n'.join(trans))
if __name__=='__main__':
 try:main()
 except Exception as ex:
  trans.append('FAIL: '+repr(ex));(E/'read-server-transcript.log').write_text('\n'.join(trans));raise
