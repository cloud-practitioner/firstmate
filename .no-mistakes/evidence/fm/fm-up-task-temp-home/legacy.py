import os, pathlib, subprocess, json, time, shutil, hashlib
ROOT=pathlib.Path.cwd()
WORK=ROOT/'.test-phase'/('run-'+str(os.getpid()))
(WORK/'tmp').mkdir(parents=True)
EVID=pathlib.Path('/home/node/.no-mistakes/evidence/01M46APVYA67J1DXJZ9Z5ZMJSJ')
EVID.mkdir(parents=True,exist_ok=True)
LOG=open(EVID/'live-legacy-temp-home.log','w')
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

CODE=ROOT/'.test-phase/code'
legacy_roots=[]
cmd="sh -c 'printf \"LEGACY_GOTMPDIR=%s\\n\" \"$GOTMPDIR\"; printf \"%s\\n\" \"$GOTMPDIR\" > \"$GOTMPDIR/observed-env\"'"
def rewrite(h,id,m):
    (h/'state'/f'{id}.meta').write_text(''.join(k+'='+v+'\n' for k,v in m.items()))
def migrate_record(h,id):
    m=meta(h,id);t=pathlib.Path(m['tasktmp'])
    legacy=pathlib.Path('/tmp/fm-'+id)
    legacy.mkdir(mode=0o700)  # exclusive unique ephemeral regression fixture
    legacy_roots.append(legacy)
    (legacy/'gotmp').mkdir();(legacy/'scratch').write_text('pre-upgrade scratch\n')
    m['tasktmp']=str(legacy);rewrite(h,id,m)
    shutil.rmtree(t)
    return legacy

def observe_legacy(h,id,legacy,sess):
    m=meta(h,id)
    assert m['tasktmp']==str(legacy)
    assert (legacy/'scratch').read_text()=='pre-upgrade scratch\n'
    for _ in range(30):
        if (legacy/'gotmp/observed-env').exists():break
        time.sleep(.2)
    assert (legacy/'gotmp/observed-env').read_text().strip()==str(legacy/'gotmp')
    assert not (h/'state'/f'{id}.tasktmp').exists()
    capture(h,id,sess)
    LOG.write('PERSISTED LEGACY STATE '+json.dumps({'tasktmp':m['tasktmp'],'scratch':(legacy/'scratch').read_text().strip(),'child_GOTMPDIR':(legacy/'gotmp/observed-env').read_text().strip(),'replacement_root_created':False})+'\n');LOG.flush()
try:
    sess=lab(['name','legacy-temp']).stdout.strip();sessions.append(sess);lab(['provision',sess])
    home=make_home('legacy-parent')
    proj=make_project('legacy-project')
    id='legacy-ship-'+str(os.getpid());brief(home,id)
    _,ee=spawn(home,id,proj,sess)
    legacy=migrate_record(home,id)
    run([ROOT/'bin/fm-spawn.sh',id,'--relaunch','--harness',cmd],ee)
    observe_legacy(home,id,legacy,sess)
    run([ROOT/'bin/fm-teardown.sh',id],ee)
    assert not legacy.exists()
    LOG.write('SCENARIO PASS: stopped ship relaunch preserves recorded legacy root, and teardown removes it.\n');LOG.flush()

    id='rootless-ship-'+str(os.getpid());brief(home,id)
    _,ee=spawn(home,id,proj,sess)
    m=meta(home,id);t=pathlib.Path(m.pop('tasktmp'));rewrite(home,id,m);shutil.rmtree(t)
    run([ROOT/'bin/fm-spawn.sh',id,'--relaunch','--harness',cmd],ee)
    verify_home(home,id)
    run([ROOT/'bin/fm-teardown.sh',id],ee)
    LOG.write('SCENARIO PASS: rootless old ship record receives a home-scoped root on relaunch.\n');LOG.flush()

    id='legacy-mate-'+str(os.getpid())
    mate=make_home('legacy-mate')
    shutil.copytree(ROOT/'bin',mate/'bin');shutil.copy2(ROOT/'AGENTS.md',mate/'AGENTS.md')
    (mate/'.fm-secondmate-home').write_text(id+'\n')
    run(['git','-C',mate,'init','-q','-b','main'])
    (mate/'data/charter.md').write_text('Disposable compatibility check only.\n')
    brief(home,id)
    ee=env.copy();ee.update(FM_HOME=str(home),HERDR_SESSION=sess,FM_SKIP_SECONDMATE_SYNC='1',FM_SKIP_SECONDMATE_INHERIT='1')
    run([CODE/'bin/fm-spawn.sh',id,mate,cmd,'--secondmate','--backend','herdr'],ee)
    records.append((home,id,sess,ee))
    legacy=migrate_record(home,id)
    # Ordinary liveness recovery does not carry --relaunch.
    run([CODE/'bin/fm-spawn.sh',id,'--secondmate',cmd,'--backend','herdr'],ee)
    observe_legacy(home,id,legacy,sess)
    run([CODE/'bin/fm-spawn.sh',id,'--relaunch','--harness',cmd],ee)
    observe_legacy(home,id,legacy,sess)
    run([CODE/'bin/fm-teardown.sh',id],ee)
    assert not legacy.exists()
    LOG.write('SCENARIO PASS: ordinary secondmate recovery and explicit relaunch both retain legacy scratch; teardown removes the recorded root.\n');LOG.flush()
except Exception as ex:
    LOG.write('LIVE DRIVER FAILURE: '+repr(ex)+'\n');LOG.flush();raise
finally:
    for h,id,s,e in records:
        if (h/'state'/f'{id}.meta').exists():
            run([CODE/'bin/fm-teardown.sh' if meta(h,id).get('kind')=='secondmate' else ROOT/'bin/fm-teardown.sh',id],e,check=False)
    for s in reversed(sessions):lab(['teardown',s],check=False,timeout=90)
    for p in legacy_roots:
        if p.exists():shutil.rmtree(p)
    LOG.close()
