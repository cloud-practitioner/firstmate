#!/usr/bin/env python3
"""Drive public Firstmate/Ixia CLIs and real Git in worktree-local disposable homes."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import stat
import subprocess

ROOT = Path.cwd()
WORK = ROOT / '.ixia-live-validation' / 'live'
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M526S0CQ1YZYNV875SKWGHDJ')
CONTRIB = ROOT / 'contrib/iqx-ixia-hook'
INSTALL = CONTRIB / 'ixia-hook-install.sh'
VERIFY = CONTRIB / 'ixia-hook-verify.sh'
STRIP = ROOT / 'bin/fm-git-strip-ai-trailers.sh'
IXIA = 'Co-Authored-By: Ixia Engineering (Claude) <noreply@anthropic.com>'
JANE = 'Co-Authored-By: Jane Doe <jane@example.com>'
SCISSORS = '# ------------------------ >8 ------------------------'
ENV = {k: v for k, v in os.environ.items() if not k.startswith(('GIT_', 'FM_'))}
ENV.update(GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1',
           GIT_AUTHOR_NAME='Ixia lab', GIT_AUTHOR_EMAIL='lab@example.invalid',
           GIT_COMMITTER_NAME='Ixia lab', GIT_COMMITTER_EMAIL='lab@example.invalid',
           GIT_TERMINAL_PROMPT='0', GIT_EDITOR=':', LC_ALL='C',
           TMPDIR=str(WORK / 'tmp'), HOME=str(WORK / 'home'))
results = []
messages = {}


def run(*args, cwd=ROOT, extra=None, expected=0):
    args = list(map(str, args))
    print('\n$ (cd ' + shlex.quote(str(cwd)) + ' && ' + shlex.join(args) + ')', flush=True)
    env = ENV.copy()
    env.update(extra or {})
    if extra:
        print('environment: ' + repr(extra), flush=True)
    out = subprocess.run(args, cwd=cwd, env=env, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
    print(out.stdout.decode(errors='replace'), end='', flush=True)
    print('[exit ' + str(out.returncode) + ']', flush=True)
    if expected is not None:
        assert out.returncode == expected, (args, out.returncode, expected)
    return out.stdout


def git(repo, *args, **kwargs):
    return run('git', *args, cwd=repo, **kwargs)


def repo(home, name, origin='git@bitbucket.org:iqxbusiness/fixture.git'):
    clone = home / 'projects' / name
    clone.mkdir(parents=True)
    git(clone, 'init', '-q', '--initial-branch=main', '--template=' + str(WORK / 'empty-template'))
    git(clone, 'remote', 'add', 'origin', origin)
    git(clone, 'commit', '--allow-empty', '-m', 'initial fixture')
    return clone


def hook(clone):
    return clone / '.git/hooks/commit-msg'


def snapshot(clone):
    return (git(clone, 'rev-parse', 'HEAD'), git(clone, 'reflog', '--all'),
            git(clone, 'count-objects', '-v'), (clone / '.git/config').read_bytes(),
            hook(clone).read_bytes(), hook(clone).stat().st_mode)


def message(clone, label, want=None, extra=None):
    raw = git(clone, 'cat-file', 'commit', 'HEAD', extra=extra)
    body = raw.split(b'\n\n', 1)[1]
    messages[label] = body.decode()
    print('Persisted message for ' + label + ': ' + repr(body), flush=True)
    assert body.splitlines().count(IXIA.encode()) == 1
    assert body.rstrip().splitlines()[-1] == IXIA.encode()
    if want is not None:
        assert body == want, (body, want)
    return body


def scenario(name, fn):
    print('\n========== ' + name + ' ==========', flush=True)
    try:
        fn()
        results.append(dict(name=name, result='pass', live=True))
    except Exception as error:
        results.append(dict(name=name, result='fail', live=True, reason=repr(error)))
        raise


try:
    WORK.mkdir(parents=True)
    for directory in ('tmp', 'home', 'empty-template'):
        (WORK / directory).mkdir()
    run('git', '--version')
    homes = {name: WORK / name for name in ('iqxo', 'atc', 'fab')}
    clones = {name: repo(home, 'iqx-fixture') for name, home in homes.items()}
    c = clones['iqxo']
    pane = WORK / 'pane-hooks'
    run('bash', STRIP, 'install', pane, c)
    pane_env = dict(GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='core.hooksPath',
                    GIT_CONFIG_VALUE_0=str(pane))

    def upgrade():
        hook(c).parent.mkdir(parents=True)
        shutil.copyfile(CONTRIB / 'previous/ixia-commit-msg-hook.v1.sh', hook(c))
        hook(c).chmod(0o755)
        git(c, 'commit', '--allow-empty', '-m', '#123 v1 reproduction', extra=pane_env)
        before = git(c, 'log', '-1', '--format=%B')
        assert IXIA.encode() not in before
        print('V1 regression reproduced: committed # subject has no Ixia trailer.', flush=True)
        run('bash', VERIFY, 'iqx-fixture', cwd=homes['iqxo'], expected=1)
        for name, home in homes.items():
            out = run('bash', INSTALL, 'iqx-fixture', cwd=home, extra=pane_env)
            assert ('updated' if name == 'iqxo' else 'installed').encode() in out
            installed = hook(clones[name])
            assert installed.read_bytes() == (CONTRIB / 'ixia-commit-msg-hook.sh').read_bytes()
            assert stat.S_IMODE(installed.stat().st_mode) == 0o755
            print('Installed digest: ' + hashlib.sha256(installed.read_bytes()).hexdigest(), flush=True)
            assert b'unchanged' in run('bash', INSTALL, 'iqx-fixture', cwd=home)
        git(c, 'commit', '--allow-empty', '-m', '#123 v2 fixed', extra=pane_env)
        message(c, 'v2-hash-subject-through-strip', b'#123 v2 fixed\n\n' + IXIA.encode() + b'\n')
    scenario('Install from each home, upgrade exact v1 and restore # attribution after Firstmate strip', upgrade)

    def sharing():
        slot = WORK / 'pool-slot'
        git(c, 'worktree', 'add', '-b', 'pool-slot', slot)
        before = snapshot(c)
        out = run('bash', VERIFY, 'iqx-fixture', cwd=homes['iqxo'], extra=pane_env)
        assert b'2 worktrees share' in out
        assert snapshot(c) == before
        git(slot, 'commit', '--allow-empty', '-m', '#pool slot commit', extra=pane_env)
        message(slot, 'linked-worktree-through-strip')
        for name in ('atc', 'fab'):
            before = snapshot(clones[name])
            run('bash', VERIFY, 'iqx-fixture', cwd=homes[name])
            assert snapshot(clones[name]) == before
    scenario('Verify without mutating clones and commit through a linked pool worktree', sharing)

    def preserve():
        text = ('IQX-7: retain human authors\n\nBody  with spacing.\n' + IXIA + '\n\n' +
                'More body.\n\n' + JANE + '\nReviewed-by:  Bob <bob@example.com>\n' +
                IXIA.lower() + '  \n' + IXIA + '\n')
        git(c, 'commit', '--allow-empty', '-m', text, extra=pane_env)
        out = message(c, 'human-trailers-and-duplicates-through-strip')
        assert JANE.encode() in out and b'More body.' in out
        trailers = git(c, 'log', '-1', '--format=%(trailers:only)', extra=pane_env)
        assert JANE.encode() in trailers and IXIA.encode() in trailers
        raw = b'Verbatim bytes\n\nBody  \t\n\nSigned-off-by:Alice <alice@example.com>\nReviewed-by:\t Bob <bob@example.com>  \n'
        msg = WORK / 'verbatim-msg'
        msg.write_bytes(raw)
        git(c, 'commit', '--allow-empty', '--cleanup=verbatim', '-F', msg)
        message(c, 'verbatim-byte-contract', raw + IXIA.encode() + b'\n')
    scenario('Deduplicate Ixia while retaining human trailers and verbatim non-Ixia bytes', preserve)

    def cleanup():
        git(c, 'config', 'commit.cleanup', 'strip')
        git(c, 'commit', '--allow-empty', '--cleanup=whitespace', '-m', '#explicit CLI wins', extra=pane_env)
        message(c, 'cli-overrides-configured-strip')
        before = git(c, 'rev-parse', 'HEAD')
        git(c, 'commit', '--allow-empty', '-m', '#configured strip emptiness', expected=1, extra=pane_env)
        assert git(c, 'rev-parse', 'HEAD') == before
        git(c, 'config', '--unset', 'commit.cleanup')
        editor = WORK / 'editor.sh'
        editor.write_text('#!/bin/sh\nprintf "Editor subject\\n\\n# editor comment\\n" >"$1"\n')
        editor.chmod(0o755)
        git(c, 'commit', '--allow-empty', extra={**pane_env, 'GIT_EDITOR': str(editor)})
        message(c, 'editor-comment-cleanup', b'Editor subject\n\n' + IXIA.encode() + b'\n')
        git(c, 'commit', '--allow-empty', '--edit', '--cleanup=scissors', '-m',
            'Scissors subject\n\n' + SCISSORS + '\nUncommitted patch text', extra=pane_env)
        message(c, 'editor-scissors', b'Scissors subject\n\n' + IXIA.encode() + b'\n')
        for args in (['-m', ''], ['-s', '-m', ''], ['--cleanup=whitespace', '-m', '  ']):
            before = git(c, 'rev-parse', 'HEAD')
            git(c, 'commit', '--allow-empty', *args, expected=1, extra=pane_env)
            assert git(c, 'rev-parse', 'HEAD') == before
        git(c, 'commit', '--allow-empty', '--cleanup=verbatim', '-m', ' ')
        message(c, 'verbatim-whitespace-is-nonempty')
        before = git(c, 'rev-parse', 'HEAD')
        git(c, '-c', 'core.commentChar=auto', 'commit', '--allow-empty', '-m', 'Refuse unresolved delimiter', expected=1, extra=pane_env)
        assert git(c, 'rev-parse', 'HEAD') == before
    scenario('Respect editor and configured cleanup, preserve empty-commit aborts, and refuse auto delimiters', cleanup)

    def merges():
        git(c, 'switch', '-c', 'merge-side')
        (c / 'side.txt').write_text('Disposable side-branch change.\n')
        git(c, 'add', 'side.txt')
        git(c, 'commit', '-m', 'Side change', extra=pane_env)
        git(c, 'switch', 'main')
        git(c, 'merge', '--no-ff', '--no-edit', '-v', '-m',
            'Merge subject\n\n' + SCISSORS + '\nRetained merge body', 'merge-side', extra=pane_env)
        body = message(c, 'merge-verbose-retains-body-through-strip')
        assert SCISSORS.encode() in body and b'Retained merge body' in body
        assert len(git(c, 'rev-list', '--parents', '-n', '1', 'HEAD').split()) == 3
    scenario('Non-fast-forward merge retains scissors-looking body text before the final Ixia trailer', merges)

    def guards():
        home = WORK / 'guard-home'
        other = repo(home, 'other', 'git@bitbucket.org:otherorg/fixture.git')
        spoof = repo(home, 'spoof', 'https://bitbucket.org.evil.invalid/iqxbusiness/fixture.git')
        custom = repo(home, 'custom')
        hp = repo(home, 'redirected')
        symlinked = repo(home, 'symlinked')
        for target in (other, spoof):
            run('bash', INSTALL, target.name, cwd=home, expected=1)
            assert not hook(target).exists()
            hook(target).parent.mkdir(parents=True)
            shutil.copyfile(CONTRIB / 'ixia-commit-msg-hook.sh', hook(target))
            hook(target).chmod(0o755)
            git(target, 'commit', '--allow-empty', '-m', 'Non IQX stays unchanged')
            raw = git(target, 'log', '-1', '--format=%B')
            assert raw == b'Non IQX stays unchanged\n\n'
        hook(custom).parent.mkdir(parents=True)
        custom_bytes = b'#!/bin/sh\n# ixia-commit-msg-hook v0\nexit 0\n'
        hook(custom).write_bytes(custom_bytes)
        run('bash', INSTALL, 'custom', cwd=home, expected=1)
        assert hook(custom).read_bytes() == custom_bytes
        git(hp, 'config', 'core.hooksPath', '.custom-hooks')
        run('bash', INSTALL, 'redirected', cwd=home, expected=1)
        assert not hook(hp).exists()
        sentinel = WORK / 'symlink-sentinel'
        sentinel.write_bytes(custom_bytes)
        hook(symlinked).parent.mkdir(parents=True)
        hook(symlinked).symlink_to(sentinel)
        run('bash', INSTALL, 'symlinked', cwd=home, expected=1)
        assert sentinel.read_bytes() == custom_bytes and hook(symlinked).is_symlink()
        run('bash', INSTALL, '../escape', cwd=home, expected=1)
        run('bash', INSTALL, '--home', str(home), 'custom', cwd=home, expected=2)
        # Verify detects damage and installation repairs only identical approved bytes.
        installed = hook(clones['atc'])
        installed.chmod(0o644)
        run('bash', VERIFY, 'iqx-fixture', cwd=homes['atc'], expected=1)
        run('bash', INSTALL, 'iqx-fixture', cwd=homes['atc'])
        assert stat.S_IMODE(installed.stat().st_mode) == 0o755
        installed.write_bytes(installed.read_bytes() + b'\n# local edit\n')
        modified = installed.read_bytes()
        run('bash', VERIFY, 'iqx-fixture', cwd=homes['atc'], expected=1)
        run('bash', INSTALL, 'iqx-fixture', cwd=homes['atc'], expected=1)
        assert installed.read_bytes() == modified
    scenario('Refuse non-IQX targets, path escapes, custom or symlink hooks, redirected hooks and altered copies', guards)

    def bypass():
        (c / 'bypass-fixture.txt').write_text('Real content for the bypass and amend scenario.\n')
        git(c, 'add', 'bypass-fixture.txt', extra=pane_env)
        git(c, 'commit', '--no-verify', '-m', 'Documented bypass', extra=pane_env)
        out = git(c, 'log', '-1', '--format=%B')
        assert IXIA.encode() not in out
        git(c, 'commit', '--amend', '--no-edit', extra=pane_env)
        message(c, 'amend-restores-after-documented-bypass')
    scenario('Show --no-verify bypass and restore attribution with an ordinary amend', bypass)
finally:
    (EVIDENCE / 'persisted-commit-messages.json').write_text(json.dumps(messages, indent=2) + '\n')
    (EVIDENCE / 'live-scenario-results.json').write_text(json.dumps(results, indent=2) + '\n')
    # Firstmate creates read-only per-launch hook wrappers; restore owner write before disposal.
    if WORK.exists():
        for entry in WORK.rglob('*'):
            if not entry.is_symlink():
                entry.chmod(entry.stat().st_mode | stat.S_IWUSR)
        shutil.rmtree(WORK)
    print('\nDisposable live homes and repositories removed.', flush=True)
