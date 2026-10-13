#!/usr/bin/env python3
"""Run real Firstmate PR CLIs/curl/tea against a private, stateful API service.
No CLI under test is mocked. This is NOT a validation of Atlassian's hosted API.
"""
import base64, http.server, json, os, pathlib, shutil, socketserver, ssl, subprocess, threading, urllib.parse
ROOT = pathlib.Path.cwd()
WORK = ROOT / '.validation'
EVIDENCE = pathlib.Path('/home/node/.no-mistakes/evidence/01M4S89G4MJKH7FQ650DXKN8MF')
EVIDENCE.mkdir(parents=True, exist_ok=True)
requests, transcript, results = [], [], []
state = {}
base_env = os.environ.copy()
for key in list(base_env):
    if key.startswith('FM_') or key.startswith('NO_MISTAKES_BITBUCKET_') or key in ('TMUX','TASKS_AXI_FILE','TASKS_AXI_BACKEND'):
        base_env.pop(key, None)
base_env.update(HOME=str(WORK/'live-user'), XDG_CONFIG_HOME=str(WORK/'live-user/config'), TMPDIR=str(WORK/'tmp'),
                PATH=str(WORK/'tools')+':'+os.environ['PATH'], GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1',
                GIT_AUTHOR_NAME='PR lab', GIT_AUTHOR_EMAIL='pr-lab@example.invalid', GIT_COMMITTER_NAME='PR lab', GIT_COMMITTER_EMAIL='pr-lab@example.invalid',
                NO_MISTAKES_BITBUCKET_EMAIL='lab@example.invalid', NO_MISTAKES_BITBUCKET_API_TOKEN='fixture"token\\only',
                FM_PR_BITBUCKET_CONFIRM_ATTEMPTS='2', FM_PR_BITBUCKET_CONFIRM_INTERVAL='0')
pathlib.Path(base_env['HOME']).mkdir(parents=True, exist_ok=True)

def command(args, env=None, expected=None):
    p = subprocess.run(list(map(str,args)), cwd=ROOT, env=env or base_env, text=True, capture_output=True, timeout=35)
    transcript.append('$ '+ ' '.join(map(str,args)).replace(str(ROOT)+'/', '')+'\n'+p.stdout+p.stderr+'[exit '+str(p.returncode)+']\n')
    if expected is not None:
        assert p.returncode == expected, (args, p.returncode, p.stdout, p.stderr)
    return p

def git(repo, *args):
    return command(['git','-C',repo,*args], expected=0).stdout.strip()

repo = WORK/'api-repo'
origin = WORK/'local-origin.git'
for path in (repo, origin, pathlib.Path(base_env['HOME'])):
    if path.exists(): shutil.rmtree(path)
pathlib.Path(base_env['HOME']).mkdir(parents=True)
repo.mkdir(exist_ok=True)
git(repo,'init','-b','main')
(repo/'example.txt').write_text('base\n')
git(repo,'add','.'); git(repo,'commit','-m','fixture base')
BASE=git(repo,'rev-parse','HEAD')
git(repo,'checkout','-b','feature')
(repo/'example.txt').write_text('base\nBitbucket feature\n')
git(repo,'add','.'); git(repo,'commit','-m','fixture feature')
HEAD=git(repo,'rev-parse','HEAD')
git(repo,'checkout','-b','alternative')
(repo/'example.txt').write_text('base\nBitbucket feature\nunverified addition\n')
git(repo,'add','.'); git(repo,'commit','-m','fixture moved head')
OTHER=git(repo,'rev-parse','HEAD')
git(repo,'checkout','main')
command(['git','init','--bare',origin],expected=0)
git(repo,'remote','add','origin',str(origin))
git(repo,'push','origin','main','feature','alternative')

def reset(**extra):
    state.clear()
    state.update(provider='bitbucket', pr_state='OPEN', draft=False, head=HEAD, pr_reads=0,
                 statuses=[{'key':'pipeline','name':'Lab pipeline','state':'SUCCESSFUL'}],
                 participants=[], restrictions=[], tasks=[], mode='normal', merged=False,
                 status_code=200, record_id=7)
    state.update(extra)

def pr_record():
    return {'type':'pullrequest','id':state['record_id'],'state':state['pr_state'],'draft':state['draft'],
            'source':{'commit':{'hash':state['head'][:12]},'branch':{'name':'feature'}},
            'destination':{'branch':{'name':'main'}},'participants':state['participants']}

