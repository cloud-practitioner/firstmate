#!/usr/bin/env python3
"""Disposable live CLI validation; no harness or backend is simulated."""
import json, os, pathlib, shlex, shutil, subprocess, sys, time, traceback
ROOT = pathlib.Path.cwd()
EVIDENCE = pathlib.Path('/home/node/.no-mistakes/evidence/01M65EG1JZD5AKPR05YZTJV7CC')
WORK = ROOT / '.test-validation/live'
WORK.mkdir(parents=True, exist_ok=True)
LOG = (EVIDENCE / 'live-tasktmp.log').open('w', buffering=1)
BASE = os.environ.copy()
for key in list(BASE):
    if key.startswith(('FM_', 'HERDR_')) or key in ('TMUX', 'TMUX_PANE', 'CLAUDECODE'):
        BASE.pop(key, None)
BASE['FM_HERDR_LAB_STATE_DIR'] = str(WORK / 'herdr-state')
BASE['TREEHOUSE_ROOT'] = str(WORK / 'treehouse')
BASE['SHELL'] = '/bin/bash'
BASE['DISABLE_AUTOUPDATER'] = '1'
HELPER = ROOT / 'bin/fm-herdr-lab.sh'
SESSION = None
RESULTS = []

def note(s):
    print(s, flush=True)
    LOG.write(s+'\n')

