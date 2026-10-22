#!/usr/bin/env python3
"""Repeatable NON-LIVE probe of the real fm-live-claude.sh CLI; the engine is a fixture."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path.cwd()
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M5GVXJC6CT9JTBDTZCKVK98P')
CASE = ROOT / '.test-isolation-validation/manual'
CASE.mkdir(parents=True, exist_ok=False)
HOST = CASE / 'host'
VERSION = HOST / '.local/share/claude/versions/fixture'
LAUNCHER = HOST / '.local/bin/claude'
VERSION.parent.mkdir(parents=True)
LAUNCHER.parent.mkdir(parents=True)
(HOST / '.claude').mkdir()
(HOST / '.claude/fixture-login').write_text('synthetic credential, not a real login\n')
ENGINE = '''#!ENGINE_PYTHON
import json, os, pathlib, subprocess, sys
home = pathlib.Path(os.environ['HOME'])
record = {'args': sys.argv[1:], 'HOME': str(home), 'PATH': os.environ['PATH'],
          'FM_LIVE_CLAUDE_SHIM': os.environ.get('FM_LIVE_CLAUDE_SHIM'),
          'DISABLE_AUTOUPDATER': os.environ.get('DISABLE_AUTOUPDATER'),
          'DISABLE_UPDATES': os.environ.get('DISABLE_UPDATES'),
          'XDG_DATA_HOME': os.environ.get('XDG_DATA_HOME'),
          'XDG_STATE_HOME': os.environ.get('XDG_STATE_HOME'),
          'XDG_CACHE_HOME': os.environ.get('XDG_CACHE_HOME'),
          'XDG_BIN_HOME': os.environ.get('XDG_BIN_HOME'),
          'fixture_login_visible': (home / '.claude/fixture-login').is_file()}
with open(os.environ['FM_PROBE_LOG'], 'a') as stream:
    stream.write(json.dumps(record, sort_keys=True) + '\\n')
(home / '.claude/fixture-session').write_text('fixture session write\\n')
if '--rogue' in sys.argv:
    # Intentionally ignore both updater switches, repoint HOME's launcher,
    # then delete the installed version exactly as scenario cleanup would.
    installed = pathlib.Path(os.environ['XDG_DATA_HOME']) / 'claude/versions/ephemeral'
    installed.parent.mkdir(parents=True, exist_ok=True)
    installed.write_text('fixture native update\\n')
    launcher = home / '.local/bin/claude'
    launcher.unlink(missing_ok=True)
    launcher.symlink_to(installed)
    installed.unlink()
if '--nested' in sys.argv:
    subprocess.run(['claude', '--nested-child'], check=True)
'''.replace('ENGINE_PYTHON', sys.executable)
VERSION.write_text(ENGINE)
VERSION.chmod(0o755)
LAUNCHER.symlink_to(VERSION)


def state():
    return {'launcher_target': os.readlink(LAUNCHER), 'launcher_resolves': LAUNCHER.exists(),
            'version_sha256': hashlib.sha256(VERSION.read_bytes()).hexdigest()}


log = CASE / 'engine.jsonl'
env = {'HOME': str(HOST), 'PATH': str(LAUNCHER.parent) + ':/usr/bin:/bin',
       'TMPDIR': str(CASE), 'FM_PROBE_LOG': str(log),
       'XDG_DATA_HOME': str(CASE / 'xdg-only'),
       'XDG_BIN_HOME': str(LAUNCHER.parent),
       'DISABLE_AUTOUPDATER': '0', 'DISABLE_UPDATES': '0'}
before = state()
subprocess.run([str(LAUNCHER), '--rogue', '--unguarded-control'], env=env, check=True)
control = state()
assert not control['launcher_resolves'] and control['launcher_target'] != before['launcher_target']
LAUNCHER.unlink()
LAUNCHER.symlink_to(VERSION)
shim = CASE / 'shim'
creation_env = dict(env, FM_LIVE_CLAUDE_REAL=str(VERSION))
creation = subprocess.run([str(ROOT / 'bin/fm-live-claude.sh'), 'shim', str(shim)], env=creation_env,
                          text=True, capture_output=True, check=True)
assert creation.stdout.strip() == str(shim)
# No inherited marker; absolute shim entry must repair it.
assert 'FM_LIVE_CLAUDE_SHIM' not in env
subprocess.run([str(shim / 'claude'), '--rogue', '--nested', '--absolute-shim-primary'], env=env, check=True)
after = state()
assert before == after
records = [json.loads(line) for line in log.read_text().splitlines()]
outer, nested = records[-2:]
sandbox = Path(outer['HOME'])
assert sandbox != HOST and sandbox.is_relative_to(shim / 'homes')
assert outer['HOME'] == nested['HOME']
assert outer['FM_LIVE_CLAUDE_SHIM'] == nested['FM_LIVE_CLAUDE_SHIM'] == str(shim)
assert outer['DISABLE_AUTOUPDATER'] == outer['DISABLE_UPDATES'] == '1'
assert outer['PATH'].split(':')[0] == str(shim)
assert str(LAUNCHER.parent) not in outer['PATH'].split(':')
assert outer['XDG_DATA_HOME'] == str(sandbox / '.local/share')
assert outer['XDG_STATE_HOME'] == str(sandbox / '.local/state')
assert outer['XDG_CACHE_HOME'] == str(sandbox / '.cache')
assert outer['XDG_BIN_HOME'] is None
assert outer['fixture_login_visible'] and (HOST / '.claude/fixture-session').exists()
# A scratch HOME replaced by an alias to the host must fail closed before
# executing the fixture engine or changing the host launcher.
shutil.rmtree(sandbox)
sandbox.symlink_to(HOST)
old_log = log.read_bytes()
refusal = subprocess.run([str(shim / 'claude'), '--tampered-home'], env=env,
                         text=True, capture_output=True)
assert refusal.returncode != 0 and 'refusing' in refusal.stderr
assert log.read_bytes() == old_log and state() == before
report = {
    'kind': 'non-live public CLI behavior probe; fixture engine, never real Claude',
    'command': 'python3 ' + str(EVIDENCE / 'sandbox-probe.py'),
    'shim_creation_stdout': creation.stdout.strip(),
    'host_before': before,
    'unguarded_xdg_only_control': control,
    'guarded_host_after_rogue_update_and_nested_launch': after,
    'guarded_primary_environment': outer,
    'nested_engine_environment': nested,
    'tampered_scratch_home_refusal': {'exit': refusal.returncode, 'stderr': refusal.stderr.strip(),
                                    'engine_ran': False, 'host_after': state()},
    'assertions': 'all passed; intentionally synthetic, not live-Claude validation'
}
(EVIDENCE / 'sandbox-probe.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
