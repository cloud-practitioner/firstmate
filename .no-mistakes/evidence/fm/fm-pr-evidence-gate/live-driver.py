import os, sys, json, subprocess, threading, http.server, shlex, pathlib, re, copy, html, time, shutil
ROOT = pathlib.Path.cwd()
LAB = ROOT / '.test-evidence-lab'
E = pathlib.Path('/home/node/.no-mistakes/evidence/01M5K1MGANF7V1TVEJY6VCTM5Y')
EV = ROOT / 'bin/fm-pr-evidence.sh'
LIB = ROOT / 'bin/fm-pr-evidence-lib.py'
home = LAB / 'home'
proj = LAB / 'project'
for d in (home/'config', home/'state', home/'data', proj): d.mkdir(parents=True, exist_ok=True)
env = dict(os.environ)
for k in tuple(env):
    if k.startswith('FM_') or k in ('GH_TOKEN','GITHUB_TOKEN','NO_MISTAKES_BITBUCKET_EMAIL','NO_MISTAKES_BITBUCKET_API_TOKEN','TASKS_AXI_FILE','TASKS_AXI_BACKEND'): env.pop(k)
env.update(FM_HOME=str(home), GH_CONFIG_DIR=str(home/'gh-isolated'), TMPDIR=str(LAB/'tmp'), PYTHONDONTWRITEBYTECODE='1', GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_SYSTEM='/dev/null', GIT_TERMINAL_PROMPT='0')
log = (E/'live-cli-transcript.log').open('w')
results = []
def run(args, rc=0, contains=None, title=None):
    args = list(map(str,args))
    log.write('\n$ '+shlex.join(args)+'\n'); log.flush()
    p = subprocess.run(args, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
    log.write(p.stdout + '\n[exit %s]\n'%p.returncode); log.flush()
    assert p.returncode == rc, (title,args,p.returncode,p.stdout)
    if contains is not None: assert contains in p.stdout, (title,contains,p.stdout)
    return p.stdout

def result(name):
    results.append(name); print('LIVE PASS: '+name, flush=True)
    (E/'live-results.json').write_text(json.dumps(results,indent=2))

run(['git','-C',proj,'init','-q'])
run(['git','-C',proj,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','--allow-empty','-qm','Disposable evidence lab'])
if not subprocess.run(['git','-C',str(proj),'remote','get-url','origin'],env=env,capture_output=True).returncode:
    run(['git','-C',proj,'remote','set-url','origin','https://github.com/disposable/example.git'])
else:
    run(['git','-C',proj,'remote','add','origin','https://github.com/disposable/example.git'])
(home/'config/pr-evidence').write_text('* enforce\nproject ui web/*.jsx\nproject api srv/*.py\n')
brief = LAB/'brief.md'
def intake(value, rc=0, contains=None, directory=proj):
    brief.write_text('# Task\n## Evidence class\n'+value+'\n\n# Definition of done\nDone.\n')
    return run([EV,'intake',brief,'project','direct-PR','none',directory],rc,contains)
intake('{EVIDENCE}',1,'not filled')
intake('ui',0,'evidence=ui')
intake('ui+api',0,'evidence=ui+api')
intake('none:',1,'no reason')
intake('none: Only a comment changed.',0,'evidence_reason=Only a comment changed.')
intake('none: Only a comment changed.',1,'none is not allowed',directory=ROOT)
run([EV,'eligible','project','direct-PR','none',proj])
run([EV,'brief-block','live-task','project','direct-PR','none',proj],0,'# Evidence for review (hard rule)')
(home/'config/pr-evidence').write_text('* enforce\nbogus option\n')
run([EV,'eligible','project','direct-PR','none',proj],2,'config/pr-evidence is not valid')
(home/'config/pr-evidence').write_text('* enforce\nproject ui web/*.jsx\nproject api srv/*.py\n')
intake('api',0,'evidence=api')
result('Intake refuses missing declarations, rejects bad configuration, persists kinds, and disallows none for Firstmate')

bad = [('', 'empty'), ('The tool prints text; the user reads it.','semicolon'), ("The tool isn’t ready.",'contraction'), ('The tool prints e.g. a name.','abbreviation'), ('The tool prints text — now.','long dash'), ('The tool is seamless.','banned word'), (' '.join(['word']*26)+'.','maximum 25'), ('One small sentence. Two small sentences. Three small sentences. Four small sentences.','maximum 3')]
for text, expected in bad: run([EV,'ste','--text',text],1,expected)
run([EV,'ste','--kind','steps','--text',' '.join(['word']*21)+'.'],1,'maximum 20')
run([EV,'ste','--kind','label','--text','One label. Two labels.'],1,'maximum 1')
run([EV,'ste','--text','The tool shows the new value.'])
run([EV,'ste','--text','The error was caused by a bad value.'],0,'[WARN]')
result('Plain-English checker refuses strict violations and leaves passive voice as a warning')

for phase, text in [('before','The tool prints text; the user reads it.'),('after','The tool prints the new text.')]:
    run([EV,'capture-ui','--out',E/(phase+'-terminal.txt'),'--',EV,'ste','--text',text],0,'')
for phase, other in [('before','after'),('after','before')]:
    run([EV,'annotate-ui','--text',E/(phase+'-terminal.txt'),'--against',E/(other+'-terminal.txt'),'--purpose','The tool refuses text with a semicolon.','--label','The result changed','--out',E/(phase+'-terminal.png')])
    run(['python3',LIB,'marks',E/(phase+'-terminal.png')])
run([EV,'annotate-ui','--text',E/'after-terminal.txt','--against',E/'after-terminal.txt','--purpose','The tool shows the result.','--out',LAB/'same.png'],1,'no differing lines')
run([EV,'annotate-ui','--image',E/'before-terminal.png','--purpose','The tool shows the result.','--out',LAB/'unmarked.png'],1,'no marks were given')
# Explicit image-annotation path, on the actual generated capture.
run([EV,'annotate-ui','--image',E/'after-terminal.png','--mark','8,108,600,32,The result changed','--purpose','The tool shows the new result.','--out',E/'image-annotation.png'])
# A pure addition still marks context in both phases.
(LAB/'left.txt').write_text('alpha\n')
(LAB/'right.txt').write_text('alpha\nbeta\n')
for a,b in [('left','right'),('right','left')]:
    run([EV,'annotate-ui','--text',LAB/(a+'.txt'),'--against',LAB/(b+'.txt'),'--purpose','The tool shows the added line.','--out',LAB/(a+'.png')])
result('Terminal capture and both annotation paths create marked PNGs; no-difference and no-mark requests refuse')

state = {'phase':'before','calls':[]}
class App(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('Content-Length','0'))
        request = self.rfile.read(n).decode()
        state['calls'].append({'phase':state['phase'],'method':'POST','path':self.path,'body':request,'accept':self.headers.get('Accept'),'auth_received':bool(self.headers.get('Authorization'))})
        code = 422 if state['phase']=='before' else 201
        body = {'result':'rejected' if code==422 else 'saved','password':'fixture-response-value'}
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header('Content-Type','application/json')
        self.send_header('Set-Cookie','session=fixture-cookie')
        self.send_header('Content-Length',str(len(payload)))
        self.end_headers(); self.wfile.write(payload)
    def log_message(self,*a): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1',0),App)
thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
try:
    req = LAB/'request.json'; req.write_text(json.dumps({'name':'sample','password':'fixture-request-value'}))
    url = 'http://127.0.0.1:%s/items'%server.server_port
    for phase in ('before','after'):
        state['phase'] = phase
        run([EV,'capture-api','--out',E/(phase+'-http.json'),'-X','POST','--header','Accept: application/json','--header','Content-Type: application/json','--header','Authorization: Bearer fixture-auth-value','--body-file',req,url])
        data = json.loads((E/(phase+'-http.json')).read_text())
        assert data['request']['method']=='POST' and data['request']['url']==url
        assert data['response']['status']==(422 if phase=='before' else 201)
        assert data['response']['reason'] and data['request']['headers'] and data['request']['body'] and data['response']['headers'] and data['response']['body']
        alltext = json.dumps(data)
        for secret in ('fixture-auth-value','fixture-cookie','fixture-request-value','fixture-response-value'): assert secret not in alltext, secret
        assert 'sample' in data['request']['body']
        run(['python3',LIB,'scan-sidecar',E/(phase+'-http.json')])
    for phase,other in [('before','after'),('after','before')]:
        run([EV,'annotate-api','--sidecar',E/(phase+'-http.json'),'--against',E/(other+'-http.json'),'--purpose','The service saves the item after the change.','--label','The status and result changed','--out',E/(phase+'-http.png')])
        run(['python3',LIB,'marks',E/(phase+'-http.png')])
    broken = json.loads((E/'before-http.json').read_text()); broken['response'].pop('reason')
    (LAB/'broken.json').write_text(json.dumps(broken))
    run([EV,'annotate-api','--sidecar',LAB/'broken.json','--against',E/'after-http.json','--purpose','The service saves the item.','--out',LAB/'broken.png'],1,'status message is missing')
    (E/'http-server-observations.json').write_text(json.dumps(state['calls'],indent=2))
finally:
    server.shutdown(); server.server_close(); thread.join()
result('Real HTTP calls retain all six exchange parts, mask conventional secrets, and render marked before/after images')

items = {'items':[
    {'id':'terminal','kind':'ui','purpose':'The tool refuses text with a semicolon.','labels':['The result changed'],'before':{'image':'before-terminal.png'},'after':{'image':'after-terminal.png'}},
    {'id':'save-item','kind':'api','purpose':'The service saves the item after the change.','labels':['The status and result changed'],'before':{'image':'before-http.png','sidecar':'before-http.json'},'after':{'image':'after-http.png','sidecar':'after-http.json'}}]}
(E/'items.json').write_text(json.dumps(items,indent=2))
head = '9512699506a2e867f9fd2bf9633ea138c3f25320'
compose = ['python3',LIB,'compose','--items',E/'items.json','--head',head,'--declared','ui','--provider','github','--repo','disposable/example','--number','1','--out',E/'composed']
run(compose)
comment = (E/'composed/comment.md').read_text()
manifest = json.loads(re.search(r'```fm-pr-evidence-v1\n(.*?)\n```',comment,re.S).group(1))
assert manifest['kind']=='ui+api' and manifest['head']==head and len(manifest['items'])==2
assert len((E/'composed/attach.tsv').read_text().splitlines())==4
# With actual rendered images, changed bytes after annotation are refused.
malformed = copy.deepcopy(items); malformed['items'][0]['after']['image']='before-terminal.png'
(LAB/'identical.json').write_text(json.dumps(malformed))
# Absolute asset paths for a deliberately malformed items file outside the evidence folder.
for item in malformed['items']:
    for phase in ('before','after'):
        for k,v in item[phase].items(): item[phase][k]=str(E/v)
(LAB/'identical.json').write_text(json.dumps(malformed))
badcompose = compose.copy(); badcompose[badcompose.index('--items')+1]=LAB/'identical.json'; badcompose[badcompose.index('--out')+1]=LAB/'bad-compose'
run(badcompose,1,'same file')
missing = {'items':[]}; (LAB/'missing.json').write_text(json.dumps(missing))
badcompose[badcompose.index('--items')+1]=LAB/'missing.json'
run(badcompose,1,'no evidence items')
result('Comment composition binds real captures to the head, adds API to UI, and refuses missing or identical evidence')

meta = home/'state/live-task.meta'
base_meta = 'kind=ship\nmode=direct-PR\nproject='+str(proj)+'\n'
meta.write_text(base_meta+'evidence=ui+api\n')
url = 'https://github.com/disposable/example/pull/1'
# No forge calls: away-mode waiver refuses before credential resolution.
(home/'state/.afk').write_text('away\n')
run([EV,'waive','live-task',url,'--words','Skip this evidence for now.'],1,'waiver is refused in away mode')
assert not (home/'state/live-task.evidence-waiver').exists()
(home/'state/.afk').unlink()
run([EV,'waive','live-task',url,'--words','Skip it'],1,'at least 4 words')
# No forge calls: old records and default-off Bitbucket are local contract boundaries.
meta.write_text(base_meta)
run([EV,'check','live-task',url],0,'predates it')
meta.write_text(base_meta+'evidence=ui+api\n')
run([EV,'check','live-task','https://bitbucket.org/disposable/example/pull-requests/1'],0,'Bitbucket arm is off')
# Restrict PATH to real binaries (no mocks) to exercise the installed stale CLI refusal.
stale = LAB/'stale-bin'; stale.mkdir(exist_ok=True)
for tool in ('gh','python3','jq','curl','bash','dirname','grep','tail','cut','basename','sed','tr','mktemp','rm','git','wc','head','sort','uniq','awk','mkdir','date','chmod','readlink','stat','sleep'): 
    link = stale/tool
    if not link.exists(): link.symlink_to(shutil.which(tool))
run(['env','PATH='+str(stale),EV,'publish','live-task',url,E/'items.json'],1,"no gh with 'pr comment --attach'")
# Normal PATH also has a newer CLI. With no sandbox credentials in the isolated config,
# it refuses a PR read rather than posting anything. Operator credentials are not consulted.
run([EV,'publish','live-task',url,E/'items.json'],1,'the PR cannot be read from GitHub')
result('Away-mode and short-word waivers refuse; legacy records pass with notice; Bitbucket is off; stale gh refuses publication')

# Reviewer gallery uses actual generated PNGs. It is a local presentation, not a forge-display proof.
parts=['<!doctype html><meta charset="utf-8"><title>Evidence CLI live validation</title><style>body{font:16px sans-serif;margin:24px;background:#f3f5f7}section{display:flex;gap:16px}figure{margin:0;width:49%}img{width:100%;height:auto}pre{white-space:pre-wrap}</style><h1>Live evidence capture and annotation</h1><p>Generated by the real Firstmate CLI in an isolated lab. This page does not prove GitHub rendering.</p>']
for title,kind in [('Terminal plain-English refusal and correction','terminal'),('HTTP status and response change','http')]:
    parts += ['<h2>'+title+'</h2><section>']
    for phase in ('before','after'): parts += ['<figure><figcaption>'+phase.title()+'</figcaption><img src="'+phase+'-'+kind+'.png"></figure>']
    parts += ['</section>']
parts += ['<h2>Generated PR comment</h2><pre>'+html.escape(comment)+'</pre>']
(E/'gallery.html').write_text('\n'.join(parts))
log.close()
print('All local live scenarios complete.',flush=True)
