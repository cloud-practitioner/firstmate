#!/usr/bin/env python3
import os,pathlib,subprocess,tempfile,time,shutil,json
root=pathlib.Path.cwd(); ev=pathlib.Path('/home/node/.no-mistakes/evidence/01M5CS8Z14AJ6WRYGCEP0JMSHD')
# Short name is essential: the gate worktree prefix plus the documented
# fm-lab.XXXXXX name exceeds Linux's 108-byte Unix socket pathname limit.
lab=pathlib.Path(tempfile.mkdtemp(prefix='.l.',dir=root))
env={k:v for k,v in os.environ.items() if not k.startswith(('FM_','HERDR_','NO_MISTAKES_GATE','TREEHOUSE_','TMUX','TASKS_AXI_'))}
env.update(TMUX_TMPDIR=str(lab/'tmux'),PATH=str(root/'.test-lab/tools/usr/bin')+':'+env['PATH'],LD_LIBRARY_PATH=str(root/'.test-lab/tools/usr/lib/x86_64-linux-gnu'),TMPDIR='/tmp')
log=(ev/'primary-lab.log').open('w');result={}
def run(args,expected=None,extra=None):
 effective=env.copy();effective.update(extra or {})
 p=subprocess.run(args,env=effective,cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=40)
 log.write('$ '+' '.join(args)+'\n'+p.stdout+f'[exit {p.returncode}]\n');log.flush()
 if expected is not None: assert p.returncode==expected,p.stdout
 return p
