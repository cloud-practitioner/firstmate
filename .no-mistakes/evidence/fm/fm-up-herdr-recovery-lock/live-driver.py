#!/usr/bin/env python3
"""Targeted live checks of the public Firstmate spawn API on real Herdr/Treehouse.
All fixture homes, pools, configuration and session data stay under the worktree.
Herdr receives a short /proc/self/fd path to avoid AF_UNIX's pathname limit.
The only production reference is a read-only default-socket symlink for the
required lab tripwire; no operations are sent to the default session.
"""
import os, pathlib, subprocess, time, json, shutil, sys
ROOT = pathlib.Path.cwd()
V = ROOT / '.gate6454'
E = pathlib.Path('/home/node/.no-mistakes/evidence/01M410E7F7G38F8N1PVBSA2B64')
E.mkdir(parents=True, exist_ok=True)
(V/'tmp').mkdir(exist_ok=True)
(V/'oshome').mkdir(exist_ok=True)
(V/'config/herdr').mkdir(parents=True, exist_ok=True)
(V/'fakebin').mkdir(exist_ok=True)
REAL_HERDR = shutil.which('herdr')
REAL_TREEHOUSE = shutil.which('treehouse')
REAL_MKTEMP = shutil.which('mktemp')
ORIGINAL_PATH = os.environ['PATH']
for name in ('slow.enabled','slow.release','slow.log','fm-primary-recover.started','fm-bravo-recover.started','bravo-attempts','ordinary-attempts','stuck-attempts','owner.ready','owner.release'):
    (V/name).unlink(missing_ok=True)
# The default session is read only and used solely by the helper's tripwire.
probe = subprocess.run([str(ROOT/'bin/fm-herdr-lab.sh'),'run','fm-lab-gate-probe','session','list','--json'],capture_output=True,text=True,check=True)
default = next(s for s in json.loads(probe.stdout)['sessions'] if s['default'])
assert default['running'], 'The trusted helper requires an already running default session.'
link = V/'config/herdr/herdr.sock'
if not link.exists(): link.symlink_to(default['socket_path'])
fd = os.open(V/'config', os.O_RDONLY)
os.dup2(fd, 9, inheritable=True)
if fd != 9: os.close(fd)
env = dict(os.environ)
for key in list(env):
    if key.startswith('FM_') or key.startswith('HERDR_') or key == 'TMUX': env.pop(key, None)
(V/'config/herdr/config.toml').write_text('[terminal]\ndefault_shell = "/bin/bash"\nshell_mode = "non_login"\n[update]\nversion_check = false\nmanifest_check = false\n[session]\nresume_agents_on_restore = false\n')
SHORT_CONFIG='/proc/'+str(os.getpid())+'/fd/9'
env.update(SHELL='/bin/bash', HERDR_CONFIG_PATH=SHORT_CONFIG+'/herdr/config.toml', HOME=str(V/'oshome'), XDG_CONFIG_HOME=SHORT_CONFIG, XDG_DATA_HOME=str(V/'oshome/data'), XDG_CACHE_HOME=str(V/'oshome/cache'), XDG_STATE_HOME=str(V/'oshome/state'), TMPDIR=str(V/'tmp'), TREEHOUSE_ROOT=str(V/'treehouse'), FM_HERDR_LAB_STATE_DIR=str(V/'lab-state'), REAL_HERDR=REAL_HERDR, REAL_TREEHOUSE=REAL_TREEHOUSE, REAL_MKTEMP=REAL_MKTEMP, HERDR_ORIGINAL_PATH=ORIGINAL_PATH, GATE_V=str(V), LAB_HELPER=str(ROOT/'bin/fm-herdr-lab.sh'))
transcript = open(E/'live-lock-transcript.log','w')
processes=[]
results=[]
def note(s):
    print(s,flush=True); transcript.write(s+'\n'); transcript.flush()
