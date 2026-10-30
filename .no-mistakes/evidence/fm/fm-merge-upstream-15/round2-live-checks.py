import os, json, pathlib, subprocess, shutil, tempfile, http.server, threading, time
R=pathlib.Path.cwd(); E=pathlib.Path('/home/node/.no-mistakes/evidence/01M64ZPT5AJ4390HHRPB92ZDZC'); W=R/'.test-validation'
lab=pathlib.Path(tempfile.mkdtemp(prefix='fm-lab.',dir=W/'tmp'))
base={k:v for k,v in os.environ.items() if not (k.startswith('FM_') or k.startswith('GIT_') or k.startswith('TASKS_AXI'))}
base.update(TMPDIR=str(W/'tmp'),GIT_CONFIG_GLOBAL=str(R/'tests/git-fixture.gitconfig'),GIT_CONFIG_NOSYSTEM='1')
log=[]
def run(args,env=None,ok=None,timeout=60):
 e=base.copy();e.update(env or {})
 p=subprocess.run([str(x) for x in args],env=e,cwd=R,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout)
 log.append('$ '+' '.join(str(x) for x in args)+'\nexit='+str(p.returncode)+'\n'+p.stdout.decode(errors='replace')+p.stderr.decode(errors='replace'))
 if ok is not None: assert p.returncode==ok,log[-1]
 return p
