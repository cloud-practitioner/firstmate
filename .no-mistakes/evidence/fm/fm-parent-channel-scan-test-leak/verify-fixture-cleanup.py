#!/usr/bin/env python3
"""Execute the real focused test, observe its temporary allocations and exit cleanup.
This validates test infrastructure, not a live Firstmate user scenario.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path('/home/node/.no-mistakes/worktrees/450411b3e67c/01M3ZFR7DBEK89N243QTJQA5RB')
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M3ZFR7DBEK89N243QTJQA5RB')
BASE = '8bcf44abca9eadb29596ced4c0168a8fa530189f'
TEST = 'tests/fm-parent-channel-scan-exclusion.test.sh'
sandbox = Path(tempfile.mkdtemp(prefix='.cleanup-validation-', dir=REPO))
baseline = REPO / 'tests' / (sandbox.name + '.baseline.sh')
results = []
try:
    baseline.write_bytes(subprocess.check_output(['git', 'show', f'{BASE}:{TEST}'], cwd=REPO))
    for revision, script in [('before-fix', baseline), ('after-fix', REPO / TEST)]:
        for forced_failure in (False, True):
            label = f'{revision}-' + ('assertion-failure' if forced_failure else 'normal-exit')
            run = sandbox / label
            run.mkdir()
            tmp = run / 'tmp'
            tmp.mkdir()
            home = run / 'home'
            home.mkdir()
            tools = run / 'tools'
            tools.mkdir()
            recorded = run / 'allocations.txt'
            mktemp = tools / 'mktemp'
            real_mktemp = shutil.which('mktemp')
            assert real_mktemp
            mktemp.write_text('#!/usr/bin/env bash\n'
                f'out=$({real_mktemp} "$@") || exit $?\n'
                'printf "%s\\n" "$out" >> "$OBSERVED_ALLOCATIONS"\n'
                'printf "%s\\n" "$out"\n')
            mktemp.chmod(0o755)
            if forced_failure:
                cut = tools / 'cut'
                cut.write_text('#!/usr/bin/env bash\nprintf "injected cut failure for EXIT-cleanup validation\\n" >&2\nexit 99\n')
                cut.chmod(0o755)
            sentinel = tmp / 'unregistered-sibling.txt'
            sentinel.write_text('must survive registered-root cleanup\n')
            env = {k: v for k, v in os.environ.items()
                   if not k.startswith(('FM_', 'GIT_', 'TASKS_AXI_'))
                   and k not in ('BASH_ENV', 'ENV', 'NO_MISTAKES_GATE')}
            env.update(HOME=str(home), FM_HOME=str(home), TMPDIR=str(tmp),
                       PATH=str(tools) + os.pathsep + os.environ['PATH'],
                       OBSERVED_ALLOCATIONS=str(recorded), FM_TEST_SKIP_ORPHAN_REAP='1')
            result = subprocess.run(['bash', str(script)], cwd=REPO, env=env,
                                    text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=120)
            allocations = [Path(line) for line in recorded.read_text().splitlines()]
            roots = [p for p in allocations if p.name.startswith('fm-parent-channel-scan-exclusion')]
            registries = [p for p in allocations if p.name.startswith(('.fm-test-cleanup.', '.fm-test-procevent.', '.fm-test-watcher.'))]
            assert len(roots) == 2, (label, roots)
            assert len(registries) == 3, (label, registries)
            survivors = [str(p.relative_to(sandbox)) for p in roots + registries if p.exists()]
            expected_rc = 1 if forced_failure else 0
            assert result.returncode == expected_rc, (label, result.returncode, result.stdout)
            if forced_failure:
                assert 'not ok -' in result.stdout and 'injected cut failure' in result.stdout
            assert sentinel.read_text() == 'must survive registered-root cleanup\n'
            if revision == 'before-fix':
                assert len(survivors) == 4, (label, survivors)
                assert not roots[0].exists() and roots[1].exists()
                assert all(p.exists() for p in registries)
            else:
                assert not survivors, (label, survivors)
            entry = {
                'case': label,
                'command': f'bash {script.relative_to(REPO)} (isolated TMPDIR/HOME; allocation observer)' + ('; cut forced to exit 99' if forced_failure else ''),
                'test_exit_status': result.returncode,
                'observed_registered_roots': [str(p.relative_to(sandbox)) for p in roots],
                'observed_registry_files': [str(p.relative_to(sandbox)) for p in registries],
                'remaining_roots_and_registries_after_exit': survivors,
                'unregistered_sibling_preserved': True,
                'checks_met': True,
                'live_product_scenario': False,
            }
            results.append(entry)
            log = result.stdout + '\nEXIT/CLEANUP OBSERVATION\n' + json.dumps(entry, indent=2) + '\n'
            (EVIDENCE / f'{label}.log').write_text(log)
            print(json.dumps(entry, indent=2), flush=True)
    (EVIDENCE / 'fixture-cleanup-results.json').write_text(json.dumps(results, indent=2) + '\n')
finally:
    baseline.unlink(missing_ok=True)
    shutil.rmtree(sandbox)
