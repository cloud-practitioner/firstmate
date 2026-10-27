import os, sys, json, time, subprocess, threading, pathlib, re, shutil, http.server
ROOT=pathlib.Path.cwd(); LAB=ROOT/'.l'; EV=pathlib.Path('/home/node/.no-mistakes/evidence/01M5XNA6EXS99GEKKQTBA3Q4G9')
TMUX=str(ROOT/'.test-rearm/deps/tmux-3.5a/tmux'); report=[]; requests=[]; release_all=threading.Event(); stop=threading.Event()
def note(s):
 print(s,flush=True); report.append(s)
def wait(pred,label,seconds=40):
 end=time.time()+seconds
 while time.time()<end:
  if pred(): return
  time.sleep(.15)
 raise AssertionError('timeout: '+label)
class Model(http.server.BaseHTTPRequestHandler):
 def log_message(self,*a): pass
 def do_POST(self):
  body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  n=len(requests)+1; requests.append({'n':n,'path':self.path,'messages':body.get('messages',[])})
  (EV/'model-requests.json').write_text(json.dumps(requests,indent=2))
  self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.send_header('Cache-Control','no-cache'); self.end_headers()
  def frame(delta,finish=None):
   data={'id':f'lab-{n}','object':'chat.completion.chunk','created':int(time.time()),'model':'stream','choices':[{'index':0,'delta':delta,'finish_reason':finish}]}
   self.wfile.write(('data: '+json.dumps(data)+'\n\n').encode()); self.wfile.flush()
  try:
   frame({'role':'assistant','content':f'LAB STREAM {n}: holding the real Pi turn while watcher results arrive. '})
   while not release_all.is_set() and not stop.is_set():
    self.wfile.write(b': waiting\n\n'); self.wfile.flush(); time.sleep(.2)
   frame({'content':'Complete.'}); frame({},'stop'); self.wfile.write(b'data: [DONE]\n\n'); self.wfile.flush()
  except (BrokenPipeError,ConnectionResetError): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Model); threading.Thread(target=server.serve_forever,daemon=True).start()
env=os.environ.copy()
for k in list(env):
 if k.startswith('FM_') or k in ['TMUX','TMUX_PANE','HERDR_ENV','HERDR_SESSION','HERDR_SOCKET_PATH','HERDR_PANE_ID','HERDR_TAB_ID','HERDR_WORKSPACE_ID','NO_MISTAKES_GATE','TASKS_AXI_FILE','TASKS_AXI_BACKEND']:
  env.pop(k,None)
env.update({'PATH':str(pathlib.Path(TMUX).parent)+':'+os.environ['PATH'],'FM_HOME':str(LAB),'HOME':str(LAB/'home'),'PI_CODING_AGENT_DIR':str(LAB/'pi'),'TMUX_TMPDIR':str(LAB/'tmux'),'TMPDIR':str(LAB/'tmp'),'XDG_CONFIG_HOME':str(LAB/'home/.config'),'XDG_STATE_HOME':str(LAB/'home/.local/state'),'XDG_CACHE_HOME':str(LAB/'home/.cache'),'XDG_DATA_HOME':str(LAB/'home/.local/share'),'PI_OFFLINE':'1','PI_TELEMETRY':'0','FM_PROCEVENT_CLAIM_ROOT':str(LAB/'claims'),'FM_POLL':'1','FM_SIGNAL_GRACE':'0','FM_CHECK_INTERVAL':'999999','FM_HEARTBEAT':'999999','FM_WATCH_EXTENSION_LOG_KEEP_LINES':'200','TERM':'xterm-256color'})
def run(args,check=True,timeout=30):
 p=subprocess.run([str(x) for x in args],env=env,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout)
 if check and p.returncode: raise RuntimeError(f'{args}: {p.returncode}\n{p.stdout}\n{p.stderr}')
 return p
def tm(*args,check=True): return run([TMUX,'-L','fm-lab',*args],check)
def pe(*args):
 p=run([ROOT/'bin/fm-procevent.sh',*args]); note('$ fm-procevent.sh '+' '.join(str(x) for x in args)+'\n'+p.stdout.strip()); return p
state=LAB/'state'
def read(p):
 try: return p.read_text()
 except FileNotFoundError: return ''
def queue(): return [r.split('\t') for r in read(state/'.wake-queue').splitlines() if r]
def keyrows(key): return [r for r in queue() if r[3]==key]
def cycles(): return read(state/'.watch-cycle-exits.log').splitlines()
def observed(): return [json.loads(l) for l in read(LAB/'observed.jsonl').splitlines()]
def users():
 return [''.join(b.get('text','') for b in e['content']) if isinstance(e['content'],list) else e['content'] for e in observed() if e['type']=='user']
