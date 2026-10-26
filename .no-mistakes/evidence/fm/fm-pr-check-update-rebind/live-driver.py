#!/usr/bin/env python3
"""Disposable live Firstmate CLI validation; only the external forge is a local API fixture."""
import hashlib
import http.server
import io
import tarfile
import json
import os
from pathlib import Path
import re
import shutil
import socketserver
import ssl
import subprocess
import threading
import time

ROOT = Path.cwd()
WORK = ROOT / '.fm-validation/live'
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M5TQX0XB6EGBB786YV97YKC3')
WORK.mkdir(parents=True, exist_ok=True)
TRANSCRIPT = EVIDENCE / 'live-cli-transcript.log'
API_LOG = EVIDENCE / 'disposable-forge-http.jsonl'
log = TRANSCRIPT.open('w', buffering=1)
api_log = API_LOG.open('w', buffering=1)
log.write('Real Firstmate scripts, git, gh, curl, jq, locks and state; disposable local TLS forge API fixture. No live forge or operator credentials used.\n')
base = dict(os.environ)
for key in list(base):
    if (key.startswith('FM_') or key.startswith('GH_') or key.startswith('GITHUB_')
        or key.startswith('NO_MISTAKES_BITBUCKET_') or key.startswith('GIT_')
        or key.startswith('TASKS_AXI_') or key in ['TMUX', 'REX_SESSION', 'REX_BLOCK']):
        base.pop(key, None)
base.update(HOME=str(WORK / 'user-home'), XDG_CONFIG_HOME=str(WORK / 'user-home/config'),
            TMPDIR=str(ROOT / '.fm-validation/tmp'), GIT_CONFIG_NOSYSTEM='1',
            GIT_CONFIG_GLOBAL='/dev/null', GIT_AUTHOR_NAME='Live validation',
            GIT_AUTHOR_EMAIL='fixture@example.invalid', GIT_COMMITTER_NAME='Live validation',
            GIT_COMMITTER_EMAIL='fixture@example.invalid', GIT_TERMINAL_PROMPT='0',
            GH_CONFIG_DIR=str(WORK / 'gh-config'), GH_TOKEN='disposable-fixture-token',
            NO_MISTAKES_BITBUCKET_EMAIL='fixture@example.invalid',
            NO_MISTAKES_BITBUCKET_API_TOKEN='disposable-fixture-token')
Path(base['HOME']).mkdir(exist_ok=True)

def command(argv, *, env=None, timeout=90, expected=0, record=True):
    proc = subprocess.run([str(a) for a in argv], env=env or base, cwd=ROOT,
                          text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if record:
        log.write('$ ' + ' '.join(str(a) for a in argv) + '\n')
        log.write(proc.stdout)
        if proc.stderr:
            log.write('stderr:\n' + proc.stderr)
        log.write(f'[exit {proc.returncode}]\n')
    if expected is not None and proc.returncode != expected:
        raise AssertionError(f'{argv}: expected {expected}, got {proc.returncode}: {proc.stdout}\n{proc.stderr}')
    return proc

cert, key = WORK / 'cert.pem', WORK / 'key.pem'
command(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
         '-keyout', key, '-out', cert, '-subj', '/CN=api.bitbucket.org',
         '-addext', 'subjectAltName=DNS:api.bitbucket.org,DNS:api.github.com,DNS:github.com'], record=False)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(cert, key)
states = {}
head = 'a' * 40

class HTTP(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        match = re.search(r'/pullrequests/(\d+)', self.path)
        if not match:
            api_log.write(json.dumps(dict(method=self.command, path=self.path, provider='out-of-scope-observer', response_status=404)) + '\n')
            self.send_error(404, 'Not part of this disposable merge-watch API')
            return
        n = int(match.group(1))
        state = states.get(('bitbucket', n), 'OPEN')
        body = dict(id=n, state=state, draft=False,
                    source={'commit': {'hash': head}, 'branch': {'name': 'fixture'}},
                    destination={'branch': {'name': 'main'}})
        self.respond(body, 'bitbucket', n, state)
    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        # gh's real GraphQL transport sends these variable names for PullRequestByNumber.
        variables = data.get('variables', {})
        n = int(variables.get('number', 1))
        state = states.get(('github', n), 'OPEN')
        body = {'data': {'repository': {'pullRequest': {
            'number': n, 'state': state, 'isDraft': False, 'headRefOid': head,
            'headRefName': 'fixture', 'baseRefName': 'main',
            'url': f'https://github.com/fixture/repo/pull/{n}'}}}}
        self.respond(body, 'github', n, state)
    def respond(self, body, provider, n, state):
        raw = json.dumps(body).encode()
        api_log.write(json.dumps(dict(method=self.command, path=self.path,
                                     provider=provider, number=n, state=state, response=body)) + '\n')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)
    def log_message(self, *args):
        pass

