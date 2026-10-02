#!/usr/bin/env python3
"""Drive the generated worker-brief text contract via the public scaffold CLI."""
import concurrent.futures
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

ROOT = Path.cwd()
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M3ZFZSTC6HHJWFSYAXAYC82K')
EVIDENCE.mkdir(parents=True, exist_ok=True)
lab = Path(tempfile.mkdtemp(prefix='.brief-live-', dir=ROOT))
transcript = []
env = dict(os.environ)
for key in list(env):
    if key.startswith('FM_') or key in ('TASKS_AXI_FILE', 'TASKS_AXI_BACKEND'):
        env.pop(key)
env['TMPDIR'] = str(lab)


def scaffold(home, task, args, executable=None, state=None):
    home.mkdir(parents=True, exist_ok=True)
    (home / 'config').mkdir(exist_ok=True)
    local = dict(env, FM_HOME=str(home))
    if state is not None:
        state.mkdir(parents=True, exist_ok=True)
        local['FM_STATE_OVERRIDE'] = str(state)
    cmd = [str(executable or ROOT / 'bin/fm-brief.sh'), task, 'firstmate', *args]
    r = subprocess.run(cmd, env=local, cwd=ROOT, text=True, capture_output=True, timeout=30)
    assert r.returncode == 0, (cmd, r.stdout, r.stderr)
    brief = home / 'data' / task / 'brief.md'
    body = brief.read_text()
    return {'command': shlex.join(cmd), 'home': str(home), 'state_override': str(state) if state else None,
            'stdout': r.stdout, 'stderr': r.stderr, 'brief': str(brief)}, body


def verify(body, root, no_mistakes=False):
    lines = body.splitlines()
    rule = next(line for line in lines if line.startswith('   Put your scratch files,'))
    prefix = 'under your task temp root '
    quoted = rule.split(prefix, 1)[1].split(', which already exists;', 1)[0]
    assert shlex.split(quoted) == [str(root)], (quoted, root)
    assert 'including any no-mistakes `--intent` file' in rule
    assert 'never write them to a fixed path in shared /tmp, which other workers share.' in rule
    permission = next(line for line in lines if line.startswith('2. Stay inside this worktree;'))
    assert 'scratch files under your task temp root' in permission
    if no_mistakes:
        assert 'If you pass `--intent` through a file, write it under your task temp root named in the Rules, never at a fixed path in shared /tmp.' in body
    return {'permission': permission, 'scratch_rule': rule, 'decoded_root': shlex.split(quoted)[0]}

try:
    home = lab / 'ordinary-home'
    for mode in ('no-mistakes', 'direct-PR', 'local-only', 'scout'):
        task = 'live-' + mode
        args = ['--scout'] if mode == 'scout' else ['--mode', mode]
        record, body = scaffold(home, task, args)
        record['observed_contract'] = verify(body, home / 'state' / (task + '.tasktmp'), mode == 'no-mistakes')
        dest = EVIDENCE / ('generated-' + mode + '-brief.md')
        dest.write_text(body)
        record['artifact'] = str(dest)
        transcript.append(record)

    # Same task ID and basename in simultaneous lanes must not name shared scratch.
    # Apostrophes and spaces challenge the shell-quoted public path contract.
    jobs = [
        (lab / "lane one's home", 'same-task', ['--mode', 'no-mistakes'], None),
        (lab / 'lane two home', 'same-task', ['--scout'], lab / "separate state's root"),
    ]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda job: scaffold(job[0], job[1], job[2], state=job[3]), jobs))
    decoded = []
    for index, ((home, task, args, state), (record, body)) in enumerate(zip(jobs, results), 1):
        root = (state or home / 'state') / (task + '.tasktmp')
        contract = verify(body, root, args == ['--mode', 'no-mistakes'])
        decoded.append(contract['decoded_root'])
        record['observed_contract'] = contract
        dest = EVIDENCE / ('concurrent-lane-' + str(index) + '-brief.md')
        dest.write_text(body)
        record['artifact'] = str(dest)
        transcript.append(record)
    assert decoded[0] != decoded[1]
    assert decoded[0] not in results[1][1] and decoded[1] not in results[0][1]
    transcript.append({'concurrent_result': 'Same task ID emits distinct home-specific scratch roots; quoted paths decode without splitting; explicit state override honored.', 'roots': decoded})

    # Execute the historical public CLI, rather than inspecting its source for phrases.
    baseline = lab / 'baseline'
    (baseline / 'bin').mkdir(parents=True)
    for file in (ROOT / 'bin').iterdir():
        (baseline / 'bin' / file.name).symlink_to(file)
    for name in ('fm-brief.sh', 'fm-dod-lib.sh'):
        dest = baseline / 'bin' / name
        dest.unlink()
        historical = subprocess.run(['git', 'show', '8bcf44abca9eadb29596ced4c0168a8fa530189f:bin/' + name], check=True, capture_output=True).stdout
        dest.write_bytes(historical)
        dest.chmod(0o755)
    for mode in ('no-mistakes', 'scout'):
        home = lab / ('baseline-' + mode)
        args = ['--scout'] if mode == 'scout' else ['--mode', mode]
        record, body = scaffold(home, 'regression', args, baseline / 'bin/fm-brief.sh')
        try:
            verify(body, home / 'state/regression.tasktmp', mode == 'no-mistakes')
        except (StopIteration, AssertionError):
            record['regression'] = 'Pre-change emitted brief fails the task-scratch contract; target passes.'
        else:
            raise AssertionError('Regression contract unexpectedly passes before change')
        dest = EVIDENCE / ('baseline-' + mode + '-brief.md')
        dest.write_text(body)
        record['artifact'] = str(dest)
        transcript.append(record)

    # Select only the added existing test, avoiding unrelated parse/static checks.
    test_source = (ROOT / 'tests/fm-brief.test.sh').read_text()
    declarations = test_source.rsplit('\ntest_script_parses\n', 1)[0]
    runner = ROOT / 'tests/.brief-targeted-runner.sh'
    runner.write_text(declarations + '\nif [ -n "${BRIEF_VALIDATION_BASELINE:-}" ]; then ROOT="$BRIEF_VALIDATION_BASELINE"; fi\ntest_scaffolds_name_task_temp_root_for_scratch\n')
    try:
        test_env = dict(env)
        current = subprocess.run(['bash', str(runner)], env=test_env, cwd=ROOT, capture_output=True, text=True, timeout=60)
        assert current.returncode == 0, (current.stdout, current.stderr)
        old = subprocess.run(['bash', str(runner)], env=dict(test_env, BRIEF_VALIDATION_BASELINE=str(baseline)), cwd=ROOT, capture_output=True, text=True, timeout=60)
        assert old.returncode != 0, 'Added test does not detect historical failure'
        transcript.append({'test_selector': 'tests/fm-brief.test.sh::test_scaffolds_name_task_temp_root_for_scratch',
                           'target': {'exit_code': current.returncode, 'stdout': current.stdout, 'stderr': current.stderr},
                           'baseline': {'exit_code': old.returncode, 'stdout': old.stdout, 'stderr': old.stderr}})
    finally:
        runner.unlink(missing_ok=True)
    (EVIDENCE / 'brief-live-validation.json').write_text(json.dumps(transcript, indent=2) + '\n')
    print(json.dumps(transcript, indent=2))
finally:
    shutil.rmtree(lab)