def captured(sid):
 pe('register','lavish',sid,'--','/bin/sh','-c','printf "session:\\n  file: /lab-board.html\\n  status: feedback\\n  session_ended: true\\n  ended_by: user\\nfeedback[1]{text}:\\n  ship it\\n"')
 pe('reconcile')
 wait(lambda:keyrows(f'procevent:{sid}:1'),f'capture {sid}')
 wait(lambda:not (LAB/f'claims/{sid}.claim').exists(),f'claim released {sid}')
 pe('retire',sid)
def ack():
 p=run([ROOT/'bin/fm-wake-drain.sh']); note('$ fm-wake-drain.sh\n'+p.stdout+p.stderr)
 m=re.search(r'--ack-through ([0-9]+) --recovery-generation ([A-Za-z0-9._-]+)',p.stderr)
 assert m, p.stderr
 p=run([ROOT/'bin/fm-wake-drain.sh','--ack-through',m[1],'--recovery-generation',m[2]])
 note('$ fm-wake-drain.sh --ack-through '+m[1]+' --recovery-generation '+m[2]+'\n'+p.stdout+p.stderr)
def append(key):
 n=len(cycles())
 p=run(['bash','-c','. bin/fm-wake-lib.sh; fm_wake_append check "$1" "check: independently queued lab event"','bash',key])
 wait(lambda:len(cycles())>n,'watcher closes for '+key)
 time.sleep(2)
 note(f'Independent queue append {key}: watcher cycles={len(cycles())}')
def capture(name):
 out=tm('capture-pane','-p','-t','primary','-S','-2000',check=False).stdout
 (EV/(name+'.txt')).write_text(out); return out
