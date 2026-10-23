#!/usr/bin/env python3
"""Drive the real brief scaffold into the real intake consumer in a disposable home."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

ROOT = Path('/home/node/.no-mistakes/worktrees/450411b3e67c/01M5KTDVCMKC5EZ9HW8F6A74KH')
OUT = Path('/home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH')
log = []
with tempfile.TemporaryDirectory(prefix='brief-', dir=ROOT / '.test-evidence-tmp') as tmp:
    home = Path(tmp) / 'home'
    for directory in ('data', 'state', 'config', 'projects/demo'):
        (home / directory).mkdir(parents=True)
    env = dict(os.environ)
    for name in list(env):
        if name.startswith('FM_') or name in ('GH_TOKEN', 'GITHUB_TOKEN', 'NO_MISTAKES_BITBUCKET_EMAIL', 'NO_MISTAKES_BITBUCKET_API_TOKEN'):
            env.pop(name)
    env.update(FM_HOME=str(home), TMPDIR=tmp, GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1')
    def run(args, expected=0):
        args = [str(x) for x in args]
        result = subprocess.run(args, cwd=ROOT, env=env, capture_output=True, text=True, timeout=15)
        log.append('$ ' + shlex.join(args) + '\n' + result.stdout + result.stderr + '(exit status %d)\n' % result.returncode)
        assert result.returncode == expected, result.stdout + result.stderr
        return result.stdout + result.stderr
    project = home / 'projects/demo'
    run(['git', '-C', project, 'init', '-q'])
    run(['git', '-C', project, 'remote', 'add', 'origin', 'https://github.com/local-validation/no-network.git'])
    (home / 'config/pr-evidence').write_text('* enforce\n')
    run([ROOT / 'bin/fm-brief.sh', 'evidence-brief', 'demo', '--mode', 'no-mistakes'])
    brief = home / 'data/evidence-brief/brief.md'
    (OUT / 'generated-brief.md').write_bytes(brief.read_bytes())
    refusal = run([ROOT / 'bin/fm-pr-evidence.sh', 'intake', brief, 'demo', 'no-mistakes', 'none', project], 1)
    assert 'not filled' in refusal, 'The actual scaffold must reach the unfilled-declaration guard'
    # This is editing generated user input, not implementation source.
    brief.write_text(brief.read_text().replace('{EVIDENCE}', 'ui+api'))
    accepted = run([ROOT / 'bin/fm-pr-evidence.sh', 'intake', brief, 'demo', 'no-mistakes', 'none', project])
    assert accepted.strip() == 'evidence=ui+api', 'The filled scaffold must reach intake as both kinds'
    (OUT / 'filled-brief.md').write_bytes(brief.read_bytes())
    run([ROOT / 'bin/fm-brief.sh', 'local-brief', 'demo', '--mode', 'local-only'])
    accepted = run([ROOT / 'bin/fm-pr-evidence.sh', 'intake', home / 'data/local-brief/brief.md', 'demo', 'local-only', 'none', project])
    assert not accepted.strip(), 'Excluded local-only intake must emit no evidence metadata'
(OUT / 'brief-intake-transcript.txt').write_text('\n'.join(log))
print(json.dumps({'name': 'Scaffold an eligible brief; refuse its placeholder and accept the filled evidence declaration',
                  'result': 'pass', 'live': True, 'evidence': 'brief-intake-transcript.txt; generated-brief.md; filled-brief.md', 'reason': ''}, indent=2))
