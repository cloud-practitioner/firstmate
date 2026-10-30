import os, subprocess as sp, pathlib as p, json, shutil, threading, http.server, base64, hashlib
ROOT=p.Path.cwd(); E=p.Path('/home/node/.no-mistakes/evidence/01M64ZPT5AJ4390HHRPB92ZDZC'); LAB=ROOT/'.test-live/product'
LAB.mkdir(exist_ok=True)
env=os.environ.copy()
for k in list(env):
 if k.startswith(('FM_', 'HERDR_','TASKS_AXI','TREEHOUSE_')) or k in ['TMUX','NM_HOME','NO_MISTAKES_GATE']: env.pop(k,None)
env.update(TMPDIR=str(ROOT/'.test-live/tmp'), HOME=str(LAB/'user'), FM_BACKEND='tmux', GIT_CONFIG_GLOBAL='/dev/null',GIT_CONFIG_NOSYSTEM='1',GIT_AUTHOR_NAME='Live validation',GIT_AUTHOR_EMAIL='test@example.invalid',GIT_COMMITTER_NAME='Live validation',GIT_COMMITTER_EMAIL='test@example.invalid')
# Real dependency executables only, deliberately omit no-mistakes so teardown cannot contact a pipeline.
binpath=LAB/'bin'; binpath.mkdir(exist_ok=True)
for name in 'bash sh env git jq node python3 perl treehouse tmux quota-axi ssh ps pgrep pkill kill sleep date stat ls cat mkdir dirname basename pwd realpath readlink sed awk grep head tail tr cut sort uniq wc cp mv rm rmdir touch chmod umask mktemp id uname find xargs sha256sum shasum base64 od timeout lsof curl printf tar tee cksum flock true false seq ln dd getconf'.split():
 f=shutil.which(name)
 if f: (binpath/name).symlink_to(f)
(binpath/'tmux').unlink(missing_ok=True)
(binpath/'tmux').symlink_to(ROOT/'.test-live/tools/tmux/usr/bin/tmux')
env.update(PATH=str(binpath),LD_LIBRARY_PATH=str(ROOT/'.test-live/tools/tmux/usr/lib/x86_64-linux-gnu'))
socketdir=None
(LAB/'user').mkdir(exist_ok=True)
log=[]
def run(args,cwd=ROOT,extra=None,check=True):
 e=env.copy(); e.update(extra or {})
 r=sp.run([str(x) for x in args],cwd=cwd,env=e,text=True,stdout=sp.PIPE,stderr=sp.STDOUT,timeout=60)
 log.append('$ '+' '.join(str(x).replace(str(ROOT),'<worktree>') for x in args)+'\n'+r.stdout+f'[exit {r.returncode}]\n')
 if check and r.returncode: raise RuntimeError(log[-1])
 return r
