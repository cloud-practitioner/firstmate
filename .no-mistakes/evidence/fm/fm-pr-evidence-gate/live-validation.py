#!/usr/bin/env python3
"""Disposable product-level checks. No forge mutations or live agent launches.
The before/after endpoint and text states illustrate the evidence workflow;
they are NOT historical before/after evidence for the submitted branch.
"""
import contextlib
import copy
import hashlib
import json
import os
from pathlib import Path
import select
import shlex
import shutil
import socket
import socketserver
import ssl
import subprocess
import tempfile
import threading

ROOT = Path('/home/node/.no-mistakes/worktrees/450411b3e67c/01M5KTDVCMKC5EZ9HW8F6A74KH')
OUT = Path('/home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH')
EV = ROOT / 'bin/fm-pr-evidence.sh'
LIB = ROOT / 'bin/fm-pr-evidence-lib.py'
SCENARIOS = []
LOG = []
SERVICES = []
REQUESTS = []
STATE = {'phase': 'before'}


def require(value, detail):
    if not value:
        raise AssertionError(detail)


def run(args, expected=0, env=None, timeout=20):
    args = [str(x) for x in args]
    result = subprocess.run(args, cwd=ROOT, env=env or ENV, capture_output=True, text=True, timeout=timeout)
    LOG.append('$ ' + shlex.join(args) + '\n' + result.stdout + result.stderr + '(exit status %s)\n' % result.returncode)
    require(result.returncode == expected, 'Unexpected exit for %s: %s' % (args, result.stdout + result.stderr))
    return result.stdout + result.stderr


def scenario(name, function):
    start = len(LOG)
    try:
        function()
        SCENARIOS.append({'name': name, 'result': 'pass', 'live': True,
                          'evidence': 'live-cli-transcript.txt; live-scenario-results.json',
                          'reason': ''})
    except Exception as exc:
        LOG.append('SCENARIO FAILURE: %s: %s\n' % (type(exc).__name__, exc))
        SCENARIOS.append({'name': name, 'result': 'fail', 'live': True,
                          'evidence': 'live-cli-transcript.txt; live-scenario-results.json',
                          'reason': str(exc)})
    LOG.insert(start, '\n=== ' + name + ' ===\n')


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


class HTTP(socketserver.StreamRequestHandler):
    def handle(self):
        request = self.rfile.readline().decode().strip()
        if not request:
            return
        headers = []
        while True:
            line = self.rfile.readline().decode()
            if line in ('\r\n', '\n', ''):
                break
            headers.append(line.strip())
        length = next((int(h.split(':', 1)[1]) for h in headers if h.lower().startswith('content-length:')), 0)
        body = self.rfile.read(length).decode()
        method, path, _ = request.split(' ', 2)
        REQUESTS.append({'method': method, 'path': path, 'body': body})
        if method == 'HEAD':
            self.wfile.write(b'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 23\r\nConnection: close\r\n\r\n')
            return
        if path == '/items':
            self.wfile.write(b'HTTP/1.1 103 Early Hints\r\nX-Interim-Only: omit\r\n\r\n')
            status = b'500 Old reply' if STATE['phase'] == 'before' else b'200 New reply'
            self.wfile.write(b'HTTP/1.1 ' + status + b'\r\nContent-Type: application/json\r\n'
                             b'Link: </items?page=2>;\r\n\trel="next"\r\n'
                             b'X-NoSpace:yes\r\nX-Tab:\tvalue\r\nX-Empty:\r\n'
                             b'Set-Cookie: sid=fixture-cookie\r\n'
                             b'Transfer-Encoding: chunked\r\nTrailer: X-Result\r\nConnection: close\r\n\r\n')
            payload = json.dumps({'result': STATE['phase'], 'count': 1 if STATE['phase'] == 'before' else 2}).encode()
            self.wfile.write(('%x\r\n' % len(payload)).encode() + payload + b'\r\n0\r\nX-Result:complete\r\n\tand checked\r\n\r\n')
        else:
            self.wfile.write(b'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}')


