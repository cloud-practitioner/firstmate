#!/usr/bin/env python3
"""Disposable live CLI evidence: run from the gate worktree, no workers or network."""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess

root = Path.cwd()
lab = root / '.iqx-live-validation' / 'manual'
evidence = Path('/home/node/.no-mistakes/evidence/01M62Y53S4A6PRE0JQ7QTSKNYK')
home = lab / 'home'
foreign = lab / 'other-home'
linked = lab / 'linked-home'
invocation = lab / 'invocation'
worker = lab / 'worker'
for p in (home / 'data', home / 'state', home / 'config', foreign / 'data', invocation, worker):
    p.mkdir(parents=True, exist_ok=True)
linked.symlink_to(home, target_is_directory=True)
ticket = 'DEMO-1'
plans = home / 'data' / ticket / 'plans'
plans.mkdir(parents=True)
for name, text in {
    'plan.md': '# Synthetic offline plan, revision 2\nCorrect the shared runner Resume outcome rule.\n',
    'dispositions.md': '# Synthetic dispositions\nAccepted: verify the persisted result before success.\n',
    'what-changed.md': '# Synthetic revision list\nAdded the persisted-result check after the panel.\n',
}.items():
    (plans / name).write_text(text)
plugin = invocation / 'vendor' / 'ixia' / 'plugins' / 'ixia-stratex'
(plugin / '.claude-plugin').mkdir(parents=True)
(plugin / '.claude-plugin' / 'plugin.json').write_text('{"version": "1.0.23"}\n')
(plugin / 'agents').mkdir()
for agent in ('plan-architect.md', 'plan-security.md'):
    (plugin / 'agents' / agent).write_text('Synthetic dependency path fixture, not a real Ixia contract.\n')
credential = invocation / 'credentials' / 'bitbucket.env'
credential.parent.mkdir()
credential.write_text('SYNTHETIC_DO_NOT_EMIT\n')
(home / 'intent.txt').write_text('Synthetic product-owner intent: preserve literal {TASK} and {FIRSTMATE_SPEC} when supplied as context.\n')
(home / 'seeds.txt').write_text('- Resume with a corrected request\n- Resume after an opposite event\n')
env = os.environ.copy()
for key in ('FM_HOME', 'FM_ROOT_OVERRIDE', 'FM_DATA_OVERRIDE', 'FM_STATE_OVERRIDE', 'FM_CONFIG_OVERRIDE', 'FM_PROJECTS_OVERRIDE'):
    env.pop(key, None)
env['TMPDIR'] = str(root / '.iqx-live-validation' / 'tmp')
log = []

def call(args, expected=0, cwd=root, extra=None):
    e = dict(env)
    if extra:
        e.update(extra)
    result = subprocess.run([str(x) for x in args], cwd=cwd, env=e, text=True, capture_output=True)
    log.append('$ (cd %s && %s)\nexit=%s\nstdout:\n%s\nstderr:\n%s' %
               (shlex.quote(str(cwd)), shlex.join([str(x) for x in args]), result.returncode, result.stdout, result.stderr))
    assert result.returncode == expected, log[-1]
    return result

def scaffold(task, branch='feature/revision', selected=home):
    args = ['bash', root / 'bin/fm-brief.sh', task, 'synthetic-module', '--scout']
    if branch:
        args += ['--base-branch', branch]
    call(args, extra={'FM_HOME': str(selected)})
    return home / 'data' / task / 'brief.md'

def generate(kind, task, *options, selected=home, stdout=False, expected=0, extra=None):
    args = ['python3', root / 'contrib/iqx-lenses/mk-lens-brief.py', kind, '--home', selected,
            '--task', task, '--ticket', ticket, '--plan', f'data/{ticket}/plans/plan.md', *options]
    if stdout:
        args += ['--stdout']
    return call(args, expected=expected, cwd=invocation, extra=extra)

