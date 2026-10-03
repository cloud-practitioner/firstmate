#!/usr/bin/env python3
"""Disposable real-CLI checks; no fake tasks-axi, backend, or gate bypass."""
import contextlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import traceback

ROOT = Path.cwd()
EVIDENCE = Path(__file__).parent
BASE = '2358151bc029052bb322d0ebbf8e039b273e463f'
base_env = {k: v for k, v in os.environ.items() if not k.startswith(('FM_', 'TASKS_AXI', 'TMUX', 'GIT_'))}
# Keep the active gate marker. Fixture homes, not a bypass, authorize lifecycle.
base_env['NO_MISTAKES_GATE'] = '1'
TEMP = Path(subprocess.check_output(['mktemp', '-d', str(ROOT / '.live-captain.XXXXXX')], text=True).strip())
base_env['TMPDIR'] = str(TEMP)
results = []
log = None


def command(argv, env, cwd=ROOT, expect=0):
    line = '$ ' + shlex.join(map(str, argv))
    if log:
        log.write(line + '\n')
        log.flush()
    p = subprocess.run(list(map(str, argv)), cwd=cwd, env=env, text=True, capture_output=True, timeout=90)
    if log:
        log.write(p.stdout)
        if p.stderr:
            log.write('[stderr]\n' + p.stderr)
        log.write(f'[exit {p.returncode}]\n\n')
        log.flush()
    if expect == 'nonzero':
        assert p.returncode != 0, f'expected refusal: {line}'
    elif expect is not None:
        assert p.returncode == expect, f'{line}: expected {expect}, got {p.returncode}: {p.stderr}'
    return p


def note(text):
    log.write(text + '\n\n')
    log.flush()