class TLS(Server):
    def get_request(self):
        connection, address = super().get_request()
        return TLS_CONTEXT.wrap_socket(connection, server_side=True), address


class Proxy(socketserver.StreamRequestHandler):
    def handle(self):
        line = self.rfile.readline().decode()
        if not line:
            return
        method, target, _ = line.split(' ', 2)
        while self.rfile.readline() not in (b'\r\n', b'\n', b''):
            pass
        require(method == 'CONNECT', 'Only CONNECT is allowed')
        require(target == '127.0.0.1:%d' % HTTPS_PORT, 'Proxy target must be the disposable TLS server')
        with socket.create_connection(('127.0.0.1', HTTPS_PORT), timeout=5) as upstream:
            self.wfile.write(b'HTTP/1.1 200 Connection established\r\nX-Proxy-Only: tunnel\r\n\r\n')
            self.wfile.flush()
            peers = (self.connection, upstream)
            while True:
                ready, _, _ = select.select(peers, [], [], 8)
                if not ready:
                    return
                for source in ready:
                    data = source.recv(65536)
                    if not data:
                        return
                    (upstream if source is self.connection else self.connection).sendall(data)


def start(server_type, handler):
    server = server_type(('127.0.0.1', 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    SERVICES.append((server, thread))
    return server.server_address[1]


with tempfile.TemporaryDirectory(prefix='live-', dir=ROOT / '.test-evidence-tmp') as tmp:
    TMP = Path(tmp)
    HOME = TMP / 'home'
    for directory in ('config', 'data', 'state', 'projects'):
        (HOME / directory).mkdir(parents=True)
    ENV = dict(os.environ)
    for key in list(ENV):
        if key.startswith('FM_') or key in ('GH_TOKEN', 'GITHUB_TOKEN', 'NO_MISTAKES_BITBUCKET_EMAIL',
                                           'NO_MISTAKES_BITBUCKET_API_TOKEN', 'TASKS_AXI_FILE', 'TASKS_AXI_BACKEND'):
            ENV.pop(key)
    ENV.update(FM_HOME=str(HOME), TMPDIR=str(TMP), PYTHONDONTWRITEBYTECODE='1',
               GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null', NO_PROXY='*', no_proxy='*')
    (HOME / '.tasks.toml').write_text('backend = "markdown"\n[markdown]\npath = "data/backlog.md"\narchive = "data/done-archive.md"\ndone_keep = 10\n')
    PROJECT = HOME / 'projects/demo'
    PROJECT.mkdir()
    run(['git', '-C', PROJECT, 'init', '-q'])
    run(['git', '-C', PROJECT, '-c', 'user.name=Evidence Test', '-c', 'user.email=test@example.invalid',
         'commit', '--allow-empty', '-qm', 'Disposable test project'])
    run(['git', '-C', PROJECT, 'remote', 'add', 'origin', 'https://github.com/local-validation/no-network.git'])
    CONFIG = HOME / 'config/pr-evidence'
    CONFIG.write_text('* enforce\ndemo ui web/*\ndemo api server/*\n')
    BRIEF = TMP / 'brief.md'

    def intake():
        for text in ('', '{EVIDENCE}', 'unknown'):
            BRIEF.write_text('# Task\n## Evidence class\n' + text + '\n')
            output = run([EV, 'intake', BRIEF, 'demo', 'no-mistakes', 'none', PROJECT], 1)
            require('[FAIL]' in output and 'FIX:' in output, 'Intake must explain the refusal')
        for kind in ('ui', 'api', 'ui+api'):
            BRIEF.write_text('# Task\n## Evidence class\n' + kind + '\n')
            output = run([EV, 'intake', BRIEF, 'demo', 'no-mistakes', 'none', PROJECT])
            require('evidence=' + kind in output, 'Intake must emit the selected kind')
        BRIEF.write_text('# Task\n## Evidence class\nnone: Only a comment changed in the file.\n')
        output = run([EV, 'intake', BRIEF, 'demo', 'direct-PR', 'none', PROJECT])
        require('evidence=none' in output and 'evidence_reason=' in output, 'None needs a persisted reason')
        output = run([EV, 'intake', BRIEF, 'firstmate', 'no-mistakes', 'none', ROOT], 1)
        require('none is not allowed' in output, 'Firstmate must forbid none by lineage')
    scenario('Declare evidence at intake; reject missing kinds and forbid none for Firstmate', intake)

    def lanes():
        for mode, forge, remote in [('local-only', 'none', 'https://github.com/local-validation/no-network.git'),
                                     ('no-mistakes', 'external', 'https://github.com/local-validation/no-network.git'),
                                     ('no-mistakes', 'none', 'https://bitbucket.org/local-validation/no-network.git')]:
            run(['git', '-C', PROJECT, 'remote', 'set-url', 'origin', remote])
            run([EV, 'eligible', 'demo', mode, forge, PROJECT], 1)
        run(['git', '-C', PROJECT, 'remote', 'set-url', 'origin', 'https://github.com/local-validation/no-network.git'])
        CONFIG.write_text('* enforce\ninvalid directive\n')
        output = run([EV, 'eligible', 'demo', 'no-mistakes', 'none', PROJECT], 2)
        require('config/pr-evidence is not valid' in output, 'Invalid configuration must refuse')
        CONFIG.unlink()
        run([EV, 'eligible', 'demo', 'no-mistakes', 'none', PROJECT], 1)
        CONFIG.write_text('* enforce\ndemo ui web/*\ndemo api server/*\n')
        run([EV, 'eligible', 'demo', 'no-mistakes', 'none', PROJECT])
    scenario('Exclude unsupported delivery lanes and keep Bitbucket off; refuse invalid configuration', lanes)

    def inheritance():
        second = TMP / 'secondmate'
        second.mkdir()
        script = '. "$1"; propagate_secondmate_inheritance "$2" "$3"'
        run(['bash', '-c', script, '_', ROOT / 'bin/fm-config-inherit-lib.sh', HOME, second])
        require((second / 'config/pr-evidence').read_bytes() == CONFIG.read_bytes(), 'Inherited policy must match')
        second_env = dict(ENV, FM_HOME=str(second))
        run([EV, 'eligible', 'demo', 'no-mistakes', 'none', PROJECT], env=second_env)
        CONFIG.write_text(CONFIG.read_text() + 'demo require\n')
        run(['bash', '-c', script, '_', ROOT / 'bin/fm-config-inherit-lib.sh', HOME, second])
        require((second / 'config/pr-evidence').read_bytes() == CONFIG.read_bytes(), 'Policy updates must converge')
        BRIEF.write_text('# Task\n## Evidence class\nnone: Only a comment changed in the file.\n')
        output = run([EV, 'intake', BRIEF, 'demo', 'no-mistakes', 'none', PROJECT], 1, env=second_env)
        require('none is not allowed' in output, 'A new CLI process must enforce the inherited policy')
        (OUT / 'inherited-policy.txt').write_text((second / 'config/pr-evidence').read_text())
    scenario('Propagate durable policy into a second home and enforce it in a fresh CLI process', inheritance)

    def english():
        invalid = ['', ' '.join(['word'] * 26), 'First step. Second step. Third step. Fourth step.',
                   'Read the file; close the file.', "It doesn't read the file.", 'Read the file etc.',
                   'Read the file — close it.', 'Use a robust tool.', 'The label says "it can’t run".']
        for text in invalid:
            output = run([EV, 'ste', '--text', text], 1)
            require('[FAIL]' in output and 'FIX:' in output, 'Strict text refusal needs a fix')
        for kind, limit in [('steps', 21), ('label', 11)]:
            run([EV, 'ste', '--kind', kind, '--text', ' '.join(['word'] * limit)], 1)
        output = run([EV, 'ste', '--text', 'The file was changed.'])
        require('passive voice' in output and '[WARN]' in output, 'Passive voice must only warn')
        output = run([EV, 'ste', '--text', 'The system will abandon the task.'])
        require('not approved' in output, 'Shipped vocabulary warnings must run')
        run([EV, 'ste', '--text', 'Read the new text.'])
    scenario('Check short plain English and distinguish strict refusals from warnings', english)

    def legacy_and_waiver():
        meta = HOME / 'state/legacy.meta'
        meta.write_text('kind=ship\nmode=no-mistakes\nproject=' + str(PROJECT) + '\n')
        output = run([EV, 'check', 'legacy', 'https://github.com/local-validation/no-network/pull/1'])
        require('predates it' in output, 'Legacy task must pass with a notice before a forge read')
        meta.write_text(meta.read_text() + 'evidence=ui\n')
        (HOME / 'state/.afk').write_text('away\n')
        output = run([EV, 'waive', 'legacy', 'https://github.com/local-validation/no-network/pull/1',
                      '--words', 'I accept this change without images.'], 1)
        require('away mode' in output, 'Away-mode waiver must refuse before any remote mutation')
        (HOME / 'state/.afk').unlink()
        output = run([EV, 'waive', 'legacy', 'https://github.com/local-validation/no-network/pull/1', '--words', 'Accept it'], 1)
        require('at least 4 words' in output, 'Short waiver must refuse')
        require(not (HOME / 'state/legacy.evidence-waiver').exists(), 'Rejected waiver must leave no waiver state')
    scenario('Allow legacy tasks with a notice and refuse away-mode or empty waiver authority', legacy_and_waiver)

    def ui_capture():
        for phase, text in [('before', 'Use a robust tool.'), ('after', 'Read the new text.')]:
            run([EV, 'capture-ui', '--out', OUT / ('ui-' + phase + '.txt'), '--', EV, 'ste', '--text', text])
        require('(exit status 1)' in (OUT / 'ui-before.txt').read_text(), 'Transcript must retain refusal status')
        require('(exit status 0)' in (OUT / 'ui-after.txt').read_text(), 'Transcript must retain pass status')
        for phase, other in [('before', 'after'), ('after', 'before')]:
            run([EV, 'annotate-ui', '--text', OUT / ('ui-' + phase + '.txt'), '--against', OUT / ('ui-' + other + '.txt'),
                 '--purpose', 'Use short text to explain the change.', '--label', 'Text check changed',
                 '--out', OUT / ('ui-' + phase + '.png')])
        secret = TMP / 'masked.txt'
        run([EV, 'capture-ui', '--out', secret, '--', 'printf', '%s\n', 'Authorization: Bearer fixture-only-token'])
        require('fixture-only-token' not in secret.read_text(), 'Captured command and output must mask a token')
        (OUT / 'masked-terminal.txt').write_text(secret.read_text())
    scenario('Capture real CLI output and draw a purpose and difference marks on both terminal images', ui_capture)

    try:
        certificate, key = TMP / 'server.crt', TMP / 'server.key'
        run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
             '-subj', '/CN=127.0.0.1', '-addext', 'subjectAltName=IP:127.0.0.1', '-keyout', key, '-out', certificate])
        TLS_CONTEXT = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        TLS_CONTEXT.load_cert_chain(certificate, key)
        HTTPS_PORT = start(TLS, HTTP)
        HTTP_PORT = start(Server, HTTP)
        PROXY_PORT = start(Server, Proxy)
        proxy_env = dict(ENV, HTTPS_PROXY='http://127.0.0.1:%d' % PROXY_PORT,
                         https_proxy='http://127.0.0.1:%d' % PROXY_PORT, NO_PROXY='', no_proxy='', CURL_CA_BUNDLE=str(certificate))

        def http_capture():
            request_body = TMP / 'request.json'
            request_body.write_text('{"name":"part","password":"fixture-only-password"}')
            for phase in ('before', 'after'):
                STATE['phase'] = phase
                run([EV, 'capture-api', '--out', OUT / ('api-' + phase + '.json'), '-X', 'POST',
                     '--header', 'Content-Type:application/json', '--header', 'X-Request: new',
                     '--header', 'Authorization: Bearer fixture-only-token', '--body-file', request_body,
                     'https://127.0.0.1:%d/items' % HTTPS_PORT], env=proxy_env)
                data = json.loads((OUT / ('api-' + phase + '.json')).read_text())
                require(data['response']['status'] == (500 if phase == 'before' else 200), 'Final status must survive trailers')
                require(data['response']['reason'] == ('Old reply' if phase == 'before' else 'New reply'), 'Custom status message must survive')
                require(data['request']['method'] == 'POST', 'API method must be retained')
                require(json.loads(data['request']['body'])['name'] == 'part', 'Request body public fields must remain')
                require(json.loads(data['response']['body'])['result'] == phase, 'Response body must match the live reply')
                require(sum(name.lower() == 'host' for name, value in data['request']['headers']) == 1, 'CONNECT Host must not leak into API request headers')
                require(not any(name.lower().startswith('proxy-') for name, value in data['request']['headers']), 'CONNECT headers must be excluded')
                response = data['response']['headers']
                require(['Link', '</items?page=2>; rel="next"'] in response, 'Header continuations must unfold')
                require(['X-NoSpace', 'yes'] in response and ['X-Tab', 'value'] in response and ['X-Empty', ''] in response, 'Optional whitespace and empty values must be preserved')
                require(['X-Result', 'complete and checked'] in response, 'Folded trailers must remain in response headers')
                require(not any(name in ('X-Proxy-Only', 'X-Interim-Only') for name, value in response), 'Proxy and interim response fields must be excluded')
                serialized = json.dumps(data)
                for value in ('fixture-only-token', 'fixture-only-password', 'fixture-cookie'):
                    require(value not in serialized, 'Secrets must be masked before persistence: ' + value)
                LOG.append('Captured exchange:\n' + json.dumps(data, indent=2) + '\n')
            require(len([r for r in REQUESTS if r['method'] == 'POST' and r['path'] == '/items']) == 2, 'Real endpoint must receive both API calls')
        scenario('Capture HTTPS through a real CONNECT tunnel; keep final headers, folded fields and trailers while masking secrets', http_capture)

        def head():
            output = OUT / 'head.json'
            run([EV, 'capture-api', '--out', output, '-X', 'HEAD', 'http://127.0.0.1:%d/head' % HTTP_PORT], timeout=5)
            data = json.loads(output.read_text())
            require(data['response']['status'] == 200 and data['response']['body'] == '', 'HEAD needs a successful empty body')
            require(['Content-Length', '23'] in data['response']['headers'], 'HEAD must retain entity length')
            for method in ('GET', 'POST'):
                run([EV, 'capture-api', '--out', TMP / (method + '.json'), '-X', method,
                     'http://127.0.0.1:%d/plain' % HTTP_PORT])
                require(json.loads((TMP / (method + '.json')).read_text())['response']['body'] == '{}', 'Non-HEAD body must not be discarded')
            LOG.append('HEAD exchange:\n' + json.dumps(data, indent=2) + '\n')
        scenario('Capture HEAD with a nonzero entity length without waiting for a body; retain GET and POST bodies', head)

        def api_images():
            for phase, other in [('before', 'after'), ('after', 'before')]:
                run([EV, 'annotate-api', '--sidecar', OUT / ('api-' + phase + '.json'), '--against', OUT / ('api-' + other + '.json'),
                     '--purpose', 'Check the server reply before and after the change.', '--label', 'The reply changed',
                     '--out', OUT / ('api-' + phase + '.png')])
            run([EV, 'annotate-api', '--sidecar', OUT / 'api-after.json', '--against', OUT / 'api-after.json',
                 '--purpose', 'Check the server reply before and after the change.', '--out', TMP / 'identical.png'], 1)
        scenario('Render the six-part HTTP exchanges with visible purpose and marks; reject an unchanged exchange', api_images)

        def composition():
            items = {'items': [
                {'id': 'text-check', 'kind': 'ui', 'purpose': 'Use short text to explain the change.',
                 'labels': ['Text check changed'], 'before': {'image': str(OUT / 'ui-before.png')}, 'after': {'image': str(OUT / 'ui-after.png')}},
                {'id': 'server-reply', 'kind': 'api', 'purpose': 'Check the server reply before and after the change.',
                 'labels': ['The reply changed'],
                 'before': {'image': str(OUT / 'api-before.png'), 'sidecar': str(OUT / 'api-before.json')},
                 'after': {'image': str(OUT / 'api-after.png'), 'sidecar': str(OUT / 'api-after.json')}}]}
            items_path = OUT / 'items.json'
            items_path.write_text(json.dumps(items, indent=2))
            head = run(['git', 'rev-parse', 'HEAD']).strip()
            def compose(path, out, expected=0):
                return run(['python3', LIB, 'compose', '--items', path, '--head', head, '--declared', 'ui+api',
                            '--provider', 'github', '--repo', 'local-validation/no-network', '--number', '1', '--out', out], expected)
            compose(items_path, OUT / 'composed')
            comment = (OUT / 'composed/comment.md').read_text()
            require(head in comment, 'Comment must bind the current head')
            for kind in ('ui', 'api'):
                for phase in ('before', 'after'):
                    image = OUT / (kind + '-' + phase + '.png')
                    annotation = json.loads(Path(str(image) + '.annotation.json').read_text())
                    require(annotation['sha256'] == hashlib.sha256(image.read_bytes()).hexdigest(), 'Annotation record must bind rendered image bytes')
                    run(['python3', LIB, 'marks', image])
            for index in range(2):
                for phase in ('before', 'after'):
                    spec = copy.deepcopy(items)
                    source = Path(spec['items'][index][phase]['image'])
                    image = TMP / ('guard-%s-%s.png' % (index, phase))
                    shutil.copyfile(source, image)
                    spec['items'][index][phase]['image'] = str(image)
                    guard_path = TMP / 'guard-items.json'
                    guard_path.write_text(json.dumps(spec))
                    output = compose(guard_path, TMP / 'refused', 1)
                    require('no annotation record' in output, 'Every phase of every kind must refuse a missing record')
                    annotation = json.loads(Path(str(source) + '.annotation.json').read_text())
                    annotation['sha256'] = '0' * 64
                    Path(str(image) + '.annotation.json').write_text(json.dumps(annotation))
                    output = compose(guard_path, TMP / 'refused', 1)
                    require('annotation does not match its image' in output, 'A stale annotation hash must refuse')
            # A real rendering operation with a mark fully outside the image bounds
            # yields a valid receipt but no drawn difference. The composer must refuse.
            unmarked = TMP / 'unmarked.png'
            run(['magick', '-size', '640x120', 'xc:white', 'PNG32:' + str(unmarked)])
            offscreen = TMP / 'offscreen.png'
            run([EV, 'annotate-ui', '--image', unmarked, '--mark', '2000,2000,10,10',
                 '--purpose', 'Use short text to explain the change.', '--out', offscreen])
            spec = copy.deepcopy(items)
            spec['items'][0]['before']['image'] = str(offscreen)
            (TMP / 'guard-items.json').write_text(json.dumps(spec))
            output = compose(TMP / 'guard-items.json', TMP / 'refused', 1)
            require('no drawn marks' in output, 'A record alone must not replace pixel marks')
        scenario('Compose a head-bound review comment; reject missing receipts, stale image hashes and marks drawn outside the image', composition)
    finally:
        for server, thread in reversed(SERVICES):
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)
        LOG.append('\nAll local HTTP, TLS and CONNECT services stopped. Disposable homes and TLS keys removed on exit.\n')
    (OUT / 'live-cli-transcript.txt').write_text('\n'.join(LOG))
    (OUT / 'live-scenario-results.json').write_text(json.dumps(SCENARIOS, indent=2))

print(json.dumps(SCENARIOS, indent=2))
raise SystemExit(any(s['result'] != 'pass' for s in SCENARIOS))