class API(http.server.BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def log_message(self,*a): pass
    def respond(self,code,body):
        payload=json.dumps(body).encode()
        self.send_response(code); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(payload))); self.send_header('Connection','close'); self.end_headers(); self.wfile.write(payload)
        self.close_connection=True
    def do_CONNECT(self):
        # The only host this proxy can serve; no upstream forwarding or DNS edits.
        if self.path != 'api.bitbucket.org:443':
            self.respond(403,{'error':'private proxy refuses non-lab destinations'}); return
        self.send_response(200,'Connection established'); self.end_headers()
        self.connection=tls.wrap_socket(self.connection,server_side=True)
        self.rfile=self.connection.makefile('rb'); self.wfile=self.connection.makefile('wb')
        self.close_connection=False
    def do_GET(self): self.dispatch('GET')
    def do_POST(self): self.dispatch('POST')
    def dispatch(self,method):
        url=urllib.parse.urlsplit(self.path)
        path=url.path; query=urllib.parse.parse_qs(url.query)
        body=self.rfile.read(int(self.headers.get('Content-Length','0')))
        data=json.loads(body) if body else None
        expected='Basic '+base64.b64encode(b'lab@example.invalid:fixture"token\\only').decode()
        authorized=(self.headers.get('Authorization')==expected if path.startswith('/2.0/') else self.headers.get('Authorization') in ('token lab-forgejo-token','Bearer lab-forgejo-token'))
        row={'scenario':state.get('scenario','setup'),'method':method,'path':path,'query':query,'body':data,'authenticated_with_disposable_credential':authorized}
        requests.append(row)
        if not authorized:
            self.respond(401,{'error':{'message':'fixture authentication failed'}}); return
        if path.startswith('/api/v1/'):
            self.forgejo(method,path,data,row); return
        if path.endswith('/pullrequests/7'):
            if state['status_code'] != 200:
                self.respond(state['status_code'],{'error':{'message':'fixture lookup failure'}}); return
            if 'fields' not in query:
                state['pr_reads']+=1
                if state['pr_reads']>=3 and state['mode']=='move-before-submit': state['head']=OTHER
                if state['pr_reads']>=3 and state['mode']=='final-read-unavailable':
                    self.respond(503,{'error':{'message':'fixture final read unavailable'}}); return
            self.respond(200,pr_record()); return
        if '/commit/' in path and not path.endswith('/statuses'):
            abbrev=path.rsplit('/',1)[1]
            match=next((h for h in (HEAD,OTHER) if h.startswith(abbrev)),None)
            self.respond(200 if match else 404,{'hash':match}); return
        if path.endswith('/statuses'):
            if state['mode']=='foreign-next':
                self.respond(200,{'values':[],'next':'https://credential-trap.invalid/steal'}); return
            self.respond(200,{'values':state['statuses']}); return
        if path.endswith('/branch-restrictions'):
            self.respond(200,{'values':state['restrictions']}); return
        if path.endswith('/effective-default-reviewers'):
            self.respond(200,{'values':[]}); return
        if path.endswith('/tasks'):
            self.respond(200,{'values':state['tasks']}); return
        if method=='POST' and path.endswith('/pullrequests/7/merge'):
            if state['mode']=='reject-merge':
                self.respond(409,{'error':{'message':'private fixture refuses conflicting merge'}}); return
            if state['mode']=='mismatch-after-submit': state['head']=OTHER
            state['pr_state']='MERGED'; state['merged']=True
            if state['mode']=='normal':
                git(repo,'merge','--squash','feature'); git(repo,'commit','-m','fixture backend squash merge')
            self.respond(200,pr_record()); return
        self.respond(404,{'error':{'message':'unhandled private route '+path}})
    def forgejo(self,method,path,data,row):
        if path=='/api/v1/user': self.respond(200,{'id':1,'login':'lab','full_name':'Fixture user'}); return
        if path=='/api/v1/version': self.respond(200,{'version':'1.24.0'}); return
        if path.endswith('/pulls/7/merge') and method=='POST':
            if state['mode']=='move-before-submit': state['head']=OTHER
            if data.get('head_commit_id')!=state['head']:
                self.respond(409,{'message':'head out of date'}); return
            state['merged']=True
            self.respond(200,{}); return
        if path.endswith('/pulls/7'):
            self.respond(200,{'number':7,'state':'closed' if state['merged'] else 'open','title':'Lab pull request',
                             'draft':False,'merged':state['merged'],'mergeable':not state['merged'],
                             'head':{'sha':state['head']},'base':{'ref':'main'}}); return
        if path.endswith('/status'):
            page=urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query).get('page',['1'])[0]
            statuses=[{'context':'pipeline','state':'success'}] if page=='1' else []
            self.respond(200,{'state':'success','total_count':1,'statuses':statuses}); return
        if path.endswith('/repos/lab/repo'):
            self.respond(200,{'id':1,'default_merge_style':'squash','default_branch':'main'}); return
        self.respond(404,{'message':'unhandled forgejo route '+path})

