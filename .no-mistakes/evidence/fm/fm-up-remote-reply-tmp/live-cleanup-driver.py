#!/usr/bin/env python3
"""Exercise the unmodified remote-reply CLI in disposable marked lab homes.
Input envelopes come from the real delta reader. Interrupted I/O uses real
OpenSSH connected to a loopback endpoint that deliberately stalls its handshake.
No product executable or SSH client is mocked; the TCP peer is disposable.
"""
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
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M6541DNVG7XABCMY2GVFT6D9')
WORK = ROOT / '.test-remote-reply/live'
ADAPTER = Path(os.environ.get('FM_VALIDATION_ADAPTER', str(ROOT / 'bin/fm-procevent-remote-reply.sh')))
READER = ROOT / 'bin/fm-remote-delta-read.sh'
EVENT = ROOT / 'bin/fm-procevent.sh'
BASE = {k: v for k, v in os.environ.items() if not k.startswith('FM_')}
BASE.update(GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1')
EMPTY = hashlib.sha256(b'').hexdigest()
results = []
processes = []

def emit(message):
    print(message, flush=True)

def run(argv, env, expected=None, timeout=20):
    p = subprocess.run([str(x) for x in argv], env=env, stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    output = p.stdout.decode(errors='replace')
    emit('$ ' + ' '.join(str(x).replace(str(ROOT), '$WORKTREE') for x in argv))
    emit('exit=' + str(p.returncode) + '\n' + output.rstrip())
    if expected is not None:
        assert p.returncode == expected, (argv, p.returncode, output)
    return p.returncode, output

def paths(home, tmp):
    return {'TMPDIR': sorted(p.name for p in tmp.iterdir()),
            'document_staging': sorted(str(p.relative_to(home)) for p in (home / 'data').rglob('.remote-doc.*')),
            'lifecycle_locks': sorted(p.name for p in (home / 'state').glob('.remote-reply-lifecycle-*')),
            'ingest_locks': sorted(p.name for p in (home / 'state').glob('.remote-reply-ingest-*'))}

def check_clean(home, tmp, check_ingest=False):
    state = paths(home, tmp)
    emit('observable cleanup state: ' + json.dumps(state))
    for key in ['TMPDIR', 'document_staging', 'lifecycle_locks'] + (['ingest_locks'] if check_ingest else []):
        assert state[key] == [], (key, state[key])
    return state

def lab(name):
    directory = WORK / name
    home = directory / 'home'
    tmp = directory / 'private tmp with spaces'
    tmp.mkdir(parents=True)
    run([ROOT / 'bin/fm-lab-home.sh', 'create', home], BASE, 0)
    remote = directory / 'remote'
    (remote / 'state').mkdir(parents=True)
    (home / 'data/secondmates.md').write_text(
        f'- ios - validation (host: cleanup-lab; root: {ROOT}; home: {remote}; scope: validation; projects: alpha; added 2026-08-02)\n')
    env = dict(BASE, FM_HOME=str(home), TMPDIR=str(tmp), FM_SSH_BIN=str(WORK / 'ssh-private-config'),
               FM_PROCEVENT_CLAIM_ROOT=str(directory / 'claims'), FM_REMOTE_REPLY_WAIT_SECONDS='2')
    return home, tmp, remote, env

def envelope(remote, env, payload, name='delta.result', broken=False):
    (remote / 'state/parent-replies.status').write_bytes(payload)
    p = subprocess.run([str(READER), 'state/parent-replies.status', '0', '0'*64 if broken else EMPTY, '0'],
                       env=dict(env, FM_HOME=str(remote)), stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
    assert p.returncode == 0, (p.returncode, p.stderr)
    result = remote.parent / name
    result.write_bytes(p.stdout)
    emit('real delta-reader envelope:\n' + p.stdout.decode())
    return result

def wait_for(predicate, seconds=30):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.025)
    raise AssertionError('timed out waiting for live operation')

def spawned(argv, env, output):
    stream = output.open('wb')
    p = subprocess.Popen([str(x) for x in argv], env=env, stdin=subprocess.DEVNULL,
                         stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
    stream.close()
    processes.append(p)
    return p

def kill_group(p):
    try:
        os.killpg(p.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        return p.wait(timeout=10)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        return p.wait(timeout=5)

def case(name, body):
    emit('\n=== ' + name + ' ===')
    try:
        body()
        results.append(dict(name=name, result='pass', live=True))
    except Exception as exc:
        emit('FAIL: ' + repr(exc))
        if 'Successful captured' in name:
            log = WORK / 'success/runner.log'
            emit('runner diagnostic:\n' + (log.read_text() if log.exists() else 'no log'))
            home = WORK / 'success/home'
            emit('persisted paths: ' + json.dumps(sorted(str(p.relative_to(home)) for p in home.rglob('*'))))
            for path in (home / 'state').rglob('*.status'):
                emit(str(path.relative_to(home)) + ':\n' + path.read_text())
        results.append(dict(name=name, result='fail', live=True, error=repr(exc)))

WORK.mkdir(parents=True, exist_ok=True)
server = socket.socket()
server.bind(('127.0.0.1', 0))
server.listen()
server.settimeout(.2)
port = server.getsockname()[1]
connections = []
stop = threading.Event()
def serve():
    while not stop.is_set():
        try:
            client, _ = server.accept()
            connections.append(client)
            client.sendall(b'SSH-2.0-fm-disposable-validation-endpoint\r\n')
        except socket.timeout:
            continue
        except OSError:
            break
thread = threading.Thread(target=serve, daemon=True)
thread.start()
config = WORK / 'ssh_config'
config.write_text(f'''Host cleanup-lab
  HostName 127.0.0.1
  Port {port}
  User disposable-validation
  BatchMode yes
  IdentityFile none
  IdentityAgent none
  IdentitiesOnly yes
  UserKnownHostsFile /dev/null
  GlobalKnownHostsFile /dev/null
  StrictHostKeyChecking yes
  ConnectTimeout 30
  LogLevel ERROR
''')
wrapper = WORK / 'ssh-private-config'
wrapper.write_text(f'#!/usr/bin/env bash\nexec /usr/bin/ssh -F "{config}" "$@"\n')
wrapper.chmod(0o700)
emit('Real adapter: ' + str(ADAPTER))
emit('Real OpenSSH client: /usr/bin/ssh; disposable loopback endpoint port=' + str(port))

try:
    def continuity():
        home, tmp, remote, env = lab('continuity')
        result = envelope(remote, env, b'', broken=True)
        run([ADAPTER, 'ingest', 'ios', result], env, 3)
        check_clean(home, tmp, True)
        # Capture through the real event runner so handle can acknowledge it.
        run([EVENT, 'register', 'remote-reply', 'remote-reply-ios', '--', '/bin/cat', result], env, 0)
        output = remote.parent / 'runner.log'
        p = spawned([EVENT, 'start', 'remote-reply-ios'], env, output)
        handled = home / 'state/procevent-inbox/remote-reply-ios.1.handled'
        wait_for(handled.exists)
        run([ADAPTER, 'handle', 'ios', '1', home / 'state/procevent-inbox/remote-reply-ios.1.result'], env, 3)
        emit('persisted status:\n' + (home / 'state/ios.status').read_text())
        assert (home / 'state/ios.status').read_text().count('remote reply continuity broke') == 1
        check_clean(home, tmp, True)
        kill_group(p)
    case('Broken continuity through ingest and lifecycle-locked handle', continuity)

    def corrupt_payload():
        home, tmp, remote, env = lab('digest')
        result = envelope(remote, env, b'working: digest check\n')
        good = result.read_bytes()
        for variant in ['digest', 'length']:
            data = good.replace(b'working: digest check', b'working: forged check') if variant == 'digest' else good.replace(b'payload_bytes=22', b'payload_bytes=99')
            if variant == 'length':
                lines = good.split(b'\n')
                data = b'\n'.join(b'payload_bytes=99' if x.startswith(b'payload_bytes=') else x for x in lines)
            result.write_bytes(data)
            for command in [['ingest', 'ios', result], ['handle', 'ios', '1', result]]:
                _, output = run([ADAPTER] + command, env, 1)
                assert 'committed digest' in output
                check_clean(home, tmp, True)
                assert not (home / 'state/ios.status').exists()
                assert not (home / 'state/remote-replies/ios.cursor').exists()
        result.write_bytes(good)
        run([ADAPTER, 'ingest', 'ios', result], env, 0)
        emit('retry persisted status:\n' + (home / 'state/ios.status').read_text())
        check_clean(home, tmp, True)
    case('Reject wrong digest and wrong length without staging, locks, or committed data', corrupt_payload)

    def successful_handle():
        home, tmp, remote, env = lab('success')
        result = envelope(remote, env, b'working: live cleanup validation\n')
        run([EVENT, 'register', 'remote-reply', 'remote-reply-ios', '--', '/bin/cat', result], env, 0)
        output = remote.parent / 'runner.log'
        p = spawned([EVENT, 'start', 'remote-reply-ios'], env, output)
        handled = home / 'state/procevent-inbox/remote-reply-ios.1.handled'
        wait_for(handled.exists)
        captured = home / 'state/procevent-inbox/remote-reply-ios.1.result'
        # Replay while the owning runner is still alive. Sweeping immediately
        # after its acknowledgement races the runner's registration handoff;
        # that is teardown, not the behavior this scenario is testing.
        run([ADAPTER, 'handle', 'ios', '1', captured], env, 0)
        emit('persisted status:\n' + (home / 'state/ios.status').read_text())
        emit('persisted cursor:\n' + (home / 'state/remote-replies/ios.cursor').read_text())
        assert (home / 'state/ios.status').read_text().count('live cleanup validation') == 1
        # Stop any rearmed polling source before observing global temp hygiene.
        kill_group(p)
        wait_for(lambda: not any(paths(home, tmp)[key] for key in ['TMPDIR', 'document_staging', 'lifecycle_locks']), seconds=5)
        check_clean(home, tmp, True)
    case('Successful captured handle and replay commit once and release lifecycle lock', successful_handle)

    def interrupted(command):
        home, tmp, remote, env = lab('term-' + command)
        if command == 'source':
            args = ['source', 'ios']
        else:
            result = envelope(remote, env, b'done: report ready report=data/reply/report.md\n')
            args = ['ingest', 'ios', result] if command == 'ingest' else ['handle', 'ios', '1', result]
        previous = len(connections)
        output = remote.parent / 'interrupted.log'
        p = spawned([ADAPTER] + args, env, output)
        wait_for(lambda: len(connections) > previous)
        before = paths(home, tmp)
        emit('before SIGTERM: ' + json.dumps(before))
        if command == 'source':
            assert any(n.startswith('fm-remote-reply-source.') for n in before['TMPDIR'])
        else:
            assert before['document_staging'] and any(n.startswith('fm-remote-doc-reason.') for n in before['TMPDIR'])
            if command == 'handle':
                assert before['lifecycle_locks']
        # Interrupt the process group, as a supervised long-poll is stopped.
        code = kill_group(p)
        emit('SIGTERM real adapter group; exit=' + str(code) + '\n' + output.read_text())
        assert code in (-15, 143)
        # The outer handle may exit before its subshell; allow five seconds
        # for the entire terminated group to settle before calling a leak.
        try:
            wait_for(lambda: not any(paths(home, tmp)[key] for key in ['TMPDIR', 'document_staging', 'lifecycle_locks']), seconds=5)
        except AssertionError:
            emit('cleanup still incomplete five seconds after SIGTERM')
        check_clean(home, tmp)
        if command != 'source':
            assert not (home / 'state/remote-replies/ios.cursor').exists()
        # Prove any retained stale ingest lock does not prevent a subsequent ingest.
        if command != 'source':
            result = envelope(remote, env, b'working: retry after interrupted fetch\n', 'retry.result')
            run([ADAPTER, 'ingest', 'ios', result], env, 0)
            check_clean(home, tmp, True)
        else:
            # A real refused transport connection also cleans staged output.
            config.write_text(config.read_text().replace(f'Port {port}', 'Port 1'))
            run([ADAPTER, 'source', 'ios'], env, 255)
            check_clean(home, tmp, True)
    for command in ['ingest', 'handle', 'source']:
        case('SIGTERM during real SSH ' + ('source read' if command == 'source' else 'document fetch via ' + command), lambda command=command: interrupted(command))
finally:
    for p in processes:
        kill_group(p)
    stop.set()
    server.close()
    for client in connections:
        client.close()
    thread.join(timeout=1)
    # Use the product-owned sweeper only for marked homes created by this driver.
    for marker in WORK.glob('*/home/.fm-lab-home'):
        home = marker.parent
        env = dict(BASE, FM_HOME=str(home), TMPDIR=str(home.parent / 'private tmp with spaces'),
                   FM_PROCEVENT_CLAIM_ROOT=str(home.parent / 'claims'))
        try:
            run([EVENT, 'sweep-home'], env, timeout=10)
        except Exception as exc:
            emit('teardown sweep: ' + repr(exc))
    shutil.rmtree(WORK)
    emit('Disposed all live lab homes and the loopback endpoint.')
    (EVIDENCE / os.environ.get('FM_VALIDATION_RESULTS', 'live-cleanup-results.json')).write_text(json.dumps(results, indent=2) + '\n')
    emit(json.dumps(results, indent=2))
raise SystemExit(1 if any(x['result'] != 'pass' for x in results) else 0)
