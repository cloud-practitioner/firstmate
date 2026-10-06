import runpy
locals().update(runpy.run_path('.v/live.py'))
rt=R/'.v/runtime';home=R/'.v/spawn-home';base['FM_HOME']=str(home);raw['FM_HOME']=str(home)
base['FM_SPAWN_NO_GUARD']='1';base['FM_HERDR_PROJECTION']='0'
poison=raw.copy();poison.update({n:'poison-'+n for n in names});poison['FM_SNAPSHOT_SCOPED_ENV']='1'
fixture_allow=['FM_HOME','FM_HERDR_LAB_STATE_DIR']+[k for k in base if k.startswith('V_')]
results={}
for p in E.glob('ship-*.json'):p.unlink()
for p in E.glob('secondmate-*.json'):p.unlink()
for label in ['relaunch','unmarked-absent','unmarked-enabled']:(E/(label+'.json')).unlink(missing_ok=True)
def workload(label,task=None):
 return 'python3 '+shlex.quote(str(R/'.v/probe.py'))+' '+shlex.quote(str(E/(label+'.json')))+' '+shlex.quote(str(rt/'bin/fm-crew-state.sh'))+' '+shlex.quote(task or label)
def waitfile(label):
 p=E/(label+'.json')
 for _ in range(150):
  if p.exists():return json.loads(p.read_text())
  time.sleep(.2)
 raise RuntimeError('workload did not publish '+str(p))
def check(label,task=None,paths_absent=True):
 obs=waitfile(label);results[label]=obs;trans.append(label+' actual workload: '+json.dumps(obs))
 assert not any(n in obs['environment'] for n in names[:7]),obs
 if paths_absent:assert not any(obs['environment'].get(n) for n in names[7:]),obs
 assert 'source: pane' in obs['current_state_with_inherited_environment']['output'],obs
 return obs
def pane_for(task):return next(x.split('=',1)[1] for x in (home/'state'/f'{task}.meta').read_text().splitlines() if x.startswith('window=')).split(':',1)[1]
def export_pane(task,vals):
 pane=pane_for(task);line='export '+' '.join(k+'='+shlex.quote(v) for k,v in vals.items())
 lab('run','fm-lab-e2','pane','send-text',pane,line);lab('run','fm-lab-e2','pane','send-keys',pane,'enter');time.sleep(.6)
def brief(task):
 cmd([rt/'bin/fm-brief.sh',task,'fixture','--mode','local-only','--herdr-lab'])
 p=home/'data'/task/'brief.md';p.write_text(p.read_text().replace('{TASK}','Publish process environment telemetry only.').replace('{FIRSTMATE_SPEC}','Finite disposable telemetry workload. No project work, pipeline, push, or PR.'))
try:
 cmd([R/'bin/fm-lab-home.sh','create',home]);lab('provision','fm-lab-e2',env=poison)
 project=R/'.v/spawn-project';repo(project)
 for setting in ['absent','all','paths-only']:
  task='ship-'+setting;brief(task)
  allow=home/'config/launch-env-allowlist'
  if setting!='absent':allow.write_text('\n'.join(fixture_allow+(names if setting=='all' else names[7:]))+'\n')
  leak=base.copy();leak.update({n:'caller-'+n for n in names[:7]});leak['FM_SNAPSHOT_SCOPED_ENV']='1'
  before=(E/'client-boundary.log').stat().st_size
  cmd([rt/'bin/fm-spawn.sh',task,project,'--mode','local-only','--yolo','off',workload(task)],leak,timeout=150)
  check(task)
  log=(E/'client-boundary.log').read_text()[before:]
  assert not any(row.startswith(n+'=') and 'caller-' in row for row in log.splitlines() for n in names),log
  allow.unlink(missing_ok=True)
 # The caller is clean, but the pane again has every marked poison variable.
 vals={n:'relaunch-poison-'+n for n in names};vals['FM_SNAPSHOT_SCOPED_ENV']='1';export_pane('ship-absent',vals)
 (home/'config/launch-env-allowlist').write_text('\n'.join(fixture_allow+names[7:])+'\n')
 cmd([rt/'bin/fm-spawn.sh','ship-absent','--relaunch','--harness',workload('relaunch','ship-absent')],timeout=150);check('relaunch')
 (home/'config/launch-env-allowlist').unlink()
 # Unmarked overrides are not snapshot-only: paths survive both filter postures.
 legit={'FM_ROOT_OVERRIDE':str(rt),'FM_STATE_OVERRIDE':str(home/'state'),'FM_DATA_OVERRIDE':str(home/'data'),'FM_PROJECTS_OVERRIDE':str(home/'projects'),'FM_CONFIG_OVERRIDE':str(home/'config')}
 for setting in ['absent','enabled']:
  export_pane('ship-absent',dict(legit,FM_SNAPSHOT_SCOPED_ENV='0'))
  if setting=='enabled':(home/'config/launch-env-allowlist').write_text('\n'.join(fixture_allow+names[7:])+'\n')
  label='unmarked-'+setting
  cmd([rt/'bin/fm-spawn.sh','ship-absent','--relaunch','--harness',workload(label,'ship-absent')],timeout=150)
  obs=check(label,paths_absent=False);assert all(obs['environment'].get(n)==v for n,v in legit.items()),obs
  (home/'config/launch-env-allowlist').unlink(missing_ok=True)
 # Secondmate homes must be sibling to the byte-for-byte runtime copy.
 sm=R/'.v/secondmate';cmd([R/'bin/fm-lab-home.sh','create',sm]);repo(sm)
 (sm/'bin').mkdir(exist_ok=True);(sm/'.fm-secondmate-home').write_text('secondmate\n');(sm/'data/charter.md').write_text('Disposable telemetry workload only. No project work.\n')
 shutil.copyfile(R/'AGENTS.md',sm/'AGENTS.md')
 (sm/'.gitignore').write_text('state/\ndata/\nconfig/\nprojects/\n.no-mistakes/\n')
 (sm/'state/child.meta').write_text(f'window=fm-lab-e2:{pane_for("ship-absent")}\nworktree={sm}\nkind=scout\nbackend=herdr\nharness=claude\n')
 for setting in ['absent','all','paths-only']:
  if setting!='absent':(home/'config/launch-env-allowlist').write_text('\n'.join(fixture_allow+(names if setting=='all' else names[7:]))+'\n')
  label='secondmate-'+setting
  args=[rt/'bin/fm-spawn.sh','secondmate',sm,'--secondmate',workload(label,'child')]
  if setting!='absent':
   export_pane('secondmate',vals);args=[rt/'bin/fm-spawn.sh','secondmate','--relaunch','--harness',workload(label,'child')]
  cmd(args,timeout=150);check(label)
  (home/'config/launch-env-allowlist').unlink(missing_ok=True)
 (E/'spawn-results.json').write_text(json.dumps(results,indent=2))
except Exception as ex:
 trans.append('FAIL: '+repr(ex));raise
finally:
 cleanup();(E/'spawn-transcript.log').write_text('\n'.join(trans))
