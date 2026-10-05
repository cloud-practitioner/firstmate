import os, subprocess, pathlib, json, time, threading, http.server, shlex
ROOT=pathlib.Path.cwd(); E=pathlib.Path('/home/node/.no-mistakes/evidence/01M472X02W8XV0139WP154XWSR'); LAB=ROOT/'.l'
TMUX=ROOT/'.validation/tools/tmux-pkg/usr/bin/tmux'; PI=ROOT/'.validation/pi101/node_modules/@earendil-works/pi-coding-agent/dist/cli.js'
base=dict(os.environ); base['LD_LIBRARY_PATH']=str(ROOT/'.validation/tools/tmux-pkg/usr/lib/x86_64-linux-gnu'); base['PATH']=str(TMUX.parent)+':'+str(ROOT/'.validation/pi101/node_modules/.bin')+':'+base['PATH']
for key in list(base):
 if key.startswith('FM_') and (key.endswith('_OVERRIDE') or key in ['FM_GATE_REFUSE_BYPASS']): base.pop(key,None)
base.pop('NO_MISTAKES_GATE',None)
requests=[]
class API(http.server.BaseHTTPRequestHandler):
 def log_message(self,*a): pass
 def do_POST(self):
  body=json.loads(self.rfile.read(int(self.headers['Content-Length']))); n=sum(r['path']==self.path for r in requests)+1; requests.append({'path':self.path,'number':n,'messages':body.get('messages')})
  texts=['The requested result is complete and verified.','The example task needs a decision.','The example task needs a decision.']
  text=texts[min(n-1,2)] if '/retry/' in self.path else 'The watcher wake was observed.'
  last=body.get('messages',[])[-1].get('content','') if body.get('messages') else ''
  if any('A new user question' in str(m.get('content','')) for m in body.get('messages',[])): text='The new user answer.'
  if '/busy/' in self.path: text='Working on the isolated inbox scenario.'
  self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.end_headers()
  def chunk(delta,finish=None): return ('data: '+json.dumps({'id':'lab-'+str(n),'object':'chat.completion.chunk','created':1,'model':'lab-model','choices':[{'index':0,'delta':delta,'finish_reason':finish}]})+'\n\n').encode()
  try:
   self.wfile.write(chunk({'role':'assistant','content':text})); self.wfile.flush()
   if '/busy/' in self.path: time.sleep(35)
   self.wfile.write(chunk({},'stop')+b'data: [DONE]\n\n'); self.wfile.flush()
  except (BrokenPipeError,ConnectionResetError): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),API); threading.Thread(target=server.serve_forever,daemon=True).start(); port=server.server_port