def run(args, extra=None, check=True):
    ee=env.copy(); ee.update(extra or {})
    p=subprocess.run([str(x) for x in args],cwd=ROOT,env=ee,pass_fds=(9,),capture_output=True,text=True)
    note('$ '+' '.join(str(x) for x in args))
    if p.stdout: note(p.stdout.rstrip())
    if p.stderr: note(p.stderr.rstrip())
    if check and p.returncode: raise RuntimeError('Command failed: '+str(p.returncode))
    return p
session=run([ROOT/'bin/fm-herdr-lab.sh','name','lock6454']).stdout.strip()
env['HERDR_SESSION']=session; env['HERDR_LAB_SESSION']=session
labready=False
homes=[]
def lab(*args): return run([ROOT/'bin/fm-herdr-lab.sh','run',session,*args],extra={'PATH':ORIGINAL_PATH})
def api(*args): return json.loads(lab(*args).stdout)
def field(home,id,key):
    return dict(line.split('=',1) for line in (home/'state'/f'{id}.meta').read_text().splitlines() if '=' in line)[key]
def focus():
    ws=[w for w in api('workspace','list')['result']['workspaces'] if w['focused']]
    assert len(ws)==1
    return ws[0]['workspace_id'],ws[0]['active_tab_id']
def waitfile(path, p=None, timeout=70):
    deadline=time.monotonic()+timeout
    while not path.exists() or path.stat().st_size==0:
        if p and p.poll() is not None: raise RuntimeError('Process ended before synchronization: '+str(p.returncode))
        if time.monotonic()>deadline: raise RuntimeError('Synchronization timeout: '+str(path))
        time.sleep(.05)
def launch(id,home,label,extra=None):
    ee=env.copy(); ee.update(FM_HOME=str(home),FM_SPAWN_NO_GUARD='1'); ee.update(extra or {})
    out=open(E/(label+'.out'),'w'); err=open(E/(label+'.err'),'w')
    args=[ROOT/'bin/fm-spawn.sh',id,V/'project',"sh -c 'while :; do sleep 60; done'",'--mode','no-mistakes','--yolo','off','--backend','herdr']
    note('$ FM_HOME='+str(home)+' bin/fm-spawn.sh '+id+' <disposable-project> <idle-shell> --mode no-mistakes --yolo off --backend herdr')
    p=subprocess.Popen([str(x) for x in args],cwd=ROOT,env=ee,pass_fds=(9,),stdout=out,stderr=err)
    out.close(); err.close(); processes.append(p); return p
def finish(p,label,expected=0,timeout=210):
    rc=p.wait(timeout=timeout)
    note(label+' exit='+str(rc))
    note((E/(label+'.out')).read_text().rstrip()); note((E/(label+'.err')).read_text().rstrip())
    if expected==0: assert rc==0, label+' failed'
    else: assert rc!=0, label+' unexpectedly succeeded'
    return rc
def brief(home,id):
    d=home/'data'/id; d.mkdir(parents=True,exist_ok=True)
    (d/'brief.md').write_text('# Task\n## Captain\'s intent\nExercise isolated recovery lock behavior.\n\n## Firstmate spec\nDisposable live lock fixture.\n')
def owner():
    (V/'owner.ready').unlink(missing_ok=True); (V/'owner.release').unlink(missing_ok=True)
    ee=env.copy(); ee.update(LOCK=lock,ROOT=str(ROOT),V=str(V))
    p=subprocess.Popen(['bash','-c','. "$ROOT/bin/fm-wake-lib.sh"; fm_lock_try_acquire "$LOCK" || exit 1; echo ready > "$V/owner.ready"; while [ ! -f "$V/owner.release" ]; do sleep .05; done; fm_lock_release "$LOCK"'],env=ee,cwd=ROOT,pass_fds=(9,))
    processes.append(p); waitfile(V/'owner.ready',p); return p
def release(p):
    (V/'owner.release').touch(); assert p.wait(10)==0