def unchanged(path, before):
    assert path.read_bytes() == before, f'{path} was modified on refusal/preview'

def snapshot(task, name):
    text = (home / 'data' / task / 'brief.md').read_text()
    (evidence / name).write_text(text)
    return text

# Actual scaffold through an absolute symlink; generator sees its canonical home.
b = scaffold('runproof-primary', selected=linked)
before = b.read_bytes()
common = ['--dispositions', f'data/{ticket}/plans/dispositions.md', '--changes', f'data/{ticket}/plans/what-changed.md',
          '--ixia-dir', 'vendor/ixia', '--seed', 'Success when nothing was applied', '--seeds-file', home / 'seeds.txt',
          '--extra', 'Ticket-specific simulator requirement: dropFields; literal {TASK}.', '--intent-file', home / 'intent.txt',
          '--touches', 'runner', '--touches', 'resume']
preview = generate('runproof', 'runproof-primary', *common, stdout=True)
unchanged(b, before)
assert 'second-model: required (plan changes runner, resume)' in preview.stderr
assert 'ONE OUTPUT PATH: ' + str(plans / 'reviews/run-proof-claude-opus-5.5.md') in preview.stdout
assert 'at origin/feature/revision in your scratch worktree' in preview.stdout
assert 'Read the Ixia plugin read-only from the pinned local copy ' + str(plugin) in preview.stdout
assert 'Ticket-specific simulator requirement: dropFields; literal {TASK}.' in preview.stdout
assert 'preserve literal {TASK} and {FIRSTMATE_SPEC}' in preview.stdout
assert 'Resume after an opposite event' in preview.stdout
written = generate('runproof', 'runproof-primary', *common)
assert b.read_text() == preview.stdout
primary = snapshot('runproof-primary', 'runproof-primary-brief.md')
# Generated brief is the owned public instruction contract; no claim about model compliance.
read_order = primary.split('ONE READ ORDER', 1)[1].split('ONE OUTPUT PATH', 1)[0]
assert read_order.index('the dispositions ') < read_order.index('6. NOT YET:')
assert 'FROZEN' in read_order
rule = next(s for s in primary.splitlines() if s.startswith('2. Stay inside this worktree;'))
assert re.findall(r'`([^`]+)`', rule) == [str(plans / 'reviews/run-proof-claude-opus-5.5.md'), str(home / 'data/runproof-primary/report.md'), str(plans / 'probes/run-proof-claude-opus-5.5')]
assert 'Write your findings to `' + str(linked / 'data/runproof-primary/report.md') + '`.' not in primary
log.append('OBSERVED: symlink-spelled scout accepted; preview byte-identical to written brief; exact review, pointer and probe grants agree.\n')

scaffold('runproof-second')
generate('runproof', 'runproof-second', *common, '--model', 'github-copilot/gpt-6.1-sol')
second = snapshot('runproof-second', 'runproof-second-model-brief.md')
assert 'Second-model run: you are the second process' in second
assert 'ONE OUTPUT PATH: ' + str(plans / 'reviews/run-proof-gpt-6.1-sol.md') in second
log.append('OBSERVED: second model receives its own report/probe paths and freeze-before-comparison instruction.\n')

for kind, task, model, filename in (
    ('panel', 'architect', None, 'panel-architect-brief.md'),
    ('shadow', 'shadow-copilot', 'github-copilot/gpt-6.1-sol', 'shadow-copilot-brief.md'),
    ('shadow', 'shadow-openai', 'openai/gpt-6.1-sol', 'shadow-openai-brief.md'),
):
    scaffold(task)
    args = ['--lens', 'solutions-architect', '--ixia-source', 'pinned', '--ixia-dir', 'vendor/ixia']
    if model:
        args += ['--shadow-model', model]
    generate(kind, task, *args)
    text = snapshot(task, filename)
    assert str(plugin / 'agents/plan-architect.md') in text
    assert 'SAP_BUPA_BUPTDTRANSMIT' in text and 'needs a live check' in text
    if kind == 'shadow':
        assert 'its output never counts for dispositions' in text