try:
 home=LAB/'home'; run(['bin/fm-lab-home.sh','create',home]); env['FM_HOME']=str(home)
 project=home/'projects/demo'; run(['git','init','-q','-b','main',project]); (project/'note.txt').write_text('baseline\n');run(['git','add','.'],project);run(['git','commit','-qm','baseline'],project)
 (home/'data/projects.md').write_text('- demo [no-mistakes pr=manual branch=fix/] - disposable project (added 2026-01-01)\n')
 assert run(['bin/fm-project-mode.sh','demo']).stdout.strip()=='no-mistakes off'
 assert run(['bin/fm-project-mode.sh','--pr','demo']).stdout.strip()=='manual'
 assert run(['bin/fm-project-mode.sh','--branch-prefix','demo']).stdout.strip()=='fix/'
 run(['bin/fm-brief.sh','manual-proof','demo','--mode','no-mistakes','--pr','manual','--project',project,'--herdr-lab'])
 brief=home/'data/manual-proof/brief.md'; body=brief.read_text(); (E/'manual-pr-brief.md').write_text(body)
 assert 'Delivery contract: mode=no-mistakes pr=manual' in body
 assert '--skip=pr,ci' in body or '--skip pr,ci' in body
 assert 'evidence' in body.lower()
 bad=run(['bin/fm-brief.sh','bad-manual','demo','--mode','local-only','--pr','manual'],check=False); assert bad.returncode!=0
 (home/'data/projects.md').write_text('- demo [direct-PR pr=manual] - invalid posture\n')
 bad=run(['bin/fm-project-mode.sh','--pr','demo'],check=False);assert bad.returncode==3
 (home/'data/projects.md').write_text('- demo [local-only] - disposable project (added 2026-01-01)\n')
 # Real linked git worktree with a deliberately hidden, untracked user file.
 env['TREEHOUSE_ROOT']=str(LAB/'pool')
 wt=p.Path(run(['treehouse','get','--lease','--no-fetch','--base','main','--branch','fm/hidden'],project).stdout.strip().splitlines()[-1])
 run(['git','config','status.showUntrackedFiles','no'],wt)
 (wt/'new directory').mkdir(); hidden=wt/'new directory/newfile.txt'; hidden.write_text('unadded work must survive\n')
 assert run(['git','status','--porcelain'],wt).stdout==''
 socketdir=run(['bin/fm-lab-home.sh','tmux-dir',home]).stdout.strip()
 env['TMUX_TMPDIR']=socketdir
 run(['tmux','-L','fm-lab','-f','/dev/null','new-session','-d','-s','firstmate','-n','fm-hidden','-c',wt])
 env['TMUX']=f'{socketdir}/tmux-{os.getuid()}/fm-lab,0,0'
 meta=home/'state/hidden.meta'; meta.write_text(f'window=firstmate:fm-hidden\nendpoint_task_id=hidden\nworktree={wt}\nproject={project}\nkind=ship\nmode=local-only\nspawn_gen=live-hidden\n')
 before=meta.read_bytes(); head=run(['git','rev-parse','HEAD'],wt).stdout
 dirty=run(['bin/fm-teardown.sh','hidden'],check=False)
 assert dirty.returncode!=0 and 'uncommitted changes' in dirty.stdout and 'new directory/newfile.txt' in dirty.stdout
 assert meta.read_bytes()==before and hidden.read_text()=='unadded work must survive\n'
 assert run(['git','rev-parse','HEAD'],wt).stdout==head
 hidden.unlink(); hidden.parent.rmdir()
 clean=run(['bin/fm-teardown.sh','hidden'])
 assert not meta.exists()
 run(['treehouse','status','--json'],project)
 # Healthy remote delta-reader public protocol: source bytes, exact new offset and unchanged log.
 replies=home/'state/parent-replies.status'; replies.write_text('done: disposable remote reply\n')
 delta=run(['bin/fm-remote-delta-read.sh','state/parent-replies.status','0',hashlib.sha256(b'').hexdigest(),'1'])
 assert 'status=delta' in delta.stdout
 assert replies.read_text()=='done: disposable remote reply\n'
 # A real failed SSH connection must not leak a non-schema capture or advance a cursor.
 (home/'data/secondmates.md').write_text(f'- offline - isolated failure (host: 127.0.0.1; root: {ROOT}; home: {home}; scope: test; projects: demo; added 2026-01-01)\n')
 failed=run(['bin/fm-procevent-remote-reply.sh','source','offline'],check=False)
 assert failed.returncode!=0
 # SSH stderr is diagnostic; no source capture bytes were emitted on stdout (checked separately below).
 e=env.copy();r=sp.run([str(ROOT/'bin/fm-procevent-remote-reply.sh'),'source','offline'],env=e,stdout=sp.PIPE,stderr=sp.PIPE,timeout=25)
 assert r.returncode!=0 and r.stdout==b''
 assert not (home/'state/remote-replies/offline.cursor').exists()
 log.append('Failed SSH source: stdout_bytes=0; exit='+str(r.returncode)+'; no remote cursor published\n')
 # Execute a local SystemOne provider over a real loopback socket with rule-driven decisions.
 class Provider(http.server.BaseHTTPRequestHandler):
  calls=[]
  def do_POST(self):
   q=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
   self.calls.append({'path':self.path,'body':q,'authorization':bool(self.headers.get('Authorization'))})
   criteria=q['questions']['rule']['criteria']; key='rule_1' if 'pager' in json.dumps(q['state']).lower() else 'default'
   response={'model':q['model'],'answers':{'rule':{'type':'choice','choice':key,'confidence':1,'probabilities':{k:float(k==key) for k in criteria}}},'usage':{'input_tokens':1,'output_tokens':1}}
   b=json.dumps(response).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(b)
  def log_message(self,*a):pass
 server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Provider);threading.Thread(target=server.serve_forever,daemon=True).start()
 try:
  (home/'config/crew-dispatch.json').write_text(json.dumps({'rules':[{'when':'A pager fix','use':{'harness':'claude','model':'sonnet'}}],'default':{'harness':'claude','model':'sonnet'}}))
  prompt=LAB/'pager.md';prompt.write_text("# Task\n## Captain's intent\nFix pager.\n## Firstmate spec\nCorrect page boundaries.\n")
  ex={'FM_DISPATCH_PROVIDER':'systemone','FM_DISPATCH_MODEL':'local-router','FM_DISPATCH_BASE_URL':f'http://127.0.0.1:{server.server_port}'}
  decision=run(['bin/fm-dispatch-resolve.sh',prompt],extra=ex)
  (E/'systemone-http-exchange.json').write_text(json.dumps(Provider.calls,indent=2))
  assert 'status: clear' in decision.stdout and "--harness 'claude'" in decision.stdout
  assert len(Provider.calls)==1 and not Provider.calls[0]['authorization']
  (home/'config/dispatch-never-send').write_text('pager\n')
  guard=run(['bin/fm-dispatch-resolve.sh',prompt],extra=ex)
  assert 'never-send' in guard.stdout and len(Provider.calls)==1
  log.append('Privacy boundary: provider request count remained 1 after denied dispatch.\n')
 finally: server.shutdown(); server.server_close()
finally:
 if socketdir:
  run(['tmux','-L','fm-lab','kill-server'],check=False)
  run(['bin/fm-lab-home.sh','teardown',home],check=False)
 (E/'product-cli-transcript.log').write_text('\n'.join(log))
 for attempt in range(3):
  try: shutil.rmtree(LAB); break
  except OSError:
   import time; time.sleep(1)
