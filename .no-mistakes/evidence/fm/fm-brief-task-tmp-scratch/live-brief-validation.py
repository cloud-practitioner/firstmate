#!/usr/bin/env python3
"""Disposable live check of fm-brief.sh's generated worker-instruction contract."""
import concurrent.futures
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

ROOT = Path.cwd()
SCRATCH = ROOT / '.nm-tasktmp-live'
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M407KTFK6ZNF2EBV1QRSBVGD')
EVIDENCE.mkdir(parents=True, exist_ok=True)
(SCRATCH / 'tmp').mkdir(exist_ok=True)
ENV = {k: v for k, v in os.environ.items() if not k.startswith('FM_') and k not in ('TASKS_AXI_FILE', 'TASKS_AXI_BACKEND')}
ENV.update(TMPDIR=str(SCRATCH / 'tmp'), GIT_CONFIG_GLOBAL=str(ROOT / 'tests/git-fixture.gitconfig'), GIT_CONFIG_NOSYSTEM='1')
TRANSCRIPT = []
RESULTS = []


def scaffold(label, home, task, flags, overrides=None, code_root=ROOT):
    home.mkdir(parents=True, exist_ok=True)
    for name in ('data', 'state', 'config'):
        (home / name).mkdir(exist_ok=True)
    env = dict(ENV, FM_HOME=str(home))
    env.update(overrides or {})
    cmd = ['bash', str(code_root / 'bin/fm-brief.sh'), task, 'disposable-project', *flags]
    result = subprocess.run(cmd, cwd=ROOT, env=env, text=True, capture_output=True, timeout=30)
    transcript = ['$ ' + shlex.join(cmd), 'FM_HOME=' + str(home), json.dumps(overrides or {}), result.stdout, result.stderr, 'exit=' + str(result.returncode)]
    assert result.returncode == 0, '\n'.join(transcript)
    data = Path(env.get('FM_DATA_OVERRIDE', str(home / 'data')))
    brief = (data / task / 'brief.md').read_text()
    rule = brief.split('# Rules\n', 1)[1].split('\n3.', 1)[0]
    transcript.extend(['Emitted Rules 1-2:', rule])
    if any(line.startswith('If you pass `--intent`') for line in brief.splitlines()):
        transcript.extend([line for line in brief.splitlines() if line.startswith('If you pass `--intent`')])
    (EVIDENCE / (label + '.brief.md')).write_text(brief)
    return brief, rule, transcript


def assert_contract(brief, rule, expected):
    lines = [line for line in rule.splitlines() if line.startswith('   Put your scratch files,')]
    assert len(lines) == 1, 'Scratch contract must be emitted exactly once in Rules'
    line = lines[0]
    assert 'including any no-mistakes `--intent` file' in line
    prefix = 'under your task temp root '
    quoted = line.split(prefix, 1)[1].split(', which already exists;', 1)[0]
    decoded = shlex.split(quoted)
    assert decoded == [str(expected)], (decoded, str(expected))
    assert 'never write them to a fixed path in shared /tmp, which other workers share.' in line
    assert 'scratch files under your task temp root' in rule.splitlines()[1]
    assert 'modify nothing outside it.' not in rule
    assert 'the only files you may write outside it are the report and the status file below.' not in rule
    assert '/tmp/intent.txt' not in brief
    return decoded[0]


