import os,json,pathlib,sys,time,subprocess
names=['FM_SNAPSHOT_SCOPED_ENV','FM_CREW_STATE_META_OVERRIDE','FM_CREW_STATE_STATUS_OVERRIDE','FM_HOME_SUMMARY_IF_IDLE','FM_HOME_SUMMARY_WORKER_BEST_EFFORT','FM_HOME_SUMMARY_PARENT_ERROR','FM_HOME_SUMMARY_PARENT_STAMP','FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_PROJECTS_OVERRIDE','FM_CONFIG_OVERRIDE','FM_HOME','FM_TASK_INBOX']
result={'pid':os.getpid(),'cwd':os.getcwd(),'environment':{k:os.environ[k] for k in names if k in os.environ}}
if len(sys.argv)>3:
    argv=[sys.argv[2],sys.argv[3]]
    broken=subprocess.run(argv,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    clean=dict(os.environ)
    for n in names[7:12]:clean.pop(n,None)
    repaired=subprocess.run(argv,env=clean,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    result['current_state_with_inherited_environment']={'exit':broken.returncode,'output':broken.stdout}
    result['current_state_without_snapshot_paths']={'exit':repaired.returncode,'output':repaired.stdout}
pathlib.Path(sys.argv[1]).write_text(json.dumps(result,indent=2)); print(json.dumps(result),flush=True)
