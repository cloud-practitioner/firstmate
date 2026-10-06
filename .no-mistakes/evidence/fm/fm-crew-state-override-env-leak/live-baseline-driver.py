exec(open('.v/live.py').read().split('arm=None')[0])
base['FM_HOME']=str(R/'.v/fm');raw['FM_HOME']=base['FM_HOME']
leak=base.copy();leak.update({n:'before-fix-'+n for n in names});leak['FM_SNAPSHOT_SCOPED_ENV']='1'
try:
 cmd(['bash','-c','. .v/baseline/bin/fm-backend.sh; fm_backend_source herdr; fm_backend_herdr_cli "$HERDR_SESSION" server'],leak)
 ws=json.loads(lab('run','fm-lab-e','workspace','create','--cwd',R,'--label','before-fix','--no-focus'))
 pane=ws['result']['root_pane']['pane_id']
 proc=json.loads(lab('run','fm-lab-e','pane','process-info','--pane',pane))
 pid=proc['result']['process_info']['shell_pid'];vals=readenv(pid)
 (E/'baseline-server-descendant.json').write_text(json.dumps({'base_commit':'06a89438bead6193fd300248c5366941a30789d9','pane':pane,'environment':vals},indent=2))
 assert vals.get('FM_CREW_STATE_META_OVERRIDE')=='before-fix-FM_CREW_STATE_META_OVERRIDE',vals
 assert vals.get('FM_CREW_STATE_STATUS_OVERRIDE')=='before-fix-FM_CREW_STATE_STATUS_OVERRIDE',vals
 trans.append('REPRODUCED before fix: a new server pane inherited the record overrides: '+json.dumps(vals))
finally:
 lab('teardown','fm-lab-e')
 (E/'baseline-reproduction.log').write_text('\n'.join(trans))