try:
    # Provision owns prepare for a new session; explicitly preparing twice is
    # deliberately refused by its ambiguous-ownership guard.
    labready=True
    run([ROOT/'bin/fm-herdr-lab.sh','provision',session],extra={'PATH':ORIGINAL_PATH})
    api('status','--json')
    # All intercepted Herdr operations execute the real binary through the helper.
    (V/'fakebin/herdr').write_text('''#!/usr/bin/env bash
set -eu
printf '%s\\t' "$@" >> "$GATE_V/herdr-calls.log"; printf '\\n' >> "$GATE_V/herdr-calls.log"
args=("$@"); n=${#args[@]}
if [ "$n" -ge 2 ] && [ "${args[n-2]}" = --session ] && [ "${args[n-1]}" = "$HERDR_LAB_SESSION" ]; then unset 'args[n-1]' 'args[n-2]'; fi
set -- "${args[@]}"
if [ "${1:-}" = --version ]; then exec env PATH="$HERDR_ORIGINAL_PATH" "$REAL_HERDR" "$@" --session "$HERDR_LAB_SESSION"; fi
if [ "${1:-} ${2:-}" = 'tab create' ] && [ -f "$GATE_V/slow.enabled" ]; then
  label=; for ((i=0;i<${#args[@]}-1;i++)); do [ "${args[i]}" != --label ] || label=${args[i+1]}; done
  if [ "$label" = fm-primary-recover ] || [ "$label" = fm-bravo-recover ]; then
    printf '%s start %s\\n' "$label" "$(date +%s)" >> "$GATE_V/slow.log"
    echo started > "$GATE_V/$label.started"
    while [ ! -f "$GATE_V/slow.release" ]; do sleep .05; done
    env PATH="$HERDR_ORIGINAL_PATH" "$LAB_HELPER" run "$HERDR_LAB_SESSION" "$@"
    printf '%s end %s\\n' "$label" "$(date +%s)" >> "$GATE_V/slow.log"
    exit 0
  fi
fi
exec env PATH="$HERDR_ORIGINAL_PATH" "$LAB_HELPER" run "$HERDR_LAB_SESSION" "$@"
''')
    (V/'fakebin/mktemp').write_text('''#!/usr/bin/env bash
set -eu
if [ "$#" -eq 2 ] && [ "$1" = -d ] && [ "$2" = "${LOCK_TARGET:-}.owner.XXXXXX" ]; then
  echo "$(date +%s.%N)" >> "$LOCK_LOG"
fi
exec "$REAL_MKTEMP" "$@"
''')
    (V/'fakebin/treehouse').write_text('''#!/usr/bin/env bash
set -eu
exec "$REAL_TREEHOUSE" "$@"
''')
    for path in (V/'fakebin').iterdir(): path.chmod(0o755)
    (V/'fakebin/mover').write_text('#!/usr/bin/env bash\nset -eu\nexec "'+str(ROOT/'bin/backends/herdr-workspace-move.py')+'" "'+SHORT_CONFIG+'/herdr/sessions/'+session+'/herdr.sock" "$2" "$3"\n')
    (V/'fakebin/mover').chmod(0o755)
    env['FM_BACKEND_HERDR_WORKSPACE_MOVER']=str(V/'fakebin/mover')
    env['PATH']=str(V/'fakebin')+':'+ORIGINAL_PATH
    # Bash's fixture startup preserves the instrumented PATH for pool entry.
    (V/'oshome/.bashrc').write_text('export PATH="'+env['PATH']+'"\n')
    run([ROOT/'bin/fm-herdr-lab.sh','stop',session],extra={'PATH':ORIGINAL_PATH})
    run([ROOT/'bin/fm-herdr-lab.sh','provision',session],extra={'PATH':ORIGINAL_PATH})
    for name in ('primary','bravo'):
        home=V/('home-'+name); home.mkdir(exist_ok=True)
        run([ROOT/'bin/fm-lab-home.sh','create',home]); homes.append(home)
        (home/'state/.last-watcher-beat').touch()
    primary,bravo=homes
    (bravo/'.fm-secondmate-home').write_text('bravo\n')
    project=V/'project'; project.mkdir(exist_ok=True)
    run(['git','-C',project,'init','-q','-b','main'])
    (project/'README.md').write_text('# Disposable recovery fixture\n')
    run(['git','-C',project,'add','README.md'])
    run(['git','-C',project,'-c','user.name=Firstmate Tests','-c','user.email=tests@example.invalid','commit','-qm','initial'])
    run(['git','clone','--quiet','--bare',project,V/'project.origin.git'])
    run(['git','-C',project,'remote','add','origin','file://'+str(V/'project.origin.git')])
    parent=api('workspace','create','--cwd',str(project),'--label','firstmate','--no-focus')['result']['workspace']['workspace_id']
    bparent=api('workspace','create','--cwd',str(project),'--label','2ndmate-bravo','--focus')['result']['workspace']['workspace_id']
    brief(primary,'primary-recover'); brief(bravo,'bravo-recover'); brief(primary,'ordinary-new')
    finish(launch('primary-recover',primary,'primary-initial'),'primary-initial')
    finish(launch('bravo-recover',bravo,'bravo-initial'),'bravo-initial')
    old={}
    for h,id in ((primary,'primary-recover'),(bravo,'bravo-recover')):
        old[id]=(field(h,id,'herdr_workspace_id'),field(h,id,'herdr_pane_id'))
        assert (h/'state'/f'{id}.herdr-presentation').exists()
    # This is the same public resolution that product spawn uses.
    lock=run(['bash','-c','. "$1/bin/backends/herdr.sh"; fm_backend_herdr_presentation_session_lock_path "$2"','bash',ROOT,session],extra={'FM_HOME':str(primary)}).stdout.strip()
    assert lock
    held=owner(); before=focus(); t=time.monotonic()
    finish(launch('ordinary-new',primary,'ordinary-new',{'LOCK_TARGET':lock,'LOCK_LOG':str(V/'ordinary-attempts')}),'ordinary-new')
    attempts=[float(x) for x in (V/'ordinary-attempts').read_text().splitlines()]
    warning=(E/'ordinary-new.err').read_text()
    assert 'presentation focus lock unavailable; using the ordinary flat layout without projection' in warning
    assert field(primary,'ordinary-new','herdr_workspace_id')==parent
    assert not (primary/'state/ordinary-new.herdr-presentation').exists()
    assert attempts[-1]-attempts[0]<6
    assert focus()==before
    release(held)
    note('ORDINARY FALLBACK: acquisition attempts spanned %.3fs; flat parent=%s; no journal; focus preserved.'%(attempts[-1]-attempts[0],parent))
    results.append({'name':'ordinary-spawn','pass':True,'attempt_span':attempts[-1]-attempts[0]})
    run([ROOT/'bin/fm-herdr-lab.sh','stop',session],extra={'PATH':ORIGINAL_PATH})
    run([ROOT/'bin/fm-herdr-lab.sh','provision',session],extra={'PATH':ORIGINAL_PATH})
    before=focus()
    # Use the production default of 120s, not the shortened test override.
    held=owner(); meta_before=(primary/'state/primary-recover.meta').read_bytes()
    calls_before=(V/'herdr-calls.log').read_text().splitlines()
    stuck=launch('primary-recover',primary,'stuck-holder',{'LOCK_TARGET':lock,'LOCK_LOG':str(V/'stuck-attempts')})
    waitfile(V/'stuck-attempts',stuck); t=time.monotonic()
    finish(stuck,'stuck-holder',expected=1,timeout=155)
    elapsed=time.monotonic()-t
    assert 'session lock within 120s; refusing a concurrent resume' in (E/'stuck-holder.err').read_text()
    assert elapsed<122, 'Default deadline overran'
    assert (primary/'state/primary-recover.meta').read_bytes()==meta_before
    assert focus()==before
    delta=(V/'herdr-calls.log').read_text().splitlines()[len(calls_before):]
    assert not any(row.startswith(tuple(a+'\t'+b+'\t' for a in ('workspace','tab','pane') for b in ('create','close','focus','move'))) for row in delta), 'Refused recovery mutated Herdr'
    release(held)
    note('STUCK HOLDER: refused after %.3fs from first attempt; production 120s budget; metadata byte-identical; no Herdr mutation; focus preserved.'%elapsed)
    results.append({'name':'stuck-holder','pass':True,'elapsed_from_first_attempt':elapsed})
    (V/'slow.enabled').touch()
    first=launch('primary-recover',primary,'primary-resume')
    waitfile(V/'fm-primary-recover.started',first)
    second=launch('bravo-recover',bravo,'bravo-resume',{'LOCK_TARGET':lock,'LOCK_LOG':str(V/'bravo-attempts')})
    waitfile(V/'bravo-attempts',second); t=time.monotonic(); time.sleep(8)
    assert second.poll() is None, 'Second recovery gave up under contention'
    assert not (V/'fm-bravo-recover.started').exists(), 'Second recovery mutated before holding lock'
    attempts=(V/'bravo-attempts').read_text().splitlines()
    assert len(attempts)>50, 'Former lock-attempt budget was not exceeded'
    note('CONCURRENT RECOVERY: second remains pending %.3fs after first observed acquisition attempt (%d attempts); no second tab-create yet.'%(time.monotonic()-t,len(attempts)))
    (V/'slow.release').touch()
    finish(first,'primary-resume'); finish(second,'bravo-resume')
    events=[line.split() for line in (V/'slow.log').read_text().splitlines()]
    assert [(e[0],e[1]) for e in events]==[('fm-primary-recover','start'),('fm-primary-recover','end'),('fm-bravo-recover','start'),('fm-bravo-recover','end')]
    for h,id in ((primary,'primary-recover'),(bravo,'bravo-recover')):
        ws,pane=old[id]
        assert field(h,id,'herdr_workspace_id')==ws
        assert field(h,id,'herdr_pane_id')!=pane
        gone=run([ROOT/'bin/fm-herdr-lab.sh','run',session,'pane','get',pane],extra={'PATH':ORIGINAL_PATH},check=False)
        assert gone.returncode!=0
        api('pane','get',field(h,id,'herdr_pane_id'))
        shutil.copyfile(h/'state'/f'{id}.meta',E/(id+'.meta'))
    assert focus()==before
    (E/'serialized-replacement-events.log').write_text((V/'slow.log').read_text())
    (E/'bravo-acquisition-attempts.log').write_text((V/'bravo-attempts').read_text())
    (E/'stuck-acquisition-attempts.log').write_text((V/'stuck-attempts').read_text())
    (E/'ordinary-acquisition-attempts.log').write_text((V/'ordinary-attempts').read_text())
    (E/'herdr-product-calls.log').write_text((V/'herdr-calls.log').read_text())
    note('CONCURRENT RECOVERY: both public spawn commands succeeded; exact workspace identities retained; old husks absent; new panes present; focus unchanged.')
    results.append({'name':'concurrent-recovery','pass':True,'attempts_while_held':len(attempts),'events':events})
