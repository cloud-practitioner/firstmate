#!/usr/bin/env python3
"""Disposable product verification; no vendor/backend/forge is mocked."""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path.cwd()
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M4M3HQQZPRX4BQKNZYCRM1HR')
LAB = ROOT / '.test-local/labs'
BASE = ROOT / '.test-local/runtime-base'
NOW = '2026-10-10T12:00:00Z'
URL = 'https://github.com/disposable-fixture/not-a-live-repository/pull/6830'
HEAD = 'a' * 40
LOG = []
RESULTS = []

def log(message):
    print(message, flush=True)
    LOG.append(message)

def home(name):
    path = LAB / name
    for child in ('data', 'state', 'config', 'projects', 'tmp', 'userhome', 'gh-config'):
        (path / child).mkdir(parents=True, exist_ok=True)
    return path

def env(path, tmp=None):
    return {'PATH': os.environ['PATH'], 'HOME': str(path / 'userhome'),
            'GH_CONFIG_DIR': str(path / 'gh-config'), 'LANG': 'C.UTF-8',
            'FM_HOME': str(path), 'TMPDIR': str(tmp or path / 'tmp'),
            'FM_SNAPSHOT_NOW': NOW, 'FM_CONTRIBUTIONS_NOW': NOW}

def run(path, args, code=ROOT, tmp=None):
    command = ['bash', str(code / 'bin' / args[0]), *args[1:]]
    start = time.monotonic()
    out = subprocess.run(command, cwd=ROOT, env=env(path, tmp), text=True,
                         capture_output=True, timeout=240)
    log(f"$ {' '.join(args)} [home={path.name}; code={'base' if code == BASE else 'head'}]\n"
        f"exit={out.returncode}; elapsed={time.monotonic()-start:.2f}s; stdout_bytes={len(out.stdout.encode())}\n"
        f"stderr={out.stderr.strip() or '<empty>'}")
    return out

def check(condition, message):
    if not condition:
        raise AssertionError(message)
    log('Verified: ' + message)

def state_digest(path):
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for top in ('data', 'state', 'config', 'projects')
            for p in (path / top).rglob('*') if p.is_file()}

def save(label, data):
    (EVIDENCE / label).write_text(json.dumps(data, indent=2) + '\n')

def snapshot(path):
    out = run(path, ['fm-fleet-snapshot.sh', '--contribution-input'])
    check(out.returncode == 0, 'canonical contribution input exits successfully')
    return json.loads(out.stdout)

def scenario(name, fn):
    log('\nSCENARIO: ' + name)
    try:
        fn()
        RESULTS.append({'name': name, 'result': 'pass'})
    except Exception as ex:
        log('FAILURE: ' + repr(ex))
        RESULTS.append({'name': name, 'result': 'fail', 'reason': repr(ex)})
    finally:
        (EVIDENCE / 'contribution-live-transcript.log').write_text('\n'.join(LOG) + '\n')
        save('contribution-live-results.json', RESULTS)


def large_backlog():
    path = home('large-backlog')
    titles = [f'Fixture contribution {i:03d} ' + ('payload-%03d-' % i) * 70 for i in range(180)]
    lines = ['# Backlog', '', '## Queued'] + [
        f'- [ ] task-{i:03d} - {title} (repo: disposable) (kind: ship)'
        for i, title in enumerate(titles)]
    (path / 'data/backlog.md').write_text('\n'.join(lines) + '\n')
    before = state_digest(path)
    data = snapshot(path)
    rows = data['backlog']['records']
    check(len(rows) == 180 and [r['id'] for r in rows] == [f'task-{i:03d}' for i in range(180)],
          'all 180 backlog records retain their order and identities')
    check([r['title'] for r in rows] == titles and all(r['kind'] == 'ship' for r in rows),
          'long titles and structured kind metadata are preserved exactly')
    size = len(json.dumps(data['backlog'], indent=2).encode())
    check(size > 131072, f'backlog JSON exceeds Linux single-argument boundary: {size} bytes')
    check(data['tasks'] == [], 'no task metadata is invented')
    save('large-backlog-contribution-input.json', data)
    old = run(path, ['fm-fleet-snapshot.sh', '--contribution-input'], BASE)
    check(not old.stdout.strip() and 'Argument list too long' in old.stderr,
          'same disposable input reproduces the pre-merge argv failure (base also masks its failing jq exit)')
    check(not list((path / 'tmp').iterdir()), 'success and baseline failure leave no temporary files')
    check(state_digest(path) == before, 'contribution input does not mutate operational data/state')
    # Poll the real observer on this oversized input without any forge-owned URL.
    polled = run(path, ['fm-contributions.sh', 'poll'])
    check(polled.returncode == 0 and not polled.stdout.strip(),
          'real contribution poll consumes oversized backlog without error or invented signals')
    check(not list((path / 'tmp').iterdir()), 'observer and transport temporary files are removed')


