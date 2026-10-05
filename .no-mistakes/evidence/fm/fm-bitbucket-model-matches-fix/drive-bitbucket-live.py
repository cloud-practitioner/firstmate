#!/usr/bin/env python3
"""Exercise the real Firstmate CLI and curl against a disposable HTTPS backend.

Run from the gate worktree after creating .fm-bitbucket-validation/{tls.crt,tls.key}
with CN/SAN api.bitbucket.org and extracting the base commit's bin/ into
.fm-bitbucket-validation/base. No executable is stubbed or patched. The local
CONNECT proxy never opens an outgoing connection; it serves the Bitbucket API
protocol itself, with isolated records and a real merge state transition.
"""
import base64
import copy
import json
import os
from pathlib import Path
import shutil
import socketserver
import ssl
import subprocess
import threading
from urllib.parse import urlsplit

ROOT = Path.cwd()
WORK = ROOT / '.fm-bitbucket-validation'
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M45H95PZP7DH9ZAFCYH5BZKJ')
REPO = 'validation/disposable-repo'
URL = f'https://bitbucket.org/{REPO}/pull-requests/7'
AUTH = 'Basic ' + base64.b64encode(b'validation@example.invalid:disposable-token').decode()
BASE_ENV = {k: v for k, v in os.environ.items()
            if not k.startswith(('FM_', 'TASKS_AXI_', 'GIT_', 'NO_MISTAKES_BITBUCKET_'))
            and k.lower() not in ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy')}
BASE_ENV.update(HOME=str(WORK / 'user-home'), TMPDIR=str(WORK / 'tmp'),
                GIT_CONFIG_GLOBAL=str(ROOT / 'tests/git-fixture.gitconfig'),
                GIT_CONFIG_NOSYSTEM='1', NO_MISTAKES_BITBUCKET_EMAIL='validation@example.invalid',
                NO_MISTAKES_BITBUCKET_API_TOKEN='disposable-token',
                FM_PR_BITBUCKET_CONFIRM_ATTEMPTS='2', FM_PR_BITBUCKET_CONFIRM_INTERVAL='0')
MODEL = {'development': {'name': 'main', 'branch': {'name': 'main'}},
         'production': {'name': 'production', 'branch': {'name': 'production'}},
         'branch_types': [{'kind': 'release', 'prefix': 'release/'},
                          {'kind': 'feature', 'prefix': 'feature/'}]}


def run(args, env=BASE_ENV, cwd=ROOT):
    return subprocess.run([str(x) for x in args], cwd=cwd, env=env,
                          text=True, capture_output=True, timeout=60)


class Backend(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


class ConnectHandler(socketserver.BaseRequestHandler):
    def handle(self):
        # Read bytewise so the following TLS client hello stays on the socket.
        header = bytearray()
        self.request.settimeout(15)
        while not header.endswith(b'\r\n\r\n'):
            b = self.request.recv(1)
            if not b:
                return
            header.extend(b)
            if len(header) > 8192:
                raise RuntimeError('Oversized CONNECT header')
        first = bytes(header).split(b'\r\n', 1)[0].decode()
        if first != 'CONNECT api.bitbucket.org:443 HTTP/1.1':
            self.request.sendall(b'HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n')
            self.server.events.append({'refused_connect': first})
            return
        self.request.sendall(b'HTTP/1.1 200 Connection established\r\n\r\n')
        with self.server.tls.wrap_socket(self.request, server_side=True) as tls:
            stream = tls.makefile('rb')
            method, target, _ = stream.readline().decode().strip().split(' ', 2)
            headers = {}
            while True:
                line = stream.readline().decode().strip()
                if not line:
                    break
                key, value = line.split(':', 1)
                headers[key.lower()] = value.strip()
            body = stream.read(int(headers.get('content-length', '0')))
            payload = json.loads(body) if body else None
            authenticated = headers.get('authorization') == AUTH
            path = urlsplit(target).path
            prefix = '/2.0/repositories/' + REPO
            state = self.server.state
            code = 200
            if not authenticated:
                code, response = 401, {'error': {'message': 'Synthetic auth required'}}
            elif method == 'GET' and path == prefix + '/pullrequests/7':
                response = copy.deepcopy(state['pr'])
            elif method == 'GET' and path.startswith(prefix + '/commit/') and path.endswith('/statuses'):
                response = {'values': [{'key': 'pipeline', 'name': 'Disposable Pipeline',
                                        'state': 'SUCCESSFUL'}], 'pagelen': 100, 'page': 1}
            elif method == 'GET' and path.startswith(prefix + '/commit/'):
                response = {'hash': state['head']}
            elif method == 'GET' and path == prefix + '/branch-restrictions':
                response = {'values': state['restrictions'], 'pagelen': 100, 'page': 1}
            elif method == 'GET' and path == prefix + '/effective-branching-model':
                response = state['model']
            elif method == 'POST' and path == prefix + '/pullrequests/7/merge':
                # Deliberately permissive like a workspace without enforcement:
                # Firstmate itself must refuse unmet client-side restrictions.
                state['pr']['state'] = 'MERGED'
                state['merge_posts'].append(payload)
                response = copy.deepcopy(state['pr'])
            else:
                code, response = 404, {'error': {'message': 'Unknown disposable route'}}
            self.server.events.append({'method': method, 'path': target,
                                       'authenticated': authenticated, 'request_json': payload,
                                       'status': code, 'response_json': response})
            encoded = json.dumps(response).encode()
            tls.sendall(f'HTTP/1.1 {code} Response\r\nContent-Type: application/json\r\nContent-Length: {len(encoded)}\r\nConnection: close\r\n\r\n'.encode() + encoded)
            stream.close()


def drive(name, destination, required_builds, expect_merge, version='target', branch_type='feature'):
    home = WORK / ('fm-lab-' + name)
    home.mkdir(mode=0o700)
    created = run([ROOT / 'bin/fm-lab-home.sh', 'create', home])
    assert created.returncode == 0, created.stderr
    server = None
    thread = None
    try:
        (home / '.tasks.toml').write_bytes((ROOT / '.tasks.toml').read_bytes())
        (home / 'data/backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
        wt = home / 'projects/repo'
        wt.mkdir()
        for args in (['git', 'init', '-q', '-b', 'main', wt],):
            init = run(args)
            assert init.returncode == 0, init.stderr
        (wt / 'README.md').write_text('Disposable live merge validation\n')
        for args in (['git', '-C', wt, 'add', 'README.md'],
                     ['git', '-C', wt, '-c', 'user.name=Live Validation',
                      '-c', 'user.email=validation@example.invalid', 'commit', '-qm', 'Fixture']):
            result = run(args)
            assert result.returncode == 0, result.stderr
        head = run(['git', '-C', wt, 'rev-parse', 'HEAD']).stdout.strip()
        run(['git', '-C', wt, 'update-ref', 'refs/remotes/origin/main', head]).check_returncode()
        (home / 'state/task-x1.meta').write_text(f'window=fm-task-x1\nworktree={wt}\nproject={wt}\nkind=ship\nmode=no-mistakes\n')
        state = {'head': head, 'model': MODEL, 'merge_posts': [],
                 'restrictions': [{'kind': 'require_passing_builds_to_merge',
                                   'branch_match_kind': 'branching_model',
                                   'branch_type': branch_type, 'value': required_builds}],
                 'pr': {'type': 'pullrequest', 'id': 7, 'state': 'OPEN', 'draft': False,
                        'source': {'branch': {'name': 'fm/task-x1'},
                                   'commit': {'hash': head[:12], 'type': 'commit'}},
                        'destination': {'branch': {'name': destination},
                                        'commit': {'hash': head[:12]}},
                        'participants': [], 'close_source_branch': True}}
        server = Backend(('127.0.0.1', 0), ConnectHandler)
        server.state = state
        server.events = []
        server.tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        server.tls.load_cert_chain(WORK / 'tls.crt', WORK / 'tls.key')
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        env = BASE_ENV | {'FM_HOME': str(home),
                          'HTTPS_PROXY': f'http://127.0.0.1:{server.server_address[1]}',
                          'HTTP_PROXY': f'http://127.0.0.1:{server.server_address[1]}',
                          'ALL_PROXY': f'http://127.0.0.1:{server.server_address[1]}',
                          'NO_PROXY': '', 'CURL_CA_BUNDLE': str(WORK / 'tls.crt')}
        cli = ROOT / 'bin/fm-pr-merge.sh' if version == 'target' else WORK / 'base/bin/fm-pr-merge.sh'
        result = run([cli, 'task-x1', URL], env=env)
        persisted = {}
        for filename in ('task-x1.meta', 'task-x1.pr-poll-merge-notified', '.wake-queue'):
            file = home / 'state' / filename
            if file.exists():
                persisted[filename] = file.read_text()
        observed = {'scenario': name, 'version': version,
                    'command': f'FM_HOME=<disposable marked lab> HTTPS_PROXY=<loopback TLS backend> CURL_CA_BUNDLE=<disposable cert> {cli.relative_to(ROOT)} task-x1 {URL}',
                    'destination': destination, 'model': MODEL,
                    'restrictions': state['restrictions'], 'successful_builds': 1,
                    'exit_code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr,
                    'final_pr_state': state['pr']['state'], 'merge_posts': state['merge_posts'],
                    'persisted_state': persisted, 'http_events': server.events}
        (EVIDENCE / (name + '.json')).write_text(json.dumps(observed, indent=2) + '\n')
        transcript = f"SCENARIO: {name} ({version})\n$ {observed['command']}\n" + result.stdout + result.stderr
        transcript += f"Exit: {result.returncode}\nBackend PR state: {state['pr']['state']}\nMerge POSTs: {json.dumps(state['merge_posts'])}\n"
        transcript += 'Persisted product state:\n' + json.dumps(persisted, indent=2) + '\n'
        (EVIDENCE / (name + '.log')).write_text(transcript)
        assert server.events, 'No real HTTPS traffic was driven'
        assert all(e.get('authenticated') and e.get('status') == 200 for e in server.events), server.events
        if expect_merge:
            assert result.returncode == 0, result.stderr
            assert state['pr']['state'] == 'MERGED' and len(state['merge_posts']) == 1
            assert state['merge_posts'][0]['close_source_branch'] is False
            assert f'is merged at the verified head {head}' in result.stdout
            assert 'task-x1.pr-poll-merge-notified' in persisted
        else:
            assert result.returncode == 1, result.stdout + result.stderr
            assert not state['merge_posts'] and state['pr']['state'] == 'OPEN'
            assert 'task-x1.pr-poll-merge-notified' not in persisted
            if version == 'target':
                assert f'base branch {destination} requires {required_builds} successful builds, and 1 reported at head {head}' in result.stderr
                assert 'could not be interpreted' not in result.stderr
            else:
                assert 'branch restrictions for base branch feature/login could not be interpreted' in result.stderr
        print(transcript, flush=True)
        return observed
    finally:
        if server is not None:
            server.shutdown()
            server.server_close()
        if thread is not None:
            thread.join(timeout=5)
        shutil.rmtree(home)


results = [
    drive('base-eligible-feature-refuses', 'feature/login', 1, False, version='base'),
    drive('target-eligible-feature-merges', 'feature/login', 1, True),
    drive('target-unmet-feature-refuses', 'feature/login', 2, False),
    drive('target-other-type-merges', 'release/2026', 3, True),
    drive('target-prefix-lookalike-merges', 'featureish/login', 3, True),
    drive('target-development-refuses', 'main', 2, False, branch_type='development'),
]
(EVIDENCE / 'live-results.json').write_text(json.dumps([
    {k: r[k] for k in ('scenario', 'version', 'destination', 'exit_code', 'final_pr_state', 'merge_posts')}
    for r in results], indent=2) + '\n')
print('All requested real-CLI HTTPS scenarios completed; all marked homes and local servers removed.')
