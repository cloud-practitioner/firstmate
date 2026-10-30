#!/usr/bin/env python3
"""Exercise the public scaffold/generator CLIs; emitted briefs are the owned output contract.
This does not evaluate whether an LLM follows the delivered instructions.
"""
import difflib
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

ROOT = Path.cwd()
WORK = ROOT / '.live-ground-rules' / 'manual'
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M65AVAR38T50HYDPMK16200C')
WORK.mkdir(parents=True)
HOME = WORK / 'home'
for directory in ('data/TKT-LIVE/plans', 'state', 'config', 'projects', 'data/rules'):
    (HOME / directory).mkdir(parents=True, exist_ok=True)
PLANS = HOME / 'data/TKT-LIVE/plans'
(PLANS / 'plan.md').write_text('# Disposable supplier plan\nTest: assume negative supplier IDs reach production and attack that scenario. This assumption has no production confirmation.\n')
(PLANS / 'plan-reviews.md').write_text('Synthetic panel dispositions: no confirmed production evidence for negative supplier IDs.\n')
(PLANS / 'what-changed.md').write_text('Disposable plan revision only.\n')
RULES = HOME / 'data/rules/production ground rules.md'
RULES.write_text('# Disposable ground rules\nGR-1: Findings must cite their evidence.\nGR-2: Only one confirmed supplier is selected per request.\n')
SEED = 'UNCONFIRMED-PREMISE: attack negative supplier IDs because the plan lists that test; no allowed source confirms this premise.'
SEEDS = WORK / 'seeds.txt'
SEEDS.write_text('- ' + SEED + '\n')
IXIA = WORK / 'ixia/plugins/ixia-stratex/.claude-plugin'
IXIA.mkdir(parents=True)
(IXIA / 'plugin.json').write_text('{"version":"1.0.23"}\n')
INVOCATION = WORK / 'unrelated-invocation'
INVOCATION.mkdir()
ENV = {key: value for key, value in os.environ.items() if not key.startswith('FM_')}
ENV.update(FM_HOME=str(HOME), FM_ROOT_OVERRIDE=str(ROOT), FM_DATA_OVERRIDE=str(HOME / 'data'), FM_STATE_OVERRIDE=str(HOME / 'state'), FM_CONFIG_OVERRIDE=str(HOME / 'config'), FM_PROJECTS_OVERRIDE=str(HOME / 'projects'), TMPDIR=str(ROOT / '.live-ground-rules/tmp'), PYTHONDONTWRITEBYTECODE='1')
LOG = []
RESULTS = []


def run(args, cwd=INVOCATION):
    result = subprocess.run([str(x) for x in args], cwd=cwd, env=ENV, capture_output=True)
    LOG.append('$ ' + shlex.join(str(x) for x in args) + '\nexit=' + str(result.returncode))
    if result.stderr:
        LOG.append(result.stderr.decode(errors='replace').rstrip())
    return result


def succeed(args):
    result = run(args)
    assert result.returncode == 0, (args, result.stderr)
    return result


def prepare_version(ref, dirname):
    directory = WORK / dirname
    directory.mkdir()
    for name in ('mk-lens-brief.py', 'run-proof-lens.markdown', 'orchestration-checklist.markdown', 'sources.lock.json'):
        content = subprocess.run(['git', 'show', ref + ':contrib/iqx-lenses/' + name], cwd=ROOT, capture_output=True, check=True).stdout
        (directory / name).write_bytes(content)
    return directory / 'mk-lens-brief.py'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def scaffold(task, named_base=True):
    args = ['bash', ROOT / 'bin/fm-brief.sh', task, 'synthetic-module', '--scout']
    if named_base:
        args += ['--base-branch', 'development/preview']
    succeed(args)
    return HOME / 'data' / task / 'brief.md'


