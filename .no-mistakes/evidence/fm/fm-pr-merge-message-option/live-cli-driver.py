import json, os, pathlib, subprocess, hashlib

root = pathlib.Path.cwd()
base = root / '.validation' / 'live'
base.mkdir(parents=True, exist_ok=True)
evidence = pathlib.Path('/home/node/.no-mistakes/evidence/01M523GGJHNFXBFZ3AEB4RK0A8')
# Only genuine programs, not stand-ins. No forge binary is present, and no
# credential or user configuration is inherited by any CLI invocation.
real_tools = {'bash': '/usr/bin/bash', 'dirname': '/usr/bin/dirname', 'head': '/usr/bin/head', 'iconv': '/usr/bin/iconv', 'uname': '/usr/bin/uname'}
for mode in ['normal', 'no-iconv']:
    bindir = base / mode
    bindir.mkdir(exist_ok=True)
    for tool, source in real_tools.items():
        if mode == 'no-iconv' and tool == 'iconv':
            continue
        (bindir / tool).symlink_to(source)

bb = 'https://bitbucket.org/fm-disposable-test/message-validation/pull-requests/7'
urls = {'github':'https://github.com/example/repo/pull/15', 'gitlab':'https://gitlab.example/group/project/-/merge_requests/7', 'forgejo':'https://forgejo.example/fixture/repo/pulls/9'}
results = []
def invoke(name, url, payload, extra=None, expected='', pathmode='normal', filekind='file', options=None):
    case = base / name
    case.mkdir()
    home = case / 'home'
    state = home / 'state'
    state.mkdir(parents=True)
    (home / 'config').mkdir()
    (home / 'data').mkdir()
    meta = state / 'task-x1.meta'
    meta.write_text('kind=ship\nmode=no-mistakes\n')
    before = meta.read_bytes()
    message = case / 'message.txt'
    if filekind == 'directory':
        message.mkdir()
    elif filekind == 'fifo':
        os.mkfifo(message)
    elif filekind != 'missing':
        message.write_bytes(payload)
        if filekind == 'unreadable': message.chmod(0)
    args = ['--message-file', str(message)] if options is None else options(str(message))
    cmd = [str(root / 'bin/fm-pr-merge.sh'), 'task-x1', url] + args + (extra or [])
    env = {'PATH':str(base / pathmode),'HOME':str(home), 'FM_HOME':str(home), 'FM_ROOT_OVERRIDE':str(root), 'FM_STATE_OVERRIDE':str(state), 'TMPDIR':str(root / '.validation/tmp'), 'LC_ALL':'C', 'GIT_CONFIG_NOSYSTEM':'1', 'GIT_CONFIG_GLOBAL':'/dev/null'}
    run = subprocess.run(cmd, env=env, capture_output=True, timeout=10)
    stderr = run.stderr.decode(errors='replace')
    new_files = sorted(str(p.relative_to(state)) for p in state.rglob('*') if p.is_file() and p != meta)
    unchanged = meta.read_bytes() == before and not new_files
    passed = run.returncode == 2 and expected in stderr and unchanged
    results.append({'name':name,'command':cmd,'exit_code':run.returncode,'stdout':run.stdout.decode(errors='replace'),'stderr':stderr,'state_unchanged':unchanged,'new_state_files':new_files,'result':'pass' if passed else 'fail','live':True,'environment':'isolated home; genuine tools only; no forge tools, credentials, or operator configuration'})

for forge, url in urls.items():
    for mode in ['default', 'explicit', 'missing-file']:
        extra = []
        if mode == 'explicit':
            extra = {'github':['--attended-override','--','--admin','--merge'], 'gitlab':['--','--squash'], 'forgejo':['--','--rebase']}[forge]
        invoke(f'{forge}-{mode}',url,b'Caller supplied message\n',extra=extra,filekind='missing' if mode == 'missing-file' else 'file',expected=f'--message-file is not supported on this forge yet ({forge})')

for name, payload, kind, expected in [
    ('empty',b'','file','empty or only whitespace'),
    ('whitespace',b' \n\t\r\n  \n','file','empty or only whitespace'),
    ('missing',b'','missing','not a readable regular file'),
    ('directory',b'','directory','not a readable regular file'),
    ('fifo',b'','fifo','not a readable regular file'),
    ('unreadable',b'Subject','unreadable','not a readable regular file'),
    ('oversize',b'a'*16385,'file','larger than 16384 bytes'),
    ('nul',b'Subject\0hidden','file','contains a NUL byte'),
    ('bad-utf8-subject',b'caf\xe9\n','file','not valid UTF-8 text'),
    ('bad-utf8-body',b'Subject\n\ncaf\xe9\n','file','not valid UTF-8 text'),
]:
    invoke('validation-'+name,bb,payload,filekind=kind,expected=expected)
for name, opts, error in [
    ('no-value',lambda p:['--message-file'],'requires a path'),
    ('duplicate',lambda p:['--message-file',p,'--message-file',p],'may be specified only once'),
    ('equals',lambda p:['--message-file='+p],'requires a separate path argument'),
]:
    invoke('syntax-'+name,bb,b'Subject',options=opts,expected=error)
for name,payload in [('ascii',b'Subject'),('unicode','Café\n\nBody ✓'.encode()),('bad-subject',b'caf\xe9'),('bad-body',b'Subject\n\ncaf\xe9')]:
    invoke('no-iconv-'+name,bb,payload,pathmode='no-iconv',expected='requires iconv on PATH to validate UTF-8 text')
for name, extra, strategy in [
    ('rebase',['--','--rebase'],'rebase_fast_forward'),
    ('fast-forward',['--','--method','fast_forward'],'fast_forward'),
    ('rebase-method',['--','--method=rebase_fast_forward'],'rebase_fast_forward'),
]:
    invoke('strategy-'+name,bb,b'Subject\n',extra=extra,expected=f'{strategy} merge strategy creates no commit to carry --message-file')

(evidence / 'live-cli-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
lines = ['Real fm-pr-merge.sh CLI; isolated homes and genuine tools; no remote forge access.\n']
for r in results:
    lines += ['$ '+' '.join(r['command']),r['stderr'].rstrip(),f"exit={r['exit_code']}; persisted state unchanged={r['state_unchanged']}; {r['result']}",'']
(evidence / 'live-cli-transcript.txt').write_text('\n'.join(lines)+'\n')
for r in results:
    print(r['name']+': '+r['result']+'; '+r['stderr'].strip())
if any(r['result']!='pass' for r in results): raise SystemExit(1)
