import json, os, sys, time
from pathlib import Path
root = Path(os.environ['LAB_ROOT'])
for line in sys.stdin:
    msg = json.loads(line)
    if 'id' not in msg:
        continue
    method = msg.get('method')
    if method == 'initialize':
        while not (root / 'release').exists():
            time.sleep(.01)
        result = {'protocolVersion': msg['params']['protocolVersion'], 'capabilities': {'tools': {'listChanged': True}}, 'serverInfo': {'name': 'disposable-exclusion-lab', 'version': '1'}}
    elif method == 'tools/list':
        result = {'tools': [{'name': n, 'description': n + ' disposable lab operation', 'inputSchema': {'type': 'object', 'properties': {}}} for n in ['editIssue','createIssue','readIssue']]}
    elif method == 'tools/call':
        name = msg['params']['name']
        with (root / 'mcp-side-effects.log').open('a') as f:
            f.write(name + '\n')
        result = {'content': [{'type': 'text', 'text': 'executed ' + name}]}
    elif method == 'ping':
        result = {}
    else:
        print(json.dumps({'jsonrpc':'2.0', 'id':msg['id'], 'error':{'code':-32601,'message':'unsupported fixture method'}}), flush=True)
        continue
    print(json.dumps({'jsonrpc':'2.0', 'id':msg['id'], 'result':result}), flush=True)