try:
    ship_home = SCRATCH / 'ship-home'
    for mode in ('no-mistakes', 'direct-PR', 'local-only'):
        task = 'live-ship-' + mode
        brief, rule, log = scaffold('ship-' + mode, ship_home, task, ['--mode', mode])
        assert_contract(brief, rule, ship_home / 'state' / (task + '.tasktmp'))
        assert 'Delivery contract: mode=' + mode in brief
        TRANSCRIPT.extend(log)
    RESULTS.append({'name': 'Scaffold a ship in each delivery mode and receive its task-specific scratch rule', 'result': 'pass'})

    task = 'live-scout'
    home = SCRATCH / 'scout-home'
    brief, rule, log = scaffold('scout', home, task, ['--scout'])
    assert_contract(brief, rule, home / 'state' / (task + '.tasktmp'))
    assert 'the only files you may write outside it are the report, the status file below, and scratch files under your task temp root.' in rule
    TRANSCRIPT.extend(log)
    RESULTS.append({'name': 'Scaffold a scout and receive the private scratch exception alongside report/status exceptions', 'result': 'pass'})

    intent_rule = 'If you pass `--intent` through a file, write it under your task temp root named in the Rules, never at a fixed path in shared /tmp.'
    assert intent_rule in (EVIDENCE / 'ship-no-mistakes.brief.md').read_text()
    home = SCRATCH / 'gerrit-home'
    task = 'live-ship-gerrit'
    brief, rule, log = scaffold('ship-gerrit-no-mistakes', home, task, ['--mode', 'no-mistakes', '--forge', 'gerrit'])
    assert_contract(brief, rule, home / 'state' / (task + '.tasktmp'))
    assert intent_rule in brief
    assert 'Delivery contract: mode=no-mistakes forge=gerrit shape=squash' in brief
    TRANSCRIPT.extend(log)
    RESULTS.append({'name': 'Choose no-mistakes delivery and receive the intent-file reminder on both ordinary and Gerrit briefs', 'result': 'pass'})

    task = 'same-intent-task'
    lane_homes = [SCRATCH / 'project-a-home', SCRATCH / 'project-b-home']
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(scaffold, 'concurrent-project-' + str(i + 1), home, task, ['--mode', 'no-mistakes']) for i, home in enumerate(lane_homes)]
        outputs = [future.result() for future in futures]
    recommended = []
    for home, (brief, rule, log) in zip(lane_homes, outputs):
        recommended.append(assert_contract(brief, rule, home / 'state' / (task + '.tasktmp')))
        TRANSCRIPT.extend(log)
    assert recommended[0] != recommended[1]
    TRANSCRIPT.extend(['Same task ID in concurrent projects; emitted intent destinations do not alias:', *recommended])
    RESULTS.append({'name': 'Scaffold the same task ID concurrently in two project homes without recommending a shared intent destination', 'result': 'pass'})

    home = SCRATCH / "relative home with ' quote"
    state = SCRATCH / "relative state with ' quote"
    data = SCRATCH / "relative data with ' quote"
    state.mkdir(exist_ok=True)
    data.mkdir(exist_ok=True)
    for kind, flags in [('ship', ['--mode', 'no-mistakes']), ('scout', ['--scout'])]:
        task = 'quoted-' + kind
        brief, rule, log = scaffold('quoted-' + kind, home, task, flags, {
            'FM_HOME': str(home.relative_to(ROOT)),
            'FM_STATE_OVERRIDE': str(state.relative_to(ROOT)),
            'FM_DATA_OVERRIDE': str(data.relative_to(ROOT)),
        })
        assert_contract(brief, rule, state / (task + '.tasktmp'))
        TRANSCRIPT.extend(log)
    RESULTS.append({'name': 'Use relative state/data overrides containing spaces and apostrophes and receive an unambiguous absolute scratch path', 'result': 'pass'})

    # Select only the new behavioral regression, not the file's suite walk or static guards.
    selector = """source tests/lib.sh
TMP_ROOT=$(fm_test_tmproot fm-brief-scratch-targeted)
eval \"$(awk '/^test_scaffolds_name_task_temp_root_for_scratch\\(\\)/,/^}/' tests/fm-brief.test.sh)\"
ROOT=$1
test_scaffolds_name_task_temp_root_for_scratch
"""
    target = subprocess.run(['bash', '-c', selector, '_', str(ROOT)], cwd=ROOT, env=ENV, text=True, capture_output=True, timeout=45)
    TRANSCRIPT.extend(['Targeted regression: test_scaffolds_name_task_temp_root_for_scratch', target.stdout, target.stderr, 'exit=' + str(target.returncode)])
    assert target.returncode == 0, target.stderr

    base_root = SCRATCH / 'base'
    base_root.mkdir(exist_ok=True)
    archive = subprocess.run(['git', 'archive', '2358151bc029052bb322d0ebbf8e039b273e463f', 'bin'], env=ENV, capture_output=True, check=True)
    subprocess.run(['tar', '-x', '-C', str(base_root)], input=archive.stdout, env=ENV, check=True)
    baseline = subprocess.run(['bash', '-c', selector, '_', str(base_root)], cwd=ROOT, env=ENV, text=True, capture_output=True, timeout=45)
    TRANSCRIPT.extend(['Same regression against base commit 2358151bc029052bb322d0ebbf8e039b273e463f:', baseline.stdout, baseline.stderr, 'exit=' + str(baseline.returncode)])
    assert baseline.returncode != 0
    assert 'brief did not name the task temp root' in baseline.stderr
    brief, rule, log = scaffold('base-no-mistakes', SCRATCH / 'base-home', 'base-proof', ['--mode', 'no-mistakes'], code_root=base_root)
    TRANSCRIPT.extend(log)
    assert 'Put your scratch files' not in rule
    assert 'modify nothing outside it.' in rule
    RESULTS.append({'name': 'Run the new generated-brief regression against base and target and reproduce the missing instruction only on base', 'result': 'pass'})
except Exception as exc:
    TRANSCRIPT.append('ERROR: ' + repr(exc))
    (EVIDENCE / 'generated-brief-transcript.log').write_text('\n'.join(TRANSCRIPT))
    raise
finally:
    (EVIDENCE / 'generated-brief-transcript.log').write_text('\n'.join(TRANSCRIPT))
    (EVIDENCE / 'scenario-results.json').write_text(json.dumps(RESULTS, indent=2) + '\n')
print(json.dumps(RESULTS, indent=2))
print('Product evidence: ' + str(EVIDENCE / 'generated-brief-transcript.log'))
