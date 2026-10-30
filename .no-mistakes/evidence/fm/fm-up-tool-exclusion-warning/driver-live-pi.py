import os, json, subprocess, threading, time, sys
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path.cwd()
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M65MFBQHY7METR56JHMH28BV')
# This is unmodified output from the actual fm-spawn generator in the targeted
# regression setup. Only its launch backend was a capture fixture. The checker,
# registry, lifecycle dispatch, direct calls, and codemode below are real Pi.
SOURCE_HOME = ROOT / '.test-phase/tmp/fm-spawn-dispatch-profile.IFHVsY/excl-registry-pi-scout-reconnect/home'
TASK = 'excl-registry-pi-scout-reconnect'
EXTENSION = SOURCE_HOME / f'state/{TASK}.pi-ext.ts'
STATUS = SOURCE_HOME / f'state/{TASK}.status'
FIXTURE = ROOT / '.test-phase/live-tools.ts'
requests = []
scenario = ''
request_number = 0

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        global request_number
        body = json.loads(self.rfile.read(int(self.headers['content-length'])))
        request_number += 1
        request = {'scenario': scenario, 'request_number': request_number,
                   'tools': body.get('tools', []), 'messages': body.get('messages', [])}
        requests.append(request)
        n = request_number
        tool = None
        args = {}
        if scenario in ('present', 'late'):
            if n == 1: tool = 'mcp__tracker__editIssue'
            if n == 2:
                tool = 'codemode'
                args = {'code': 'return await tools.mcp__tracker__createIssue({});'}
            if n == 3: tool = 'mcp__tracker__readIssue'
        elif scenario == 'next-start':
            if n == 2: tool = 'mcp__tracker__editIssue'
        elif scenario == 'absent' and n == 1:
            tool = 'mcp__tracker__readIssue'
        elif scenario == 'mcp-absent' and n == 1:
            tool = 'codemode'
            args = {'code': 'return await tools.mcp__tracker__readIssue({});'}
        delta = {'role': 'assistant'}
        finish = 'stop'
        if tool:
            delta['tool_calls'] = [{'index': 0, 'id': f'call_{n}', 'type': 'function',
                                   'function': {'name': tool, 'arguments': json.dumps(args)}}]
            finish = 'tool_calls'
        else:
            delta['content'] = f'Fixture response {scenario} {n} complete.'
        chunk = {'id': f'chatcmpl-{n}', 'object': 'chat.completion.chunk', 'created': int(time.time()),
                 'model': 'exclusion-fixture', 'choices': [{'index': 0, 'delta': delta, 'finish_reason': None}]}
        end = dict(chunk, choices=[{'index': 0, 'delta': {}, 'finish_reason': finish}])
        data = ('data: '+json.dumps(chunk)+'\n\ndata: '+json.dumps(end)+'\n\ndata: [DONE]\n\n').encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
home = ROOT / '.test-phase/pi-home'
home.mkdir(exist_ok=True)
(home/'models.json').write_text(json.dumps({'providers': {'lab': {
    'baseUrl': f'http://127.0.0.1:{server.server_port}/v1', 'api': 'openai-completions',
    'apiKey': 'disposable-local-endpoint', 'models': [{
        'id': 'exclusion-fixture', 'name': 'Local exclusion fixture', 'reasoning': False,
        'input': ['text'], 'contextWindow': 128000, 'maxTokens': 2048,
        'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0}}]}}}))
base = ['pi', '--provider', 'lab', '--model', 'exclusion-fixture', '--thinking', 'off',
        '--offline', '--no-context-files', '--no-skills', '--no-extensions',
        '--no-mcp', '--no-prompt-templates', '--no-themes', '--tools', '+codemode',
        '-e', 'builtin:codemode',
        '-e', str(FIXTURE), '-e', str(EXTENSION), '--mode', 'json', '--print']
results = []
try:
    for scenario in sys.argv[1:] or ['absent', 'present', 'late', 'next-start', 'mcp-absent']:
        request_number = 0
        STATUS.write_text('working: live validation fixture\n')
        events = EVIDENCE / f'pi-{scenario}-events.jsonl'
        events.write_text('')
        env = dict(os.environ, PI_CODING_AGENT_DIR=str(home), LIVE_SCENARIO=scenario,
                   LIVE_STATUS=str(STATUS), LIVE_EVENTS=str(events), PI_TELEMETRY='0')
        sessiondir = ROOT/'.test-phase/pi-sessions'
        sessiondir.mkdir(exist_ok=True)
        sessionfile = sessiondir/f'{scenario}.jsonl'
        sessionfile.unlink(missing_ok=True)
        cmd = base.copy() + ['--session', str(sessionfile)]
        if scenario in ('absent', 'mcp-absent'):
            cmd += ['--exclude-tools', 'mcp__tracker__editIssue,mcp__tracker__createIssue']
        if scenario == 'mcp-absent':
            cmd.remove('--no-mcp')
            cmd += ['-e', 'builtin:mcp']
            serverlog = EVIDENCE/'pi-mcp-server.jsonl'
            serverlog.write_text('')
            (home/'mcp.json').write_text(json.dumps({'mcpServers': {'tracker': {
                'command': 'python3', 'args': [str(ROOT/'.test-phase/mcp-server.py'), str(serverlog)],
                'exposure': 'codemode'}}}))
        cmd += ['Exercise the isolated tool-exclusion fixture.']
        start = time.monotonic()
        run = subprocess.run(cmd, env=env, cwd=ROOT, capture_output=True, text=True, timeout=90)
        (EVIDENCE / f'pi-{scenario}-transcript.jsonl').write_text(run.stdout)
        (EVIDENCE / f'pi-{scenario}-stderr.log').write_text(run.stderr)
        status = STATUS.read_text()
        (EVIDENCE / f'pi-{scenario}-status.log').write_text(status)
        observed = [json.loads(x) for x in events.read_text().splitlines()]
        results.append({'scenario': scenario, 'command': cmd, 'exit': run.returncode,
                        'seconds': round(time.monotonic()-start, 2), 'requests': request_number,
                        'status': status, 'observed_events': observed})
        print(json.dumps({k:v for k,v in results[-1].items() if k != 'observed_events'}), flush=True)
        print(run.stderr, flush=True)
finally:
    server.shutdown()
    (home/'mcp.json').unlink(missing_ok=True)
    (EVIDENCE/'pi-live-results.json').write_text(json.dumps(results, indent=2))
    (EVIDENCE/'pi-local-endpoint-requests.json').write_text(json.dumps(requests, indent=2))
