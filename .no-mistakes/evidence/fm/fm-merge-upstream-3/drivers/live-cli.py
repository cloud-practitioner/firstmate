import os, pathlib, subprocess, json, time, shutil
R=pathlib.Path.cwd(); E=pathlib.Path('/home/node/.no-mistakes/evidence/01M472X02W8XV0139WP154XWSR'); D=R/'.validation/cli-lab'; D.mkdir()
env=dict(os.environ); env['TMPDIR']=str(R/'.validation/tmp')
for k in list(env):
 if k.startswith('FM_') and (k.endswith('_OVERRIDE') or k=='FM_GATE_REFUSE_BYPASS'): env.pop(k,None)
logs=[]
def run(args,e=None,check=True):
 p=subprocess.run([str(a) for a in args],env=e or env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 logs.append('$ '+' '.join(str(a) for a in args)+'\n'+p.stdout+'exit='+str(p.returncode))
 if check and p.returncode: raise RuntimeError(p.stdout)
 return p
try:
 # Real quota-axi snapshot input is an explicitly supported consumer contract.
 q=D/'quota'; q.mkdir(); (q/'home').mkdir(); snap=q/'snapshot.json'
 payload={'schemaVersion':3,'providers':[{'provider':'codex','label':'Codex','source':'oauth','windows':[{'id':'five_hour','label':'session','kind':'session','percentRemaining':0,'percentUsed':100,'resetsAt':'2099-01-01T00:00:00Z'}],'state':{'status':'fresh','stale':False,'sourcesTried':['oauth'],'refreshedAt':'2026-10-05T00:00:00Z'}}]}
 qe=dict(env,HOME=str(q/'home'),XDG_CONFIG_HOME=str(q/'home/config'),QUOTA_AXI_SNAPSHOT=str(snap))
 snap.write_text(json.dumps(payload)); actual=run(['quota-axi','--json'],qe); (E/'quota-snapshot-consumed.json').write_text(actual.stdout)
 data=json.loads(actual.stdout); assert any(p['provider']=='codex' and p['quotaSemantics']['effectiveAvailability'] for p in data['providers'])
 snap.unlink()
 command=[str(R/'bin/fm-procevent-quota.sh'),'poll','--provider','codex','--interval','1','--threshold','10','--timeout','3']
 started=time.monotonic(); p=subprocess.Popen(command,env=qe,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 time.sleep(.8); assert p.poll() is None,'first transient read killed quota watch'; snap.write_text(json.dumps(payload)); output=p.communicate(timeout=15)[0]
 logs.append('REAL POLL: absent snapshot restored after first failure; elapsed='+str(round(time.monotonic()-started,2))+'s\n'+output)
 assert 'status: exhausted' in output and 'condition_polls: 1' not in output,output
 snap.unlink(); output=run(command,qe).stdout; assert 'status: error' in output and 'condition_polls: 3' in output and '3 consecutive read failures' in output,output
 (E/'quota-live-transcript.txt').write_text('\n\n'.join(logs)); logs=[]
 # Real remote-worker supervisor and serving process; no worker or process stubs.
 root=D/'remote-code'; home=D/'account'; state=D/'remote-jobs'; (root/'bin').mkdir(parents=True); home.mkdir()
 for n in ['fm-remote-job-lib.sh','fm-remote-job-worker.sh','fm-remote-delta-read.sh']: shutil.copy2(R/'bin'/n,root/'bin'/n)
 (root/'AGENTS.md').write_text('Disposable worker code root.\n')
 run(['git','-C',root,'init','-q','-b','main']); run(['git','-C',root,'add','.']); run(['git','-C',root,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture'])
 e=dict(env,FM_REMOTE_JOB_STATE_ROOT=str(state),FM_REMOTE_JOB_PLATFORM_OVERRIDE='Linux')
 driver=D/'worker.sh'; driver.write_text('''#!/bin/bash
set -eu
. "$1/bin/fm-remote-job-lib.sh"
root=$2; account=$3
cleanup(){ [ ! -f "$FM_REMOTE_JOB_STATE/worker.pid" ] || fm_remote_job_stop_worker_tree "$(cat "$FM_REMOTE_JOB_STATE/worker.pid")"; }
trap cleanup EXIT
fm_remote_job_ensure_worker "$root" "$account"
first=$(cat "$FM_REMOTE_JOB_STATE/worker.pid")
printf 'first_worker=%s repaired=%s\\n' "$first" "$FM_REMOTE_JOB_REPAIRED"
rm "$FM_REMOTE_JOB_STATE/worker.ready"
sleep 3
[ -f "$FM_REMOTE_JOB_STATE/worker.ready" ]
fm_remote_job_ensure_worker "$root" "$account"
second=$(cat "$FM_REMOTE_JOB_STATE/worker.pid")
printf 'after_missing_ready_worker=%s repaired=%s\\n' "$second" "$FM_REMOTE_JOB_REPAIRED"
[ "$first" = "$second" ] && [ "$FM_REMOTE_JOB_REPAIRED" = 0 ]
for i in 1 2 3; do fm_remote_job_ensure_worker "$root" "$account"; [ "$(cat "$FM_REMOTE_JOB_STATE/worker.pid")" = "$first" ]; done
printf 'three further ensures preserved the same worker\\n'
ps -o pid,ppid,pgid,stat,args -p "$first"
''')
 run(['bash',driver,R,root,home],e); (E/'remote-owner-live.txt').write_text('\n\n'.join(logs)); logs=[]
 # Output contract: the final brief emitted to a worker, not implementation prose.
 lab=D/'home'; run([R/'bin/fm-lab-home.sh','create',lab]); le=dict(env,FM_HOME=str(lab))
 run([R/'bin/fm-brief.sh','scratch-task','fixture-project','--mode','local-only'],le)
 brief=lab/'data/scratch-task/brief.md'; output=brief.read_text(); (E/'emitted-ship-brief.md').write_text(output)
 assert 'proof and scratch output outside it' in output and 'task temp root' in output and 'Leave the worktree clean' in output
 # Adversarial real teardown calls: no backend, forge, treehouse, or git stubs.
 project=lab/'projects/demo'; project.mkdir(); run(['git','-C',project,'init','-q','-b','main']); (project/'tracked.txt').write_text('landed\n'); run(['git','-C',project,'add','.']); run(['git','-C',project,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','landed'])
 wt=lab/'worktree'; run(['git','-C',project,'worktree','add','-q','-b','fm/task',wt]);
 (lab/'state/task.meta').write_text('window=primary:fm-task\nendpoint_task_id=task\nbackend=tmux\nharness=pi\nworktree='+str(wt)+'\nproject='+str(project)+'\nkind=ship\nmode=local-only\nspawn_gen=live-task-gen\n')
 (lab/'state/.last-watcher-beat').touch()
 for mode in ['untracked','mixed','tracked']:
  for p in wt.glob('*scratch*'): p.unlink()
  (wt/'tracked.txt').write_text('edited\n' if mode!='untracked' else 'landed\n')
  if mode!='tracked':
   for i in range(12): (wt/(f'{i:02}-scratch.txt')).write_text('proof\n')
  before=run(['git','-C',wt,'status','--porcelain']).stdout
  result=run([R/'bin/fm-teardown.sh','task'],le,False)
  assert result.returncode==1 and 'REFUSED' in result.stdout,result.stdout
  assert ('untracked-only leftovers' if mode=='untracked' else 'includes tracked edits') in result.stdout,result.stdout
  if mode!='tracked': assert '09-scratch.txt' in result.stdout and '10-scratch.txt' not in result.stdout and 'additional untracked paths omitted' in result.stdout
  assert before==run(['git','-C',wt,'status','--porcelain']).stdout and (lab/'state/task.meta').exists()
 (E/'dirty-teardown-live.txt').write_text('\n\n'.join(logs)); print('LIVE_CLI_OK')
finally:
 if logs: (E/'live-cli-last.log').write_text('\n\n'.join(logs))
 shutil.rmtree(D)
