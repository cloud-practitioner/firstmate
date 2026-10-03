#!/usr/bin/env python3
"""Drive real Git with disposable synthetic data; keep fixtures inside the run worktree."""
import io
import os
from pathlib import Path
import shlex
import subprocess
import tarfile
import tempfile

ROOT = Path('/home/node/.no-mistakes/worktrees/c98b859efde5/01M40YVJWSTKAKKCZ1EQJ228JJ')
BASE = '1f3e769616fdf9f31f85f4c3e6a9f71606634238'
ENV = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
ENV.update(GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1',
           GIT_TERMINAL_PROMPT='0', GIT_AUTHOR_NAME='Disposable Test',
           GIT_AUTHOR_EMAIL='test@example.invalid', GIT_COMMITTER_NAME='Disposable Test',
           GIT_COMMITTER_EMAIL='test@example.invalid')


def git(repo, *args, expected=0):
    cmd = ['git', '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false',
           '-C', str(repo), *args]
    result = subprocess.run(cmd, env=ENV, text=True, capture_output=True, check=False)
    print('$ git -C ' + repo.name + ' ' + shlex.join(args), flush=True)
    print(result.stdout.rstrip() or '(no stdout)', flush=True)
    if result.stderr:
        print(result.stderr.rstrip(), flush=True)
    print(f'exit={result.returncode}', flush=True)
    assert result.returncode == expected, (args, result.returncode, expected)
    return result.stdout


def seed(repo, ignore):
    repo.mkdir()
    git(repo, 'init', '-q', '--initial-branch=main')
    (repo / '.gitignore').write_text(ignore)
    git(repo, 'add', '.gitignore')
    git(repo, 'commit', '-qm', 'Seed disposable ignore rules')
    (repo / '.claude').mkdir()
    (repo / '.claude/settings.local.json').write_text('{"permissions":{"allow":["Bash(echo disposable)"]}}\n')


print('Real Git consumer validation; all settings and identities are synthetic.', flush=True)
print(subprocess.run(['git', '--version'], env=ENV, text=True, capture_output=True, check=True).stdout.rstrip())
base_ignore = git(ROOT, 'show', f'{BASE}:.gitignore')
target_ignore = (ROOT / '.gitignore').read_text()
with tempfile.TemporaryDirectory(prefix='.fm-gitignore-live.', dir=ROOT) as scratch:
    scratch = Path(scratch)
    baseline = scratch / 'baseline'
    target = scratch / 'target'
    print('\n=== Baseline: session-created local settings dirty status and enter normal staging ===')
    seed(baseline, base_ignore)
    assert git(baseline, 'status', '--porcelain=v1', '--untracked-files=all') == '?? .claude/settings.local.json\n'
    git(baseline, 'check-ignore', '-v', '.claude/settings.local.json', expected=1)
    git(baseline, 'add', '--all')
    assert git(baseline, 'diff', '--cached', '--name-only') == '.claude/settings.local.json\n'
    print('Reported pre-fix failure reproduced with the baseline rules.')

    print('\n=== Target: local settings do not dirty status ===')
    seed(target, target_ignore)
    assert git(target, 'status', '--porcelain=v1', '--untracked-files=all') == ''
    assert git(target, 'status', '--porcelain=v1', '--ignored', '--untracked-files=all') == '!! .claude/settings.local.json\n'
    git(target, 'check-ignore', '-v', '.claude/settings.local.json')

    print('\n=== Target adversarial: ordinary explicit staging rejects local settings ===')
    git(target, 'add', '--', '.claude/settings.local.json', expected=1)
    assert git(target, 'diff', '--cached', '--name-only') == ''
    assert git(target, 'ls-files') == '.gitignore\n'

    print('\n=== Target controls: shared settings and other contributions stay visible ===')
    controls = ['.claude/commands/contribution.md', '.claude/settings.json', 'contributor-notes.txt']
    (target / '.claude/commands').mkdir()
    (target / controls[0]).write_text('Synthetic shared command.\n')
    (target / controls[1]).write_text('{"permissions":{"allow":[]}}\n')
    (target / controls[2]).write_text('Synthetic public contributor notes.\n')
    for path in controls:
        git(target, 'check-ignore', '-v', path, expected=1)
    status = git(target, 'status', '--porcelain=v1', '--untracked-files=all')
    assert status.splitlines() == ['?? ' + path for path in controls]

    print('\n=== Target bulk staging and exported commit omit per-user settings ===')
    git(target, 'add', '--all')
    assert git(target, 'diff', '--cached', '--name-only').splitlines() == controls
    git(target, 'commit', '-qm', 'Add disposable shared contributions')
    committed = git(target, 'ls-tree', '-r', '--name-only', 'HEAD').splitlines()
    assert set(committed) == {'.gitignore', *controls}
    archive = subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-C', str(target),
                              'archive', '--format=tar', 'HEAD'], env=ENV, capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as exported:
        names = [entry.name for entry in exported.getmembers() if entry.isfile()]
    print('$ git -C target archive --format=tar HEAD | inspect exported file list')
    print('\n'.join(names))
    assert set(names) == {'.gitignore', *controls}
    assert '.claude/settings.local.json' not in names
    assert git(target, 'status', '--porcelain=v1', '--untracked-files=all') == ''
    assert git(target, 'status', '--porcelain=v1', '--ignored', '--untracked-files=all') == '!! .claude/settings.local.json\n'
    print('Normal contribution staging and commit export exclude the local file while retaining shared files.')
print('\nBoth disposable repositories removed; no operator configuration or credentials used.')
