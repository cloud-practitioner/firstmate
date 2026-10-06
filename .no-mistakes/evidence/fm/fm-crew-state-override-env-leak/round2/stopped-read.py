import runpy
locals().update(runpy.run_path('.v/live.py'))
for version in ['baseline','current']:
 home=R/'.v'/('stopped-'+version);base['FM_HOME']=str(home);raw['FM_HOME']=str(home)
 try:
  cmd([R/'bin/fm-lab-home.sh','create',home]);lab('provision','fm-lab-e2')
  status=json.loads(lab('run','fm-lab-e2','status','--json'));(E/'herdr-version.json').write_text(json.dumps(status,indent=2))
  ws=json.loads(lab('run','fm-lab-e2','workspace','create','--cwd',R,'--label','stopped-read','--no-focus'));pane=ws['result']['root_pane']['pane_id']
  lab('stop','fm-lab-e2')
  captured=R/'.v'/('stopped-captured-'+version);captured.mkdir();project=R/'.v'/('stopped-project-'+version);repo(project)
  (captured/'read.meta').write_text(f'window=fm-lab-e2:{pane}\nworktree={project}\nkind=scout\nbackend=herdr\nharness=claude\n');(captured/'read.status').write_text('')
  root=R if version=='current' else R/'.v/baseline'
  leak=base.copy();leak.update({n:'stopped-'+n for n in names});leak.update(FM_SNAPSHOT_SCOPED_ENV='1',FM_ROOT_OVERRIDE=str(root),FM_STATE_OVERRIDE=str(home/'state'),FM_DATA_OVERRIDE=str(home/'data'),FM_PROJECTS_OVERRIDE=str(home/'projects'),FM_CONFIG_OVERRIDE=str(home/'config'),FM_CREW_STATE_META_OVERRIDE=str(captured/'read.meta'),FM_CREW_STATE_STATUS_OVERRIDE=str(captured/'read.status'))
  before=(E/'client-boundary.log').stat().st_size
  out=cmd([root/'bin/fm-crew-state.sh','stopped-task'],leak)
  log=(E/'client-boundary.log').read_text()[before:]
  assert 'HERDR command:' in log,log
  if version=='current':assert not any(row.startswith(n+'=') for row in log.splitlines() for n in names),log
  status=json.loads(lab('run','fm-lab-e2','status','--json'))
  obs={'crew_state':out,'status_after_read':status,'cli_environment_log':log}
  if status.get('server',{}).get('running'):
   descendant=observe(pane);obs['autostarted_server_descendant']=descendant
   if version=='current':assert not any(n in descendant['environment'] for n in names),descendant
   else:assert descendant['environment'].get('FM_CREW_STATE_META_OVERRIDE')==str(captured/'read.meta'),descendant
  (E/(version+'-stopped-read.json')).write_text(json.dumps(obs,indent=2))
  assert 'no metadata' not in out,out
 finally:cleanup()
(E/'stopped-read-transcript.log').write_text('\n'.join(trans))
