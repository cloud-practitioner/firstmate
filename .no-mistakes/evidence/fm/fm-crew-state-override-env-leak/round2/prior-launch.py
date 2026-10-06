import runpy
locals().update(runpy.run_path('.v/live.py'))
rt=R/'.v/prior';home=R/'.v/prior-home';base['FM_HOME']=str(home);raw['FM_HOME']=str(home);base['FM_SPAWN_NO_GUARD']='1'
(E/'prior-ship.json').unlink(missing_ok=True)
poison=raw.copy();poison.update({n:'prior-poison-'+n for n in names});poison['FM_SNAPSHOT_SCOPED_ENV']='1'
try:
 cmd([R/'bin/fm-lab-home.sh','create',home]);lab('provision','fm-lab-e2',env=poison)
 project=R/'.v/prior-project';repo(project)
 cmd([rt/'bin/fm-brief.sh','prior-ship','fixture','--mode','local-only','--herdr-lab'])
 p=home/'data/prior-ship/brief.md';p.write_text(p.read_text().replace('{TASK}','Observe environment only.').replace('{FIRSTMATE_SPEC}','Finite telemetry workload; no pipeline, push, or PR.'))
 (home/'config/launch-env-allowlist').write_text('\n'.join(['FM_HOME','FM_HERDR_LAB_STATE_DIR']+[k for k in base if k.startswith('V_')]+names[7:])+'\n')
 workload='python3 '+shlex.quote(str(R/'.v/probe.py'))+' '+shlex.quote(str(E/'prior-ship.json'))+' '+shlex.quote(str(rt/'bin/fm-crew-state.sh'))+' prior-ship'
 cmd([rt/'bin/fm-spawn.sh','prior-ship',project,'--mode','local-only','--yolo','off',workload],timeout=150)
 for _ in range(150):
  if (E/'prior-ship.json').exists():break
  time.sleep(.2)
 obs=json.loads((E/'prior-ship.json').read_text());trans.append('Prior revision actual workload: '+json.dumps(obs))
 assert all(obs['environment'].get(n)=='prior-poison-'+n for n in names[7:]),obs
 assert 'no metadata' in obs['current_state_with_inherited_environment']['output'],obs
 assert 'source: pane' in obs['current_state_without_snapshot_paths']['output'],obs
finally:
 cleanup();(E/'prior-launch-transcript.log').write_text('\n'.join(trans))
