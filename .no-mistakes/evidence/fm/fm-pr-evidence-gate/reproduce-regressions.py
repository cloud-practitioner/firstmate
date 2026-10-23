#!/usr/bin/env python3
"""Run narrow executable-interface regressions against historical snapshots and HEAD.
Snapshots and temp state stay under this run's worktree and are removed on exit.
No fleet lifecycle, credential operations, or forge mutation is involved.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path('/home/node/.no-mistakes/worktrees/450411b3e67c/01M5KTDVCMKC5EZ9HW8F6A74KH')
OUT = Path('/home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH')
log = []
results = []
with tempfile.TemporaryDirectory(prefix='historical-', dir=ROOT / '.test-evidence-tmp') as tmp:
    tmp = Path(tmp)
    env = dict(os.environ, TMPDIR=str(tmp), PYTHONDONTWRITEBYTECODE='1')
    for name in list(env):
        if name.startswith('FM_') or name in ('GH_TOKEN', 'GITHUB_TOKEN', 'NO_MISTAKES_BITBUCKET_EMAIL', 'NO_MISTAKES_BITBUCKET_API_TOKEN'):
            env.pop(name)
    selectors = {
        '163827e5': ['EvidenceRegressions.test_sidecar_capture_retains_only_final_response_headers_and_trailers'],
        '38d81698': ['EvidenceRegressions.test_api_capture_handles_head_without_a_response_body',
                     'EvidenceRegressions.test_sidecar_capture_unfolds_headers_before_masking'],
    }
    for revision, tests in selectors.items():
        snapshot = tmp / revision
        (snapshot / 'bin').mkdir(parents=True)
        (snapshot / 'tests').mkdir()
        shutil.copyfile(ROOT / 'tests/fm-pr-evidence-regressions.test.py', snapshot / 'tests/fm-pr-evidence-regressions.test.py')
        for path in (ROOT / 'bin').iterdir():
            target = snapshot / 'bin' / path.name
            if path.name in ('fm-pr-evidence.sh', 'fm-pr-evidence-lib.py'):
                source = subprocess.run(['git', 'show', revision + ':bin/' + path.name], cwd=ROOT, capture_output=True, check=True).stdout
                target.write_bytes(source)
                target.chmod(0o755)
            else:
                target.symlink_to(path)
        for test in tests:
            command = ['python3', str(snapshot / 'tests/fm-pr-evidence-regressions.test.py'), test]
            result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=25)
            log.append('$ ' + ' '.join(command) + '\n' + result.stdout + result.stderr + '(exit status %d)\n' % result.returncode)
            assert result.returncode == 1 and 'FAIL:' in result.stderr, 'The historical version must reproduce the regression: ' + test
            results.append({'revision': revision, 'test': test, 'expected': 'failure before fix', 'exit': result.returncode})
    tests = [test for values in selectors.values() for test in values]
    command = ['python3', str(ROOT / 'tests/fm-pr-evidence-regressions.test.py')] + tests
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=25)
    log.append('$ ' + ' '.join(command) + '\n' + result.stdout + result.stderr + '(exit status %d)\n' % result.returncode)
    assert result.returncode == 0, 'The current version must pass all focused regressions'
    results.append({'revision': '791c507bc21d52563f59e2e410087668d6ac8783', 'tests': tests, 'expected': 'pass after fixes', 'exit': result.returncode})
(OUT / 'historical-regression-transcript.txt').write_text('\n'.join(log))
(OUT / 'historical-regression-results.json').write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))
