#!/usr/bin/env python3
"""Drive the actual remote-reply CLI with private homes and a stalled TCP peer."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import threading
import time

ROOT = Path.cwd()
WORK = ROOT / '.test-remote-reply'
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M40ZWNEA2SFB6TYZ9XPBVA68')
TARGET = ROOT / 'bin/fm-procevent-remote-reply.sh'
BASE = WORK / 'baseline/bin'
BASE.mkdir(parents=True, exist_ok=True)
for source in (ROOT / 'bin').iterdir():
    if source.name != TARGET.name:
        (BASE / source.name).symlink_to(source)
base_adapter = BASE / TARGET.name
base_adapter.write_bytes(subprocess.check_output(['git', 'show', '1f3e769616fdf9f31f85f4c3e6a9f71606634238:bin/fm-procevent-remote-reply.sh']))
base_adapter.chmod(0o755)
records = []

def digest(data):
    return hashlib.sha256(data).hexdigest()

def fixture(label, payload=b'working: disposable relay verification\n', status='delta', bad_hash=False):
    case = WORK / label
    case.mkdir()
    for directory in ['home/data', 'home/state', 'remote/data', 'remote/state', 'tmp', 'claims', 'cli-home']:
        (case / directory).mkdir(parents=True, exist_ok=True)
    (case / 'home/data/secondmates.md').write_text(
        f'- labmate - Disposable relay (host: fm-lab-peer; root: {ROOT}; home: {case / "remote"}; scope: verification; projects: disposable; added 2026-10-03)\n')
    empty = digest(b'')
    size = len(payload)
    to = size if status == 'delta' else 0
    final_hash = digest(payload) if status == 'delta' else empty
    payload_hash = ('0' * 64) if bad_hash else digest(payload)
    result = (f'schema=fm-remote-delta.v1\nstatus={status}\npath=state/parent-replies.status\n'
              f'from_offset=0\nto_offset={to}\nfrom_prefix_sha256={empty}\nto_prefix_sha256={final_hash}\n'
              f'payload_sha256={payload_hash}\npayload_bytes={size}\nreason=disposable-live-check\n\n').encode() + payload
    (case / 'result').write_bytes(result)
    # Seed the adapter's owned durable-capture input contract, not a substitute
    # implementation: handle must acknowledge this exact generation.
    inbox = case / 'home/state/procevent-inbox'
    inbox.mkdir(mode=0o700)
    (inbox / 'remote-reply-labmate.1.result').write_bytes(result)
    (inbox / 'remote-reply-labmate.1.adapter').write_text('remote-reply\n')
    for item in inbox.iterdir():
        item.chmod(0o600)
    env = {k: v for k, v in os.environ.items() if not k.startswith('FM_') and k not in ['TASKS_AXI_FILE', 'TASKS_AXI_BACKEND', 'TMUX', 'NO_MISTAKES_GATE']}
    env.update(FM_HOME=str(case / 'home'), FM_ROOT_OVERRIDE=str(ROOT),
               FM_PROCEVENT_CLAIM_ROOT=str(case / 'claims'), TMPDIR=str(case / 'tmp'),
               HOME=str(case / 'cli-home'), XDG_STATE_HOME=str(case / 'cli-home/state'),
               XDG_CONFIG_HOME=str(case / 'cli-home/config'), XDG_DATA_HOME=str(case / 'cli-home/data'))
    return case, env

def leftovers(case):
    return {
        'TMPDIR': sorted(str(p.relative_to(case)) for p in (case / 'tmp').iterdir()),
        'document_staging': sorted(str(p.relative_to(case)) for p in (case / 'home/data').rglob('.remote-doc.*')),
        'lifecycle_locks': sorted(str(p.relative_to(case)) for p in (case / 'home/state').glob('.remote-reply-lifecycle-*')),
    }

def invoke(adapter, command, case, env, sequence='1'):
    args = [str(adapter), command, 'labmate']
    if command in ['handle', 'autohandle']:
        args.append(sequence)
    args.append(str(case / 'result'))
    p = subprocess.run(args, env=env, text=True, capture_output=True, timeout=20)
    return {'argv': [str(a) for a in args], 'exit': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr}

def normal_case(version, adapter, kind, command):
    label = f'{version}-{kind}-{command}'
    case, env = fixture(label, payload=b'' if kind == 'continuity' else b'working: disposable relay verification\n',
                        status='continuity-broken' if kind == 'continuity' else 'delta', bad_hash=kind == 'digest')
    response = invoke(adapter, command, case, env)
    remaining = leftovers(case)
    state = case / 'home/state'
    persisted = {str(p.relative_to(state)): p.read_text() for p in state.rglob('*') if p.is_file() and not p.is_symlink()}
    expected = 3 if kind == 'continuity' else 1
    if kind == 'success':
        expected = 0
        valid = ('ingested: labmate appended=1' in response['stdout']
                 and 'handled: remote-reply-labmate 1' in response['stdout']
                 and (state / 'labmate.status').read_bytes() == b'working: disposable relay verification\n'
                 and (state / 'remote-replies/labmate.cursor').is_file()
                 and (state / 'procevent-inbox/remote-reply-labmate.1.handled').is_file())
    elif kind == 'continuity':
        valid = ('continuity-broken: labmate' in response['stdout']
                 and 'remote reply continuity broke' in (state / 'labmate.status').read_text()
                 and not (state / 'remote-replies/labmate.cursor').exists()
                 and (command != 'handle' or (state / 'procevent-inbox/remote-reply-labmate.1.handled').is_file()))
    else:
        valid = ('result payload bytes do not match its committed digest' in response['stderr']
                 and not (state / 'labmate.status').exists()
                 and not (state / 'remote-replies/labmate.cursor').exists())
    clean = not any(remaining.values())
    passed = valid and clean and response['exit'] == expected
    followup = None
    if version == 'target' and command == 'handle':
        followup_p = subprocess.run([str(adapter), 'arm', 'labmate'], env=env, capture_output=True, text=True, timeout=20)
        followup = {'command': 'arm labmate (prove lifecycle lock reusable)', 'exit': followup_p.returncode,
                    'stdout': followup_p.stdout, 'stderr': followup_p.stderr, 'remaining': leftovers(case)}
        passed = passed and followup_p.returncode == 0 and not any(followup['remaining'].values())
    records.append({'scenario': label, 'result': 'pass' if passed else 'fail', 'live': version == 'target',
                    'response': response, 'after_exit': remaining, 'persisted_state': persisted, 'followup': followup})

class StalledPeer:
    def __init__(self):
        self.listener = socket.socket()
        self.listener.bind(('127.0.0.1', 0))
        self.listener.listen(1)
        self.port = self.listener.getsockname()[1]
        self.accepted = threading.Event()
        self.close_requested = threading.Event()
        self.banner = b''
        self.thread = threading.Thread(target=self.serve, daemon=True)
        self.thread.start()
    def serve(self):
        self.listener.settimeout(10)
        connection = None
        try:
            connection, _ = self.listener.accept()
            connection.settimeout(5)
            self.banner = connection.recv(4096)
            self.accepted.set()
            self.close_requested.wait(12)
        finally:
            if connection:
                connection.close()
            self.listener.close()
    def close(self):
        self.close_requested.set()
        self.thread.join(5)

def interrupted_case(version, adapter, command, signal_group=False):
    label = f'{version}-sigterm-{"group-" if signal_group else ""}fetch-{command}'
    case, env = fixture(label, payload=b'done: disposable proof report=data/proof/report.md\n')
    peer = StalledPeer()
    config = case / 'ssh-config'
    config.write_text(f'Host fm-lab-peer\n HostName 127.0.0.1\n Port {peer.port}\n User disposable\n BatchMode yes\n IdentityFile none\n IdentitiesOnly yes\n IdentityAgent none\n UserKnownHostsFile {case / "known_hosts"}\n GlobalKnownHostsFile /dev/null\n StrictHostKeyChecking yes\n')
    ssh_wrapper = case / 'ssh-private'
    ssh_wrapper.write_text(f'#!/bin/bash\nexec /usr/bin/ssh -F "{config}" "$@"\n')
    ssh_wrapper.chmod(0o755)
    env['FM_SSH_BIN'] = str(ssh_wrapper)
    args = [str(adapter), command, 'labmate'] + (['1'] if command == 'handle' else []) + [str(case / 'result')]
    process = subprocess.Popen(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
    try:
        if not peer.accepted.wait(10):
            raise RuntimeError(f'{label}: real SSH client never connected')
        before = leftovers(case)
        assert before['TMPDIR'] and before['document_staging'], (label, before)
        if signal_group:
            # Keep the peer stalled: cleanup must be caused by termination,
            # not by a normally completed or refused fetch.
            os.killpg(process.pid, signal.SIGTERM)
        else:
            process.send_signal(signal.SIGTERM)
            # Bash defers its exit trap while waiting on a foreground command.
            time.sleep(0.25)
            peer.close()
        stdout, stderr = process.communicate(timeout=10)
        after = leftovers(case)
        passed = not any(after.values()) and process.returncode != 0
        records.append({'scenario': label, 'result': 'pass' if passed else 'fail', 'live': version == 'target',
                        'argv': args, 'peer': 'disposable loopback TCP endpoint stalled before server SSH banner',
                        'real_ssh_client_banner': peer.banner.decode(errors='replace'),
                        'signal': 'SIGTERM to private process group while peer stayed stalled' if signal_group else 'SIGTERM to adapter PID after SSH connected', 'before_signal': before,
                        'exit': process.returncode, 'stdout': stdout, 'stderr': stderr, 'after_exit': after})
    finally:
        peer.close()
        # Scope termination to this driver's private process group only.
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        if process.poll() is None:
            process.wait(timeout=5)
        # The lifecycle subshell can outlive its parent briefly. Wait only for
        # this case's owned staged files to settle and record that separately.
        if command == 'handle':
            for _ in range(100):
                if not any(leftovers(case).values()):
                    break
                time.sleep(0.05)
            records[-1]['after_owned_children_stop'] = leftovers(case)

try:
    for version, adapter in [('baseline', base_adapter), ('target', TARGET)]:
        for kind in ['continuity', 'digest']:
            for command in ['ingest', 'handle']:
                normal_case(version, adapter, kind, command)
        if version == 'target':
            normal_case(version, adapter, 'success', 'handle')
        interrupted_case(version, adapter, 'ingest')
        interrupted_case(version, adapter, 'handle')
        interrupted_case(version, adapter, 'handle', signal_group=True)
finally:
    (EVIDENCE / 'live-remote-reply-results.json').write_text(json.dumps(records, indent=2) + '\n')
    for record in records:
        print(json.dumps(record))
    shutil.rmtree(BASE.parent)
    for record in records:
        shutil.rmtree(WORK / record['scenario'])

if any(record['result'] != 'pass' for record in records if record['scenario'].startswith('target-')):
    raise SystemExit(1)
