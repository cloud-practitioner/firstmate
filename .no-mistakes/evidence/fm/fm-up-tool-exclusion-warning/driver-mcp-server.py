import json, sys, time
from pathlib import Path
log=Path(sys.argv[1])
def record(value):
    with log.open('a') as f: f.write(json.dumps(dict(time=time.time(),**value))+'\n')
for line in sys.stdin:
    message=json.loads(line)
    method=message.get('method')
    record({'request':message})
    if 'id' not in message: continue
    if method=='initialize':
        answer={'protocolVersion':message['params']['protocolVersion'],'capabilities':{'tools':{}},'serverInfo':{'name':'disposable-tracker','version':'1.0'}}
    elif method=='tools/list':
        time.sleep(.5)
        answer={'tools':[{'name':name,'description':'Disposable live MCP tool '+name,'inputSchema':{'type':'object','properties':{}}} for name in ('readIssue','editIssue','createIssue')]}
    elif method=='tools/call':
        record({'executed':message['params']['name']})
        answer={'content':[{'type':'text','text':'Live MCP '+message['params']['name']+' executed'}]}
    elif method=='ping': answer={}
    else:
        print(json.dumps({'jsonrpc':'2.0','id':message['id'],'error':{'code':-32601,'message':'Unsupported method'}}),flush=True)
        continue
    response={'jsonrpc':'2.0','id':message['id'],'result':answer}
    record({'response':response})
    print(json.dumps(response),flush=True)
