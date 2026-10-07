#!/usr/bin/env python3
"""Drive real CLI/backend; fault injection uses TERM and filesystem permissions only."""
import json, os, pathlib, shutil, subprocess, tempfile, traceback
ROOT = pathlib.Path.cwd()
EVIDENCE = pathlib.Path(__file__).parent
BASE_ENV = {k:v for k,v in os.environ.items() if not (k.startswith('FM_') or k.startswith('TASKS_AXI_') or k == 'BASH_ENV')}
BASE_ENV['TMPDIR'] = '/tmp'
HOLD = ROOT / 'bin/fm-captain-hold.sh'
TASKS = ROOT / 'bin/fm-tasks-axi.sh'
log = (EVIDENCE / 'live-hold-origin.log').open('w', buffering=1)
results = []
homes = []

def emit(s):
    print(s, file=log)
    print(s, flush=True)

def run(home, tool, *args, fault=None, success=True):
    env = dict(BASE_ENV, FM_HOME=str(home))
    if fault:
        env.update(VALIDATION_FAULT=fault, BASH_ENV=str(EVIDENCE / 'fault-env.sh'))
    cmd = [str(tool), *map(str,args)]
    p = subprocess.run(cmd, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=50)
    emit('$ FM_HOME=<disposable-lab> ' + tool.name + ' ' + ' '.join(map(str,args)))
    emit('exit=' + str(p.returncode) + '\n' + p.stdout + p.stderr)
    if success is True: assert p.returncode == 0, (args, p.returncode, p.stderr)
    if success is False: assert p.returncode != 0, (args, p.stdout)
    return p