# Read the actual delivered paths from the generated public interface; write same-named retained probes there.
paths = []
for task in ('architect', 'shadow-copilot', 'shadow-openai'):
    text = (home / 'data' / task / 'brief.md').read_text()
    rule = next(s for s in text.splitlines() if s.startswith('2. Stay inside this worktree;'))
    grants = [Path(p) for p in re.findall(r'`([^`]+)`', rule)]
    paths.append(grants[2])
    target = grants[2] / 'check-target.py'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('print(' + repr(task) + ')\n')
    result = call(['python3', target], cwd=worker)
    assert result.stdout.strip() == task
assert len(set(paths)) == len(paths)
log.append('OBSERVED: panel and two providers with identical model tails retain and run same-named probes without overwriting each other.\n')

# Clone instructions emit an absolute credential path, not credential content.
b = scaffold('clone-path')
generate('panel', 'clone-path', '--lens', 'business-analyst', '--bitbucket-env', 'credentials/bitbucket.env')
text = snapshot('clone-path', 'panel-clone-path-brief.md')
assert str(credential) in text and 'SYNTHETIC_DO_NOT_EMIT' not in text
log.append('OBSERVED: relative credential path emitted absolute; synthetic file content not emitted or consumed. No clone or login attempted.\n')

# Named-base assertion refuses before a write; likewise missing input files and unsupported scaffolds.
b = scaffold('guard')
before = b.read_bytes()
for stdout in (False, True):
    r = generate('panel', 'guard', '--lens', 'business-analyst', '--base-branch', 'wrong/base', stdout=stdout, expected=2)
    assert 'does not match the scaffold' in r.stderr
    unchanged(b, before)
r = generate('runproof', 'guard', '--dispositions', 'missing-dispositions.md', '--changes', f'data/{ticket}/plans/what-changed.md', expected=2)
assert 'dispositions not found' in r.stderr
unchanged(b, before)
r = generate('runproof', 'guard', expected=2)
assert '--dispositions and --changes' in r.stderr
unchanged(b, before)
# Existing filled briefs must not be overwritten.
b = home / 'data/runproof-primary/brief.md'
before = b.read_bytes()
r = generate('runproof', 'runproof-primary', *common, expected=2)
assert 'must contain {TASK} exactly once' in r.stderr
unchanged(b, before)
# Contradictory inherited home: explicit home wins and foreign state stays unchanged.
foreign_before = sorted(str(p.relative_to(foreign)) for p in foreign.rglob('*'))
scaffold('explicit-home')
r = generate('panel', 'explicit-home', '--lens', 'business-analyst', extra={'FM_HOME': str(foreign)})
assert 'differs from --home; using --home' in r.stderr
assert sorted(str(p.relative_to(foreign)) for p in foreign.rglob('*')) == foreign_before
log.append('OBSERVED: base mismatch, missing required files/arguments and second fill refuse without modifying the brief; explicit home leaves foreign home unchanged.\n')

# Version mismatch is a warning, not a refusal.
(plugin / '.claude-plugin/plugin.json').write_text('{"version":"0.9.0"}\n')
scaffold('old-version')
r = generate('runproof', 'old-version', *common)
assert 'pinned Ixia copy is version 0.9.0, the sources lock says 1.0.23' in r.stderr
log.append('OBSERVED: locked-version mismatch warned and brief generated, per the public compatibility contract.\n')

manifest = {}
for p in sorted(evidence.glob('*-brief.md')):
    manifest[p.name] = {'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
(evidence / 'generated-brief-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(evidence / 'manual-cli-transcript.txt').write_text('\n'.join(log))
print('Live CLI scenarios completed. Generated briefs and exact CLI transcript saved to ' + str(evidence))
