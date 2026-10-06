import runpy,re
locals().update(runpy.run_path('.v/live.py'))
rt=R/'.v/runtime';shutil.copytree(R/'tests',rt/'tests');shutil.copytree(R/'docs',rt/'docs');shutil.copyfile(R/'.tasks.toml',rt/'.tasks.toml')
cases={
 'fm-backend-herdr.test.sh':['test_herdr_client_calls_never_receive_snapshot_scoped_env'],
 'fm-crew-state.test.sh':['test_snapshot_override_read_never_reaches_herdr'],
 'fm-spawn-compact-adviser-disable.test.sh':['test_snapshot_scoped_variables_are_cleared_from_the_launch','test_launch_preserves_unmarked_path_overrides','test_spawn_process_clears_snapshot_scoped_variables_before_backend_calls','test_relaunch_clears_snapshot_scoped_variables'],
 'fm-watch-arm.test.sh':['test_arm_clears_snapshot_scoped_variables_before_forking_the_watcher']}
env=base.copy()
for k in ['FM_BACKEND','HERDR_SESSION','FM_HOME']:env.pop(k,None)
env['PATH']=oldpath
logs=[]
for file,selectors in cases.items():
 source=(R/'tests'/file).read_text()
 # Keep executable function definitions and fixture initialization; select
 # only the requested entrypoints, never the broad suite invocation list.
 source='\n'.join(row for row in source.splitlines() if not re.fullmatch(r'test_[A-Za-z0-9_]+',row))
 runner=rt/'tests'/('selected-'+file);runner.write_text(source+'\n'+'\n'.join(selectors)+'\n')
 p=subprocess.run(['bash',str(runner)],env=env,cwd=R,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
 logs.append('$ bash '+str(runner)+' # '+', '.join(selectors)+'\n'+p.stdout);print(logs[-1],flush=True)
 (E/'targeted-regressions.log').write_text('\n'.join(logs))
 if p.returncode:raise RuntimeError('selected regressions failed: '+file)