def run(args, env=None, ok=True, timeout=100, cwd=ROOT):
    args = list(map(str,args))
    note('$ ' + shlex.join(args))
    p = subprocess.run(args, cwd=cwd, env=env or BASE, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    note(p.stdout.rstrip() + '\n[exit '+str(p.returncode)+']')
    if ok and p.returncode:
        raise RuntimeError('command failed: '+shlex.join(args))
    return p

def lab(*args, **kw):
    return run([HELPER,'run',SESSION,*args], **kw)

def env(home):
    e=BASE.copy()
    e.update(FM_HOME=str(home), FM_BACKEND='herdr', HERDR_SESSION=SESSION,
             HERDR_LAB_SESSION=SESSION, HERDR_LAB_HELPER=str(HELPER),
             HERDR_ORIGINAL_PATH=BASE['PATH'], REAL_HERDR=shutil.which('herdr',path=BASE['PATH']),
             PATH=str(WORK/'bin')+':'+BASE['PATH'], FM_SPAWN_NO_GUARD='1')
    return e

def home(name):
    h=WORK/name
    run([ROOT/'bin/fm-lab-home.sh','create',h])
    (h/'config/backend').write_text('herdr\n')
    (h/'config/backlog-backend').write_text('manual\n')
    return h

def git(args,cwd):
    return run(['git','-c','user.name=Task Temp Lab','-c','user.email=lab@example.invalid',*args],cwd=cwd)

def project(h):
    p=h/'projects/notes'
    p.mkdir()
    git(['init','-q','-b','main'],p)
    (p/'README.md').write_text('Disposable task temp validation project.\n')
    git(['add','README.md'],p)
    git(['commit','-qm','Initial fixture'],p)
    return p

def brief(h,id):
    run([ROOT/'bin/fm-brief.sh',id,'notes','--mode','local-only','--herdr-lab'],env=env(h))
    f=h/'data'/id/'brief.md'
    s=f.read_text().replace('{TASK}', 'Run a local task that records its real inherited temporary-directory environment.').replace('{FIRSTMATE_SPEC}', 'Write the environment probe in GOTMPDIR; do not publish or change the project.')
    f.write_text(s)

def meta(h,id):
    return dict(line.split('=',1) for line in (h/'state'/f'{id}.meta').read_text().splitlines() if '=' in line)

def setmeta(h,id,key,value):
    f=h/'state'/f'{id}.meta'
    lines=f.read_text().splitlines()
    lines=[x for x in lines if not x.startswith(key+'=')]
    if value is not None: lines.append(key+'='+value)
    f.write_text('\n'.join(lines)+'\n')

def probe(h,id,label):
    m=meta(h,id)
    f=pathlib.Path(m['tasktmp'])/'gotmp'/f'{label}.json'
    for _ in range(80):
        if f.exists(): break
        time.sleep(.2)
    assert f.exists(), 'real task did not produce '+str(f)
    data=json.loads(f.read_text())
    note('TASK OUTPUT '+json.dumps(data,sort_keys=True))
    assert data['GOTMPDIR']==str(f.parent)
    assert data['cwd']==m['worktree']
    assert data['root_mode']=='0o700'
    assert data['TMPDIR']!=m['tasktmp']
    lab('pane','read',m['herdr_pane_id'],'--source','recent','--lines','20','--format','text')
    return f

def spawn(h,id,p,label,extra=None,ok=True):
    command='/usr/bin/python3 '+shlex.quote(str(WORK/'probe.py'))+' '+shlex.quote(label)
    args=[ROOT/'bin/fm-spawn.sh',id]
    if extra: args += extra
    else: args += [p,'--mode','local-only','--yolo','off','--backend','herdr']
    args += ['--harness',command]
    r=run(args,env=env(h),ok=ok,timeout=140)
    if ok: probe(h,id,label)
    return r

def teardown(h,id):
    m=meta(h,id)
    root=pathlib.Path(m['tasktmp'])
    run([ROOT/'bin/fm-teardown.sh',id,'--force'],env=env(h),timeout=120)
    assert not root.exists(), 'recorded task temp root survived teardown'
    assert not (h/'state'/f'{id}.meta').exists()
    note('FILESYSTEM: recorded task temp root and metadata are absent after teardown: '+str(root))

def passed(name):
    RESULTS.append({'name':name,'result':'pass'})
    note('SCENARIO PASS: '+name)

try:
    SESSION=run([HELPER,'name','tasktmp-live']).stdout.strip()
    # provision owns prepare on a new session (calling prepare twice is refused).
    run([HELPER,'provision',SESSION])
    lab('status','--json')
    (WORK/'bin').mkdir()
    wrapper=WORK/'bin/herdr'
    wrapper.write_text('''#!/usr/bin/env python3
import os,sys
args=sys.argv[1:]; session=os.environ['HERDR_LAB_SESSION']
while '--session' in args:
 i=args.index('--session')
 if i+1>=len(args) or args[i+1]!=session: sys.exit(9)
 del args[i:i+2]
if any(x.startswith('--session=') for x in args): sys.exit(9)
e=os.environ.copy();e['PATH']=e['HERDR_ORIGINAL_PATH']
if args==['--version']:
 os.execve(e['REAL_HERDR'],[e['REAL_HERDR'],'--version','--session',session],e)
os.execve(e['HERDR_LAB_HELPER'],[e['HERDR_LAB_HELPER'],'run',session]+args,e)
''')
    wrapper.chmod(0o755)
    (WORK/'probe.py').write_text('''import json,os,pathlib,sys
p=pathlib.Path(os.environ['GOTMPDIR'])
d={'GOTMPDIR':str(p),'TMPDIR':os.environ.get('TMPDIR'),'cwd':os.getcwd(),'root_mode':oct(p.parent.stat().st_mode & 0o777),'task':os.environ.get('FM_TASK_ID'),'label':sys.argv[1]}
(p/(sys.argv[1]+'.json')).write_text(json.dumps(d,sort_keys=True)+'\\n')
print('REAL TASK TEMP ENVIRONMENT: '+json.dumps(d,sort_keys=True),flush=True)
''')
    a=home('home-a')
    b=home("home b's quoted path")
    pa,pb=project(a),project(b)
    id='temp-'+str(os.getpid())
    brief(a,id);brief(b,id)
    spawn(a,id,pa,'home-a')
    spawn(b,id,pb,'home-b')
    ma,mb=meta(a,id),meta(b,id)
    ta,tb=pathlib.Path(ma['tasktmp']),pathlib.Path(mb['tasktmp'])
    assert ta==a/'state'/f'{id}.tasktmp'
    assert tb==b/'state'/f'{id}.tasktmp' and tb!=ta
    assert not pathlib.Path('/tmp/fm-'+id).exists()
    note('FILESYSTEM: two same-ID tasks use distinct home-scoped roots; /tmp/fm-'+id+' is absent')
    passed('Same task ID in two homes gets isolated private roots, including a quoted home path')
    teardown(a,id)
    assert (tb/'gotmp/home-b.json').exists()
    note('FILESYSTEM: home B output survives teardown of equal-ID home A task')
    passed('Teardown removes only the recorded home root and preserves the other home')
    # A missing recorded root is assigned a new home-scoped root.
    setmeta(b,id,'tasktmp',None)
    spawn(b,id,pb,'rootless-relaunch',extra=['--relaunch'])
    assert meta(b,id)['tasktmp']==str(tb)
    passed('Relaunch of a task with no tasktmp field gets its home-scoped root')
    # Seed only the persisted legacy-path contract; the real product creates it.
    legacy=pathlib.Path('/tmp/fm-'+id)
    assert not legacy.exists()
    setmeta(b,id,'tasktmp',str(legacy))
    spawn(b,id,pb,'legacy-first',extra=['--relaunch'])
    spawn(b,id,pb,'legacy-second',extra=['--relaunch'])
    assert (legacy/'gotmp/legacy-first.json').exists()
    assert meta(b,id)['tasktmp']==str(legacy)
    passed('Legacy relaunch keeps recorded /tmp root and earlier scratch output')
    teardown(b,id)
    assert not legacy.exists()
    passed('Teardown removes the recorded legacy root')
    # Unsafe pre-existing home temp roots must refuse without writing through them.
    for variant in ('world-writable','symlink'):
        bid=id+'-'+variant
        brief(a,bid)
        t=a/'state'/f'{bid}.tasktmp'
        target=WORK/('sentinel-'+variant)
        target.mkdir()
        (target/'keep').write_text('untouched\n')
        if variant=='symlink': t.symlink_to(target,target_is_directory=True)
        else: t.mkdir();t.chmod(0o777)
        r=spawn(a,bid,pa,'must-not-run',ok=False)
        assert r.returncode!=0 and 'not a private directory owned by this user' in r.stdout
        assert not (a/'state'/f'{bid}.meta').exists()
        assert not (t/'gotmp').exists()
        assert (target/'keep').read_text()=='untouched\n'
        note('FILESYSTEM: unsafe '+variant+' root refused before metadata or task output; target sentinel unchanged')
        passed('Spawn refuses a '+variant+' task root without writing into it')
    lab('workspace','list')
except Exception as e:
    note('VALIDATION ERROR: '+str(e)+'\n'+traceback.format_exc())
    RESULTS.append({'name':'live driver','result':'fail','reason':str(e)})
finally:
    if SESSION:
        try: run([HELPER,'teardown',SESSION],timeout=40)
        except Exception as e: note('TEARDOWN ERROR: '+str(e));RESULTS.append({'name':'lab teardown','result':'fail','reason':str(e)})
    # Legacy roots, if any, are cleaned by the real teardown above; do not sweep /tmp.
    (EVIDENCE/'live-tasktmp-results.json').write_text(json.dumps(RESULTS,indent=2)+'\n')
    note('FINAL RESULTS '+json.dumps(RESULTS))
    LOG.close()
    sys.exit(1 if any(x['result']=='fail' for x in RESULTS) else 0)
