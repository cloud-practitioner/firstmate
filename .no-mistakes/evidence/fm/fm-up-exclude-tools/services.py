import json, sys, os, time, threading
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
BASE=Path(__file__).parent
TOOLS=['readIssue','addComment','createIssue','editIssue','transitionIssue','deleteIssue']
def record(filename, data):
    with (BASE/filename).open('a') as f: f.write(json.dumps(data,ensure_ascii=False)+'\n')
if len(sys.argv)>1 and sys.argv[1]=='mcp':
    for line in sys.stdin:
        req=json.loads(line)
        if 'id' not in req: continue
        method=req['method']
        if method=='initialize':
            result={'protocolVersion':'2024-11-05','capabilities':{'tools':{}},'serverInfo':{'name':'disposable-tracker','version':'1'}}
        elif method=='tools/list':
            result={'tools':[{'name':n,'description':'Disposable tracker '+n,'inputSchema':{'type':'object','properties':{},'additionalProperties':False}} for n in TOOLS]}
        elif method=='tools/call':
            name=req['params']['name']
            record('mcp-calls.jsonl',{'pid':os.getpid(),'tool':name,'cwd':os.getcwd(),'at':time.time()})
            result={'content':[{'type':'text','text':'Executed '+name+' in disposable tracker'}]}
        else:
            print(json.dumps({'jsonrpc':'2.0','id':req['id'],'error':{'code':-32601,'message':'Unsupported fixture method'}}),flush=True); continue
        print(json.dumps({'jsonrpc':'2.0','id':req['id'],'result':result}),flush=True)
else:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args): pass
        def do_POST(self):
            req=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            names=[t['function']['name'] for t in req.get('tools',[])]
            msgs=req['messages']
            record('model-requests.jsonl',{'tools':names,'messages':msgs,'at':time.time()})
            text=str(msgs[-1].get('content',''))
            if msgs[-1]['role']=='user' and 'ADVERSARIAL_DIRECT' in text:
                delta={'role':'assistant','tool_calls':[{'index':0,'id':'lab-denied','type':'function','function':{'name':'mcp__tracker__createIssue','arguments':'{}'}}]}
                reason='tool_calls'
            elif msgs[-1]['role']=='user' and 'ADVERSARIAL_CODEMODE' in text:
                delta={'role':'assistant','tool_calls':[{'index':0,'id':'lab-code-denied','type':'function','function':{'name':'codemode','arguments':json.dumps({'code':'return await tools.mcp__tracker__createIssue({});'})}}]}
                reason='tool_calls'
            elif msgs[-1]['role']=='user' and 'mcp__tracker__readIssue' in names:
                calls=[n for n in ['mcp__tracker__readIssue','mcp__tracker__addComment'] if n in names]
                delta={'role':'assistant','tool_calls':[{'index':i,'id':'lab-call-'+str(i),'type':'function','function':{'name':n,'arguments':'{}'}} for i,n in enumerate(calls)]}
                reason='tool_calls'
            else:
                results=[m.get('content','') for m in msgs if m['role']=='tool'][-2:]
                delta={'role':'assistant','content':'LAB RESULT: model-visible tools = '+', '.join(names)+'; tracker results = '+json.dumps(results)}
                reason='stop'
            self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.end_headers()
            for choice in [{'index':0,'delta':delta,'finish_reason':None},{'index':0,'delta':{},'finish_reason':reason}]:
                self.wfile.write(('data: '+json.dumps({'id':'lab-completion','object':'chat.completion.chunk','created':int(time.time()),'model':'fixture','choices':[choice]})+'\n\n').encode())
            self.wfile.write(b'data: [DONE]\n\n'); self.wfile.flush()
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
    (BASE/'port').write_text(str(server.server_port))
    server.serve_forever()
