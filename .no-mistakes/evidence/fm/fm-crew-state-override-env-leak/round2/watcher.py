import runpy
locals().update(runpy.run_path('.v/live.py'))
arm=None
try:
 lab('provision','fm-lab-e2')
 for version in ['baseline','current']:
  home=R/'.v'/('watch-'+version);cmd([R/'bin/fm-lab-home.sh','create',home]);base['FM_HOME']=str(home);raw['FM_HOME']=str(home)
  leak=base.copy();leak.update({n:'watcher-'+n for n in names[:7]});leak['FM_SNAPSHOT_SCOPED_ENV']='1';leak['FM_POLL']='1';leak['FM_ARM_CONFIRM_TIMEOUT']='10'
  leak.update(FM_ROOT_OVERRIDE=str(R),FM_STATE_OVERRIDE=str(home/'state'),FM_DATA_OVERRIDE=str(home/'data'),FM_CONFIG_OVERRIDE=str(home/'config'),FM_PROJECTS_OVERRIDE=str(home/'projects'))
  script=R/('bin/fm-watch-arm.sh' if version=='current' else '.v/baseline/bin/fm-watch-arm.sh')
  log=(E/(version+'-watch-arm.log')).open('w')
  # The repository test harness authorizes this deliberately contaminated,
  # stock-layout sandbox. The watcher itself is the real unmodified product.
  args=['bash','-c','. tests/lib.sh; exec '+shlex.quote(str(script))]
  trans.append('$ '+shlex.join(args));arm=subprocess.Popen(args,cwd=R,env=leak,stdout=log,stderr=subprocess.STDOUT)
  lock=home/'state/.watch.lock/pid';beat=home/'state/.last-watcher-beat'
  for _ in range(160):
   if lock.exists() and beat.exists():break
   if arm.poll() is not None:raise RuntimeError('watcher never armed: '+(E/(version+'-watch-arm.log')).read_text())
   time.sleep(.1)
  pid=int(lock.read_text());vals=readenv(pid);beacon=beat.read_text()
  obs={'version':version,'watcher_pid':pid,'environment':vals,'beacon':beacon,'alive':os.path.exists(f'/proc/{pid}')}
  (E/(version+'-watcher.json')).write_text(json.dumps(obs,indent=2));trans.append('Real watcher: '+json.dumps(obs))
  if version=='current':assert not any(n in vals for n in names),obs
  else:assert vals.get('FM_CREW_STATE_META_OVERRIDE')==leak['FM_CREW_STATE_META_OVERRIDE'],obs
  cmd([script,'--stop']);arm.wait(timeout=30);arm=None;log.close()
finally:
 if arm is not None:
  cmd([script,'--stop'],check=False)
  try:arm.wait(timeout=15)
  except subprocess.TimeoutExpired:arm.terminate();arm.wait(timeout=15)
 cleanup();(E/'watcher-transcript.log').write_text('\n'.join(trans))
