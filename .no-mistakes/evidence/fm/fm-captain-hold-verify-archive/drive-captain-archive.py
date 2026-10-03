#!/usr/bin/env python3
"""Drive real Firstmate and tasks-axi CLIs in disposable marked worktree homes."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(sys.argv[1])
EVIDENCE = Path(__file__).parent
LOG = (EVIDENCE / 'captain-archive-live.txt').open('w')
RESULTS = []
ENV = {k: v for k, v in os.environ.items() if not k.startswith(('FM_', 'TASKS_AXI_', 'HERDR_')) and k != 'TMUX'}
# NO_MISTAKES_GATE remains set; lifecycle is allowed only via the minted lab.

def record(text):
    LOG.write(text + '\n')
    LOG.flush()

def run(home, script, *args, expected=0):
    env = dict(ENV)
    if home:
        env.update(FM_HOME=str(home), HOME=str(home / 'user-home'), TMPDIR=str(home / 'tmp'))
    command = [str(ROOT / 'bin' / script), *map(str, args)]
    record('$ ' + ('FM_HOME=' + str(home) + ' HOME=<isolated> ' if home else '') + shlex.join(command))
    p = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
    record(p.stdout.rstrip())
    record('exit=' + str(p.returncode))
    if expected == 'refuse':
        assert p.returncode != 0, 'Expected refusal: ' + shlex.join(command)
    elif expected is not None:
        assert p.returncode == expected, p.stdout
    return p

def snapshot(path):
    record('\n--- Persisted public state: ' + str(path) + ' ---')
    record(path.read_text() if path.exists() else '<absent>')

def tasks(home, *args, **kwargs):
    return run(home, 'fm-tasks-axi.sh', *args, **kwargs)

def captain(home, *args, **kwargs):
    return run(home, 'fm-captain-hold.sh', *args, **kwargs)

def new_home(variant='default'):
    home = Path(tempfile.mkdtemp(prefix='fm-lab.archive-', dir=ROOT))
    run(None, 'fm-lab-home.sh', 'create', home)
    (home / 'user-home/.tasks-axi').mkdir(parents=True)
    (home / 'tmp').mkdir()
    archive = home / 'data/done-archive.md'
    config = 'backend = "markdown"\n[markdown]\npath = "data/backlog.md"\ndone_keep = 10\n'
    if variant == 'default':
        config += 'archive = "data/done-archive.md"\n'
    elif variant in ('inline-comment', 'project-precedence'):
        archive = home / 'data/history.md'
        config += '  archive = "data/history.md" # retained answers\n'
        if variant == 'project-precedence':
            (home / 'user-home/.tasks-axi/config.toml').write_text('[markdown]\narchive = "data/other-history.md"\n')
    elif variant == 'single-quoted':
        archive = home / 'data/history # retained.md'
        config += "  [ markdown ] # archive settings\n  archive = 'data/history # retained.md' # retained answers\n"
    elif variant == 'inherited':
        archive = home / 'data/home-history.md'
        (home / 'user-home/.tasks-axi/config.toml').write_text("[markdown]\n  archive = 'data/home-history.md' # retained answers\n")
    elif variant == 'absolute':
        archive = home / 'history.md'
        config += 'archive = "' + str(archive) + '" # retained answers\n'
    elif variant != 'unset':
        raise AssertionError(variant)
    (home / '.tasks.toml').write_text(config)
    (home / 'data/backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
    return home, archive

def origin(home, identifier):
    tasks(home, 'add', identifier, 'Investigate archive cleanup', '--kind', 'scout', '--repo', 'sample')
    tasks(home, 'start', identifier)
    # Supported windowless legacy leftover: no endpoint and no actual worktree.
    (home / ('state/' + identifier + '.meta')).write_text(
        f'worktree={home}/projects/missing-{identifier}\nproject={home}/projects/sample\nharness=codex\nkind=scout\nmode=scout\n')
    (home / ('state/' + identifier + '.status')).write_text('done: report complete\n')
    directory = home / ('data/' + identifier)
    directory.mkdir()
    (directory / 'report.md').write_text('# Archive cleanup investigation\n\nCaptain-call inventory is recorded in this home.\n')

def hold_answer(home, identifier, call, entry=None):
    captain(home, 'hold', call, '--title', 'Choose route', '--reason', 'captain route choice pending', '--repo', 'sample')
    captain(home, 'complete', identifier, entry or call)
    (home / 'answer.txt').write_text('Choose route north.\n')
    captain(home, 'answer', call, '--decision-file', home / 'answer.txt')

def teardown(home, identifier, expected=0):
    p = run(home, 'fm-teardown.sh', identifier, expected=expected)
    if expected == 0:
        assert not (home / ('state/' + identifier + '.meta')).exists(), 'cleanup left metadata'
        assert (home / ('data/' + identifier + '/report.md')).exists(), 'cleanup lost report'
        shown = tasks(home, 'show', identifier, '--full').stdout
        assert 'state: done' in shown, shown
        record('Observed: scout metadata removed, report retained, origin Done with report link.')
    else:
        assert (home / ('state/' + identifier + '.meta')).exists(), 'refusal removed metadata'
        assert (home / ('data/' + identifier + '/report.md')).exists(), 'refusal removed report'
        assert 'captain-call completion gate' in p.stdout, 'refused before exercising captain-call gate'
        record('Observed: refused at captain-call gate; scout metadata and report remain.')
    return p

def old_script(commit):
    content = subprocess.check_output(['git', 'show', commit + ':bin/fm-captain-hold.sh'], cwd=ROOT)
    fd, name = tempfile.mkstemp(prefix='.archive-prior-', suffix='.sh', dir=ROOT / 'bin')
    with os.fdopen(fd, 'wb') as f:
        f.write(content)
    os.chmod(name, 0o700)
    return Path(name)

def scenario(name, body):
    record('\n========== SCENARIO: ' + name + ' ==========')
    try:
        body()
        RESULTS.append(dict(name=name, result='pass', live=True, evidence='captain-archive-live.txt', reason=''))
        record('Scenario observable assertions passed.')
    except Exception as e:
        RESULTS.append(dict(name=name, result='fail', live=True, evidence='captain-archive-live.txt', reason=str(e)))
        record('SCENARIO FAILURE: ' + repr(e))
    (EVIDENCE / 'captain-archive-results.json').write_text(json.dumps(RESULTS, indent=2) + '\n')

def retained():
    h, archive = new_home()
    try:
        identifier, call = 'live-retained-review', 'live-retained-review-decision-route'
        origin(h, identifier)
        hold_answer(h, identifier, call)
        tasks(h, 'show', call, '--full')
        captain(h, 'verify', identifier)
        captain(h, 'complete', identifier, call)
        teardown(h, identifier)
        snapshot(h / 'data/backlog.md')
    finally:
        shutil.rmtree(h)


def archived(variants):
    for variant in variants:
        record('\n--- Archive configuration variant: ' + variant + ' ---')
        h, archive = new_home(variant)
        prior = None
        try:
            identifier, call = 'live-archived-review', 'live-archived-review-decision-route'
            origin(h, identifier)
            hold_answer(h, identifier, call)
            tasks(h, 'prune', '--keep', '0')
            tasks(h, 'show', call, '--full', expected='refuse')
            snapshot(h / '.tasks.toml')
            if (h / 'user-home/.tasks-axi/config.toml').exists():
                snapshot(h / 'user-home/.tasks-axi/config.toml')
            snapshot(archive)
            assert call in archive.read_text() and 'Captain decision:' in archive.read_text()
            captain(h, 'verify', identifier)
            captain(h, 'complete', identifier, call)
            if variant == 'default':
                prior = old_script('e42087e4513c4483d832aa8898b28efd410fdac8')
                record('Regression reproduction: base commit cannot verify the pruned answered row.')
                run(h, prior.name, 'verify', identifier, expected='refuse')
            # Re-attest a legacy key (the metadata reader takes the final record).
            with (h / ('state/' + identifier + '.meta')).open('a') as f:
                f.write('decision_keys=route\n')
            captain(h, 'verify', identifier)
            captain(h, 'complete', identifier, 'route')
            teardown(h, identifier)
        finally:
            if prior:
                prior.unlink(missing_ok=True)
            shutil.rmtree(h)


def unanswered(archived_row):
    h, archive = new_home()
    try:
        identifier, call = 'live-unanswered-review', 'live-unanswered-review-decision-route'
        origin(h, identifier)
        # A held call is durable but never falsely changed into an answered one.
        captain(h, 'hold', call, '--title', 'Choose route', '--reason', 'captain choice pending', '--repo', 'sample')
        captain(h, 'complete', identifier, call)
        captain(h, 'verify', identifier)
        if archived_row:
            tasks(h, 'done', call, '--keep', '0')
            snapshot(archive)
        else:
            tasks(h, 'unhold', call)
            tasks(h, 'show', call, '--full')
        captain(h, 'verify', identifier, expected='refuse')
        captain(h, 'complete', identifier, call, expected='refuse')
        teardown(h, identifier, expected='refuse')
    finally:
        shutil.rmtree(h)


def stale():
    for identity in ('exact', 'legacy'):
        h, archive = new_home()
        prior = None
        try:
            identifier, call = 'live-reused-review', 'live-reused-review-decision-route'
            origin(h, identifier)
            hold_answer(h, identifier, call, 'route' if identity == 'legacy' else call)
            tasks(h, 'prune', '--keep', '0')
            tasks(h, 'add', call, 'Choose a new route', '--kind', 'captain', '--repo', 'sample')
            captain(h, 'hold', call, '--reason', 'new captain choice pending')
            tasks(h, 'done', call, '--keep', '10')
            snapshot(archive)
            tasks(h, 'show', call, '--full')
            if identity == 'legacy':
                prior = old_script('f8913bf')
                record('Regression reproduction: pre-fix commit incorrectly accepts an old answer over a newer legacy row.')
                run(h, prior.name, 'verify', identifier)
            captain(h, 'verify', identifier, expected='refuse')
            captain(h, 'complete', identifier, 'route' if identity == 'legacy' else call, expected='refuse')
            teardown(h, identifier, expected='refuse')
            # If the newer unanswered lifecycle is also pruned, its newest archive
            # record must override the earlier archived answer, not resurrect it.
            tasks(h, 'prune', '--keep', '0')
            snapshot(archive)
            captain(h, 'verify', identifier, expected='refuse')
            captain(h, 'complete', identifier, 'route' if identity == 'legacy' else call, expected='refuse')
        finally:
            if prior:
                prior.unlink(missing_ok=True)
            shutil.rmtree(h)


def open_status():
    h, archive = new_home()
    try:
        identifier, call = 'live-status-review', 'live-status-review-decision-route'
        origin(h, identifier)
        hold_answer(h, identifier, call)
        tasks(h, 'prune', '--keep', '0')
        with (h / ('state/' + identifier + '.status')).open('a') as f:
            f.write('needs-decision [key=new-choice]: new captain decision remains\n')
        captain(h, 'verify', identifier, expected='refuse')
        teardown(h, identifier, expected='refuse')
        snapshot(h / ('state/' + identifier + '.status'))
    finally:
        shutil.rmtree(h)


try:
    record('Real backend: tasks-axi ' + subprocess.check_output(['tasks-axi', '--version'], env=ENV, text=True).strip())
    record('No harness mocks, no fleet/session commands; cleanup uses the supported endpoint-less legacy record path.')
    scenario('Clean up a scout after verifying an answered call retained in Done', retained)
    scenario('Clean up a scout after its answered call is pruned into the default archive, using exact and legacy identities', lambda: archived(['default']))
    scenario('Clean up a scout using tasks-axi configured or inherited archives', lambda: archived(['unset', 'inline-comment', 'single-quoted', 'inherited', 'project-precedence', 'absolute']))
    scenario('Refuse a live unheld unanswered call without destroying the scout report or metadata', lambda: unanswered(False))
    scenario('Refuse an archived unanswered call without destroying the scout report or metadata', lambda: unanswered(True))
    scenario('Reject stale archived answers when newer exact, legacy, or archived lifecycles are unanswered', stale)
    scenario('Refuse scout cleanup when a new status-stream captain decision is still open', open_status)
finally:
    LOG.close()
print(json.dumps(RESULTS, indent=2))
sys.exit(1 if any(r['result'] != 'pass' for r in RESULTS) else 0)
