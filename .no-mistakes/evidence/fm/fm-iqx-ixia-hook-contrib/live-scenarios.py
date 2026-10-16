#!/usr/bin/env python3
"""Disposable end-user CLI checks; all labs stay beneath the gate worktree."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

ROOT = Path.cwd()
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M523AZA1Z7G4KMXJS24DB4VS')
CONTRIB = ROOT / 'contrib/iqx-ixia-hook'
INSTALL = CONTRIB / 'ixia-hook-install.sh'
VERIFY = CONTRIB / 'ixia-hook-verify.sh'
HOOK = CONTRIB / 'ixia-commit-msg-hook.sh'
STRIP = ROOT / 'bin/fm-git-strip-ai-trailers.sh'
IXIA = 'Co-Authored-By: Ixia Engineering (Claude) <noreply@anthropic.com>'
JANE = 'Co-Authored-By: Jane Doe <jane@example.com>'
SHA = '39c0d3c156f1b8ba404dcd5797874947b22c07e82ed06ff15f5f6837a19e8472'
LAB = Path(tempfile.mkdtemp(prefix='.ixia-live.', dir=ROOT))
LOG = (EVIDENCE / 'live-cli-transcript.log').open('w')
RESULTS = []
ENV = {k: v for k, v in os.environ.items() if not k.startswith(('GIT_', 'FM_'))}
ENV.update(HOME=str(LAB / 'isolated-user'), XDG_CONFIG_HOME=str(LAB / 'isolated-user/.config'),
           TMPDIR=str(LAB / 'tmp'), GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1',
           GIT_TERMINAL_PROMPT='0', GIT_AUTHOR_NAME='Ixia Lab', GIT_AUTHOR_EMAIL='lab@example.invalid',
           GIT_COMMITTER_NAME='Ixia Lab', GIT_COMMITTER_EMAIL='lab@example.invalid', LC_ALL='C')
Path(ENV['HOME']).mkdir()
Path(ENV['TMPDIR']).mkdir()

def emit(text):
    LOG.write(str(text) + '\n')
    LOG.flush()
    print(text, flush=True)

def run(args, cwd=ROOT, expected=0, env=None):
    args = [str(a) for a in args]
    emit(f'\n$ (cd {shlex.quote(str(cwd))} && {shlex.join(args)})')
    proc = subprocess.run(args, cwd=cwd, env=env or ENV, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    emit(proc.stdout.rstrip())
    emit(f'[exit {proc.returncode}]')
    if expected is not None:
        assert proc.returncode == expected, (args, proc.returncode, expected)
    return proc

def git(repo, *args, **kwargs):
    return run(['git', '-C', repo, *args], **kwargs)

def check(condition, detail):
    emit(('CONFIRMED: ' if condition else 'FAILED: ') + detail)
    assert condition, detail

def new_clone(home, name, origin='git@bitbucket.org:iqxbusiness/lab.git'):
    repo = home / 'projects' / name
    repo.mkdir(parents=True)
    git(repo, 'init', '-q')
    git(repo, 'remote', 'add', 'origin', origin)
    git(repo, '-c', 'commit.gpgsign=false', 'commit', '-q', '--allow-empty', '-m', 'Seed disposable clone')
    return repo

def hook(repo):
    return repo / '.git/hooks/commit-msg'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def snapshot(repo):
    # Persisted clone contents, modes, links, refs, objects, reflogs, index and files;
    # exclude atime so read-only inspection does not appear to be a mutation.
    entries = {}
    for p in sorted(repo.rglob('*')):
        st = p.lstat()
        entries[str(p.relative_to(repo))] = {
            'mode': st.st_mode & 0o7777, 'mtime_ns': st.st_mtime_ns,
            'link': os.readlink(p) if p.is_symlink() else None,
            'sha256': digest(p) if p.is_file() and not p.is_symlink() else None,
        }
    return entries

def installed(repo):
    check(digest(hook(repo)) == SHA, f'{repo.name}: installed approved sha256 {SHA}')
    check(hook(repo).stat().st_mode & 0o7777 == 0o755, f'{repo.name}: installed mode 755')

def scenario(name, fn):
    emit('\n========== ' + name + ' ==========')
    try:
        fn()
        RESULTS.append({'name': name, 'result': 'pass', 'live': True})
    except Exception as exc:
        emit(f'SCENARIO FAILED: {exc!r}')
        RESULTS.append({'name': name, 'result': 'fail', 'live': True, 'error': repr(exc)})

homes = {name: LAB / name for name in ('iqxo', 'atc', 'fab')}
repos = {}

def install_homes():
    for home, projects in (
        ('iqxo', [('iqx.orchestration.online', 'git@bitbucket.org:iqxbusiness/iqxo.git')]),
        ('atc', [('iqx_atc_remedy', 'https://bitbucket.org/IQXBusiness/atc.git')]),
        ('fab', [('iqx-fab', 'ssh://git@bitbucket.org:7999/iqxbusiness/fab.git'),
                 ('iqx-common', 'git@bitbucket.org-work:iqxbusiness/common.git'),
                 ('iqx-fab_common', 'https://lab@bitbucket.org/iqxbusiness/fab-common.git')]),
    ):
        for name, origin in projects:
            repos[name] = new_clone(homes[home], name, origin)
        names = [p[0] for p in projects]
        run(['bash', INSTALL, *names], cwd=homes[home])
        for name in names:
            installed(repos[name])
        before = {name: digest(hook(repos[name])) for name in names}
        out = run(['bash', INSTALL, *names], cwd=homes[home]).stdout
        check(all(f'unchanged {name} ->' in out for name in names), f'{home}: identical copies reported unchanged')
        check(before == {name: digest(hook(repos[name])) for name in names}, 'reinstall preserved approved bytes')
    repo = repos['iqx-fab']
    hook(repo).chmod(0o644)
    run(['bash', INSTALL, 'iqx-fab'], cwd=homes['fab'])
    installed(repo)
    # A locally re-cloned project's untracked hook is missing and must be reinstalled.
    fresh = homes['fab'] / 'projects/recloned'
    git(ROOT, 'clone', '-q', '--no-local', repo, fresh)
    git(fresh, 'remote', 'set-url', 'origin', 'git@bitbucket.org:iqxbusiness/recloned.git')
    check(not hook(fresh).exists(), 'new clone does not inherit commit-msg hook')
    run(['bash', VERIFY, 'recloned'], cwd=homes['fab'], expected=1)
    run(['bash', INSTALL, 'recloned'], cwd=homes['fab'])
    run(['bash', VERIFY, 'recloned'], cwd=homes['fab'])
    installed(fresh)


def refusal_guards():
    home = LAB / 'refusals'
    good = new_clone(home, 'good')
    for name, origin in (
        ('github', 'git@github.com:iqxbusiness/lab.git'),
        ('other-org', 'git@bitbucket.org:someone/lab.git'),
        ('lookalike-host', 'https://bitbucket.org.evil.invalid/iqxbusiness/lab.git'),
        ('lookalike-org', 'git@bitbucket.org:iqxbusiness-lookalike/lab.git'),
    ):
        repo = new_clone(home, name, origin)
        before = snapshot(repo)
        run(['bash', INSTALL, name], cwd=home, expected=1)
        run(['bash', VERIFY, name], cwd=home, expected=1)
        check(snapshot(repo) == before, f'{name}: refused clone unchanged')
    (home / 'projects/plain').mkdir()
    for name in ('plain', 'missing', '../escape', '.', '..'):
        run(['bash', INSTALL, name], cwd=home, expected=1)
    # A STOP on one project must not prevent handling another named project.
    run(['bash', INSTALL, 'github', 'good'], cwd=home, expected=1)
    installed(good)
    for name, payload in (
        ('custom', b'#!/bin/sh\necho operator-owned\n'),
        ('marked', b'#!/bin/sh\n# ixia-commit-msg-hook v0\nexit 0\n'),
    ):
        repo = new_clone(home, name)
        hook(repo).write_bytes(payload)
        hook(repo).chmod(0o755)
        before = snapshot(repo)
        run(['bash', INSTALL, name], cwd=home, expected=1)
        check(snapshot(repo) == before, f'{name}: existing different commit-msg bytes and metadata untouched')
    target = LAB / 'external-hook-owned-by-lab'
    target.write_bytes(HOOK.read_bytes())
    for name, broken in (('symlink', False), ('broken-link', True), ('directory', False)):
        repo = new_clone(home, name)
        if name == 'directory':
            hook(repo).mkdir()
        else:
            hook(repo).symlink_to(LAB / 'absent-target' if broken else target)
        before = snapshot(repo)
        run(['bash', INSTALL, name], cwd=home, expected=1)
        check(snapshot(repo) == before, f'{name}: existing non-regular destination untouched')
    for script in (INSTALL, VERIFY):
        run(['bash', script, '--help'], cwd=home)
        run(['bash', script], cwd=home, expected=2)
        for args in (['--home', homes['fab'], 'good'], [f'--home={homes["fab"]}', 'good']):
            run(['bash', script, *args], cwd=home, expected=2)


def overrides_and_source():
    home = LAB / 'overrides'
    pane = LAB / 'pane-hooks'
    pane.mkdir()
    (pane / 'sentinel').write_text('not the repository hook destination\n')
    repo = new_clone(home, 'pane-safe')
    env = dict(ENV, GIT_CONFIG_COUNT='2', GIT_CONFIG_KEY_0='core.hooksPath', GIT_CONFIG_VALUE_0=str(pane),
               GIT_CONFIG_KEY_1='user.name', GIT_CONFIG_VALUE_1='Inherited pane identity')
    pane_before = snapshot(pane)
    run(['bash', INSTALL, 'pane-safe'], cwd=home, env=env)
    run(['bash', VERIFY, 'pane-safe'], cwd=home, env=env)
    installed(repo)
    check(snapshot(pane) == pane_before, 'pane hooks override directory unchanged')
    for scope in ('local', 'global', 'worktree'):
        name = f'{scope}-config'
        repo = new_clone(home, name)
        env = dict(ENV)
        if scope == 'global':
            config = LAB / 'isolated-global.gitconfig'
            config.write_text('[core]\n\thooksPath = .alternate-hooks\n')
            env['GIT_CONFIG_GLOBAL'] = str(config)
        elif scope == 'worktree':
            git(repo, 'config', 'extensions.worktreeConfig', 'true')
            git(repo, 'config', '--worktree', 'core.hooksPath', '.alternate-hooks')
        else:
            git(repo, 'config', 'core.hooksPath', '.alternate-hooks')
        before = snapshot(repo)
        run(['bash', INSTALL, name], cwd=home, expected=1, env=env)
        run(['bash', VERIFY, name], cwd=home, expected=1, env=env)
        check(snapshot(repo) == before, f'{scope} hooksPath: refused without writes')
    copy = LAB / 'tampered-contrib'
    shutil.copytree(CONTRIB, copy)
    with (copy / HOOK.name).open('a') as out:
        out.write('\n# accidental local change\n')
    repo = new_clone(home, 'tamper-destination')
    before = snapshot(repo)
    for script in (INSTALL, VERIFY):
        run(['bash', copy / script.name, 'tamper-destination'], cwd=home, expected=2)
    check(snapshot(repo) == before, 'changed bundle rejected before any target changes')


def verify_worktrees():
    home = homes['iqxo']
    repo = repos['iqx.orchestration.online']
    slots = [LAB / 'pool-slot-1', LAB / 'pool slot 2']
    for i, slot in enumerate(slots):
        git(repo, 'worktree', 'add', '-q', '-b', f'pool-{i}', slot)
    before = snapshot(repo)
    slot_before = [snapshot(s) for s in slots]
    out = run(['bash', VERIFY, repo.name], cwd=home).stdout
    check('(3 worktrees share ' in out, 'main clone and both pool worktrees share the installed hook')
    check(snapshot(repo) == before and [snapshot(s) for s in slots] == slot_before,
          'verify left all clone/worktree files, modes, mtimes, refs, reflogs, objects and index unchanged')
    (EVIDENCE / 'verify-clone-snapshot.json').write_text(json.dumps(before, indent=2))
    git(repo, 'config', 'extensions.worktreeConfig', 'true')
    git(slots[1], 'config', '--worktree', 'core.hooksPath', '.elsewhere')
    before = snapshot(repo)
    out = run(['bash', VERIFY, repo.name], cwd=home, expected=1).stdout
    check('core.hooksPath' in out and 'pool slot 2' in out, 'per-worktree redirect detected')
    check(snapshot(repo) == before, 'failed verify also leaves clone untouched')
    git(slots[1], 'config', '--worktree', '--unset', 'core.hooksPath')
    for mode in (0o644, 0o775):
        hook(repo).chmod(mode)
        run(['bash', VERIFY, repo.name], cwd=home, expected=1)
    hook(repo).chmod(0o755)
    with hook(repo).open('a') as out:
        out.write('\n# changed installed bytes\n')
    run(['bash', VERIFY, repo.name], cwd=home, expected=1)
    hook(repo).unlink()
    run(['bash', VERIFY, repo.name], cwd=home, expected=1)
    run(['bash', INSTALL, repo.name], cwd=home)
    run(['bash', VERIFY, repo.name], cwd=home)
    repos['slot'] = slots[0]


def commit_chain():
    repo = repos['iqx.orchestration.online']
    slot = repos['slot']
    launch_hooks = LAB / 'launch-hooks'
    run(['bash', STRIP, 'install', launch_hooks, slot])
    envfile = LAB / 'pane-env.sh'
    run(['bash', STRIP, 'env-file', launch_hooks, envfile])
    (EVIDENCE / 'chain.git-trace.log').write_text('')
    trace_env = dict(ENV, GIT_TRACE=str(EVIDENCE / 'chain.git-trace.log'))
    direct = LAB / 'direct-duplicate.msg'
    direct.write_text('IQX-100: direct hook duplicate removal\n\nBody stays.\n\n' + IXIA + '\n' +
                      JANE + '\n' + IXIA.lower() + '  \n\nMiddle line.\n\n' +
                      'Reviewed-by: Reviewer <reviewer@example.com>\n' + IXIA + '\n')
    git(slot, '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-F', direct)
    final = git(slot, 'log', '-1', '--format=%B').stdout
    (EVIDENCE / 'direct-hook-committed-message.txt').write_text(final)
    check(final.rstrip().splitlines()[-1] == IXIA and final.splitlines().count(IXIA) == 1,
          'repository hook alone removes canonical, lowercase and trailing-space duplicates')
    check(JANE in final and 'Middle line.' in final and 'Reviewed-by: Reviewer <reviewer@example.com>' in final,
          'repository hook alone retains human trailers and intervening body text')
    messages = [
        ('plain', 'IQX-101: plain commit\n\nBody line stays intact.\n'),
        ('duplicate-human', 'IQX-102: retain human trailers\n\nBody with punctuation: = & < >.\n\n' +
         IXIA + '\n' + JANE + '\n' + IXIA.lower() + '  \n\nMiddle line stays here.\n\n' +
         'Reviewed-by: Reviewer <reviewer@example.com>\n' +
         'Co-Authored-By: Codex <noreply@openai.com>\n' + IXIA + '\n'),
    ]
    for label, original in messages:
        message = LAB / f'{label}.msg'
        message.write_text(original)
        (EVIDENCE / f'{label}-input.txt').write_text(original)
        stripped = LAB / f'{label}-strip-only.msg'
        stripped.write_text(original)
        run(['bash', STRIP, stripped])
        strip_text = stripped.read_text()
        emit('Standalone Firstmate strip output:\n' + strip_text)
        check(IXIA not in strip_text and 'noreply@openai.com' not in strip_text, 'Firstmate strip removes AI lines before chaining')
        command = f'. {shlex.quote(str(envfile))}; git -C {shlex.quote(str(slot))} -c commit.gpgsign=false commit --allow-empty -F {shlex.quote(str(message))}'
        run(['bash', '-c', command], env=trace_env)
        final = git(slot, 'log', '-1', '--format=%B').stdout
        (EVIDENCE / f'{label}-committed-message.txt').write_text(final)
        check(final.rstrip().splitlines()[-1] == IXIA and final.splitlines().count(IXIA) == 1,
              'actual commit object ends with exactly one canonical Ixia line')
        check([line for line in final.splitlines() if line and line != IXIA] ==
              [line for line in strip_text.splitlines() if line],
              'subject, body and human trailer lines are unchanged and ordered after strip + chain')
    # Hook itself must leave non-IQX messages byte-for-byte alone.
    git(repo, 'remote', 'set-url', 'origin', 'https://bitbucket.org/not-iqx/lab.git')
    message = LAB / 'non-iqx.msg'
    message.write_text('OTHER-1: do not touch\n\n' + IXIA + '\n\nTail text.\n')
    before = message.read_bytes()
    run(['sh', hook(repo), message], cwd=slot)
    check(message.read_bytes() == before, 'non-IQX direct hook invocation leaves message bytes identical')
    git(slot, '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-m', 'OTHER-2: no attribution')
    final = git(slot, 'log', '-1', '--format=%B').stdout
    check(IXIA not in final, 'ordinary non-IQX commit is not attributed')
    git(repo, 'remote', 'set-url', 'origin', 'git@bitbucket.org:iqxbusiness/iqxo.git')


def empty_and_gaps():
    repo = repos['iqx.orchestration.online']
    slot = repos['slot']
    empty = LAB / 'empty.msg'
    empty.write_text('\n\n')
    before = empty.read_bytes()
    run(['sh', hook(repo), empty], cwd=slot)
    check(empty.read_bytes() == before, 'empty input stays byte-for-byte unchanged')
    head = git(slot, 'rev-parse', 'HEAD').stdout
    run(['git', '-C', slot, 'commit', '--allow-empty', '-F', empty], expected=1)
    check(git(slot, 'rev-parse', 'HEAD').stdout == head, 'Git aborts empty message without adding a commit')
    run(['sh', hook(repo)], cwd=slot, expected=1)
    envfile = LAB / 'pane-env.sh'
    for args, expected in ((['-m', '#123 fix'], '#123 fix'),
                           (['--no-verify', '-m', 'IQX-103: bypass accepted gap'], 'IQX-103: bypass accepted gap')):
        command = f'. {shlex.quote(str(envfile))}; git -C {shlex.quote(str(slot))} -c commit.gpgsign=false commit --allow-empty {shlex.join(args)}'
        run(['bash', '-c', command])
        final = git(slot, 'log', '-1', '--format=%B').stdout
        check(final.strip() == expected, 'documented gap reproduced without changing approved hook')
    check(digest(HOOK) == SHA and digest(hook(repo)) == SHA, 'approved source and installed hook bytes still match pinned digest')


def portable_checksum():
    tools = LAB / 'tools-with-shasum-only'
    tools.mkdir()
    for name in ('bash', 'sh', 'git', 'dirname', 'basename', 'mkdir', 'mktemp', 'rm', 'chmod',
                 'cp', 'mv', 'awk', 'tr', 'sed', 'grep', 'tail', 'wc', 'stat', 'cmp', 'cat', 'shasum'):
        exe = shutil.which(name)
        assert exe, f'{name} missing from PATH'
        (tools / name).symlink_to(exe)
    env = dict(ENV, PATH=str(tools))
    run(['bash', '-c', 'command -v shasum; if command -v sha256sum; then exit 1; fi'], env=env)
    previous = LAB / 'pre-portability-fix'
    shutil.copytree(CONTRIB, previous)
    emit('\nRetrieve pre-fix test: git show 2c9335a:contrib/iqx-ixia-hook/ixia-hook.test.sh')
    old = subprocess.run(['git', 'show', '2c9335a:contrib/iqx-ixia-hook/ixia-hook.test.sh'],
                         cwd=ROOT, env=ENV, check=True, text=True, stdout=subprocess.PIPE).stdout
    # Only running the executable below proves the checksum regression.
    (previous / 'ixia-hook.test.sh').write_text(old)
    proc = run(['bash', previous / 'ixia-hook.test.sh'], env=env, expected=None)
    check(proc.returncode != 0 and 'sha256sum: command not found' in proc.stdout,
          'pre-fix test really fails on PATH with shasum but no sha256sum')
    run(['bash', CONTRIB / 'ixia-hook.test.sh'], env=env)

def upstream_merge():
    # Local upstream/fork divergence is deliberate fixture data. No real remote,
    # fork branch, gate ref or operator checkout is changed.
    repo = LAB / 'merge-workflow'
    repo.mkdir()
    git(repo, 'init', '-q', '-b', 'upstream-main')
    (repo / 'README.md').write_text('Disposable upstream template\n')
    git(repo, 'add', 'README.md')
    git(repo, 'commit', '-q', '-m', 'Upstream base')
    git(repo, 'checkout', '-q', '-b', 'personal-fork')
    folder = repo / 'contrib/iqx-ixia-hook'
    shutil.copytree(CONTRIB, folder)
    git(repo, 'add', 'contrib')
    git(repo, 'commit', '-q', '-m', 'Keep approved hook in personal fork only')
    before = {p.name: digest(p) for p in folder.iterdir() if p.is_file()}
    git(repo, 'checkout', '-q', 'upstream-main')
    (repo / 'README.md').write_text('Disposable upstream template: updated\n')
    (repo / 'bin').mkdir()
    (repo / 'bin/upstream-addition').write_text('Unrelated upstream addition\n')
    git(repo, 'add', 'README.md', 'bin')
    git(repo, 'commit', '-q', '-m', 'Unrelated upstream changes')
    git(repo, 'checkout', '-q', 'personal-fork')
    git(repo, 'merge', '--no-edit', 'upstream-main')
    check(before == {p.name: digest(p) for p in folder.iterdir() if p.is_file()},
          'upstream merge retained every contrib file byte-for-byte')
    home = LAB / 'post-merge-home'
    clone = new_clone(home, 'merged')
    run(['bash', folder / INSTALL.name, 'merged'], cwd=home)
    run(['bash', folder / VERIFY.name, 'merged'], cwd=home)
    installed(clone)

try:
    for name, fn in (
        ('Install from each home, reinstall safely and restore hooks after re-clone', install_homes),
        ('Refuse non-IQX targets and every differing or non-regular existing hook', refusal_guards),
        ('Respect hook routing boundaries and reject a changed approved bundle', overrides_and_source),
        ('Verify shared linked-worktree hooks without changing clone state; diagnose drift', verify_worktrees),
        ('Commit through the real Firstmate strip-and-chain path, retaining human content', commit_chain),
        ('Preserve empty-message abort and reproduce explicitly accepted bypass gaps', empty_and_gaps),
        ('Run the documented lab test with shasum and no GNU sha256sum', portable_checksum),
        ('Merge unrelated upstream changes and use the preserved fork-only hook tooling', upstream_merge),
    ):
        scenario(name, fn)
finally:
    # Firstmate intentionally makes its generated launch hooks read-only.
    for p in LAB.rglob('*'):
        if not p.is_symlink():
            p.chmod(p.stat().st_mode | 0o700 if p.is_dir() else p.stat().st_mode | 0o600)
    shutil.rmtree(LAB)
    emit(f'\nRemoved disposable lab: {LAB}')
    (EVIDENCE / 'live-results.json').write_text(json.dumps(RESULTS, indent=2) + '\n')
    LOG.close()
if any(result['result'] != 'pass' for result in RESULTS):
    raise SystemExit(1)