server=None; ssh=None; sd=None
try:
 run(['bin/fm-lab-home.sh','create',lab],ok=0)
 env={'FM_HOME':str(lab)}
 (lab/'config/backlog-backend').write_text('manual\n')
 (lab/'data/projects.md').write_text('- sample [pr=manual no-mistakes branch=feature/] - disposable (added 2026-10-30)\n- bad [direct-PR pr=manual] - invalid (added 2026-10-30)\n')
 assert run(['bin/fm-project-mode.sh','--pr','sample'],env,0).stdout==b'manual\n'
 assert run(['bin/fm-project-mode.sh','sample'],env,0).stdout==b'no-mistakes off\n'
 assert run(['bin/fm-project-mode.sh','--pr','bad'],env,3).stdout==b''
 run(['bin/fm-brief.sh','manual-proof','sample','--mode','no-mistakes','--pr','manual'],env,0)
 brief=(lab/'data/manual-proof/brief.md').read_text(); assert 'pr=manual' in brief and '--skip pr,ci' in brief
 (E/'manual-pr-brief.md').write_text(brief)
 run(['bin/fm-brief.sh','invalid-proof','sample','--mode','local-only','--pr','manual'],env,1)
 (E/'manual-pr-live.log').write_text('\n'.join(log)); log=[]
 project=lab/'projects/sample'; wt=lab/'task-copy'
 run(['git','init','-q','-b','main',project],ok=0)
 run(['git','-C',project,'-c','user.name=Validation','-c','user.email=validation@example.invalid','commit','-q','--allow-empty','-m','fixture'],ok=0)
 run(['git','-C',project,'worktree','add','-q','-b','fm/hidden-proof',wt],ok=0)
 run(['git','-C',wt,'config','status.showUntrackedFiles','no'],ok=0)
 (wt/'new directory').mkdir(); hidden=wt/'new directory/unadded.txt';hidden.write_text('uncommitted work must survive\n')
 meta=lab/'state/hidden-proof.meta'; meta.write_text(f'window=validation:fm-hidden-proof\nendpoint_task_id=hidden-proof\nworktree={wt}\nproject={project}\nkind=ship\nmode=local-only\nspawn_gen=live-validation\n')
 original=meta.read_bytes(); head=run(['git','-C',wt,'rev-parse','HEAD'],ok=0).stdout
 assert run(['git','-C',wt,'status','--porcelain'],ok=0).stdout==b''
 p=run(['bin/fm-teardown.sh','hidden-proof'],env,1)
 assert b'uncommitted changes' in p.stderr and b'new directory/unadded.txt' in p.stderr
 assert hidden.read_text()=='uncommitted work must survive\n' and meta.read_bytes()==original
 assert run(['git','-C',wt,'rev-parse','HEAD'],ok=0).stdout==head
 log.append('Observed: hidden untracked bytes, task metadata, and HEAD preserved after refusal. No backend or pool stub used.')
 (E/'hidden-untracked-live.log').write_text('\n'.join(log));log=[]
 # A disposable HTTP decision service exercises the real curl/provider pipeline.
 requests=[]; response={'model':'local-systemone','answers':{'rule':{'type':'choice','choice':'rule_1','confidence':0.99,'probabilities':{'rule_1':0.99,'default':0.01}}},'usage':{'input_tokens':12,'output_tokens':0}}
 class Handler(http.server.BaseHTTPRequestHandler):
  def do_POST(self):
   body=json.loads(self.rfile.read(int(self.headers['Content-Length'])));requests.append({'path':self.path,'body':body,'authorization_present':bool(self.headers.get('Authorization'))})
   self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(json.dumps(response).encode())
  def log_message(self,*a): pass
 server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
 (lab/'config/crew-dispatch.json').write_text(json.dumps({'rules':[{'when':'A small known bug fix.','use':{'harness':'agy'}}]}))
 user=lab/'isolated-user'; user.mkdir()
 denv={'FM_HOME':str(lab),'FM_DISPATCH_PROVIDER':'systemone','FM_DISPATCH_MODEL':'local-systemone','FM_DISPATCH_BASE_URL':f'http://127.0.0.1:{server.server_port}','HOME':str(user),'XDG_CONFIG_HOME':str(user/'config'),'XDG_CACHE_HOME':str(user/'cache')}
 # Do not leak production provider credentials into quota collection.
 for k in list(base):
  if any(s in k for s in ('API_KEY','TOKEN','AUTH')): base.pop(k)
 p=run(['bin/fm-dispatch-resolve.sh',lab/'data/manual-proof/brief.md','--project','sample'],denv,0,timeout=90)
 assert b'status: escalate' in p.stdout and b'no rankable eligible candidate' in p.stdout and b'candidate: agy:-' in p.stdout
 log.append('Observed: typed response accepted; real quota-axi in an empty disposable user home reports unknown quota, so dispatch honestly escalates instead of inventing a ranking.')
 assert requests[-1]['path']=='/v1/systemone' and not requests[-1]['authorization_present']
 (lab/'config/dispatch-never-send').write_text('127.0.0.1\n'); n=len(requests)
 p=run(['bin/fm-dispatch-resolve.sh',lab/'data/manual-proof/brief.md','--project','sample'],denv,0)
 assert len(requests)==n and b'nothing sent' in p.stderr
 (lab/'config/dispatch-never-send').unlink()
 response['answers']['rule']['probabilities']={'rule_1':0.99}
 p=run(['bin/fm-dispatch-resolve.sh',lab/'data/manual-proof/brief.md'],denv,0)
 assert b'status: error' in p.stdout and b'profile:' not in p.stdout
 (E/'systemone-http-requests.json').write_text(json.dumps(requests,indent=2));(E/'systemone-live.log').write_text('\n'.join(log));log=[]
 p=run(['bin/fm-dispatch-resolve.sh',lab/'data/manual-proof/brief.md'],{'FM_HOME':str(lab),'FM_DISPATCH_PROVIDER':'openai','FM_DISPATCH_MODEL':'gpt-6-luna'},0)
 assert p.stdout==b'' and b'OPENAI_API_KEY absent' in p.stderr
 (E/'openai-live-credential-check.log').write_text('\n'.join(log));log=[]
 print('manual policy, hidden-untracked refusal, systemone HTTP and never-send checks passed')
except Exception:
 (E/'live-checks-error.log').write_text('\n'.join(log));raise
finally:
 if server: server.shutdown();server.server_close()
 shutil.rmtree(lab)