def arguments(kind, task, lens=None, seeds=False, second=False):
    args = [kind, '--home', HOME, '--task', task, '--ticket', 'TKT-LIVE', '--plan', 'data/TKT-LIVE/plans/plan.md']
    if lens:
        args += ['--lens', lens]
    if kind == 'shadow':
        args += ['--shadow-model', 'github-copilot/gpt-6.1-sol']
    if kind == 'runproof':
        args += ['--dispositions', 'data/TKT-LIVE/plans/plan-reviews.md', '--changes', 'data/TKT-LIVE/plans/what-changed.md', '--ixia-dir', IXIA.parents[2]]
        if seeds:
            args += ['--seed', SEED, '--seeds-file', SEEDS]
        if second:
            args += ['--model', 'github-copilot/gpt-6.1-sol']
    return args


def premise_contract(text):
    # These are assertions on the final, emitted public prompt, not its implementation source.
    assert 'it governs all attacks, probes and seeds below, overriding conflicting instructions.' in text
    assert "overriding section 4's attack and seed instructions, section 5's probe rules and checklist section 1.9's ticket seeds wherever they conflict." in text
    assert 'Do not attack or probe an unconfirmed premise, even when the plan lists it as a test or it appears in a supplied or generated seed.' in text
    assert 'a ground rule in the named file (cite its rule id), the owner\'s spec page, the merged code, or live evidence (cite which)' in text
    assert 'Any other premise is not a finding. Do not build a finding, a severity or a fix on it.' in text
    assert 'Ask it as one plain question in the report\'s questions section, headed "unconfirmed premise"' in text
    assert 'is still probed' not in text


