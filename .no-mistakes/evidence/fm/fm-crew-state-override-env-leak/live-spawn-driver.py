exec(open('.v/live.py').read().split('arm=None')[0])
# Use the actual product's public raw-command escape hatch to launch a finite
# telemetry workload; neither Herdr nor the product is replaced by a stub.
rt=R/'.v/runtime';home=R/'.v/spawn-home';base['FM_HOME']=str(home);raw['FM_HOME']=str(home)
base['FM_SPAWN_NO_GUARD']='1';base['FM_HERDR_PROJECTION']='0'
base['PATH']=str(R/'.v/adapter')+':'+oldpath
poison=raw.copy();poison.update({n:'poison-'+n for n in names});poison['FM_SNAPSHOT_SCOPED_ENV']='1'
poison['FM_HOME']=str(home)
results={}
for label in ['live-ship','live-filtered','live-relaunch','live-secondmate']:(E/(label+'.json')).unlink(missing_ok=True)
def workload(label):
 task='live-ship' if label=='live-relaunch' else label
 return 'python3 '+shlex.quote(str(R/'.v/probe.py'))+' '+shlex.quote(str(E/(label+'.json')))+' '+shlex.quote(str(rt/'bin/fm-crew-state.sh'))+' '+shlex.quote(task)
def waitfile(label):
 p=E/(label+'.json')
 for _ in range(100):
  if p.exists():return json.loads(p.read_text())
  time.sleep(.2)
 raise RuntimeError('workload did not publish '+str(p))
def setup_repo(path):
 path.mkdir(exist_ok=True);cmd(['git','-C',path,'init','-q','-b','main']);cmd(['git','-C',path,'-c','user.name=Lab','-c','user.email=lab@example.invalid','commit','--allow-empty','-qm','fixture'])
try:
 cmd([R/'bin/fm-lab-home.sh','create',home])
 # Deliberately reproduce the inherited server poison in this lab only.
 lab('provision','fm-lab-e',env=poison)
 project=R/'.v/spawn-project';setup_repo(project)
 for id in ['live-ship','live-filtered']:
  cmd([rt/'bin/fm-brief.sh',id,'fixture','--mode','local-only','--herdr-lab'])
  brief=home/'data'/id/'brief.md';brief.write_text(brief.read_text().replace('{TASK}','Print the launch environment only; do not perform project work.').replace('{FIRSTMATE_SPEC}','Launch telemetry is the complete disposable workload. No pipeline, push, or PR.'))
  if id=='live-filtered':(home/'config/launch-env-allowlist').write_text('\n'.join(names)+'\n')
  leak=base.copy();leak.update({n:'caller-'+n for n in names[:7]});leak['FM_SNAPSHOT_SCOPED_ENV']='1'
  cmd([rt/'bin/fm-spawn.sh',id,project,'--mode','local-only','--yolo','off',workload(id)],leak,timeout=100)
  obs=waitfile(id);results[id]=obs
  trans.append(id+' launched workload environment: '+json.dumps(obs))
  # Existing leaked record overrides must not reach even a raw command or an
  # allowlist that explicitly tries to retain them.
  assert not any(n in obs['environment'] for n in names[:7]),obs
  (home/'config/launch-env-allowlist').unlink(missing_ok=True)
 # Relaunch the completed workload into the same contaminated shell.
 meta=home/'state/live-ship.meta'
 target=next(x.split('=',1)[1] for x in meta.read_text().splitlines() if x.startswith('window='))
 lab('run','fm-lab-e','pane','send-text',target.split(':',1)[1], 'export FM_SNAPSHOT_SCOPED_ENV=1 FM_CREW_STATE_META_OVERRIDE=poison.meta FM_CREW_STATE_STATUS_OVERRIDE=poison.status FM_HOME_SUMMARY_IF_IDLE=poison-idle FM_HOME_SUMMARY_WORKER_BEST_EFFORT=poison-worker FM_HOME_SUMMARY_PARENT_ERROR=poison-error FM_HOME_SUMMARY_PARENT_STAMP=poison-stamp')
 lab('run','fm-lab-e','pane','send-keys',target.split(':',1)[1],'enter')
 time.sleep(.5)
 cmd([rt/'bin/fm-spawn.sh','live-ship','--relaunch','--harness',workload('live-relaunch')],timeout=100)
 obs=waitfile('live-relaunch');results['live-relaunch']=obs
 assert not any(n in obs['environment'] for n in names[:7]),obs
 # A secondmate is a sibling home of the runtime copy, not an illegal nested
 # home inside the firstmate source root.
 sm=R/'.v/secondmate';cmd([R/'bin/fm-lab-home.sh','create',sm]);setup_repo(sm)
 (sm/'bin').mkdir(exist_ok=True)
 (sm/'.fm-secondmate-home').write_text('live-secondmate\n')
 (sm/'data/charter.md').write_text('Disposable test home: report environment only. Do not perform project work.\n')
 # Fixtures reuse the existing memory document rather than authoring new rules.
 cmd(['cp',R/'AGENTS.md',sm/'AGENTS.md'])
 (sm/'.gitignore').write_text('state/\ndata/\nconfig/\nprojects/\n.no-mistakes/\n')
 cmd([rt/'bin/fm-spawn.sh','live-secondmate',sm,'--secondmate',workload('live-secondmate')],timeout=100)
 obs=waitfile('live-secondmate');results['live-secondmate']=obs
 assert not any(n in obs['environment'] for n in names[:7]),obs
 for key,obs in results.items():
  paths={n:obs['environment'][n] for n in names[7:] if n in obs['environment']}
  trans.append('Snapshot path inheritance '+key+': '+json.dumps(paths))
 (E/'spawn-results.json').write_text(json.dumps(results,indent=2))
 failures={key:{n:obs['environment'][n] for n in names[7:12] if obs['environment'].get(n)} for key,obs in results.items() if any(obs['environment'].get(n) for n in names[7:12])}
 (E/'snapshot-path-failure.json').write_text(json.dumps(failures,indent=2))
 assert not failures, 'Marked snapshot-only path overrides survived launches: '+json.dumps(failures)
except Exception as ex:
 trans.append('FAIL: '+repr(ex));print('FAIL',repr(ex),flush=True);raise
finally:
 lab('teardown','fm-lab-e')
 (E/'live-spawn-transcript.log').write_text('\n'.join(trans))
