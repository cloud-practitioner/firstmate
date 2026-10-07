#!/usr/bin/env python3
"""Resume only captain-hold suite cases not reached by the bounded first invocation."""
import os, pathlib, subprocess
root = pathlib.Path.cwd()
suite = (root / 'tests/fm-captain-hold-lifecycle.test.sh').read_text()
marker = '\ntest_hold_reason_round_trips_awkward_characters\n'
definitions, calls = suite.split(marker, 1)
definitions = definitions.replace('. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"', '. "' + str(root / 'tests/lib.sh') + '"')
remaining = calls[calls.index('test_legacy_identities_keep_working\n'):]
result = subprocess.run(['bash'], input=definitions + '\n' + remaining, text=True, env={**os.environ, 'TMPDIR': '/tmp'})
print('remaining captain-hold suite exit=' + str(result.returncode), flush=True)
pathlib.Path(__file__).with_name('remaining-suite.exit').write_text(str(result.returncode) + '\n')
raise SystemExit(result.returncode)
