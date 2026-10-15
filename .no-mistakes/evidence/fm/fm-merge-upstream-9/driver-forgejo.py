import os, sys, pathlib, subprocess, socket, time, json, urllib.request, urllib.error, base64, shutil
R=pathlib.Path.cwd(); D=R/'.live-test-lab/forge'; E=pathlib.Path('/home/node/.no-mistakes/evidence/01M4ZWHVKH10H7VQ0P4VH5RD51'); D.mkdir(parents=True,exist_ok=True)
H=D/'home'; H.mkdir(exist_ok=True); F=D/'fm'; F.mkdir(exist_ok=True)
env={'PATH':str(R/'.live-test-lab/tools')+':'+os.environ['PATH'],'HOME':str(H),'TMPDIR':str(R/'.live-test-lab/tmp'),'USER':'node','LOGNAME':'node','LANG':'C.UTF-8','GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':str(H/'.gitconfig'),'FM_HOME':str(F),'NO_MISTAKES_GATE':'1'}
log=open(E/'forgejo-live.log','w',buffering=1)
def run(args, ok=True, cwd=R, record=True):
 p=subprocess.run([str(a) for a in args],env=env,cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=45)
 if record: log.write('$ '+' '.join(str(a) for a in args)+'\n'+p.stdout+'exit='+str(p.returncode)+'\n')
 if ok and p.returncode: raise RuntimeError(p.stdout)
 return p
run(['bin/fm-lab-home.sh','create',F])
s=socket.socket();s.bind(('127.0.0.1',0));port=s.getsockname()[1];s.close(); base=f'http://localhost:{port}'
ini=D/'app.ini'; ini.write_text(f'''APP_NAME = Disposable Firstmate Test Forge
RUN_MODE = prod
[server]
HTTP_ADDR = 127.0.0.1
HTTP_PORT = {port}
ROOT_URL = {base}/
DISABLE_SSH = true
OFFLINE_MODE = true
[database]
DB_TYPE = sqlite3
PATH = {D}/forge.db
[repository]
ROOT = {D}/repos
DEFAULT_BRANCH = main
[security]
INSTALL_LOCK = true
SECRET_KEY = disposable-test-key
[service]
DISABLE_REGISTRATION = true
[log]
MODE = console
LEVEL = Warn
''')
forge=R/'.live-test-lab/tools/forgejo'; common=[forge,'--work-path',D,'--config',ini]
run(common+['migrate'])
run(common+['admin','user','create','--username','fixture','--password','disposable-password-1234','--email','fixture@example.invalid','--admin','--must-change-password=false'],record=False)
token=run(common+['admin','user','generate-access-token','--username','fixture','--token-name','disposable-live','--scopes','all','--raw'],record=False).stdout.strip().splitlines()[-1]
serverlog=open(E/'forgejo-server.log','w');server=subprocess.Popen([str(a) for a in common+['web']],env=env,stdout=serverlog,stderr=subprocess.STDOUT)
def api(method,path,data=None, expected=(200,201,204)):
 req=urllib.request.Request(base+'/api/v1/'+path, data=None if data is None else json.dumps(data).encode(),method=method,headers={'Authorization':'token '+token,'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=10) as r: code=r.status; body=r.read().decode()
 except urllib.error.HTTPError as e: code=e.code;body=e.read().decode()
 if code not in expected:raise RuntimeError(f'{method} {path}: {code} {body}')
 return json.loads(body) if body else None
try:
 for _ in range(100):
  try:
   urllib.request.urlopen(base+'/api/v1/version',timeout=1).close();break
  except Exception:time.sleep(.2)
 else:raise RuntimeError('Forgejo did not start')
 log.write('Runtime: '+run([forge,'--version'],record=False).stdout+'Runtime: '+run(['tea','--version'],record=False).stdout)
 api('POST','user/repos',{'name':'fixture-repo','auto_init':True,'default_branch':'main','private':False})
 repo='repos/fixture/fixture-repo'
 api('POST',repo+'/contents/change.txt',{'branch':'main','new_branch':'candidate','content':base64.b64encode(b'candidate change\n').decode(),'message':'Candidate fixture change'})
 pr=api('POST',repo+'/pulls',{'head':'candidate','base':'main','title':'Disposable upstream catch-up candidate','body':'Must remain unmerged until checks are green.'})
 sha=pr['head']['sha']; n=pr['number']; url=f'https://localhost/fixture/fixture-repo/pulls/{n}'
 # This is a disposable login in a worktree-local HOME, never operator credentials.
 run(['tea','login','add','--name','local-fixture','--url',base,'--token',token,'--no-version-check'],record=False)
 log.write('Disposable tea login: localhost-only instance, worktree-local HOME.\n')
 wt=D/'worktree'
 run(['git','clone','--quiet','--branch','candidate',base+'/fixture/fixture-repo.git',wt])
 for task in ['forge-live','ambiguous-login']:
  meta=F/'state'/f'{task}.meta'
  meta.write_text(f'window=fm-{task}\nworktree={wt}\nproject={wt}\nkind=ship\nmode=direct-PR\n')
  meta.chmod(0o600)
 run(['bin/fm-pr-check.sh','forge-live',url])
 run(['bash',F/'state/forge-live.check.sh'])
 api('POST',repo+'/statuses/'+sha,{'state':'failure','context':'fixture-ci','description':'Intentional adversarial red check'})
 red=run(['bin/fm-pr-merge.sh','forge-live',url],ok=False)
 assert red.returncode!=0, 'Red CI unexpectedly permitted a merge'
 before=api('GET',repo+f'/pulls/{n}');assert before['state']=='open' and not before['merged']
 log.write('Persisted API result after refusal: '+json.dumps({k:before[k] for k in ('number','state','merged')})+'\n')
 api('POST',repo+'/statuses/'+sha,{'state':'success','context':'fixture-ci','description':'Disposable check is green'})
 green=run(['bin/fm-pr-merge.sh','forge-live',url]); after=api('GET',repo+f'/pulls/{n}')
 assert after['merged'] is True and after['state']=='closed'
 merge_sha=after['merge_commit_sha']; commit=api('GET',repo+'/git/commits/'+merge_sha)
 log.write('Merged API result: '+json.dumps({k:after[k] for k in ('number','state','merged','merge_commit_sha')})+'\n')
 log.write('Merge commit parents: '+json.dumps([p['sha'] for p in commit['parents']])+'\n')
 assert len(commit['parents'])==2, 'Disposable default-style merge did not preserve both parents'
 run(['bash',F/'state/forge-live.check.sh'],ok=False)
 log.write('Durable wake queue:\n'+(F/'state/.wake-queue').read_text())
 # A second same-host login is deliberately ambiguous and must refuse before arming.
 token2=run(common+['admin','user','generate-access-token','--username','fixture','--token-name','duplicate-live','--scopes','all','--raw'],record=False).stdout.strip().splitlines()[-1]
 run(['tea','login','add','--name','duplicate-local','--url',base,'--token',token2,'--no-version-check'],record=False)
 ambiguous=run(['bin/fm-pr-check.sh','ambiguous-login',url],ok=False)
 assert ambiguous.returncode!=0 and not (F/'state/ambiguous-login.check.sh').exists()
 log.write('Live assertions: red CI stayed open; green CI merged with two parents; durable wake recorded; ambiguous login refused without arming.\n')
finally:
 server.terminate()
 try:server.wait(timeout=10)
 except subprocess.TimeoutExpired:server.kill();server.wait()
 serverlog.close(); log.write('Disposable Forgejo server stopped; fixture data removed.\n'); log.close(); shutil.rmtree(D)