class Proxy(socketserver.StreamRequestHandler):
    def handle(self):
        first = self.rfile.readline().decode().strip()
        if first not in ['CONNECT api.bitbucket.org:443 HTTP/1.1',
                         'CONNECT api.github.com:443 HTTP/1.1',
                         'CONNECT github.com:443 HTTP/1.1']:
            raise AssertionError('fixture blocks all other network requests: ' + first)
        while self.rfile.readline().strip():
            pass
        self.wfile.write(b'HTTP/1.1 200 Connection established\r\n\r\n')
        self.wfile.flush()
        with context.wrap_socket(self.request, server_side=True) as tls:
            HTTP(tls, self.client_address, self.server)

class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

server = Server(('127.0.0.1', 0), Proxy)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
proxy = f'http://127.0.0.1:{server.server_address[1]}'
base.update(HTTPS_PROXY=proxy, https_proxy=proxy, HTTP_PROXY=proxy, http_proxy=proxy,
            ALL_PROXY=proxy, all_proxy=proxy, NO_PROXY='', no_proxy='',
            CURL_CA_BUNDLE=str(cert), SSL_CERT_FILE=str(cert))


def git(where, *args):
    return command(['git', '-C', where, *args], record=False).stdout.strip()

def home(path):
    command([ROOT / 'bin/fm-lab-home.sh', 'create', path])
    return path

def env_for(code, h):
    e = dict(base, FM_HOME=str(h), FM_ROOT_OVERRIDE=str(code), FM_STATE_OVERRIDE=str(h / 'state'),
             FM_CONFIG_OVERRIDE=str(h / 'config'), FM_CHECK_INTERVAL='0', FM_POLL='0.05',
             FM_HEARTBEAT='999999', FM_SIGNAL_GRACE='0')
    return e

def url(provider, n):
    return (f'https://github.com/fixture/repo/pull/{n}' if provider == 'github' else
            f'https://bitbucket.org/fixture/repo/pull-requests/{n}')

def arm(code, h, task, provider, n):
    (h / 'state' / f'{task}.meta').write_text(
        f'window=fm-{task}\nworktree={code}\nkind=ship\nmode=no-mistakes\n')
    p = command([code / 'bin/fm-pr-check.sh', task, url(provider, n)], env=env_for(code, h))
    assert f'armed: state/{task}.check.sh' in p.stdout
    assert (h / 'state' / f'{task}.pr-poll-registration').is_file()
    assert f'pr_head={head}' in (h / 'state' / f'{task}.meta').read_text()
    # Keep this disposable home's supervision focused on PR merge checks, not the separate review observer.
    (h / 'state/contributions.check.sh').unlink(missing_ok=True)

def snapshot(h, task):
    return {suffix: (h / 'state' / f'{task}.{suffix}').read_bytes()
            for suffix in ['meta', 'pr-poll', 'check.sh', 'pr-poll-registration']}

def valid(h, task, code):
    # Owned persisted-state byte contract: producer check must equal deployed template.
    s = snapshot(h, task)
    assert s['check.sh'] == (code / 'bin/fm-pr-poll.sh').read_bytes()
    for suffix in ['pr-poll', 'check.sh', 'pr-poll-registration']:
        assert (h / 'state' / f'{task}.{suffix}').stat().st_mode & 0o777 == 0o600
    return s

def watch(code, h, task, provider, n):
    # The real watcher runs and exits on the first merge wake; no TUI or harness required.
    states[(provider, n)] = 'MERGED'
    (h / 'state/.last-check').unlink(missing_ok=True)
    p = command([code / 'bin/fm-watch.sh'], env=env_for(code, h), timeout=55)
    assert f'/{task}.check.sh: merged' in p.stdout, p.stdout
    assert not (h / 'state' / f'{task}.check.sh').exists()
    log.write(f'Observed merge wake and retired authenticated poll for {task}.\n')
    drained = command([code / 'bin/fm-wake-drain.sh'], env=env_for(code, h))
    ack = re.search(r'--ack-through (\d+) --recovery-generation ([A-Za-z0-9._-]+)', drained.stderr)
    if ack:
        command([code / 'bin/fm-wake-drain.sh', '--ack-through', ack.group(1),
                 '--recovery-generation', ack.group(2)], env=env_for(code, h))