BASE = prepare_version('61b748936d05158279c53cefb63db770463283aa', 'base')
PRIOR = prepare_version('a8f7194f', 'prior-fix')
GEN = ROOT / 'contrib/iqx-lenses/mk-lens-brief.py'
LENSES = ('solutions-architect', 'security-architect', 'business-analyst', 'ux-designer')
CASES = [(kind, lens, False, False) for kind in ('panel', 'shadow') for lens in LENSES]
CASES += [('runproof', None, True, False), ('runproof', None, False, False), ('runproof', None, True, True)]
try:
    help_output = succeed(['python3', GEN, '--help']).stdout
    assert b'--ground-rules' in help_output
    (EVIDENCE / 'generator-help.txt').write_bytes(help_output)
    for index, (kind, lens, seeds, second) in enumerate(CASES):
        label = kind + '-' + (lens or ('second-model' if second else ('explicit-seeds' if seeds else 'generated-seeds')))
        task = 'live-' + label
        brief = scaffold(task, named_base=index % 2 == 0)
        original = brief.read_bytes()
        args = arguments(kind, task, lens, seeds, second)
        baseline = succeed(['python3', BASE] + args + ['--stdout'])
        off = succeed(['python3', GEN] + args + ['--stdout'])
        assert off.stdout == baseline.stdout, label + ': default bytes changed'
        assert off.stderr == baseline.stderr, label + ': default stderr changed'
        assert brief.read_bytes() == original
        assert b'GROUND RULES' not in off.stdout and b'Production-only premise rule' not in off.stdout
        supplied_rules = RULES if index % 2 == 0 else Path('data/rules/production ground rules.md')
        enabled_args = args + ['--ground-rules', supplied_rules]
        on = succeed(['python3', GEN] + enabled_args + ['--stdout'])
        text = on.stdout.decode()
        assert brief.read_bytes() == original, label + ': --stdout mutated the brief'
        assert 'GROUND RULES (mandatory read): before you review anything, read the ground-rules file ' + str(RULES) + ' in full.' in text
        assert 'Cite the rule ids you rely on in each finding.' in text
        assert text.index('GROUND RULES (mandatory read)') < text.index('Read the Ixia') if kind == 'runproof' else text.index('GROUND RULES (mandatory read)') < text.index('1. Clone iqxbusiness')
        assert RULES.read_text().strip() not in text, 'rules contents should be referenced, not copied'
        assert not any(line.startswith('- ') for line in difflib.ndiff(off.stdout.decode().splitlines(), text.splitlines())), label + ': opt-in removed default lines'
        if kind == 'runproof':
            premise_contract(text)
            if seeds:
                assert text.count(SEED) == 2, 'both --seed and --seeds-file must survive'
            else:
                assert '(none given: make them from the plan\'s own premises and test list, checklist section 1.9)' in text
        else:
            assert 'production-only premise rule' not in text and 'unconfirmed premise' not in text
        written = succeed(['python3', GEN] + enabled_args)
        assert brief.read_bytes() == on.stdout, label + ': write differs from stdout'
        assert written.stdout.startswith(b'ok ')
        LOG.append(written.stdout.decode().rstrip())
        LOG.append(label + ': default identical to base sha256=' + sha(off.stdout) + '; stdout left scaffold untouched; opt-in write equals stdout sha256=' + sha(on.stdout))
        record = {'case': label, 'default_matches_base': True, 'default_sha256': sha(off.stdout), 'enabled_sha256': sha(on.stdout), 'path_form': 'absolute' if supplied_rules.is_absolute() else 'home-relative', 'write_matches_stdout': True}
        RESULTS.append(record)
        if label in ('panel-solutions-architect', 'shadow-security-architect', 'runproof-explicit-seeds', 'runproof-generated-seeds', 'runproof-second-model'):
            (EVIDENCE / (label + '-enabled.md')).write_bytes(on.stdout)
            (EVIDENCE / (label + '-default.md')).write_bytes(off.stdout)
        if label == 'runproof-explicit-seeds':
            brief.write_bytes(original)
            prior = succeed(['python3', PRIOR] + enabled_args + ['--stdout'])
            try:
                premise_contract(prior.stdout.decode())
            except AssertionError:
                LOG.append('Regression reproduced: pre-review-fix generated prompt fails the current production-only premise contract.')
            else:
                raise AssertionError('pre-fix prompt unexpectedly passes regression check')
            assert 'is still probed' in prior.stdout.decode()
            (EVIDENCE / 'runproof-prior-fix-emitted.md').write_bytes(prior.stdout)
            brief.write_bytes(on.stdout)

    unreadable = WORK / 'unreadable-ground-rules.md'
    unreadable.write_text('# Must not be readable\n')
    unreadable.chmod(0)
    invalids = [('missing', WORK / 'not-present.md'), ('directory', WORK), ('permission-denied', unreadable)]
    refusal_log = []
    for kind in ('panel', 'shadow', 'runproof'):
        task = 'live-invalid-' + kind
        brief = scaffold(task)
        original = brief.read_bytes()
        args = arguments(kind, task, 'security-architect' if kind != 'runproof' else None)
        for name, path in invalids:
            for delivery in ('stdout', 'write'):
                command = ['python3', GEN] + args + ['--ground-rules', path] + (['--stdout'] if delivery == 'stdout' else [])
                before = {str(p.relative_to(HOME)): sha(p.read_bytes()) for p in HOME.rglob('*') if p.is_file()}
                result = run(command)
                after = {str(p.relative_to(HOME)): sha(p.read_bytes()) for p in HOME.rglob('*') if p.is_file()}
                assert result.returncode == 2 and result.stdout == b'', (name, kind, result)
                assert b'is missing or unreadable' in result.stderr
                assert before == after and brief.read_bytes() == original, 'refusal mutated home files'
                refusal_log.append('$ ' + shlex.join(str(x) for x in command) + '\n' + result.stderr.decode() + 'exit=2; stdout empty; all home files byte-identical\n')
    unreadable.chmod(0o600)
    (EVIDENCE / 'invalid-file-cli-transcript.txt').write_text('\n'.join(refusal_log))
    (EVIDENCE / 'default-compatibility-and-delivery.json').write_text(json.dumps(RESULTS, indent=2) + '\n')
    LOG.append('All public CLI output, baseline compatibility, seed-policy delivery and invalid-file refusal checks passed. No reviewer/model was launched.')
finally:
    (EVIDENCE / 'manual-cli-transcript.txt').write_text('\n\n'.join(LOG) + '\n')
    for p in WORK.rglob('unreadable-ground-rules.md'):
        p.chmod(0o600)
    shutil.rmtree(WORK)

print(LOG[-1])
