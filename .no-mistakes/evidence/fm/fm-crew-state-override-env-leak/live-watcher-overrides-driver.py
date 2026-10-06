exec(open('.v/live.py').read().split('arm=None')[0])
base['FM_HOME']=str(R/'.v/watch-overrides');raw['FM_HOME']=base['FM_HOME'];home=pathlib.Path(base['FM_HOME'])
arm=None
try:
 cmd([R/'bin/fm-lab-home.sh','create',home]);lab('provision','fm-lab-e')
 leak=base.copy();leak.update({n:'watcher-inherited-'+n for n in names[:7]});leak['FM_SNAPSHOT_SCOPED_ENV']='1';leak['FM_POLL']='1'
 # The repository's test harness owns the sandbox gate seam. No primary is
 # launched, and the unmodified real watcher targets a marked disposable home.
 log=(E/'watcher-overrides-arm.log').open('w')
 arm=subprocess.Popen(['bash','-c','. tests/lib.sh; exec bin/fm-watch-arm.sh'],env=leak,cwd=R,stdout=log,stderr=subprocess.STDOUT)
 lock=home/'state/.watch.lock/pid'
 for _ in range(120):
  if lock.exists() and (home/'state/.last-watcher-beat').exists():break
  if arm.poll() is not None:raise RuntimeError('watcher did not become live: '+(E/'watcher-overrides-arm.log').read_text())
  time.sleep(.1)
 pid=int(lock.read_text());vals=readenv(pid)
 (E/'watcher-override-process-environment.json').write_text(json.dumps({'watcher_pid':pid,'environment':vals,'injected_snapshot_names':names[:7]},indent=2))
 assert not any(n in vals for n in names),vals
 trans.append('Unmodified watcher process after inherited record and summary overrides: '+json.dumps(vals))
 cmd([R/'bin/fm-watch-arm.sh','--stop']);arm.wait(timeout=20);arm=None;log.close()
finally:
 if arm is not None:
  cmd([R/'bin/fm-watch-arm.sh','--stop'],check=False);arm.wait(timeout=20)
 lab('teardown','fm-lab-e')
 (E/'watcher-override-transcript.log').write_text('\n'.join(trans))
