import hashlib
import json
import os
from pathlib import Path
import resource
import shutil
import signal
import subprocess

root = Path.cwd()
evidence = Path('/home/node/.no-mistakes/evidence/01M4M3HQQZPRX4BQKNZYCRM1HR')
lab = root / '.test-local/staging-failure-home'
for name in ('data', 'state', 'config', 'projects', 'tmp', 'userhome'):
    (lab / name).mkdir(parents=True, exist_ok=True)
(lab / 'data/backlog.md').write_text('# Backlog\n\n## Queued\n' + ''.join(
    f'- [ ] task-{i} - Long contribution title {i} ' + 'payload ' * 10 + ' (kind: ship)\n'
    for i in range(12)))

def digest():
    return {str(p.relative_to(lab)): hashlib.sha256(p.read_bytes()).hexdigest()
            for top in ('data', 'state', 'config', 'projects')
            for p in (lab / top).rglob('*') if p.is_file()}

def limit_output_files():
    signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
    resource.setrlimit(resource.RLIMIT_FSIZE, (1024, 1024))

before = digest()
try:
    out = subprocess.run(['bash', str(root / 'bin/fm-fleet-snapshot.sh'), '--contribution-input'],
                         env={'PATH': os.environ['PATH'], 'HOME': str(lab / 'userhome'),
                              'FM_HOME': str(lab), 'TMPDIR': str(lab / 'tmp'), 'LANG': 'C.UTF-8'},
                         text=True, capture_output=True, preexec_fn=limit_output_files, timeout=30)
    remaining = [p.name for p in (lab / 'tmp').iterdir()]
    unchanged = before == digest()
    success = out.returncode != 0 and not out.stdout and 'contribution backlog write failed' in out.stderr and not remaining and unchanged
    (evidence / 'staging-failure.log').write_text(
        '$ RLIMIT_FSIZE=1024; SIGXFSZ=ignored; bash bin/fm-fleet-snapshot.sh --contribution-input\n'
        f'exit={out.returncode}\nstdout={out.stdout!r}\nstderr={out.stderr}'
        f'temporary_entries_after_exit={remaining}\noperational_state_unchanged={unchanged}\n'
        f'expected_write_refusal_and_cleanup={success}\n')
    assert success, 'real staging failure must refuse output, retain state, and remove partial files'
finally:
    shutil.rmtree(lab)
