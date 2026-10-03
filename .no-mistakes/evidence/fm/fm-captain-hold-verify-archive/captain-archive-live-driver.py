#!/usr/bin/env python3
"""Disposable CLI validation. Product commands are real; only task data is synthetic."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

ROOT = Path.cwd()
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M3ZYE1DS003X0Y14YX40P7WY')
EVIDENCE.mkdir(parents=True, exist_ok=True)
TOOLS = ROOT / '.fm-live-validation/tools/tmux-local'
BASELINE = ROOT / 'bin/.fm-captain-hold-before-test.sh'
BASELINE.write_bytes(subprocess.check_output(['git', 'show', 'e42087e4513c4483d832aa8898b28efd410fdac8:bin/fm-captain-hold.sh']))
BASELINE.chmod(0o700)
LOG = []
RESULTS = []
HOMES = []
BASEENV = {k: v for k, v in os.environ.items() if not k.startswith(('FM_', 'HERDR_', 'TASKS_AXI_', 'TMUX', 'BD_'))}
BASEENV['PATH'] = str(TOOLS / 'usr/bin') + ':' + BASEENV['PATH']
BASEENV['LD_LIBRARY_PATH'] = str(TOOLS / 'usr/lib/x86_64-linux-gnu')
BASEENV['TERM'] = 'xterm-256color'


def run(env, cmd, expected=0):
    p = subprocess.run([str(x) for x in cmd], cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
    LOG.append('$ ' + shlex.join(str(x) for x in cmd) + '\n' + p.stdout + p.stderr + f'[exit {p.returncode}]\n')
    if expected == 'nonzero':
        assert p.returncode != 0, f'Expected refusal: {cmd}'
    else:
        assert p.returncode == expected, f'Unexpected exit {p.returncode}: {cmd}\n{p.stdout}{p.stderr}'
    return p


def record(label, text):
    LOG.append(f'--- {label} ---\n{text}\n')


def home(variant):
    h = Path(tempfile.mkdtemp(prefix='l.', dir=ROOT))
    HOMES.append(h)
    env = BASEENV.copy()
    env.update(FM_HOME=str(h), HOME=str(h / 'user-home'), TMPDIR=str(h / 'tmp'),
               XDG_CONFIG_HOME=str(h / 'user-home/config'), XDG_STATE_HOME=str(h / 'user-home/state'),
               XDG_DATA_HOME=str(h / 'user-home/data'), XDG_CACHE_HOME=str(h / 'user-home/cache'))
    run(env, [ROOT / 'bin/fm-lab-home.sh', 'create', h])
    for d in ('user-home/.tasks-axi', 'tmp', 'tmux'):
        (h / d).mkdir(parents=True, exist_ok=True)
    config = 'backend = "markdown"\n\n[markdown]\npath = "data/backlog.md"\ndone_keep = 10\n'
    archive = h / 'data/done-archive.md'
    if variant == 'default':
        config += 'archive = "data/done-archive.md"\n'
    elif variant in ('inline-comment', 'project-precedence'):
        config += 'archive = "data/history.md" # retained answers\n'
        archive = h / 'data/history.md'
        if variant == 'project-precedence':
            (h / 'user-home/.tasks-axi/config.toml').write_text('[markdown]\narchive = "data/other-history.md"\n')
            (h / 'data/other-history.md').write_text('# Wrong archive: must not be selected\n')
    elif variant == 'single-quoted':
        config += "  [ markdown ] # archive settings\n  archive = 'data/history # retained.md' # retained answers\n"
        archive = h / 'data/history # retained.md'
    elif variant == 'inherited':
        (h / 'user-home/.tasks-axi/config.toml').write_text("[markdown]\n  archive = 'data/home-history.md' # retained answers\n")
        archive = h / 'data/home-history.md'
    elif variant == 'absolute':
        archive = h / 'history.md'
        config += f'archive = "{archive}" # retained answers\n'
    elif variant != 'unset':
        raise ValueError(variant)
    (h / '.tasks.toml').write_text(config)
    (h / 'data/backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
    record(f'{variant}: project tasks-axi configuration', config)
    return h, env, archive


def captain(env, *args, expected=0, baseline=False):
    return run(env, [BASELINE if baseline else ROOT / 'bin/fm-captain-hold.sh', *args], expected)


def tasks(env, *args, expected=0):
    return run(env, [ROOT / 'bin/fm-tasks-axi.sh', *args], expected)


def origin(h, env, name='live-review'):
    tasks(env, 'add', name, 'Review archive cleanup', '--kind', 'scout', '--repo', 'sample')
    (h / f'data/{name}').mkdir()
    (h / f'data/{name}/report.md').write_text('# Completed investigation\n\nThe captain chose the retained option.\n')
    (h / f'state/{name}.status').write_text('done: report complete\n')
    (h / f'state/{name}.meta').write_text(f'window=fixture:fm-{name}\nworktree={h}/projects/retired-{name}\nproject={h}/projects/sample\nharness=codex\nkind=scout\nmode=scout\nspawn_gen=validation-{name}\n')
    tasks(env, 'start', name)
    return name


def state_hash(h):
    return {str(p.relative_to(h)): hashlib.sha256(p.read_bytes()).hexdigest()
            for root in (h / 'data', h / 'state') for p in root.rglob('*') if p.is_file()}


def check_variant(variant):
    h, env, archive = home(variant)
    name = origin(h, env)
    call = f'{name}-decision-route'
    captain(env, 'hold', call, '--title', 'Choose the route', '--reason', 'Captain route choice pending', '--repo', 'sample')
    captain(env, 'complete', name, call)
    answer = h / 'answer.txt'
    answer.write_text('Choose route north; the investigation may be cleaned up.\n')
    captain(env, 'answer', call, '--decision-file', answer)
    shown = tasks(env, 'show', call, '--full').stdout
    assert 'state: done' in shown and 'Captain decision:' in shown
    before = state_hash(h)
    captain(env, 'verify', name)
    assert state_hash(h) == before, 'Retained Done verification changed durable state'
    captain(env, 'complete', name, call)
    tasks(env, 'prune', '--keep', '0')
    tasks(env, 'show', call, '--full', expected='nonzero')
    assert archive.is_file(), f'Real tasks-axi did not produce expected archive: {archive}'
    record(f'{variant}: tasks-axi persisted archive', archive.read_text())
    if variant == 'default':
        captain(env, 'verify', name, expected='nonzero', baseline=True)
    before = state_hash(h)
    captain(env, 'verify', name)
    assert state_hash(h) == before, 'Archived verification changed durable state'
    captain(env, 'complete', name, call)
    with (h / f'state/{name}.meta').open('a') as f:
        f.write('decision_keys=route\n')
    captain(env, 'verify', name)
    captain(env, 'complete', name, 'route')
    record(f'{variant}: attestation persisted after archived legacy-key completion', (h / f'state/{name}.meta').read_text())

    if variant == 'default':
        # Reintroduced exact id is authoritative over its earlier archived answer.
        tasks(env, 'add', call, 'Reopened route needing an answer', '--kind', 'captain', '--repo', 'sample')
        captain(env, 'hold', call, '--reason', 'New captain choice remains unanswered')
        tasks(env, 'done', call, '--keep', '10')
        tasks(env, 'show', call, '--full')
        captain(env, 'verify', name, expected='nonzero', baseline=True)
        # Capture the observed regression without preventing the remaining scenarios.
        captain(env, 'verify', name)
        captain(env, 'complete', name, 'route')
        captain(env, 'complete', name, call, expected='nonzero')
        RESULTS.append({'scenario': 'live legacy row overrides stale archived answer', 'result': 'fail',
                        'reason': 'Legacy-key verify and complete accept the stale archive instead of rejecting the current Done row with no recorded answer; baseline verify refuses.'})
        record('PRODUCT FAILURE: legacy archive lookup bypasses current unanswered Done row',
               'Current verify and complete(route) exit 0; baseline verify exits 1. Complete(full task id) correctly exits 1.')
        tasks(env, 'rm', call)
        captain(env, 'verify', name)

        # Keep the real, finished scout pane on a private server; never touch a default socket.
        run(env, ['tmux', '-f', '/dev/null', '-L', 'fm-lab', 'new-session', '-d', '-s', 'fixture', '-n', f'fm-{name}', '-x', '120', '-y', '40', '-c', ROOT, 'bash --noprofile --norc'])
        tmux_identity = run(env, ['tmux', '-L', 'fm-lab', 'display-message', '-p', '-t', 'fixture', '#{socket_path},#{pid},0']).stdout.strip()
        env['TMUX'] = tmux_identity
        env['TMUX_TMPDIR'] = str(h / 'tmux')
        # Late unresolved status remains blocking despite the old archived answer.
        with (h / f'state/{name}.status').open('a') as f:
            f.write('needs-decision [key=late-call]: A new choice has no durable owner\n')
        before = state_hash(h)
        captain(env, 'verify', name, expected='nonzero')
        assert state_hash(h) == before
        refused = run(env, [ROOT / 'bin/fm-teardown.sh', name], expected='nonzero')
        assert 'captain-call completion gate' in refused.stderr
        assert (h / f'state/{name}.meta').is_file()
        assert (h / f'data/{name}/report.md').is_file()
        run(env, ['tmux', '-L', 'fm-lab', 'has-session', '-t', 'fixture'])
        # Transfer the genuinely unresolved call, answer it, archive it, then clean up.
        captain(env, 'hold', 'late-call', '--title', 'Decide the late choice', '--reason', 'Captain choice still pending', '--repo', 'sample')
        captain(env, 'complete', name, 'late-call')
        captain(env, 'answer', 'late-call', '--decision-file', answer)
        tasks(env, 'prune', '--keep', '0')
        captain(env, 'verify', name)
        run(env, [ROOT / 'bin/fm-teardown.sh', name])
        assert not (h / f'state/{name}.meta').exists(), 'Cleanup retained scout metadata'
        assert (h / f'data/{name}/report.md').is_file(), 'Cleanup lost the report'
        shown = tasks(env, 'show', name, '--full').stdout
        assert 'state: done' in shown and f'data/{name}/report.md' in shown
        run(env, ['tmux', '-L', 'fm-lab', 'has-session', '-t', 'fixture'], expected='nonzero')
        record('scout cleanup persisted state', f'metadata absent; report retained; private scout pane gone\n{shown}')

    # A closed row with no captain resolution never becomes accepted simply by pruning it.
    other = origin(h, env, 'unanswered-review')
    tasks(env, 'add', 'unanswered-call', 'No captain answer', '--kind', 'captain', '--repo', 'sample')
    with (h / f'state/{other}.meta').open('a') as f:
        f.write(f'decisions_reviewed=1\ndecision_keys={call},unanswered-call\n')
    tasks(env, 'done', 'unanswered-call', '--keep', '10')
    captain(env, 'verify', other, expected='nonzero')
    captain(env, 'complete', other, 'unanswered-call', expected='nonzero')
    tasks(env, 'prune', '--keep', '0')
    before = state_hash(h)
    captain(env, 'verify', other, expected='nonzero')
    assert state_hash(h) == before, 'Refused verification changed state'
    captain(env, 'complete', other, 'unanswered-call', expected='nonzero')
    record(f'{variant}: archived unanswered persisted row', archive.read_text())
    # Fresh origin cannot attest an untransferred open status as --none.
    fresh = origin(h, env, 'open-review')
    with (h / f'state/{fresh}.status').open('a') as f:
        f.write('needs-decision [key=still-open]: Choose the unresolved option\n')
    captain(env, 'complete', fresh, '--none', expected='nonzero')
    assert 'decisions_reviewed=1' not in (h / f'state/{fresh}.meta').read_text()
    RESULTS.append({'variant': variant, 'result': 'pass', 'archive': str(archive)})

try:
    # TMUX_TMPDIR is installed separately per fixture by the launcher below.
    original_run = run
    def run(env, cmd, expected=0):
        env = env.copy()
        if env.get('FM_HOME'):
            env['TMUX_TMPDIR'] = str(Path(env['FM_HOME']) / 'tmux')
        return original_run(env, cmd, expected)
    for variant in ('default', 'unset', 'inline-comment', 'single-quoted', 'inherited', 'project-precedence', 'absolute'):
        check_variant(variant)
except Exception as exc:
    record('VALIDATION FAILED', repr(exc))
    raise
finally:
    for h in HOMES:
        env = BASEENV.copy()
        env.update(HOME=str(h / 'user-home'), TMUX_TMPDIR=str(h / 'tmux'))
        subprocess.run(['tmux', '-L', 'fm-lab', 'kill-server'], cwd=ROOT, env=env, capture_output=True)
        shutil.rmtree(h)
    BASELINE.unlink(missing_ok=True)
    (EVIDENCE / 'captain-archive-live-cli.log').write_text('\n'.join(LOG))
    (EVIDENCE / 'captain-archive-live-results.json').write_text(json.dumps(RESULTS, indent=2) + '\n')
print(json.dumps(RESULTS, indent=2))