try:
 run(['bin/fm-lab-home.sh','create',str(lab)],0)
 (lab/'tmux').mkdir();(lab/'config/supervision-host').touch()
 run(['tmux','-L','fm-lab','new-session','-d','-s','primary','-x','120','-y','40','-c',str(root),'-e','FM_HOME='+str(lab),'claude'],0)
 final='';sent=False
 for i in range(45):
  time.sleep(2)
  cap=run(['tmux','-L','fm-lab','capture-pane','-p','-t','primary'])
  final=cap.stdout
  (ev/'primary-lab-pane.txt').write_text(final)
  if cap.returncode: break
  if 'trust this folder' in final.lower() or 'yes, i trust' in final.lower():
   run(['tmux','-L','fm-lab','send-keys','-t','primary','Enter']);continue
  if any(s in final.lower() for s in ['not logged in','please run /login','select login method','login method','choose the text style','let’s get started','let\u2019s get started']):
   result={'result':'untested','reason':'Existing normal Claude startup is not authenticated/ready; no login or account configuration was changed.'};break
  if not sent and ('❯' in final or 'Try "' in final):
   prompt='Isolated validation only. Do not run session-start, spawn, delegate, no-mistakes, git, or access other homes. Use Bash exactly once to run `printf "LAB_HARNESS="; bash bin/fm-harness.sh; printf "LAB_HOME=%s\\n" "$FM_HOME"`. Then reply only LAB_CHECK_COMPLETE. This is a disposable marked lab; do not modify any files.'
   run(['tmux','-L','fm-lab','send-keys','-t','primary','-l',prompt]);time.sleep(0.7);run(['tmux','-L','fm-lab','send-keys','-t','primary','Enter']);sent=True
  if 'LAB_CHECK_COMPLETE' in final and 'LAB_HARNESS=claude' in final:
   result={'result':'pass','reason':'Real Claude primary executed the real harness detector in the marked lab.'};break
  if any(s in final.lower() for s in ['invalid api key','authentication_error','authentication failed','not logged in','please run /login','credit balance','unable to connect']):
   result={'result':'untested','reason':'Existing normal Claude startup could not run inference: '+final.strip()[-800:]};break
 if not result: result={'result':'untested','reason':'Real CLI started at 120x40 but did not complete the isolated detector command within 90 seconds. See the retained pane and transcript; no login was attempted.'}
 run(['tmux','-L','fm-lab','capture-pane','-p','-e','-t','primary'])
 (ev/'primary-lab-pane.ansi').write_text(run(['tmux','-L','fm-lab','capture-pane','-p','-e','-t','primary']).stdout)
 if result.get('result')=='pass':
  # Public crew-state reconciliation over a REAL, idle Claude pane. The only
  # seeded semantic data is an explicit Firstmate recovery reset, not a
  # fabricated vendor hook or model transcript. Hide no-mistakes from this
  # one read so no outer/real pipeline ledger is inspected.
  git_env={'GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':'/dev/null','GIT_AUTHOR_NAME':'Disposable validation','GIT_AUTHOR_EMAIL':'validation@example.invalid','GIT_COMMITTER_NAME':'Disposable validation','GIT_COMMITTER_EMAIL':'validation@example.invalid'}
  project=lab/'project';worker=lab/'worker';remote=lab/'remote.git'
  for path in [project,remote]:path.mkdir()
  def git(path,*args):return run(['git','-C',str(path),*args],0,git_env)
  git(remote,'init','-q','--bare','-b','main');git(project,'init','-q','-b','main');git(project,'commit','-q','--allow-empty','-m','base')
  git(project,'remote','add','origin',str(remote));git(project,'push','-q','origin','main')
  run(['git','clone','-q',str(project),str(worker)],0,git_env);git(worker,'remote','set-url','origin',str(remote));git(worker,'checkout','-qb','fm/live-ready');git(worker,'commit','-q','--allow-empty','-m','only in disposable worker')
  head=git(worker,'rev-parse','HEAD').stdout.strip()
  socket=run(['tmux','-L','fm-lab','display-message','-p','-t','primary','#{socket_path}'],0).stdout.strip()
  window=run(['tmux','-L','fm-lab','display-message','-p','-t','primary','#{window_id}'],0).stdout.strip()
  meta=lab/'state/live-ready.meta';status=lab/'state/live-ready.status'
  meta.write_text(f'window=primary:{window}\nbackend=tmux\nworktree={worker}\nproject={project}\nkind=ship\nmode=no-mistakes\nharness=claude\n');meta.chmod(0o600)
  run(['bin/fm-busy-event.sh','arm',str(lab/'state'),'live-ready','--state','idle','--source','fm-recovery','--event','confirmed-idle-lab'],0)
  reads={'FM_HOME':str(lab),'TMUX':socket+',0,0','FM_CREW_STATE_NO_FORGE':'1','PATH':str(root/'.test-lab/tools/usr/bin')+':/usr/bin:/bin:/usr/local/bin'}
  status.write_text('paused: PROD deploy watch, checks green on TEST\n')
  paused=run(['bin/fm-crew-state.sh','live-ready'],0,reads).stdout
  assert 'state: paused' in paused,paused
  status.write_text('done: PR https://bitbucket.org/team/repo/pull-requests/7 checks green\n')
  blocked=run(['bin/fm-crew-state.sh','live-ready'],0,reads).stdout
  assert 'state: blocked' in blocked and f'named head {head} is unreachable outside the worker copy' in blocked,blocked
  git(worker,'push','-q','origin','HEAD:refs/heads/fm/live-ready');git(worker,'fetch','-q','origin')
  done=run(['bin/fm-crew-state.sh','live-ready'],0,reads).stdout
  assert 'state: done' in done,done
  result['crew_state_result']='pass'
  result['crew_state_reason']='Real idle Claude pane: incidental PROD text stays paused; Bitbucket checks-green note is blocked until named HEAD is preserved on a real local remote.'
except Exception as e:
 result={'result':'untested','reason':'Disposable-primary setup failed: '+repr(e)}
finally:
 run(['tmux','-L','fm-lab','kill-server'])
 shutil.rmtree(lab,ignore_errors=True)
 log.write(json.dumps(result)+'\n');log.close();(ev/'primary-lab-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