try:
 assert not LAB.exists(),'refusing to adopt .l'
 run([ROOT/'bin/fm-lab-home.sh','create',LAB])
 for d in ['tmux','tmp','home','pi','sessions','claims']: (LAB/d).mkdir(parents=True,exist_ok=True)
 (LAB/'config/supervision-host').touch()
 (LAB/'pi/models.json').write_text(json.dumps({'providers':{'lab':{'baseUrl':f'http://127.0.0.1:{server.server_port}/v1','api':'openai-completions','apiKey':'disposable-local-endpoint','models':[{'id':'stream','name':'Disposable streaming endpoint','reasoning':False,'contextWindow':128000,'maxTokens':1000}]}}}))
 (LAB/'pi/settings.json').write_text(json.dumps({'followUpMode':'one-at-a-time','autoCompaction':False,'quietStartup':True,'retry':{'enabled':False}}))
 launch=['pi','--offline','--no-extensions','--no-mcp','--no-skills','--no-prompt-templates','--no-context-files','--no-themes','--approve','-e',str(ROOT/'.test-rearm/observe.ts'),'-e',str(ROOT/'.pi/extensions/fm-primary-pi-watch.ts'),'--provider','lab','--model','stream','--thinking','off','--session-dir',str(LAB/'sessions'),'--system-prompt','Isolated live test. Respond only to the local endpoint.']
 note('Launch real Pi '+run(['pi','--version']).stdout.strip()+' on private tmux 3.5a, 120x40; isolated FM_HOME and Pi configuration; local streaming provider dependency (no login or external model).')
 tm('new-session','-d','-s','primary','-x','120','-y','40','-c',str(ROOT),'-e','FM_HOME='+str(LAB),*launch)
 wait(lambda:read(LAB/'observed.jsonl'),'real Pi session_start',60)
 wait(lambda:(state/'.watch.lock/pid').exists(),'real watcher start',60)
 tm('send-keys','-t','primary','Hold this main turn while lab process results arrive.','Enter')
 wait(lambda:len(requests)==1,'real Pi local provider request',60)
 captured('delivery-src')
 wait(lambda:len(cycles())>0 and 'process-event result captured' in capture('pi-startup-check'),'initial process-event watcher close',60)
 time.sleep(3)
 initial=read(state/'.wake-queue'); marker=read(state/'.watcher-down'); count=len(cycles())
 for _ in range(5): pe('reconcile')
 time.sleep(15)
 assert read(state/'.wake-queue')==initial,'queued copy changed during repeated polls'
 assert len(keyrows('procevent:delivery-src:1'))==1
 assert read(state/'.watcher-down')==marker,'recovery generation changed for identical queued result'
 assert len(cycles())==count,'unhandled result closed successor again'
 wp=int(read(state/'.watch.lock/pid').strip()); os.kill(wp,0)
 note('PASS queued result: one durable row; queue bytes and recovery generation unchanged across five explicit reconciles plus 15 seconds of one-second watcher polls; successor pid '+str(wp)+' still alive.')
 (EV/'queued-result.tsv').write_text(initial); (EV/'queued-recovery-marker.txt').write_text(marker)
 capture('pi-unread-initial')
 oldseq=int(keyrows('procevent:delivery-src:1')[0][1]); ack()
 wait(lambda:len(keyrows('procevent:delivery-src:1'))==1 and int(keyrows('procevent:delivery-src:1')[0][1])>oldseq,'republication after drain')
 time.sleep(3); q=read(state/'.wake-queue'); c=len(cycles()); mark=read(state/'.watcher-down'); time.sleep(10)
 assert read(state/'.wake-queue')==q and read(state/'.watcher-down')==mark and len(cycles())==c,'reannouncement did not settle'
 note('PASS acknowledged-but-unhandled: next watcher poll republished exactly one row with a new sequence; 10-second quiet period did not change queue, recovery marker or cycle count.')
 pe('handled','delivery-src','1'); ack(); time.sleep(5)
 assert not keyrows('procevent:delivery-src:1'),'handled result reappeared'
 note('PASS handled: explicit durable acknowledgement followed by drain left no copy after five more watcher polls.')
 # Force real recovery episodes independently of the procevent guard to exercise Pi coalescing.
 for i in range(4): append('independent-'+str(i))
 before_distinct=len(cycles())
 captured('different-src')
 wait(lambda:len(cycles())>before_distinct,'distinct captured wake',60)
 time.sleep(3)
 held=capture('pi-unread-coalesced')
 note('While first real Pi stream remains held, independently forced four further actionable recovery closes and a different process-event result. User message_start count before release='+str(len(users())))
 assert len(users())==1,'main consumed a follow-up before the streaming hold ended'
 pe('handled','different-src','1'); ack()
 release_all.set()
 wait(lambda:sum('FIRSTMATE WATCHER WAKE:' in u for u in users())>=3,'real Pi consumes queued wakes',45)
 time.sleep(4)
 wakes=[u for u in users() if 'FIRSTMATE WATCHER WAKE:' in u]
 recovery=[u for u in wakes if 'FIRSTMATE WATCHER WAKE: check: rearm-resurface\n' in u]
 assert len(recovery)==1, f'identical unread recovery wakes consumed {len(recovery)} times: {wakes}'
 assert len([u for u in wakes if 'process-event result captured' in u and 'delivery-src' in u])==1,wakes
 assert len([u for u in wakes if 'process-event result captured' in u and 'different-src' in u])==1,wakes
 note('PASS real Pi follow-ups: consumed exactly one initial process-result wake, one rearm-resurface wake despite four additional identical unread closes, and one distinct process-result wake. No mock ExtensionAPI was used.')
 # Start a second actual stream, and prove that consumption releases the coalescing key.
 release_all.clear(); nreq=len(requests)
 tm('send-keys','-t','primary','Hold another turn to verify a consumed wake can be sent again.','Enter')
 wait(lambda:len(requests)>nreq,'second held primary stream')
 append('after-consumption')
 capture('pi-resend-after-consumption')
 ack(); release_all.set()
 wait(lambda:len([u for u in users() if 'FIRSTMATE WATCHER WAKE: check: rearm-resurface\n' in u])==2,'same wake accepted after consumption',45)
 time.sleep(3)
 note('PASS consumption boundary: a later identical rearm-resurface wake was delivered again after Pi consumed its earlier copy.')
 capture('pi-final')
 (EV/'pi-user-messages.json').write_text(json.dumps(users(),indent=2,ensure_ascii=False))
 (EV/'pi-observed.jsonl').write_text(read(LAB/'observed.jsonl'))
 (EV/'watch-cycle-exits.log').write_text(read(state/'.watch-cycle-exits.log'))
 (EV/'watch-extension.log').write_text(read(state/'.watch-extension.log'))
 (EV/'final-queue.tsv').write_text(read(state/'.wake-queue'))
 note('All live assertions passed.')
except Exception as e:
 note('ERROR '+repr(e))
 if LAB.exists():
  capture('pi-error')
  (EV/'error-observed.jsonl').write_text(read(LAB/'observed.jsonl'))
  (EV/'error-watch-cycles.log').write_text(read(state/'.watch-cycle-exits.log'))
  (EV/'error-watch-extension.log').write_text(read(state/'.watch-extension.log'))
  (EV/'error-queue.tsv').write_text(read(state/'.wake-queue'))
 raise
finally:
 release_all.set(); stop.set()
 if LAB.exists():
  run([ROOT/'bin/fm-procevent.sh','sweep-home'],check=False)
  tm('kill-server',check=False)
  time.sleep(1)
  # The extension owns the arm's stop on process exit; ensure this lab alone has no watcher left.
  run([ROOT/'bin/fm-watch-arm.sh','--stop'],check=False)
  shutil.rmtree(LAB)
 server.shutdown(); server.server_close()
 note('Teardown: killed only private fm-lab tmux server, swept only lab process-event home, stopped lab watcher, removed disposable lab home.')
 (EV/'live-transcript.log').write_text('\n'.join(report)+'\n')