@contextlib.contextmanager
def home(name, variant='default'):
    path = Path(subprocess.check_output(['mktemp', '-d', str(TEMP / 'fm-lab.XXXXXX')], text=True).strip())
    env = dict(base_env, FM_HOME=str(path), FM_BACKEND='tmux', HOME=str(path / 'user-home'))
    try:
        command([ROOT / 'bin/fm-lab-home.sh', 'create', path], env)
        (path / 'user-home/.tasks-axi').mkdir(parents=True)
        (path / 'tmux').mkdir()
        config = 'backend = "markdown"\n\n[markdown]\npath = "data/backlog.md"\ndone_keep = 10\n'
        archive = path / 'data/done-archive.md'
        if variant == 'default':
            config += 'archive = "data/done-archive.md"\n'
        elif variant == 'unset':
            pass
        elif variant in ('inline-comment', 'project-precedence'):
            config += 'archive = "data/history.md" # retained answers\n'
            archive = path / 'data/history.md'
            if variant == 'project-precedence':
                (path / 'user-home/.tasks-axi/config.toml').write_text('[markdown]\narchive = "data/other-history.md"\n')
        elif variant == 'single-quoted':
            config += "  [ markdown ] # archive settings\n  archive = 'data/history # retained.md' # retained answers\n"
            archive = path / 'data/history # retained.md'
        elif variant == 'inherited':
            (path / 'user-home/.tasks-axi/config.toml').write_text("[markdown]\n  archive = 'data/home-history.md' # inherited archive\n")
            archive = path / 'data/home-history.md'
        elif variant == 'absolute':
            archive = path / 'history.md'
            config += f'archive = "{archive}" # absolute archive\n'
        else:
            raise ValueError(variant)
        (path / '.tasks.toml').write_text(config)
        (path / 'data/backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
        note(f'ISOLATION: {name}; marked lab FM_HOME={path}; HOME={env["HOME"]}; no FM_*_OVERRIDE, gate bypass, backend mocks, or real fleet data.')
        note('Effective input .tasks.toml:\n' + config)
        if (path / 'user-home/.tasks-axi/config.toml').exists():
            note('Isolated user config:\n' + (path / 'user-home/.tasks-axi/config.toml').read_text())
        yield path, env, archive
    finally:
        shutil.rmtree(path)
        note(f'TEARDOWN: removed disposable lab {path}')


def tasks(h, env, *args, expect=0):
    return command(['tasks-axi', *args], env, cwd=h, expect=expect)


def captain(h, env, *args, expect=0):
    return command([ROOT / 'bin/fm-captain-hold.sh', *args], env, expect=expect)


def origin(h, env, id='sample-review'):
    tasks(h, env, 'add', id, 'Investigate routing', '--kind', 'scout', '--repo', 'sample', '--start')
    # Public persisted metadata contract for a windowless leftover scout whose endpoint/worktree is gone.
    (h / f'state/{id}.meta').write_text(f'kind=scout\nworktree={h}/projects/missing-{id}\nproject={h}/projects/sample\nbranch=fm/{id}\nmode=no-mistakes\n')
    (h / f'state/{id}.status').write_text('done: report complete\n')
    (h / f'data/{id}').mkdir(parents=True)
    (h / f'data/{id}/report.md').write_text('# Routing investigation\n\nChoose route north or south.\n')
    return id


def hold(h, env, call, origin_id=None):
    args = ['hold', call, '--title', 'Choose route', '--reason', 'captain must choose north or south', '--repo', 'sample']
    if origin_id:
        args += ['--origin', origin_id]
    captain(h, env, *args)


def answer(h, env, call, release=False):
    file = h / 'answer.txt'
    file.write_text('Choose north.\n')
    args = ['answer', call, '--decision-file', str(file)]
    if release:
        args += ['--release']
    captain(h, env, *args)


def snapshot(h, archive, label):
    note(label + ' BACKLOG:\n' + (h / 'data/backlog.md').read_text())
    if archive.exists():
        note(label + ' ARCHIVE:\n' + archive.read_text())
    for meta in (h / 'state').glob('*.meta'):
        note(label + ' METADATA ' + meta.name + ':\n' + meta.read_text())


def closed_unanswered_refuses(h, env, id, call):
    before = (h / f'state/{id}.meta').read_bytes()
    p = captain(h, env, 'verify', id, expect='nonzero')
    assert call in p.stderr and 'recorded captain answer' in p.stderr
    p = captain(h, env, 'complete', id, call, expect='nonzero')
    assert call in p.stderr and 'recorded captain answer' in p.stderr
    p = command([ROOT / 'bin/fm-teardown.sh', id], env, expect='nonzero')
    assert 'captain-call completion gate' in p.stderr
    assert (h / f'state/{id}.meta').read_bytes() == before, 'refusal changed task metadata'
    assert (h / f'data/{id}/report.md').exists(), 'refusal lost scout report'
    note('OBSERVED: verify, complete and scout teardown all refused the unanswered call; source metadata is byte-identical and report survives.')


def scenario(key, name, fn):
    global log
    path = EVIDENCE / (key + '.log')
    with path.open('w') as log:
        note(name)
        try:
            fn()
            result = 'pass'
            reason = 'Real Firstmate and tasks-axi CLI commands produced the expected output and persisted state in disposable marked lab homes.'
        except Exception as exc:
            result = 'fail'
            reason = str(exc)
            note(traceback.format_exc())
        results.append(dict(name=name, result=result, live=True, evidence=str(path), reason=reason))
        print(f'{key}: {result}: {reason}', flush=True)
    log = None
    (EVIDENCE / 'captain-archive-results.json').write_text(json.dumps(results, indent=2) + '\n')


def archived_cleanup():
    with home('answered archived scout cleanup') as (h, env, archive):
        id = origin(h, env)
        call = 'sample-route'
        hold(h, env, call, id)
        captain(h, env, 'complete', id, call)
        answer(h, env, call)
        captain(h, env, 'verify', id)
        tasks(h, env, 'prune', '--keep', '0')
        tasks(h, env, 'show', call, '--full', expect='nonzero')
        assert 'Choose north.' in archive.read_text()
        captain(h, env, 'verify', id)
        captain(h, env, 'complete', id, call)
        snapshot(h, archive, 'BEFORE CLEANUP')
        command([ROOT / 'bin/fm-teardown.sh', id], env)
        show = tasks(h, env, 'show', id, '--full').stdout
        assert 'state: done' in show
        assert not (h / f'state/{id}.meta').exists()
        assert (h / f'data/{id}/report.md').exists()
        assert 'Choose north.' in archive.read_text()
        snapshot(h, archive, 'AFTER CLEANUP')
        note('OBSERVED: scout cleanup succeeded without force; metadata retired, scout backlog row Done, report and archived captain answer retained.')


def retained_done():
    with home('answered retained Done') as (h, env, archive):
        id = origin(h, env)
        call = 'sample-route'
        hold(h, env, call, id)
        captain(h, env, 'complete', id, call)
        answer(h, env, call)
        show = tasks(h, env, 'show', call, '--full').stdout
        assert 'state: done' in show and 'Choose north.' in show
        assert not archive.exists()
        captain(h, env, 'verify', id)
        captain(h, env, 'complete', id, call)
        snapshot(h, archive, 'RETAINED DONE ACCEPTED')


def open_status():
    with home('untransferred open decision prevents cleanup') as (h, env, archive):
        id = origin(h, env)
        captain(h, env, 'complete', id, '--none')
        with (h / f'state/{id}.status').open('a') as file:
            file.write('needs-decision [key=late-route]: choose north or south\n')
        before = (h / f'state/{id}.meta').read_bytes()
        captain(h, env, 'verify', id, expect='nonzero')
        captain(h, env, 'complete', id, '--none', expect='nonzero')
        command([ROOT / 'bin/fm-teardown.sh', id], env, expect='nonzero')
        assert before == (h / f'state/{id}.meta').read_bytes()
        hold(h, env, 'sample-route', id)
        captain(h, env, 'complete', id, 'sample-route')
        captain(h, env, 'verify', id)
        show = tasks(h, env, 'show', 'sample-route', '--full').stdout
        assert 'hold_kind: captain' in show and 'state: done' not in show
        snapshot(h, archive, 'OPEN CALL TRANSFERRED, NOT CLOSED')
        note('OBSERVED: new untransferred status decision blocks cleanup; completing its durable held inventory repairs the gate without falsely answering or closing the call (existing lifecycle contract).')


def configured_archives():
    for variant in ('default', 'unset', 'inline-comment', 'single-quoted', 'inherited', 'project-precedence', 'absolute'):
        with home('configured archive ' + variant, variant) as (h, env, archive):
            id = origin(h, env)
            call = id + '-decision-route'
            hold(h, env, call)
            captain(h, env, 'complete', id, call)
            answer(h, env, call)
            tasks(h, env, 'prune', '--keep', '0')
            assert archive.exists() and 'Choose north.' in archive.read_text()
            tasks(h, env, 'show', call, expect='nonzero')
            captain(h, env, 'verify', id)
            captain(h, env, 'complete', id, 'route')
            captain(h, env, 'verify', id)
            snapshot(h, archive, 'CONFIGURED ' + variant + ' EXACT/LEGACY ACCEPTED')


def unanswered_archive_precedence():
    for variant in ('no-old-row', 'archived-legacy', 'live-legacy-released', 'live-legacy-held', 'live-legacy-done', 'same-id-old-answer', 'empty-body'):
        with home('unanswered archived call over ' + variant) as (h, env, archive):
            id = origin(h, env)
            call = 'sample-route'
            old = call if variant == 'same-id-old-answer' else id + '-decision-' + call
            if variant not in ('no-old-row', 'empty-body'):
                hold(h, env, old, id)
                if variant != 'live-legacy-held':
                    answer(h, env, old, release=variant.startswith('live-legacy'))
                if not variant.startswith('live-legacy'):
                    tasks(h, env, 'prune', '--keep', '0')
            if variant == 'empty-body':
                tasks(h, env, 'add', call, 'Unanswered captain call', '--kind', 'captain', '--repo', 'sample')
                with (h / f'state/{id}.meta').open('a') as file:
                    file.write('decisions_reviewed=1\ndecision_keys=' + call + '\n')
            else:
                hold(h, env, call, id)
                captain(h, env, 'complete', id, call)
                captain(h, env, 'verify', id)
            tasks(h, env, 'done', call, '--keep', '0')
            if variant == 'live-legacy-done':
                tasks(h, env, 'done', old, '--keep', '10')
            tasks(h, env, 'show', call, expect='nonzero')
            if variant.startswith('live-legacy'):
                tasks(h, env, 'show', old, '--full')
            snapshot(h, archive, 'UNANSWERED EXACT ARCHIVE WITH ' + variant)
            closed_unanswered_refuses(h, env, id, call)


def current_over_archive():
    with home('current unanswered Done over older archived same-id answer') as (h, env, archive):
        id = origin(h, env)
        call = id + '-decision-route'
        hold(h, env, call)
        captain(h, env, 'complete', id, 'route')
        answer(h, env, call)
        tasks(h, env, 'prune', '--keep', '0')
        hold(h, env, call)
        tasks(h, env, 'done', call, '--keep', '10')
        tasks(h, env, 'show', call, '--full')
        snapshot(h, archive, 'CURRENT UNANSWERED DONE AND OLD ARCHIVED ANSWER')
        closed_unanswered_refuses(h, env, id, 'route')


def origin_boundary():
    with home('archived answer for other origin and missing identity') as (h, env, archive):
        id = origin(h, env)
        other = origin(h, env, 'sample-other-review')
        legacy = id + '-decision-sample-route'
        hold(h, env, legacy, other)
        answer(h, env, legacy, release=True)
        hold(h, env, 'sample-route', id)
        captain(h, env, 'complete', id, 'sample-route')
        answer(h, env, 'sample-route')
        tasks(h, env, 'prune', '--keep', '0')
        captain(h, env, 'verify', id)
        captain(h, env, 'complete', id, 'sample-route')
        captain(h, env, 'complete', other, 'sample-route', expect='nonzero')
        captain(h, env, 'complete', id, 'sample-missing-route', expect='nonzero')
        snapshot(h, archive, 'EXACT ANSWER WINS; OTHER ORIGIN/MISSING ID REFUSED')


def baseline_regression():
    with home('base commit regression') as (h, env, archive):
        id = origin(h, env)
        hold(h, env, 'sample-route', id)
        captain(h, env, 'complete', id, 'sample-route')
        answer(h, env, 'sample-route')
        tasks(h, env, 'prune', '--keep', '0')
        # Copy tracked script dependencies locally; never touch another checkout.
        base_root = TEMP / 'base-code'
        shutil.copytree(ROOT / 'bin', base_root / 'bin')
        note('$ git show ' + BASE + ':bin/fm-captain-hold.sh > disposable base-code/bin/fm-captain-hold.sh (materialized pre-fix CLI)')
        content = subprocess.check_output(['git', 'show', BASE + ':bin/fm-captain-hold.sh'], cwd=ROOT, env=env, text=True)
        (base_root / 'bin/fm-captain-hold.sh').write_text(content)
        p = command([base_root / 'bin/fm-captain-hold.sh', 'verify', id], env, expect='nonzero')
        assert 'resolves to nothing' in p.stderr or 'no captain-held task' in p.stderr
        captain(h, env, 'verify', id)
        snapshot(h, archive, 'SAME ARCHIVED ANSWER: BASE REFUSES, TARGET ACCEPTS')


try:
    for key, name, fn in [
        ('01-archived-cleanup', 'Answer and prune a captain call, then clean up its finished scout', archived_cleanup),
        ('02-retained-done', 'Keep an answered captain call in Done and complete/verify its scout inventory', retained_done),
        ('03-open-status', 'Open a new untransferred captain decision and attempt scout cleanup', open_status),
        ('04-archive-configuration', 'Prune answers using supported archive settings and resolve exact/legacy identities', configured_archives),
        ('05-unanswered-archive', 'Close without an answer and try to satisfy cleanup with missing, older, or legacy answers', unanswered_archive_precedence),
        ('06-current-row-precedence', 'Reuse an archived answered identity, close its new row unanswered, and attempt cleanup', current_over_archive),
        ('07-origin-boundary', 'Resolve an exact archived answer before a legacy row and reject wrong-origin or missing calls', origin_boundary),
        ('08-baseline-regression', 'Run pre-fix and fixed verify against the same real pruned answer', baseline_regression),
    ]:
        scenario(key, name, fn)
finally:
    shutil.rmtree(TEMP)
    print('Removed all disposable worktree fixtures.', flush=True)
sys.exit(1 if any(s['result'] == 'fail' for s in results) else 0)