def home(name):
    h = pathlib.Path(tempfile.mkdtemp(prefix='fm-lab.'))
    homes.append(h)
    run(h, ROOT / 'bin/fm-lab-home.sh', 'create', h)
    shutil.copyfile(ROOT / '.tasks.toml', h / '.tasks.toml')
    (h / 'data/backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
    for o in ['origin-a','origin-b']:
        run(h, TASKS, 'add', o, 'Review ' + o, '--kind', 'scout', '--repo', 'sample')
        (h / ('state/' + o + '.meta')).write_text('kind=scout\nmode=scout\nproject=' + str(h / 'projects/sample') + '\nspawn_gen=live-' + name + '-' + o + '\n')
    (h / 'answer-a.txt').write_text('Release the work for A.\n')
    (h / 'answer-b.txt').write_text('Ship it for B.\n')
    return h

def permissions(h):
    os.chmod(h / 'data', 0o755)
    os.chmod(h / 'data/backlog.md', 0o644)

def snapshot(h):
    return run(h, TASKS, 'show', 'call', '--full').stdout

def refuse_b(h, phase):
    p=run(h, HOLD, 'complete', 'origin-b', 'call', success=False)
    assert 'decisions_reviewed=1' not in (h / 'state/origin-b.meta').read_text()
    with (h / 'state/origin-b.meta').open('a') as f:
        f.write('decisions_reviewed=1\ndecision_keys=call\n')
    run(h, HOLD, 'verify', 'origin-b', success=False)

def verify_a(h):
    run(h, HOLD, 'complete', 'origin-a', 'call')
    run(h, HOLD, 'verify', 'origin-a')

def scenario(name, function):
    emit('\n=== SCENARIO: ' + name + ' ===')
    try:
        function()
        results.append(dict(name=name,result='pass',live=True))
        emit('SCENARIO RESULT: pass')
    except Exception:
        error=traceback.format_exc()
        emit(error)
        results.append(dict(name=name,result='fail',live=True,reason=error))

def success_move():
    h=home('success')
    run(h,HOLD,'hold','call','--title','Decision call','--reason','Choose for A','--origin','origin-a')
    verify_a(h)
    run(h,HOLD,'answer','call','--release','--decision-file',h/'answer-a.txt')
    verify_a(h)
    run(h,HOLD,'hold','call','--reason','Choose for B','--origin','origin-b')
    s=snapshot(h)
    assert 'held: yes' in s and 'Captain hold origin: origin-b' in s and 'Captain hold origin: origin-a' not in s
    run(h,HOLD,'complete','origin-b','call')
    run(h,HOLD,'verify','origin-b')
    run(h,HOLD,'answer','call','--release','--decision-file',h/'answer-b.txt')
    run(h,HOLD,'complete','origin-b','call')
    run(h,HOLD,'verify','origin-b')

def failed_move(phase, fault):
    h=home(phase+'-'+fault)
    run(h,HOLD,'hold','call','--title','Decision call','--reason','Choose for A','--origin','origin-a')
    run(h,HOLD,'answer','call','--release','--decision-file',h/'answer-a.txt')
    if phase in ['active','expired']:
        args=['hold','call','--reason','Choose again for A','--origin','origin-a']
        if phase == 'expired': args += ['--until','2000-01-01']
        run(h,HOLD,*args)
    verify_a(h)
    try:
        p=run(h,HOLD,'hold','call','--reason','Choose for B','--origin','origin-b',fault=fault,success=False)
        if fault == 'interrupt': assert p.returncode == -15, p.returncode
        if fault == 'refuse':
            assert 'could not hold task call' in p.stderr
            assert 'could not restore the body' in p.stderr
    finally:
        permissions(h)
    s=snapshot(h)
    assert 'Captain hold origin: origin-a' in s and 'Captain hold origin: origin-b' not in s
    assert 'Captain hold set:' in s and 'Release the work for A.' in s
    assert ('held: yes' in s) == (phase == 'active')
    refuse_b(h, phase)
    if phase.startswith('released'):
        p=run(h,HOLD,'complete','origin-a','call',success=False)
        assert 'newer hold never completed' in p.stderr
        p=run(h,HOLD,'verify','origin-a',success=False)
        assert 'newer hold never completed' in p.stderr
        if phase == 'released-replay':
            run(h,HOLD,'answer','call','--release','--decision-file',h/'answer-a.txt')
        else:
            run(h,TASKS,'done','call','--keep','1')
        s=snapshot(h)
        assert 'Captain hold origin: origin-a' in s
        p=run(h,HOLD,'complete','origin-b','call',success=False)
        assert 'was held for origin origin-a, not origin-b' in p.stderr
        run(h,HOLD,'verify','origin-b',success=False)
    verify_a(h)
    if phase != 'released-done':
        run(h,HOLD,'hold','call','--reason','Choose for B','--origin','origin-b')
        run(h,HOLD,'complete','origin-b','call')
        run(h,HOLD,'verify','origin-b')

def parent_failure(phase):
    h=home('mate-'+phase)
    parent=home('parent-'+phase)
    if phase != 'new':
        run(h,HOLD,'hold','call','--title','Decision call','--reason','Choose for A','--origin','origin-a')
        if phase == 'released':
            run(h,HOLD,'answer','call','--release','--decision-file',h/'answer-a.txt')
    (h/'.fm-secondmate-home').write_text('origin-mate\n')
    (h/'.fm-secondmate-parent').write_text('schema=fm-secondmate-parent.v1\nroute=local\nparent_home=' + str(parent) + '\n')
    try:
        p=run(h,HOLD,'hold','call','--title','Decision call','--reason','Choose for B','--origin','origin-b',fault='origin-write',success=False)
        assert 'could not record the hold origin' in p.stderr
    finally:
        permissions(h)
    s=snapshot(h)
    assert 'held: yes' in s and 'hold_kind: captain' in s
    assert 'Captain hold origin: origin-b' not in s
    channel=parent/'state/origin-mate.status'
    content=channel.read_text()
    emit('Persisted parent channel after failed origin write:\n'+content)
    n=2 if phase=='released' else 1
    key=f'needs-decision [key=captain-hold-call-{n}]'
    assert content.count(key)==1 and 'Choose for B' in content
    run(h,HOLD,'hold','call','--reason','Choose for B','--origin','origin-b')
    content=channel.read_text()
    emit('Persisted parent channel after retry:\n'+content)
    assert content.count(key)==1
    run(h,HOLD,'complete','origin-b','call')
    run(h,HOLD,'verify','origin-b')

try:
    scenario('Successful reassociation and new answer verify only for the new origin',success_move)
    for phase in ['active','expired','released-replay','released-done']:
        for fault in ['interrupt','refuse']:
            scenario(f'{phase}: {fault} before backend hold retains A and refuses B',lambda phase=phase,fault=fault:failed_move(phase,fault))
    for phase in ['new','active','released']:
        scenario(f'Secondmate {phase} hold: origin-write failure still delivers one parent decision and retry deduplicates',lambda phase=phase:parent_failure(phase))
finally:
    for h in homes:
        try: permissions(h)
        except FileNotFoundError: pass
        shutil.rmtree(h)
    emit('All disposable homes removed; no default session, agent login, or fleet data used.')
    (EVIDENCE/'live-hold-origin-results.json').write_text(json.dumps(results,indent=2)+'\n')
    log.close()
raise SystemExit(1 if any(s['result']!='pass' for s in results) else 0)