except Exception as ex:
    note('FAIL: '+repr(ex))
    if labready:
        try:
            for ws in api('workspace','list')['result']['workspaces']:
                for pane in api('pane','list','--workspace',ws['workspace_id'])['result']['panes']:
                    lab('pane','read',pane['pane_id'],'--source','recent','--lines','80')
        except Exception as capture_error: note('Failure capture: '+repr(capture_error))
    raise
finally:
    (V/'slow.release').touch(); (V/'owner.release').touch()
    for p in processes:
        if p.poll() is None:
            try: p.wait(20)
            except subprocess.TimeoutExpired: p.terminate(); p.wait(10)
    if labready:
        # Real lifecycle cleanup; the disposable lab marker, never a bypass.
        for home in homes:
            for meta in (home/'state').glob('*.meta'):
                run([ROOT/'bin/fm-teardown.sh',meta.stem,'--force'],extra={'FM_HOME':str(home)},check=False)
        tear=run([ROOT/'bin/fm-herdr-lab.sh','teardown',session],extra={'PATH':ORIGINAL_PATH},check=False)
        note('LAB TEARDOWN: status='+str(tear.returncode)+' (includes default-session tripwire verification)')
        if tear.returncode: results.append({'name':'teardown','pass':False})
    (E/'live-lock-results.json').write_text(json.dumps(results,indent=2)+'\n')
    transcript.close()