try:
    log.write('\nSCENARIO 1: Real self-update from local origin repairs one GitHub + nine Bitbucket watches in two homes; tampered watch is reported.\n')
    seed, origin, main = WORK / 'seed', WORK / 'origin.git', WORK / 'main'
    seed.mkdir()
    # Materialize the existing tracked code/home contract as an unchanged fixture checkout.
    archive = subprocess.run(['git', 'archive', 'HEAD', 'bin', 'AGENTS.md'], cwd=ROOT,
                             env=base, check=True, stdout=subprocess.PIPE).stdout
    with tarfile.open(fileobj=io.BytesIO(archive)) as snapshot_archive:
        snapshot_archive.extractall(seed, filter='data')
    (seed / '.gitignore').write_text('state/\ndata/\nconfig/\nprojects/\n.fm-*\n')
    git(seed, 'init', '-q', '-b', 'main')
    git(seed, 'add', '.')
    git(seed, 'commit', '-qm', 'initial deployed release')
    command(['git', 'clone', '--bare', seed, origin], record=False)
    git(seed, 'remote', 'add', 'origin', str(origin))
    command(['git', 'clone', origin, main], record=False)
    primary = home(WORK / 'primary-home')
    mate = WORK / 'mate'
    git(main, 'worktree', 'add', '--detach', str(mate), 'main')
    for name in ['state', 'data', 'config', 'projects']:
        (mate / name).mkdir(exist_ok=True)
    (mate / '.fm-secondmate-parent').write_text(
        f'schema=fm-secondmate-parent.v1\nroute=local\nparent_home={primary}\n')
    (mate / '.fm-secondmate-home').write_text('mate\n')
    (primary / 'state/mate.meta').write_text(f'kind=secondmate\nhome={mate}\nwindow=main:fm-mate\n')
    arm(main, primary, 'gh-watch', 'github', 1)
    for n in range(1, 10):
        arm(mate, mate, f'bb-{n}', 'bitbucket', n)
    arm(main, primary, 'unsafe-watch', 'bitbucket', 91)
    with (primary / 'state/unsafe-watch.check.sh').open('a') as f:
        f.write('# untrusted hand edit\n')
    before = snapshot(primary, 'gh-watch')
    bad_before = snapshot(primary, 'unsafe-watch')
    before_commit = git(main, 'rev-parse', 'HEAD')
    with (seed / 'bin/fm-pr-poll.sh').open('a') as f:
        f.write('# later release changes template bytes\n')
    git(seed, 'add', 'bin/fm-pr-poll.sh')
    git(seed, 'commit', '-qm', 'new release template bytes')
    git(seed, 'push', '-q', 'origin', 'main')
    p = command([main / 'bin/fm-update.sh'], env=env_for(main, primary), timeout=100)
    assert 'firstmate: updated ' in p.stdout
    assert 'secondmate mate: updated ' in p.stdout
    assert 'rebound: gh-watch' in p.stdout
    for n in range(1, 10):
        assert f'rebound: bb-{n}\n' in p.stdout
        valid(mate, f'bb-{n}', mate)
    assert f'bin/fm-pr-check.sh unsafe-watch {url("bitbucket", 91)}' in p.stdout
    assert snapshot(primary, 'unsafe-watch') == bad_before
    after = valid(primary, 'gh-watch', main)
    assert before['meta'] == after['meta'] and before['pr-poll'] == after['pr-poll']
    assert before['check.sh'] != after['check.sh']
    assert git(main, 'rev-parse', 'HEAD') != before_commit
    p = command([main / 'bin/fm-pr-rebind.sh'], env=env_for(main, primary), expected=1)
    assert '0 rebound' in p.stdout and '1 unchanged' in p.stdout
    assert valid(primary, 'gh-watch', main) == after
    p = command([mate / 'bin/fm-pr-rebind.sh'], env=env_for(mate, mate))
    assert '0 rebound, 9 unchanged, 0 need a re-arm' in p.stdout
    # Do not run persistent-secondmate auto-relaunch here: it is not part of the PR watch surface.
    (primary / 'state/mate.meta').unlink()
    watch(main, primary, 'gh-watch', 'github', 1)
    for n in range(1, 10):
        watch(mate, mate, f'bb-{n}', 'bitbucket', n)
    log.write('SCENARIO 1 PASS: ten original watches detected merges after update; unsafe watch remained untouched with a named repair.\n')

    log.write('\nSCENARIO 2: A separate home sharing a code root heals in its watcher after an external template change.\n')
    shared_home = home(WORK / 'unregistered-home')
    arm(main, shared_home, 'sync-watch', 'bitbucket', 22)
    with (main / 'bin/fm-pr-poll.sh').open('a') as f:
        f.write('# code root synced outside fm-update\n')
    watch(main, shared_home, 'sync-watch', 'bitbucket', 22)
    triage = (shared_home / 'state/.watch-triage.log').read_text()
    assert 're-recorded PR poll template for sync-watch' in triage
    log.write(triage)
    log.write('SCENARIO 2 PASS: watcher re-recorded the stale template and delivered the merge wake.\n')

    log.write('\nSCENARIO 2B: An already-running watcher survives a code-root sync without a restart.\n')
    running_home = home(WORK / 'running-watcher-home')
    arm(main, running_home, 'running-watch', 'bitbucket', 23)
    before_http = len(API_LOG.read_text().splitlines())
    cmd = [str(main / 'bin/fm-watch.sh')]
    log.write('$ ' + ' '.join(cmd) + ' [start before sync, keep same pid]\n')
    watcher = subprocess.Popen(cmd, env=env_for(main, running_home), cwd=ROOT,
                               text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               start_new_session=True)
    try:
        deadline = time.monotonic() + 25
        observed_open = False
        while time.monotonic() < deadline:
            events = [json.loads(r) for r in API_LOG.read_text().splitlines()[before_http:]]
            if any(r.get('number') == 23 and r.get('state') == 'OPEN' for r in events):
                observed_open = True
                break
            if watcher.poll() is not None:
                break
            time.sleep(0.005)
        assert observed_open, 'watcher must poll OPEN before the sync'
        with (main / 'bin/fm-pr-poll.sh').open('a') as f:
            f.write('# synced while watcher was already running\n')
        states[('bitbucket', 23)] = 'MERGED'
        stdout, stderr = watcher.communicate(timeout=55)
        log.write(stdout + ('stderr:\n' + stderr if stderr else '') + f'[exit {watcher.returncode}]\n')
        assert watcher.returncode == 0 and '/running-watch.check.sh: merged' in stdout
        triage = (running_home / 'state/.watch-triage.log').read_text()
        assert 're-recorded PR poll template for running-watch' in triage
        assert not (running_home / 'state/running-watch.check.sh').exists()
        log.write(triage)
        log.write('SCENARIO 2B PASS: the same live watcher polled OPEN, rebound after template sync, detected MERGED and retired its poll.\n')
    finally:
        if watcher.poll() is None:
            watcher.terminate()
            watcher.communicate(timeout=10)

    log.write('\nSCENARIO 3: Tampered artifacts cannot be blessed by template refresh, and every refused watch gets its own repair command.\n')
    adversarial = home(WORK / 'adversarial-home')
    for n, mutation in enumerate(['edited-check', 'swapped-check', 'changed-sidecar', 'changed-hash'], 30):
        arm(main, adversarial, mutation, 'bitbucket', n)
        state = adversarial / 'state'
        if mutation == 'edited-check':
            with (state / f'{mutation}.check.sh').open('a') as f:
                f.write('echo EXECUTED_UNTRUSTED_POLL\n')
        elif mutation == 'swapped-check':
            replacement = state / '.replacement'
            shutil.copyfile(state / f'{mutation}.check.sh', replacement)
            replacement.chmod(0o600)
            replacement.replace(state / f'{mutation}.check.sh')
        elif mutation == 'changed-sidecar':
            data = state / f'{mutation}.pr-poll'
            lines = data.read_text().splitlines()
            lines[1], lines[4] = url('bitbucket', 99), '99'
            data.write_text('\n'.join(lines) + '\n')
        else:
            data = state / f'{mutation}.pr-poll-registration'
            lines = data.read_text().splitlines()
            lines[8] = '0' * 64
            data.write_text('\n'.join(lines) + '\n')
    bad = {name: snapshot(adversarial, name) for name in ['edited-check', 'swapped-check', 'changed-sidecar', 'changed-hash']}
    with (main / 'bin/fm-pr-poll.sh').open('a') as f:
        f.write('# another release\n')
    p = command([main / 'bin/fm-pr-rebind.sh'], env=env_for(main, adversarial), expected=1)
    assert '0 rebound, 0 unchanged, 4 need a re-arm' in p.stdout
    for n, name in enumerate(bad, 30):
        assert f'bin/fm-pr-check.sh {name} {url("bitbucket", n)}' in p.stdout
        assert snapshot(adversarial, name) == bad[name]
    api_before = API_LOG.read_text().splitlines()
    p = command([main / 'bin/fm-watch.sh'], env=env_for(main, adversarial), timeout=55)
    assert 'check: rejected unauthenticated state checks:' in p.stdout
    assert 'EXECUTED_UNTRUSTED_POLL' not in p.stdout
    for n, name in enumerate(bad, 30):
        assert f'bin/fm-pr-check.sh {name} {url("bitbucket", n)}' in p.stdout
        assert snapshot(adversarial, name) == bad[name]
    api_after = API_LOG.read_text().splitlines()
    assert not [r for r in api_after[len(api_before):] if json.loads(r)['provider'] == 'bitbucket']
    log.write('SCENARIO 3 PASS: real rebind and watcher refused all four mutations without executing a poll or changing artifacts.\n')
    log.write('\nAll disposable product processes exited; fixture API and fixture homes are torn down.\n')
finally:
    server.shutdown()
    server.server_close()
    log.close()
    api_log.close()
    shutil.rmtree(WORK)
