import os, pathlib, subprocess, json, time, shutil, hashlib
ROOT=pathlib.Path.cwd()
WORK=ROOT/'.test-phase'/('run-'+str(os.getpid()))
(WORK/'tmp').mkdir(parents=True)
EVID=pathlib.Path('/home/node/.no-mistakes/evidence/01M46APVYA67J1DXJZ9Z5ZMJSJ')
EVID.mkdir(parents=True,exist_ok=True)
LOG=open(EVID/'live-private-reuse.log','w')
env=os.environ.copy()
for k in list(env):
    if k.endswith('_OVERRIDE') and k.startswith('FM_') or k in ['FM_GATE_REFUSE_BYPASS','TMUX','TMUX_PANE','HERDR_ENV','HERDR_SESSION','HERDR_SOCKET_PATH','HERDR_PANE_ID','HERDR_TAB_ID','HERDR_WORKSPACE_ID']:
        env.pop(k,None)
env.update(TMPDIR=str(WORK/'tmp'),FM_HERDR_LAB_STATE_DIR=str(WORK/'herdr-state'),TREEHOUSE_ROOT=str(WORK/'treehouse'),DISABLE_AUTOUPDATER='1')
sessions=[]
records=[]
def run(args,e=None,check=True,timeout=140):
    LOG.write('\n$ '+ ' '.join(map(str,args))+'\n'); LOG.flush()
    p=subprocess.run(list(map(str,args)),env=e or env,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=timeout)
    LOG.write(p.stdout+'\nexit='+str(p.returncode)+'\n');LOG.flush()
    if check and p.returncode: raise RuntimeError(p.stdout)
    return p

def lab(args,e=None,**kw):return run([ROOT/'bin/fm-herdr-lab.sh',*args],e,**kw)
def make_home(name):
    p=WORK/name
    run([ROOT/'bin/fm-lab-home.sh','create',p])
    (p/'config/herdr-presentation-spaces').write_text('off\n')
    (p/'config/backlog-backend').write_text('manual\n')
    return p

def make_project(name):
    p=WORK/name;p.mkdir()
    run(['git','-C',p,'init','-q','-b','main'])
    (p/'README.md').write_text('Disposable project\n')
    run(['git','-C',p,'add','README.md'])
    run(['git','-C',p,'-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','initial'])
    run(['git','clone','--quiet','--bare',p,str(p)+'.origin.git'])
    run(['git','-C',p,'remote','add','origin','file://'+str(p)+'.origin.git'])
    return p

def brief(h,id):
    d=h/'data'/id;d.mkdir(parents=True,exist_ok=True)
    (d/'brief.md').write_text('# Task\n## Captain\'s intent\nVerify isolated task scratch storage.\n\n## Firstmate spec\nOnly inspect the disposable environment.\n')

def meta(h,id):
    return dict(line.split('=',1) for line in (h/'state'/f'{id}.meta').read_text().splitlines() if '=' in line)

def spawn(h,id,proj,sess,extra=None,check=True):
    ee=env.copy();ee.update(FM_HOME=str(h),HERDR_SESSION=sess)
    # A raw command is a supported public adapter escape hatch, not a fake product.
    cmd="sh -c 'printf \"LIVE_GOTMPDIR=%s\\n\" \"$GOTMPDIR\"; printf \"%s\\n\" \"$GOTMPDIR\" > \"$GOTMPDIR/observed-env\"'"
    p=run([ROOT/'bin/fm-spawn.sh',id,proj,cmd,'--mode','local-only','--yolo','off','--backend','herdr'],ee,check=check)
    if not p.returncode:records.append((h,id,sess,ee))
    return p,ee

def capture(h,id,sess):
    m=meta(h,id)
    return lab(['run',sess,'pane','read',m['herdr_pane_id'],'--source','recent','--lines','200']).stdout

def verify_home(h,id):
    m=meta(h,id);t=h/'state'/f'{id}.tasktmp'
    assert m['tasktmp']==str(t),(m['tasktmp'],t)
    assert t.stat().st_mode&0o777==0o700
    for _ in range(30):
        if (t/'gotmp/observed-env').exists():break
        time.sleep(.2)
    assert (t/'gotmp/observed-env').read_text().strip()==str(t/'gotmp')
    assert not pathlib.Path('/tmp/fm-'+id).exists()
    LOG.write('OBSERVABLE STATE '+json.dumps({'tasktmp':m['tasktmp'],'mode':oct(t.stat().st_mode&0o777),'child_GOTMPDIR':(t/'gotmp/observed-env').read_text().strip(),'legacy_root_created':False})+'\n');LOG.flush()
    return t

try:
    sess=lab(['name','private-reuse']).stdout.strip();sessions.append(sess);lab(['provision',sess])
    h=make_home('reuse-home');p=make_project('reuse-project')
    id='reuse-'+str(os.getpid());brief(h,id)
    t=h/'state'/f'{id}.tasktmp';t.mkdir(mode=0o750);(t/'scratch').write_text('keep existing scratch\n')
    _,ee=spawn(h,id,p,sess);verify_home(h,id)
    assert (t/'scratch').read_text()=='keep existing scratch\n'
    capture(h,id,sess)
    LOG.write('OBSERVED: user-owned non-writable-by-others root reused, permissions tightened from 0750 to 0700, and existing scratch retained.\n');LOG.flush()
    run([ROOT/'bin/fm-teardown.sh',id],ee)
    assert not t.exists()
    LOG.write('SCENARIO PASS: private root reuse and eventual cleanup.\n')
finally:
    for h,id,s,e in records:
        if (h/'state'/f'{id}.meta').exists():run([ROOT/'bin/fm-teardown.sh',id],e,check=False)
    for s in reversed(sessions):lab(['teardown',s],check=False,timeout=90)
    LOG.close()
