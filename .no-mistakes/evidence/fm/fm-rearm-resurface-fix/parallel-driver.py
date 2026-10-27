import os, pathlib, subprocess, concurrent.futures, json, shutil
R=pathlib.Path.cwd(); H=R/'.test-rearm/parallel-home'; E=pathlib.Path('/home/node/.no-mistakes/evidence/01M5XNA6EXS99GEKKQTBA3Q4G9'); logs=[]
env=os.environ.copy()
for k in list(env):
 if k.startswith('FM_') or k=='NO_MISTAKES_GATE': env.pop(k,None)
env.update({'FM_HOME':str(H),'FM_PROCEVENT_CLAIM_ROOT':str(H/'claims'),'HOME':str(H/'home'),'TMPDIR':str(R/'.test-rearm/tmp')})
def run(*args):
 p=subprocess.run([str(x) for x in args],cwd=R,env=env,text=True,capture_output=True,timeout=40)
 assert p.returncode==0,(args,p.stdout,p.stderr)
 return p.stdout+p.stderr
def pe(*args): return run(R/'bin/fm-procevent.sh',*args)
def read(name): return (H/'state'/name).read_text()
try:
 assert not H.exists()
 run(R/'bin/fm-lab-home.sh','create',H)
 for i in [1,2]:
  logs.append(pe('register','lavish','same-source','--','/bin/sh','-c',f'printf "session:\\n  status: feedback\\n  session_ended: true\\nfeedback[1]{{text}}:\\n  round {i}\\n"'))
  logs.append(pe('start','same-source'))
 before=read('.wake-queue'); marker=read('.watcher-down')
 keys=[row.split('\t')[3] for row in before.splitlines()]
 assert sorted(keys)==['procevent:same-source:1','procevent:same-source:2'],keys
 with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
  results=list(pool.map(lambda _:pe('reconcile'),range(12)))
 assert read('.wake-queue')==before,'parallel publishers changed queued copies'
 assert read('.watcher-down')==marker,'parallel publishers changed recovery generation'
 logs+=results
 logs.append('PASS: two real captured rounds for the same source remain distinct (sequences 1 and 2); twelve simultaneous public reconcile commands leave exactly those two rows and the same recovery generation.\n')
 logs.append('Persisted queue contract (epoch, sequence, kind, key, payload):\n'+read('.wake-queue'))
 (E/'parallel-two-rounds.tsv').write_text(read('.wake-queue'))
finally:
 if H.exists():
  pe('sweep-home'); shutil.rmtree(H)
 logs.append('Teardown: swept only the disposable process-event home and removed it.\n')
 (E/'parallel-rounds.log').write_text(''.join(logs))
 print(''.join(logs))
