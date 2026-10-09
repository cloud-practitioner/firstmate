import json, sys, time
from pathlib import Path
release, logfile = map(Path, sys.argv[1:3])
def log(obj):
    with logfile.open('a') as f: f.write(json.dumps(obj)+'\n')
for line in sys.stdin:
    req = json.loads(line)
    method = req.get('method')
    if 'id' not in req: continue
    log({'method':method})
    if method == 'initialize':
        result = {'protocolVersion':'2024-11-05','capabilities':{'tools':{'listChanged':True}},'serverInfo':{'name':'disposable-tracker','version':'1'}}
    elif method == 'tools/list':
        while not release.exists(): time.sleep(.01)
        result = {'tools':[{'name':n,'description':n+' on a disposable issue','inputSchema':{'type':'object','properties':{}}} for n in ['editIssue','createIssue','readIssue']]}
    elif method == 'tools/call':
        log({'executed':req['params']['name']})
        result = {'content':[{'type':'text','text':'disposable issue read successfully'}]}
    else: result = {}
    print(json.dumps({'jsonrpc':'2.0','id':req['id'],'result':result}), flush=True)