transcript=[]
def run(args,env=None,check=True):
 r=subprocess.run([str(a) for a in args],env=env or base,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 transcript.append('$ '+shlex.join([str(a) for a in args])+'\n'+r.stdout+'[exit '+str(r.returncode)+']')
 if check and r.returncode: raise RuntimeError(r.stdout)
 return r

def tm(*args,check=True): return run([TMUX,'-L','fm-lab',*args],env,check)
def wait(pred,label,seconds=35):
 end=time.time()+seconds
 while time.time()<end:
  if pred(): return
  time.sleep(.15)
 raise RuntimeError('timeout: '+label+'\n'+tm('capture-pane','-p','-t','primary',check=False).stdout)
def capture(name):
 text=tm('capture-pane','-p','-t','primary','-S','-150').stdout; (E/(name+'.txt')).write_text(text)
 # Reviewer-visible terminal rendering of the actual pane, not a source snapshot.
 import html
 (E/(name+'.html')).write_text('<!doctype html><meta charset="utf-8"><title>'+name+'</title><style>body{background:#15171a;color:#eee;font:16px monospace}pre{white-space:pre-wrap;padding:24px}</style><pre>'+html.escape(text)+'</pre>')
def send(text): tm('send-keys','-t','primary','-l',text); tm('send-keys','-t','primary','Enter')
def create(mode):
 global env
 assert not LAB.exists()
 run([ROOT/'bin/fm-lab-home.sh','create',LAB]); (LAB/'tmux').mkdir(); (LAB/'agent').mkdir(); (LAB/'sessions').mkdir()
 env=dict(base,FM_HOME=str(LAB),PI_CODING_AGENT_DIR=str(LAB/'agent'),TMUX_TMPDIR=str(LAB/'tmux'),FM_POLL='1',FM_CHECK_INTERVAL='999999',FM_HEARTBEAT='999999',FM_SIGNAL_GRACE='1')
 (LAB/'agent/models.json').write_text(json.dumps({'providers':{'lab-local':{'baseUrl':f'http://127.0.0.1:{port}/{mode}/v1','api':'openai-completions','apiKey':'disposable-local-fixture','models':[{'id':'lab-model','name':'Local scenario data','contextWindow':8192,'maxTokens':512}]}}}))
 (LAB/'agent/settings.json').write_text(json.dumps({'quietStartup':True,'defaultProvider':'lab-local','defaultModel':'lab-model','thinkingLevel':'off'}))
 (LAB/'config/calm').write_text('off\n'); (LAB/'config/pi-supervision-branch').write_text('on\n' if mode=='retry' else 'off\n')
 if mode=='watch':
  # Keep the extension's redundant path overrides from defeating the lab marker.
  # This is only an environment normalizer: it executes the real product arm.
  arm=LAB/'arm-stock-env.sh'
  arm.write_text('#!/bin/bash\nunset FM_ROOT_OVERRIDE FM_CONFIG_OVERRIDE\nexec "'+str(ROOT/'bin/fm-watch-arm.sh')+'" "$@"\n'); arm.chmod(0o755)
  env['FM_WATCH_ARM_SCRIPT']=str(arm)
 env['FM_BUSY_GEN']=run([ROOT/'bin/fm-busy-event.sh','arm',LAB/'state','inbox'],env).stdout.strip()
 probe=LAB/'probe.ts' 
 probe.write_text('''import { execFileSync } from "node:child_process";
import { writeFileSync, appendFileSync } from "node:fs";
export default function(pi:any){
 const script=(name:string,...args:string[])=>execFileSync(process.cwd()+"/bin/"+name,args,{encoding:"utf8",env:process.env});
 pi.on("session_start",()=>{try {writeFileSync(process.env.FM_HOME+"/lock-result",script("fm-lock.sh"));}catch(e){writeFileSync(process.env.FM_HOME+"/lock-error",String(e));}});
 pi.on("agent_start",()=>script("fm-busy-event.sh","apply",process.env.FM_HOME+"/state","inbox","busy","--gen",process.env.FM_BUSY_GEN,"--source","pi-ext","--event","agent-start"));
 pi.on("agent_settled",()=>appendFileSync(process.env.FM_HOME+"/settled","settled\\n"));
 pi.registerCommand("lab-retry",{description:"Seed a disposable outcome and start a real model turn",handler:async()=>{script("fm-branch-outcome.sh","processed-init");script("fm-branch-outcome.sh","append","--task","example","--verdict","captain","--summary","A decision is needed");pi.sendUserMessage("Finish the requested work.");}});
 pi.registerCommand("lab-watch",{description:"Arm the real product watcher",handler:async()=>{pi.events.emit("lab-arm",{});}});
}
''')
 exts=[ROOT/'.pi/extensions/fm-branch-supervision.ts',ROOT/'.pi/extensions/fm-primary-pi-watch.ts',probe]
 cmd=['node',PI,'--offline','--approve','--no-extensions','--no-context-files','--no-skills','--no-prompt-templates','--no-builtin-tools','--session-dir',LAB/'sessions','--provider','lab-local','--model','lab-model','--thinking','off']
 for ext in exts: cmd+=['-e',ext]
 tm('new-session','-d','-s','primary','-x','120','-y','40','-c',ROOT,'-e','FM_HOME='+str(LAB),shlex.join([str(a) for a in cmd]))
 wait(lambda:(LAB/'lock-result').exists() or (LAB/'lock-error').exists(),'primary session lock')
 if (LAB/'lock-error').exists(): raise RuntimeError((LAB/'lock-error').read_text())
 transcript.append('PRIMARY LOCK: '+(LAB/'lock-result').read_text())
def dispose():
 if LAB.exists():
  tm('kill-server',check=False)
  # Stop only the watcher bound to this disposable home.
  run([ROOT/'bin/fm-watch-arm.sh','--stop'],env,False)
  import shutil; shutil.rmtree(LAB)
watcher=None
try:
 create('busy'); tm('rename-window','-t','primary','fm-inbox')
 env['TMUX']=tm('display-message','-p','-t','primary','#{socket_path},#{pid},0').stdout.strip()
 (LAB/'state/inbox.meta').write_text('window=primary:fm-inbox\nendpoint_task_id=inbox\nbackend=tmux\nharness=pi\nproject='+str(LAB/'projects')+'\nworktree='+str(LAB/'projects')+'\nkind=ship\nmode=local-only\nspawn_gen=busy-live\n')
 send('Keep working on the isolated inbox scenario.')
 wait(lambda:(LAB/'state/inbox.busy-state').exists() and 'busy' in (LAB/'state/inbox.busy-state').read_text(),'real Pi agent-start busy event')
 capture('pi-busy-before')
 env['FM_TASK_INBOX_GRACE_SECS']='1'; env['FM_TASK_INBOX_BUSY_MAX']='2'
 record=run(['bash','-c','. "$1"; fm_task_inbox_write "$2" inbox "Preserve this instruction until handled."','_',ROOT/'bin/fm-task-inbox-lib.sh',LAB/'state'],env).stdout.strip()
 time.sleep(2)
 out=LAB/'watch.out'; f=out.open('w')
 watcher=subprocess.Popen([str(ROOT/'bin/fm-watch.sh')],env=env,stdout=f,stderr=subprocess.STDOUT)
 wait(lambda:out.exists() and 'stuck-busy after 2' in out.read_text(),'live busy-budget escalation',25)
 watcher.wait(timeout=4); f.close()
 transcript.append('WATCHER OUTPUT:\n'+out.read_text())
 assert pathlib.Path(record).exists(),'durable record was consumed'
 transcript.append('DURABLE BUSY STATE: '+(LAB/'state/inbox.inbox/.busy-state').read_text())
 transcript.append('DURABLE WAKE QUEUE: '+(LAB/'state/.wake-queue').read_text())
 capture('pi-busy-after')
 assert 'Firstmate operational input waiting' not in tm('capture-pane','-p','-t','primary').stdout
 # A restarted watcher must not issue the same escalation again.
 f=out.open('w'); watcher=subprocess.Popen([str(ROOT/'bin/fm-watch.sh')],env=env,stdout=f,stderr=subprocess.STDOUT); time.sleep(3); watcher.terminate(); watcher.wait(timeout=5); f.close()
 assert 'stuck-busy' not in out.read_text(),out.read_text()
 transcript.append('RESTARTED WATCHER OUTPUT: '+out.read_text())
 (E/'busy-inbox-live.log').write_text('\n\n'.join(transcript)); print('LIVE_BUSY_OK')
finally:
 if watcher and watcher.poll() is None: watcher.terminate(); watcher.wait(timeout=5)
 dispose(); server.shutdown(); (E/'busy-inbox-live.log').write_text('\n\n'.join(transcript))
