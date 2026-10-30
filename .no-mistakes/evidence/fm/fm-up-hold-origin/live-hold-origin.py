#!/usr/bin/env python3
"""Disposable live CLI checks: real fm-captain-hold + real tasks-axi.
Bash DEBUG barriers pause the actual CLI, never replace backend operations.
Failures use SIGTERM or filesystem permissions, not backend stubs.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path('/home/node/.no-mistakes/worktrees/5e28e613310e/01M659S8WG6KGGNCGWSPAJN2FC')
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M659S8WG6KGGNCGWSPAJN2FC')
BASELINE = os.environ.get('FM_LIVE_BASELINE') == '1'
CLI = Path(os.environ.get('FM_LIVE_CLI', str(ROOT / 'bin/fm-captain-hold.sh')))
ONLY_BOUNDARY = os.environ.get('FM_LIVE_ONLY') == 'origin-boundary'
PREFIX = 'before-fix' if BASELINE else ('origin-boundary-recheck' if ONLY_BOUNDARY else 'live-hold-origin')
SCRATCH = Path(tempfile.mkdtemp(prefix='.live-hold-origin-', dir=ROOT))
LOG = (EVIDENCE / (PREFIX + '.log')).open('w', buffering=1)
RESULTS = []
TASKS = shutil.which('tasks-axi')
ACTIVE = []

def note(s):
    LOG.write(s + '\n')
    print(s, flush=True)

def check(value, message):
    if not value:
        raise AssertionError(message)
    note('OBSERVED: ' + message)

def env(home):
    e = {k: v for k, v in os.environ.items()
         if not k.startswith(('FM_', 'TASKS_AXI', 'BD_', 'BASH_ENV', 'GIT_', 'XDG_'))}
    e.update(FM_HOME=str(home), HOME=str(SCRATCH / 'actor'),
             XDG_CONFIG_HOME=str(SCRATCH / 'actor/config'),
             XDG_CACHE_HOME=str(SCRATCH / 'actor/cache'),
             GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1',
             TASKS_AXI_BACKEND='markdown')
    return e

def run(home, args, expected=0, extra=None):
    e = env(home)
    if extra:
        e.update(extra)
    note('$ ' + ' '.join(map(str, args)))
    p = subprocess.run(list(map(str, args)), env=e, cwd=home, capture_output=True, text=True, timeout=40)
    note(p.stdout.rstrip())
    if p.stderr:
        note('stderr: ' + p.stderr.rstrip())
    note('exit=' + str(p.returncode))
    if expected == 'nonzero':
        check(p.returncode != 0, 'CLI refused the operation')
    elif expected is not None:
        if p.returncode != expected:
            raise AssertionError(f'expected exit {expected}, got {p.returncode}')
    return p

def tasks(home, *args, **kw):
    return run(home, [TASKS, *args], **kw)

def captain(home, *args, **kw):
    return run(home, [CLI, *args], **kw)

def new_home(name):
    home = SCRATCH / name
    run(ROOT, [ROOT / 'bin/fm-lab-home.sh', 'create', home])
    (home / '.tasks.toml').write_text('backend = "markdown"\n[markdown]\npath = "data/backlog.md"\narchive = "data/done-archive.md"\ndone_keep = 10\n')
    (home / 'data/backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
    for origin in ('origin-a', 'origin-b'):
        tasks(home, 'add', origin, 'Review ' + origin, '--kind', 'scout', '--repo', 'sample')
        (home / f'state/{origin}.meta').write_text(
            f'kind=scout\nmode=scout\nproject={home}/projects/sample\nworktree={home}/projects/{origin}\n')
    return home

def setup(name, phase='released'):
    home = new_home(name)
    captain(home, 'hold', 'call', '--title', 'Choose work', '--reason', 'Choose for A', '--origin', 'origin-a')
    decision = home / 'answer-a.txt'
    decision.write_text('Release this work for A.\n')
    captain(home, 'answer', 'call', '--release', '--decision-file', decision)
    if phase in ('active', 'expired'):
        args = ['hold', 'call', '--reason', 'Choose again for A', '--origin', 'origin-a']
        if phase == 'expired':
            args += ['--until', '2000-01-01']
        captain(home, *args)
    captain(home, 'complete', 'origin-a', 'call')
    captain(home, 'verify', 'origin-a')
    return home

def shown(home):
    return tasks(home, 'show', 'call', '--full').stdout

def verify_b_refused(home):
    p = captain(home, 'complete', 'origin-b', 'call', expected='nonzero')
    check('decisions_reviewed=1' not in (home / 'state/origin-b.meta').read_text(), 'refused completion wrote no B attestation')
    with (home / 'state/origin-b.meta').open('a') as f:
        f.write('decisions_reviewed=1\ndecision_keys=call\n')
    captain(home, 'verify', 'origin-b', expected='nonzero')
    return p

# DEBUG trap stops the real process immediately before the named public-shell
# operation. It does not evaluate implementation text or assert source shape.
BARRIER = SCRATCH / 'pause.bash'
BARRIER.write_text('''
set -T
fm_live_pause() {
  case "${FM_LIVE_BOUNDARY:-}:$BASH_COMMAND" in
    'hold:tasks_axi hold '*|'origin:write_hold_origin '*)
      trap - DEBUG
      printf '%s\\n' "$BASHPID" > "$FM_LIVE_BARRIER"
      kill -STOP "$BASHPID"
      ;;
  esac
}
trap fm_live_pause DEBUG
''')

def paused(home, boundary):
    marker = home / 'paused.pid'
    marker.unlink(missing_ok=True)
    e = env(home)
    e.update(BASH_ENV=str(BARRIER), FM_LIVE_BOUNDARY=boundary, FM_LIVE_BARRIER=str(marker))
    cmd = [str(CLI), 'hold', 'call', '--reason', 'Choose for B', '--origin', 'origin-b']
    note('$ [real CLI paused before ' + boundary + '] ' + ' '.join(cmd))
    out = (home / 'paused.stdout').open('w')
    err = (home / 'paused.stderr').open('w')
    p = subprocess.Popen(cmd, cwd=home, env=e, stdout=out, stderr=err, start_new_session=True)
    ACTIVE.append(p)
    end = time.monotonic() + 30
    while time.monotonic() < end:
        if marker.exists():
            pid = int(marker.read_text())
            # Barrier file is written just before STOP; wait for stopped state.
            for _ in range(100):
                status = Path(f'/proc/{pid}/status').read_text()
                if 'State:\tT' in status:
                    return p, pid
                time.sleep(.01)
        if p.poll() is not None:
            raise AssertionError('CLI exited before barrier: ' + (home / 'paused.stderr').read_text())
        time.sleep(.01)
    raise AssertionError('CLI did not reach pause boundary')

def finish(home, p, pid, terminate=False):
    if terminate:
        note('FAULT: SIGTERM to actual CLI while stopped before backend hold')
        os.killpg(p.pid, signal.SIGTERM)
    os.kill(pid, signal.SIGCONT)
    rc = p.wait(timeout=45)
    note((home / 'paused.stdout').read_text().rstrip())
    note('stderr: ' + (home / 'paused.stderr').read_text().rstrip())
    note('exit=' + str(rc))
    ACTIVE.remove(p)
    return rc

def readonly(home, yes):
    (home / 'data/backlog.md').chmod(0o400 if yes else 0o600)
    (home / 'data').chmod(0o500 if yes else 0o700)
    note('FAULT: ' + ('remove' if yes else 'restore') + ' write permission on isolated backlog and data directory')

def successful_ordering():
    home = setup('success')
    p, pid = paused(home, 'hold')
    state = shown(home)
    check('Captain hold origin: origin-a' in state and 'Captain hold origin: origin-b' not in state,
          'before backend hold the task still belongs to A')
    check('held: no' in state, 'before backend hold released A is not held')
    check(finish(home, p, pid) == 0, 'move completes successfully')
    state = shown(home)
    check('held: yes' in state and 'Captain hold origin: origin-b' in state, 'successful move has a live hold and B association')
    captain(home, 'complete', 'origin-b', 'call')
    captain(home, 'verify', 'origin-b')
    answer = home / 'answer-b.txt'
    answer.write_text('Ship it for B.\n')
    captain(home, 'answer', 'call', '--release', '--decision-file', answer)
    captain(home, 'complete', 'origin-b', 'call')
    captain(home, 'verify', 'origin-b')
    state = shown(home)
    check('Ship it for B.' in state and 'held: no' in state, 'B answer is persisted and work released')

def failed_moves(mode):
    for phase in ('active', 'expired', 'released-replay', 'released-done'):
        note('\nCASE: ' + mode + ' / ' + phase)
        home = setup(mode + '-' + phase, phase)
        p, pid = paused(home, 'hold')
        if mode == 'refused':
            readonly(home, True)
        rc = finish(home, p, pid, terminate=(mode == 'interrupted'))
        if mode == 'refused':
            readonly(home, False)
        check(rc != 0, 'failed move returns nonzero')
        if mode == 'refused':
            errors = (home / 'paused.stderr').read_text()
            check('could not restore the body' in errors and 'could not hold task' in errors,
                  'real backend hold AND rollback writes failed')
        state = shown(home)
        check('Captain hold origin: origin-a' in state and 'Captain hold origin: origin-b' not in state,
              'failed move retains only the original A association')
        check('Release this work for A.' in state, 'old answer survives the failed move')
        if phase == 'active':
            check('held: yes' in state, 'A active hold survives')
        else:
            check('held: no' in state, 'failed move creates no live hold')
        if phase == 'expired':
            check('hold_kind: captain' in state, 'expired A retains captain annotations')
        verify_b_refused(home)
        if phase.startswith('released-'):
            refusal = captain(home, 'complete', 'origin-a', 'call', expected='nonzero')
            check('newer hold never completed' in refusal.stderr, 'durability boundary refuses old answer below incomplete stamp')
            captain(home, 'verify', 'origin-a', expected='nonzero')
            if phase == 'released-replay':
                captain(home, 'answer', 'call', '--release', '--decision-file', home / 'answer-a.txt')
            else:
                tasks(home, 'done', 'call', '--keep', '1')
            refusal = captain(home, 'complete', 'origin-b', 'call', expected='nonzero')
            check('was held for origin origin-a, not origin-b' in refusal.stderr,
                  'replaying old answer / completing work still cannot certify B')
            captain(home, 'verify', 'origin-b', expected='nonzero')
        captain(home, 'complete', 'origin-a', 'call')
        captain(home, 'verify', 'origin-a')
        if phase != 'released-done':
            captain(home, 'hold', 'call', '--reason', 'Choose for B', '--origin', 'origin-b')
            captain(home, 'complete', 'origin-b', 'call')
            captain(home, 'verify', 'origin-b')

def secondmate_write_failure():
    for phase in ('new', 'active', 'released'):
        note('\nCASE: origin-write failure / ' + phase)
        home = new_home('mate-new') if phase == 'new' else setup('mate-' + phase, phase)
        parent = SCRATCH / ('parent-' + phase)
        run(ROOT, [ROOT / 'bin/fm-lab-home.sh', 'create', parent])
        (home / '.fm-secondmate-home').write_text('origin-mate\n')
        (home / '.fm-secondmate-parent').write_text(f'schema=fm-secondmate-parent.v1\nroute=local\nparent_home={parent}\n')
        if phase == 'new':
            tasks(home, 'add', 'call', 'Choose work', '--kind', 'captain', '--repo', 'sample')
        p, pid = paused(home, 'origin')
        state = shown(home)
        check('held: yes' in state and 'hold_kind: captain' in state, 'backend hold is live before origin publication')
        check('Captain hold origin: origin-b' not in state, 'B not published yet')
        channel = parent / 'state/origin-mate.status'
        check(channel.exists(), 'parent event exists BEFORE origin publication attempt')
        note('PARENT CHANNEL BEFORE ORIGIN WRITE:\n' + channel.read_text())
        check('needs-decision [key=captain-hold-call-' in channel.read_text(), 'parent receives needs-decision')
        before = channel.read_text()
        readonly(home, True)
        rc = finish(home, p, pid)
        readonly(home, False)
        check(rc != 0 and 'could not record the hold origin' in (home / 'paused.stderr').read_text(),
              'actual origin write fails and command returns nonzero')
        state = shown(home)
        check('held: yes' in state and 'Captain hold origin: origin-b' not in state,
              'failed origin write leaves real hold without claiming B')
        captain(home, 'hold', 'call', '--reason', 'Choose for B', '--origin', 'origin-b')
        check(channel.read_text() == before, 'retry does not duplicate parent event')
        captain(home, 'complete', 'origin-b', 'call')
        captain(home, 'verify', 'origin-b')
        note('PARENT CHANNEL AFTER RETRY:\n' + channel.read_text())

def invalid_origin():
    home = setup('origin-boundary')
    before = shown(home)
    captain(home, 'hold', 'call', '--reason', 'Choose for invalid origin', '--origin', '../outside-home', expected='nonzero')
    check(shown(home) == before, 'invalid origin slug leaves released task completely unchanged')
    captain(home, 'complete', 'origin-a', 'call')
    captain(home, 'verify', 'origin-a')

def baseline_reproduction():
    home = setup('before-fix')
    p, pid = paused(home, 'hold')
    state = shown(home)
    check('Captain hold origin: origin-b' in state and 'held: no' in state,
          'BEFORE FIX: new B origin published despite no backend hold')
    check(finish(home, p, pid, terminate=True) != 0, 'old command interrupted before backend hold')
    state = shown(home)
    check('Release this work for A.' in state and 'Captain hold origin: origin-b' in state,
          'BEFORE FIX: interrupted move associates A answer with B')
    captain(home, 'complete', 'origin-b', 'call')
    captain(home, 'verify', 'origin-b')
    note('BASELINE BUG REPRODUCED: complete and verify accepted A answer for unheld B')

try:
    (SCRATCH / 'actor/config').mkdir(parents=True)
    scenarios = [
        ('Before-fix CLI wrongly certifies B using A answer', baseline_reproduction)
    ] if BASELINE else [
        ('Successful origin move and genuine B answer', successful_ordering),
        ('Interrupted active, expired, and released origin moves', lambda: failed_moves('interrupted')),
        ('Backend and rollback failure, old-answer replay and work completion', lambda: failed_moves('refused')),
        ('Secondmate delivery survives origin-write failure and retry', secondmate_write_failure),
        ('Invalid origin slug cannot alter existing call', invalid_origin),
    ]
    if ONLY_BOUNDARY:
        scenarios = [('Invalid origin slug cannot alter existing call', invalid_origin)]
    for name, fn in scenarios:
        note('\n===== ' + name + ' =====')
        start = time.monotonic()
        try:
            fn()
            RESULTS.append(dict(name=name, result='pass', live=True, seconds=round(time.monotonic()-start, 2)))
            note('SCENARIO PASS: ' + name)
        except Exception as exc:
            RESULTS.append(dict(name=name, result='fail', live=True, error=str(exc)))
            note('SCENARIO FAIL: ' + name + ': ' + str(exc))
            raise
finally:
    for p in ACTIVE:
        try:
            os.killpg(p.pid, signal.SIGCONT)
            os.killpg(p.pid, signal.SIGTERM)
            p.wait(timeout=10)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            pass
    for folder, dirs, files in os.walk(SCRATCH):
        os.chmod(folder, 0o700)
        for file in files:
            os.chmod(Path(folder) / file, 0o600)
    shutil.rmtree(SCRATCH)
    note('CLEANUP: disposable live homes removed from worktree')
    (EVIDENCE / (PREFIX + '-results.json')).write_text(json.dumps(RESULTS, indent=2) + '\n')
    LOG.close()