def large_tasks():
    path = home('large-tasks')
    (path / 'data/backlog.md').write_text('# Backlog\n\n## Queued\n')
    for i in range(720):
        (path / f'state/ship-{i:04d}.meta').write_text(
            f'kind=ship\npr={URL}\npr_head={HEAD}\n')
    before = state_digest(path)
    data = snapshot(path)
    tasks = data['tasks']
    check(len(tasks) == 720 and [t['id'] for t in tasks] == [f'ship-{i:04d}' for i in range(720)],
          'all 720 task records retain sorted identities')
    check(all(t['kind'] == 'ship' and t['pr'] == {'url': URL, 'head': HEAD} and
              t['merge_authority'] == 'attended' for t in tasks),
          'task kind, PR URL/head, and attended authority context remain intact')
    size = len(json.dumps(tasks, indent=2).encode())
    check(size > 131072, f'task JSON independently exceeds single-argument boundary: {size} bytes')
    save('large-task-contribution-input.json', data)
    old = run(path, ['fm-fleet-snapshot.sh', '--contribution-input'], BASE)
    check(not old.stdout.strip() and 'Argument list too long' in old.stderr,
          'oversized task document independently reproduces the pre-merge argv failure')
    check(state_digest(path) == before, 'large metadata read does not change fleet state')
    check(not list((path / 'tmp').iterdir()), 'large task transport cleans its temporary directory')


def normal_and_parallel():
    path = home('normal')
    (path / 'data/backlog.md').write_text(
        '# Backlog\n\n## Queued\n'
        f'- [ ] delivery - Published contribution {URL} (repo: disposable) (kind: ship)\n')
    (path / 'state/delivery.meta').write_text(f'kind=ship\npr={URL}\npr_head={HEAD}\n')
    record = {'schema': 'fm-contributions.v1', 'task': 'delivery', 'records': [{
        'url': URL, 'kind': 'pr', 'checked_at': NOW, 'error': None, 'pending': [],
        'seen': [], 'verdict': None, 'observation': {'head': HEAD, 'state': 'merged',
        'draft': False, 'mergeable': 'mergeable', 'review_decision': 'APPROVED',
        'can_merge': False, 'checks': [], 'reviews': [], 'events': []}}]}
    (path / 'data/delivery').mkdir()
    (path / 'data/delivery/contributions.json').write_text(json.dumps(record) + '\n')
    before = state_digest(path)
    data = snapshot(path)
    save('normal-contribution-input.json', data)
    old = run(path, ['fm-fleet-snapshot.sh', '--contribution-input'], BASE)
    check(old.returncode == 0 and json.loads(old.stdout) == data,
          'normal ownership-pair output is semantically identical before and after merge')
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        parallel = list(executor.map(lambda _: snapshot(path), range(4)))
    check(all(item == data for item in parallel),
          'four concurrent real snapshot calls return identical canonical ownership pairs')
    out = run(path, ['fm-contributions.sh', 'snapshot', str(EVIDENCE / 'normal-contribution-input.json'), '--all'])
    check(out.returncode == 0, 'real contribution projection consumes the ownership pair')
    projection = json.loads(out.stdout)
    save('normal-contribution-projection.json', projection)
    check(projection['known'] == 1 and projection['checked'] == 1 and
          projection['complete'] is True and projection['counts']['nobody'] == 1,
          'persisted merged contribution is measured as final, without captain/fleet work')
    out = run(path, ['fm-contributions.sh', 'poll'])
    check(out.returncode == 0 and not out.stdout.strip(),
          'real poll accepts canonical input and settles existing final observation without a forge read')
    check(state_digest(path) == before, 'local observation does not change the final record or backlog')
    check(not list((path / 'tmp').iterdir()), 'parallel calls, projection and poll remove all temp files')


def failed_tempdir():
    path = home('failed-tempdir')
    (path / 'data/backlog.md').write_text('# Backlog\n\n## Queued\n- [ ] task - Retain me (kind: ship)\n')
    before = state_digest(path)
    out = run(path, ['fm-fleet-snapshot.sh', '--contribution-input'], tmp=path / 'nonexistent/tmp')
    check(out.returncode != 0 and not out.stdout.strip() and
          'contribution temp dir failed' in out.stderr,
          'unavailable temporary directory refuses output and names the failed transport')
    check(state_digest(path) == before and not (path / 'nonexistent').exists(),
          'failed staging leaves operational state unchanged and creates no fallback files')

try:
    scenario('Oversized backlog remains lossless and usable by contribution poll', large_backlog)
    scenario('Oversized task metadata remains lossless', large_tasks)
    scenario('Normal and concurrent reads preserve ownership and final observation', normal_and_parallel)
    scenario('Unavailable temporary storage fails closed without state changes', failed_tempdir)
finally:
    shutil.rmtree(LAB)
    log('\nDisposable live homes removed; no lifecycle or forge operations were used.')
    (EVIDENCE / 'contribution-live-transcript.log').write_text('\n'.join(LOG) + '\n')
    save('contribution-live-results.json', RESULTS)
raise SystemExit(0 if all(r['result'] == 'pass' for r in RESULTS) else 1)