class Server(socketserver.ThreadingMixIn,http.server.HTTPServer):
    daemon_threads=True

tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
tls.load_cert_chain(WORK/'tls/cert.pem',WORK/'tls/key.pem')
server=Server(('127.0.0.1',0),API)
port=server.server_port
thread=threading.Thread(target=server.serve_forever,daemon=True); thread.start()
base_env.update(HTTPS_PROXY=f'http://127.0.0.1:{port}', HTTP_PROXY=f'http://127.0.0.1:{port}',
                https_proxy=f'http://127.0.0.1:{port}', http_proxy=f'http://127.0.0.1:{port}', ALL_PROXY='', all_proxy='', NO_PROXY='', no_proxy='',
                CURL_CA_BUNDLE=str(WORK/'tls/cert.pem'))
BB='https://bitbucket.org/lab/repo/pull-requests/7'
FJ='https://forgejo.test/lab/repo/pulls/7'

homes=[]
def new_home(label):
    home=WORK/('lab-'+label)
    command([ROOT/'bin/fm-lab-home.sh','create',home],expected=0)
    homes.append(home)
    (home/'.tasks.toml').write_text((ROOT/'.tasks.toml').read_text())
    (home/'data/backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
    (home/'state/task-x1.meta').write_text(f'window=lab-task-x1\nworktree={repo}\nproject={repo}\nkind=ship\nmode=no-mistakes\n')
    env=base_env.copy(); env['FM_HOME']=str(home)
    return home,env

def run_scenario(name, fn):
    transcript.append('\n=== '+name+' ===\n')
    start=len(requests)
    try:
        fn()
        result={'name':name,'result':'pass','live':True,'evidence':'live-pr-transcript.log; live-pr-http.jsonl','reason':'Real repository CLI and transport executed against a disposable stateful API service, not a hosted forge.'}
    except Exception as e:
        transcript.append('SCENARIO ERROR: '+repr(e)+'\n')
        result={'name':name,'result':'fail','live':True,'evidence':'live-pr-transcript.log; live-pr-http.jsonl','reason':repr(e)}
    result['request_count']=len(requests)-start
    results.append(result)

def register():
    reset(scenario='registration'); home,env=new_home('register')
    p=command([ROOT/'bin/fm-pr-check.sh','task-x1',BB],env,0)
    assert 'armed:' in p.stdout
    meta=(home/'state/task-x1.meta').read_text()
    transcript.append('Persisted task metadata contract:\n'+meta)
    assert f'pr_head={HEAD}' in meta and f'pr={BB}' in meta
    assert (home/'state/task-x1.pr-poll').read_text().splitlines()[0]=='bitbucket'
    assert (home/'state/task-x1.check.sh').stat().st_mode & 0o777 == 0o600
    assert 'fixture' not in meta

def auth_and_draft():
    reset(scenario='auth-boundary'); home,env=new_home('auth')
    pathlib.Path(env['HOME'],'.curlrc').write_text('user = "ambient:must-not-be-used"\n')
    env.pop('NO_MISTAKES_BITBUCKET_API_TOKEN')
    before=len(requests)
    p=command([ROOT/'bin/fm-pr-check.sh','task-x1',BB],env,1)
    assert 'environment variable' in p.stderr and len(requests)==before
    assert not (home/'state/task-x1.check.sh').exists()
    p=command([ROOT/'bin/fm-pr-check.sh','task-x1',BB+'?redirect=evil'],env,2)
    assert len(requests)==before
    reset(scenario='draft-boundary',draft=True)
    home,env=new_home('draft')
    p=command([ROOT/'bin/fm-pr-check.sh','task-x1',BB],env,1)
    assert 'is a draft' in p.stderr and 'pr=' not in (home/'state/task-x1.meta').read_text()
    assert not (home/'state/task-x1.check.sh').exists()

def blockers():
    reset(scenario='state-blockers',statuses=[{'key':'pipeline','state':'FAILED'}],participants=[{'state':'changes_requested','user':{'nickname':'reviewer'}}])
    p=command([ROOT/'bin/fm-pr-state.sh',BB],expected=0)
    assert 'CHECK: pipeline (FAILED)' in p.stdout and 'REVIEW: reviewer CHANGES_REQUESTED' in p.stdout
    reset(scenario='state-clean')
    assert command([ROOT/'bin/fm-pr-state.sh',BB],expected=0).stdout==''
    reset(scenario='state-terminal',pr_state='DECLINED')
    assert command([ROOT/'bin/fm-pr-state.sh',BB],expected=0).stdout.strip()=='STATE: declined'
    reset(scenario='foreign-pagination',mode='foreign-next')
    p=command([ROOT/'bin/fm-pr-state.sh',BB],expected=2)
    assert 'could not read the builds' in p.stderr
    assert all('credential-trap' not in r['path'] for r in requests)

def poll():
    reset(scenario='poll'); home,env=new_home('poll')
    command([ROOT/'bin/fm-pr-check.sh','task-x1',BB],env,0)
    script=home/'state/task-x1.check.sh'
    assert command(['bash',script],env,0).stdout==''
    state['pr_state']='MERGED'
    assert command(['bash',script],env,0).stdout.strip()=='merged'
    state['record_id']=8
    assert command(['bash',script],env,0).stdout==''
    state['record_id']=7; state['status_code']=500
    assert command(['bash',script],env,0).stdout==''
    env.pop('NO_MISTAKES_BITBUCKET_API_TOKEN')
    assert command(['bash',script],env,0).stdout==''

def review_diff():
    reset(scenario='review-live-head'); home,env=new_home('review')
    with (home/'state/task-x1.meta').open('a') as f:
        f.write(f'pr={BB}\npr_head={OTHER}\n')
    p=command([ROOT/'bin/fm-review-diff.sh','task-x1'],env,0)
    assert '+Bitbucket feature' in p.stdout and '+unverified addition' not in p.stdout
    assert 'falling back' not in p.stderr
    state['status_code']=503
    p=command([ROOT/'bin/fm-review-diff.sh','task-x1'],env,0)
    assert '+unverified addition' in p.stdout and 'falling back to its recorded pr_head' in p.stderr

def merge():
    reset(scenario='merge-success'); home,env=new_home('merge')
    p=command([ROOT/'bin/fm-pr-merge.sh','task-x1',BB,'--','--squash'],env,0)
    assert 'is merged at the verified head '+HEAD in p.stdout
    posts=[r for r in requests if r['scenario']=='merge-success' and r['method']=='POST']
    assert len(posts)==1 and posts[0]['body']=={'type':'pullrequest','close_source_branch':False,'merge_strategy':'squash'}
    wake=(home/'state/.wake-queue').read_text()
    transcript.append('Durable landed wake contract:\n'+wake)
    assert 'merge landed: task-x1 '+BB in wake
    assert git(repo,'rev-parse','main^{tree}')==git(repo,'rev-parse','feature^{tree}')
    assert git(repo,'rev-parse','feature')==HEAD
    transcript.append('Destination tree equals feature tree; source branch retained.\n')

def refusal():
    reset(scenario='merge-check-refusal',statuses=[{'key':'pipeline','state':'FAILED'}],
          restrictions=[{'kind':'require_passing_builds_to_merge','branch_match_kind':'glob','pattern':'main','value':2},
                        {'kind':'require_approvals_to_merge','branch_match_kind':'glob','pattern':'main','value':1},
                        {'kind':'require_tasks_to_be_completed','branch_match_kind':'glob','pattern':'main'}],
          tasks=[{'id':1,'state':'UNRESOLVED'}])
    home,env=new_home('refusal')
    p=command([ROOT/'bin/fm-pr-merge.sh','task-x1',BB],env,1)
    for text in ('not SUCCESSFUL','requires 2 successful builds','requires 1 approvals','1 are unresolved'): assert text in p.stderr,text
    assert not any(r['method']=='POST' and r['scenario']=='merge-check-refusal' for r in requests)
    assert not (home/'state/.wake-queue').exists()

def head_guard():
    for mode in ('move-before-submit','final-read-unavailable'):
        reset(scenario=mode,mode=mode); home,env=new_home(mode)
        p=command([ROOT/'bin/fm-pr-merge.sh','task-x1',BB],env,1)
        assert 'nothing was merged' in p.stderr
        assert not any(r['method']=='POST' and r['scenario']==mode for r in requests)
        assert not (home/'state/.wake-queue').exists()

def containment():
    reset(scenario='mismatch-after-submit',mode='mismatch-after-submit'); home,env=new_home('mismatch')
    p=command([ROOT/'bin/fm-pr-merge.sh','task-x1',BB],env,1)
    assert 'landed commits were never verified' in p.stderr and 'no landed outcome is recorded' in p.stderr
    assert state['merged'] and state['head']==OTHER
    assert not (home/'state/.wake-queue').exists()
    assert (home/'state/task-x1.check.sh').exists()
    transcript.append('Accepted containment: merged API record has changed head; CLI refuses a clean landing. This does NOT close the accepted post-read race.\n')

def forgejo():
    git(repo,'checkout','feature')
    reset(scenario='forgejo-setup',provider='forgejo')
    command([WORK/'tools/tea','login','add','--name','lab','--url',f'http://forgejo.test:{port}','--token','lab-forgejo-token','--no-version-check'],expected=0)
    command([WORK/'tools/tea','login','list','--output','json'],expected=0)
    reset(scenario='forgejo-success',provider='forgejo'); home,env=new_home('forgejo')
    command([ROOT/'bin/fm-pr-check.sh','task-x1',FJ],env,0)
    assert command(['bash',home/'state/task-x1.check.sh'],env,0).stdout==''
    command([ROOT/'bin/fm-pr-merge.sh','task-x1',FJ,'--','--squash'],env,0)
    assert state['merged']
    body=next(r['body'] for r in requests if r['scenario']=='forgejo-success' and r['method']=='POST')
    assert body['head_commit_id']==HEAD and body['Do']=='squash'
    assert 'merge landed:' in (home/'state/.wake-queue').read_text()
    assert command(['bash',home/'state/task-x1.check.sh'],env,0).stdout.strip()=='merged'
    reset(scenario='forgejo-head-race',provider='forgejo',mode='move-before-submit'); home,env=new_home('forgejo-race')
    p=command([ROOT/'bin/fm-pr-merge.sh','task-x1',FJ,'--','--squash'],env,1)
    assert 'head out of date' in p.stderr and not state['merged']
    assert not (home/'state/.wake-queue').exists()

try:
    run_scenario('Register a Bitbucket PR and persist its resolved head and private watch',register)
    run_scenario('Refuse missing environment credentials, malformed URLs, and drafts before arming',auth_and_draft)
    run_scenario('Report Bitbucket blockers and terminal state; refuse off-host pagination',blockers)
    run_scenario('Run the persisted poll: wake only for the exact merged PR, never errors',poll)
    run_scenario('Review the live Bitbucket head over stale metadata; warn on recorded-head fallback',review_diff)
    run_scenario('Merge a green Bitbucket PR with squash and publish a durable landed wake',merge)
    run_scenario('Refuse failed builds, insufficient approvals, and unresolved tasks without POST',refusal)
    run_scenario('Refuse a changed or unreadable head at the final pre-submit read',head_guard)
    run_scenario('Detect a landed-head mismatch without reporting a clean landing (accepted containment)',containment)
    run_scenario('Register, poll, and merge Forgejo with real tea; preserve expected-head binding',forgejo)
finally:
    server.shutdown(); server.server_close(); thread.join(timeout=3)
    (EVIDENCE/'live-pr-transcript.log').write_text('Real Firstmate CLI / curl / tea; disposable TLS API service only. No hosted forge or operator fleet used.\n'+''.join(transcript))
    (EVIDENCE/'live-pr-http.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in requests))
    (EVIDENCE/'live-pr-scenarios.json').write_text(json.dumps(results,indent=2)+'\n')
    for result in results: print(result['result']+': '+result['name']+' '+result['reason'])
    import shutil
    for home in homes: shutil.rmtree(home)
if any(r['result']=='fail' for r in results): raise SystemExit(1)
