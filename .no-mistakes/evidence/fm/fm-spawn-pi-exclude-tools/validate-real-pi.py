import http.server, json, os, pathlib, subprocess, sys, tempfile, threading
root = pathlib.Path.cwd()
fixtures = pathlib.Path(sys.argv[1])
scratch = pathlib.Path('/home/node/.treehouse/firstmate-35d3d0/1/firstmate/state/fm-spawn-pi-exclude-tools.tasktmp')
evidence = pathlib.Path('/home/node/.no-mistakes/evidence/01M49W3M79ENYHYMK104A317EC')
requests = []
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        requests.append(body)
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.end_headers()
        for delta, finish in [({'role':'assistant','content':'Disposable endpoint completed the validation turn.'}, None), ({}, 'stop')]:
            obj = {'id':'lab-completion','object':'chat.completion.chunk','created':1,'model':'lab-model','choices':[{'index':0,'delta':delta,'finish_reason':finish}]}
            self.wfile.write(('data: '+json.dumps(obj)+'\n\n').encode())
        self.wfile.write(b'data: [DONE]\n\n')
server = http.server.ThreadingHTTPServer(('127.0.0.1',0), Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
lab = pathlib.Path(tempfile.mkdtemp(prefix='real-pi.',dir=scratch))
(lab/'agent').mkdir(); (lab/'project').mkdir()
(lab/'agent/models.json').write_text(json.dumps({'providers':{'exclusion-lab':{'baseUrl':f'http://127.0.0.1:{server.server_port}/v1','api':'openai-completions','apiKey':'disposable-local-only','models':[{'id':'lab-model','name':'Local validation endpoint','reasoning':False,'input':['text'],'contextWindow':32000,'maxTokens':1024,'compat':{'supportsDeveloperRole':False,'supportsStore':False}}]}}}))
tools = lab/'local-tools.ts'
tools.write_text('''export default function(pi: any) {
 for (const name of ['mcp__iqx_jira__editJiraIssue', 'mcp__iqx_jira__transitionJiraIssue', 'mcp__iqx_jira__createJiraIssue', 'mcp__iqx_jira__executeWrite', 'mcp__iqx_jira__executeDestructive', 'mcp__iqx_jira__createConfluenceContent', 'mcp__iqx_jira__updateConfluenceContent', 'mcp__iqx_jira__anotherWriteTool', 'mcp__iqx_jira__getJiraIssue', 'mcp__iqx_jira__addOrEditJiraIssueComment']) {
  pi.registerTool({name, label:name, description:'Disposable local tool; never contacts MCP.', parameters:{type:'object',properties:{}}, async execute(){return {content:[{type:'text',text:'local'}],details:{}};}});
 }
}
''')
env = {k:v for k,v in os.environ.items() if not k.startswith('HERDR_') and not (k.startswith('FM_') and (k.endswith('_OVERRIDE') or k in ['FM_HOME','FM_BACKEND','FM_ROOT','FM_GATE_REFUSE_BYPASS','FM_TASK_TMP','FM_TASK_ID']))}
env.update(PI_CODING_AGENT_DIR=str(lab/'agent'), PI_OFFLINE='1', PI_TELEMETRY='0', TMPDIR=str(scratch), HOME=str(lab))
try:
    results=[]
    for scenario in ['matched','unmatched','unverified','fab','loaded-registry-match']:
        id='excl-registry-pi-ship-'+ ('matched' if scenario=='loaded-registry-match' else scenario)
        home=fixtures/id/'home'; status=home/'state'/(id+'.status')
        ext=home/'state'/(id+'.pi-ext.ts')
        status.write_text('active: real Pi validation\n')
        exclusions=subprocess.check_output(['bash','-c','. "$1/bin/fm-exclude-tools-lib.sh"; fm_exclude_tools_names "$2"','_',str(root),str(home/'config')],env=env,text=True)
        cmd=['pi','--offline','--no-mcp','--no-extensions','--no-skills','--no-prompt-templates','--no-themes','--no-context-files','--no-session','--provider','exclusion-lab','--model','lab-model','--thinking','off','--exclude-tools',exclusions,'-e',str(ext)]
        if scenario!='unverified': cmd+=['-e',str(tools)]
        if scenario=='loaded-registry-match':
            # Exercise the registry-reporting boundary with a actually loaded exact match.
            index=cmd.index('--exclude-tools'); del cmd[index:index+2]
        cmd+=['-p','Return one short confirmation without using tools.']
        requests.clear()
        run=subprocess.run(cmd,cwd=lab/'project',env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
        report=status.read_text()
        names=[tool['function']['name'] for tool in requests[-1].get('tools',[])] if requests else []
        result={'scenario':scenario,'command':cmd,'exit':run.returncode,'pi_output':run.stdout,'tools_advertised_to_local_endpoint':names,'task_status':report}
        results.append(result)
        (evidence/'real-pi-runtime.json').write_text(json.dumps(results,indent=2))
        assert run.returncode==0, run.stdout
        assert requests, 'Pi did not reach the disposable endpoint'
        if scenario=='loaded-registry-match':
            assert 'mcp__iqx_jira__editJiraIssue' in names
            assert report=='active: real Pi validation\n', report
        else:
            for name in exclusions.split(','): assert name in report, report
            assert 'unverified' in report and str(home/'config/crew-exclude-tools') in report
            if scenario in ['matched','fab']:
                for name in exclusions.split(','): assert name not in names, names
                assert 'mcp__iqx_jira__getJiraIssue' in names and 'mcp__iqx_jira__addOrEditJiraIssueComment' in names
        supervisor=subprocess.run(['bash','-c','. "$1/bin/fm-classify-lib.sh"; scan_unread_surface_lines "$2"','_',str(root),str(home/'state')],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=10)
        result['supervisor_unread_output']=supervisor.stdout
        (evidence/'real-pi-runtime.json').write_text(json.dumps(results,indent=2))
        if scenario!='loaded-registry-match': assert 'unverified' in supervisor.stdout and str(home/'config/crew-exclude-tools') in supervisor.stdout
        print('real Pi',scenario,'completed; tools:',','.join(names),'status:',report.strip())
finally:
    server.shutdown(); server.server_close()
    subprocess.run(['chmod','-R','u+w',str(lab)],check=True)
    subprocess.run(['rm','-rf',str(lab)],check=True)
