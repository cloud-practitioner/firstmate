#!/usr/bin/env python3
"""Execute the changed counted wait blocks, not source-text assertions.

This is a focused non-live check of a test-only change. It is not fleet/harness
validation. The full delayed lifecycle script supplies product-script assertions.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path('/home/node/.no-mistakes/worktrees/450411b3e67c/01M40012HAGF4C4Q91QNT4Q373')
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M40012HAGF4C4Q91QNT4Q373')
BASE = 'e42087e4513c4483d832aa8898b28efd410fdac8'
PATH = 'tests/fm-remote-secondmate-lifecycle-e2e.test.sh'
versions = {
    'base': subprocess.check_output(['git', 'show', f'{BASE}:{PATH}'], cwd=ROOT, text=True),
    'target': (ROOT/PATH).read_text(),
}
# Extract executable blocks to exercise the exact counter, sleep cadence,
# process-death guard, and failure output. No content-matching assertion is
# counted as proof; every result below comes from executing a block in Bash.
def executable_block(source, start, end):
    return source[source.index(start):source.index(end, source.index(start))]

specs = {
    'inheritance': ('\ninherit_wait=0\n', 'cat > "$PARENT/data/captain-shared.md"', 'config_first', 'inherit.entered', 'inherit_wait'),
    'watcher': ('watch_wait=0\n', "watch_pid=''", 'watch_pid', None, 'watch_wait'),
    'respawn': ('launch_wait=0\n', 'remote_env "$ROOT/bin/fm-teardown.sh" ios > "$TMP_ROOT/teardown-serialized.out"', 'spawn_retirement_pid', 'launch.entered', 'launch_wait'),
}

def run_case(version, scenario, mode):
    start, end, pidvar, marker, counter = specs[scenario]
    source = versions[version]
    block = executable_block(source, start, end)
    budget = executable_block(source, '\nWAIT_BOUND_POLLS=', '\n\n') if version == 'target' else ''
    with tempfile.TemporaryDirectory(prefix='poll-proof-', dir=ROOT/'.no-mistakes/test-phase/tmp') as directory:
        child = "sleep 70 & timer=$!; trap 'kill \"$timer\" 2>/dev/null; wait \"$timer\" 2>/dev/null; exit 1' TERM; wait \"$timer\""
        if marker:
            child += f'; touch "$TMP_ROOT/{marker}"'
        if mode == 'early-exit':
            child = 'sleep 0.1; exit 7'
        elif mode == 'no-arrival':
            child = child.replace('sleep 70', 'sleep 10000')
        script = 'set -u\nTMP_ROOT=$1\n' + budget + '\n' + '''fail() { printf 'ASSERTION_FAILURE: %s\n' "$1" >&2; printf 'FAILURE_POLLS=%s\n' "${watch_wait:-${inherit_wait:-${launch_wait:-unknown}}}" >&2; exit 1; }
trap 'kill "$job" 2>/dev/null || true; wait "$job" 2>/dev/null || true' EXIT
'''
        script += f'( {child} ) &\njob=$!\n{pidvar}=$job\n'
        script += block
        script += f'printf "OBSERVED_POLLS=%s\\n" "${counter}"\n'
        started = time.monotonic()
        result = subprocess.run(['bash', '-c', script, '_', directory], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=500)
        return dict(version=version, scenario=scenario, mode=mode, exit=result.returncode, elapsed_seconds=round(time.monotonic()-started, 3), output=result.stdout)

cases = [(v, s, 'delayed') for v in versions for s in specs]
cases += [('target', s, 'early-exit') for s in ('inheritance', 'respawn')]
bounded = '--bounded-only' in sys.argv
if bounded:
    cases = [('target', 'watcher', 'no-arrival')]
results = []
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    for result in pool.map(lambda args: run_case(*args), cases):
        results.append(result)
        print(json.dumps(result), flush=True)
(EVIDENCE/('polling-bounded-results.json' if bounded else 'polling-regression-results.json')).write_text(json.dumps(results, indent=2)+'\n')
for result in results:
    expected = 0 if result['version'] == 'target' and result['mode'] == 'delayed' else 1
    if result['exit'] != expected:
        raise SystemExit(f"Unexpected wait behavior: {result}")
print('No-arrival watcher still fails at the fixed counted bound.' if bounded else 'Delayed arrivals: base rejects, target accepts; early process death: target still rejects.')
