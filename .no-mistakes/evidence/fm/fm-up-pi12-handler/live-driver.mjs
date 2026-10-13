import {createServer} from 'node:http';
import {readFileSync, writeFileSync, mkdirSync, existsSync, rmSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const root=process.cwd(), work=resolve('.test-pi12');
const sdkPath=process.env.TEST_PI_SDK || resolve(work,'node_modules/@earendil-works/pi-coding-agent/dist/index.js');
const sdk=await import(pathToFileURL(sdkPath));
const {createAgentSession,DefaultResourceLoader,SettingsManager,SessionManager,ModelRuntime,createEventBus}=sdk;
const label=process.env.TEST_LABEL || 'pi12';
const home=resolve(work,label+'-home'), agentDir=resolve(work,label+'-agent');
const evidence=process.env.TEST_EVIDENCE;
assert(evidence);
const script=(name,args=[])=>{
 const out=spawnSync('bash',[resolve(root,'bin',name),...args],{env:process.env,encoding:'utf8',cwd:root});
 if(out.status!==0) throw new Error(`${name}: ${out.status} ${out.stdout} ${out.stderr}`);
 return out.stdout.trim();
};
mkdirSync(home,{recursive:true});
script('fm-lab-home.sh',['create',home]);
process.env.FM_HOME=home;
for(const key of ['FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_CONFIG_OVERRIDE','FM_DATA_OVERRIDE','FM_PROJECTS_OVERRIDE','FM_BACKEND','FM_GATE_REFUSE_BYPASS','FM_TASK_ID','HERDR_SESSION','TMUX']) delete process.env[key];
process.env.PI_CODING_AGENT_DIR=agentDir;
process.env.PI_OFFLINE='1'; process.env.PI_TELEMETRY='0';
process.env.FM_POLL='0.2'; process.env.FM_SIGNAL_GRACE='0'; process.env.FM_HEARTBEAT='999999'; process.env.FM_CHECK_INTERVAL='999999';
mkdirSync(agentDir,{recursive:true});
writeFileSync(home+'/state/.lock',`${process.pid}\n`);
// The watcher supports this home-local shell config. Restore stock lab paths
// after its arm launcher supplies overrides; no lifecycle bypass is used.
writeFileSync(home+'/config/x-mode.env','unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_CONFIG_OVERRIDE FM_DATA_OVERRIDE FM_PROJECTS_OVERRIDE\n');
const proof={version:sdk.VERSION,product:'real Pi AgentSession + tracked Firstmate extensions + real bin scripts',dependency:'disposable loopback OpenAI-compatible SSE endpoint (no live LLM or credentials)',before:[],contexts:[],requests:[],errors:[],results:[]};
let hold=false, enterAwayOnProcessing=false, cancelCustom=false;
const server=createServer(async(req,res)=>{
 let body=''; for await(const chunk of req) body+=chunk;
 const input=JSON.parse(body);
 proof.requests.push({url:req.url, messages:input.messages.map(m=>({role:m.role,content:m.content})),tools:(input.tools||[]).map(t=>t.function.name)});
 res.writeHead(200,{'Content-Type':'text/event-stream'});
 const emit=(delta,finish=null)=>res.write(`data: ${JSON.stringify({id:'lab-'+proof.requests.length,object:'chat.completion.chunk',created:Math.floor(Date.now()/1000),model:'lab',choices:[{index:0,delta,finish_reason:finish}]})}\n\n`);
 emit({role:'assistant'});
 if(hold) { req.on('close',()=>res.end()); return; }
 if((input.tools||[]).some(t=>t.function.name==='fm_branch_report') && input.messages.at(-1)?.role!=='tool') {
  emit({tool_calls:[{index:0,id:'report-'+proof.requests.length,type:'function',function:{name:'fm_branch_report',arguments:JSON.stringify({task:'fleet',verdict:'routine',summary:'Disposable heartbeat checked.'})}}]});
  emit({},'tool_calls');
 } else { emit({content:'Local endpoint completed the requested run.'}); emit({},'stop'); }
 res.end('data: [DONE]\n\n');
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
writeFileSync(agentDir+'/models.json',JSON.stringify({providers:{lab:{baseUrl:`http://127.0.0.1:${server.address().port}/v1`,api:'openai-completions',apiKey:'disposable-lab',models:[{id:'lab',name:'Disposable local endpoint',reasoning:false,input:['text'],contextWindow:100000,maxTokens:128,cost:{input:0,output:0,cacheRead:0,cacheWrite:0}}]}}}));
writeFileSync(agentDir+'/settings.json',JSON.stringify({compaction:{enabled:false},retry:{enabled:false},cacheWarming:{enabled:false}}));
const modelRuntime=await ModelRuntime.create({authPath:agentDir+'/auth.json',modelsPath:agentDir+'/models.json'});
const model=modelRuntime.getModel('lab','lab'); assert(model,'local model loaded');
const eventBus=createEventBus();
const mode=process.env.TEST_MODE || 'branch';
const paths=[process.env.TEST_EXTENSION || resolve(root,'.pi/extensions', mode==='watch'?'fm-primary-pi-watch.ts':'fm-branch-supervision.ts')];
const settingsManager=SettingsManager.inMemory({compaction:{enabled:false},retry:{enabled:false},cacheWarming:{enabled:false}});
const loader=new DefaultResourceLoader({cwd:root,agentDir,settingsManager,eventBus,noExtensions:true,noContextFiles:true,noSkills:true,noThemes:true,noPromptTemplates:true,additionalExtensionPaths:paths,systemPrompt:'Use no tools. Reply briefly.',extensionFactories:[pi=>{
 pi.on('before_agent_start',(event)=>{
  proof.before.push({messageType:event.messageType,hasPrompt:'prompt' in event,prompt:event.prompt,customType:event.message?.customType,content:event.message?.content});
  if(enterAwayOnProcessing && event.message?.customType==='fm-branch-process') {
   script('fm-afk-contract.sh',['enter','--words','Hold reports for my return.']);
  }
 });
 pi.on('context',(event,ctx)=>{
  proof.contexts.push({roles:event.messages.map(m=>m.role),customTypes:event.messages.filter(m=>m.role==='custom').map(m=>m.customType)});
  if(cancelCustom && event.messages.at(-1)?.customType==='lab-same-wake') ctx.abort();
 });
}]});
await loader.reload(); assert.equal(loader.getExtensions().errors.length,0,JSON.stringify(loader.getExtensions().errors));
let session;
const wait=async(pred,label)=>{for(let i=0;i<1000;i++){if(pred()) return; await new Promise(r=>setTimeout(r,20));} throw new Error('timeout: '+label);};
try {
 ({session}=await createAgentSession({cwd:root,agentDir,resourceLoader:loader,modelRuntime,model,settingsManager,sessionManager:SessionManager.create(root,home+'/main-sessions'),noTools:true}));
 await session.bindExtensions({onError:e=>proof.errors.push(e)});
 if(mode==='branch') {
  const captain='Please give me a fresh mini system-resource report.';
  const custom='Please give me a fresh mini system-resource report from this custom message.';
  await session.prompt(captain);
  if(!process.env.TEST_SKIP_CUSTOM) await session.sendCustomMessage({customType:'lab-custom',content:custom,display:false},{triggerTurn:true});
  writeFileSync(home+'/state/.wake-queue',`1\t1\theartbeat\theartbeat\theartbeat\n`);
  let settlement,accepted=false;
  eventBus.emit('fm-branch-supervision:dispatch',{message:'heartbeat',projects:[],heartbeat:true,eligible:true,accept(p){accepted=true;settlement=p;}});
  assert(accepted,'branch accepts a real heartbeat'); await settlement;
  const branchFile=readFileSync(home+'/state/.branch-session','utf8').trim();
  const entries=readFileSync(branchFile,'utf8').trim().split('\n').map(JSON.parse);
  const mirrors=entries.filter(e=>e.type==='custom_message'&&e.customType==='fm-main-mirror').map(e=>e.content);
  proof.results.push({scenario:'dialog mirror',mirrors});
  assert(mirrors.some(m=>m===`[captain] ${captain}`),'ordinary user request remains mirrored');
  assert(!mirrors.some(m=>m.includes(custom)),'custom never becomes captain dialog');
  if(sdk.VERSION.startsWith('1.2.')&&!process.env.TEST_SKIP_CUSTOM) assert(proof.before.some(e=>e.customType==='lab-custom'&&!e.hasPrompt));
  if(!process.env.TEST_MIRROR_ONLY) {
  enterAwayOnProcessing=sdk.VERSION.startsWith('1.2.');
  if(!enterAwayOnProcessing) script('fm-afk-contract.sh',['enter','--words','Hold reports for my return.']);
  const before=proof.requests.length;
  const captainSeq=Number(script('fm-branch-outcome.sh',['append','--task','fleet','--verdict','captain','--summary','Disposable report ready for review.']));
  await session.reload();
  await wait(()=>proof.before.some(e=>e.customType==='fm-branch-process')||!sdk.VERSION.startsWith('1.2.'),'dedicated processing opening');
  await session.waitForIdle();
  assert(existsSync(home+'/state/.afk-contract'),'away record appeared before context');
  assert.equal(proof.requests.length,before,'dedicated processing run aborted before provider request');
  const unprocessed=script('fm-branch-outcome.sh',['unprocessed']);
  assert(JSON.parse(unprocessed).seq===captainSeq,'captain outcome remains unprocessed');
  proof.results.push({scenario:enterAwayOnProcessing?'away cancels dedicated processing':'Pi 1.1 away suppresses processing presentation',providerRequestsAdded:proof.requests.length-before,unprocessed:JSON.parse(unprocessed)});
  const prior=proof.requests.length;
  await session.prompt('I am here; answer this ordinary user prompt without processing the held report.');
  assert.equal(proof.requests.length,prior+1,'away does not cancel captain prompt');
  assert(!proof.contexts.at(-1).customTypes.includes('fm-branch-process'));
  proof.results.push({scenario:'away preserves user run',response:session.getLastAssistantText()});
  }
 } else {
  hold=true;
  const running=session.prompt('Keep this run active while the local watcher receives a status update.');
  await wait(()=>proof.requests.length>0,'stream started');
  await wait(()=>existsSync(home+'/state/.last-watcher-beat'),'real watcher beacon');
  writeFileSync(home+'/state/lab.status','needs-decision: disposable watcher boundary report\n');
  await wait(()=>session.getFollowUpMessages().some(m=>m.includes('lab.status')),'real watcher wake queued');
  const wake=session.getFollowUpMessages().find(m=>m.includes('lab.status'));
  proof.results.push({scenario:'real watcher delivery',wake});
  await session.abort(); await running;
  session.clearQueue(); hold=false; cancelCustom=true;
  await session.sendCustomMessage({customType:'lab-same-wake',content:wake,display:false},{triggerTurn:true});
  cancelCustom=false;
  let handoff;
  const prior=proof.requests.length;
  await session.reload({beforeSessionStart:()=>{
   handoff=JSON.parse(readFileSync(home+'/state/extensions/pi-primary-watch/session-replacement-actionable.json','utf8'));
  }});
  assert.equal(handoff.pending.length,1,'custom message does not consume the pending wake');
  assert(handoff.pending[0].message.includes('lab.status'));
  await wait(()=>proof.requests.length>prior,'replacement replays wake');
  await session.waitForIdle();
  await wait(()=>!existsSync(home+'/state/extensions/pi-primary-watch/session-replacement-actionable.json'),'user consumption clears handoff');
  proof.results.push({scenario:'custom wake survives replacement and user consumes replay',handoff,replayedPrompt:proof.before.filter(e=>e.hasPrompt).at(-1).prompt,response:session.getLastAssistantText()});
 }
 assert.equal(proof.errors.length,0,JSON.stringify(proof.errors));
 proof.status='pass';
} catch(error) { proof.status='fail'; proof.failure=error.stack; proof.queued=session?.getFollowUpMessages(); throw error; }
finally {
 if(session){await session.abort(); await session.extensionRunner?.emit({type:'session_shutdown',reason:'quit'}); session.dispose();}
 if(mode==='watch') { try{script('fm-watch-arm.sh',['--stop']);}catch(e){proof.cleanupError=String(e);} }
 server.closeAllConnections(); await new Promise(r=>server.close(r));
 writeFileSync(evidence,JSON.stringify(proof,null,2)+'\n');
 rmSync(home,{recursive:true,force:true});rmSync(agentDir,{recursive:true,force:true});
 console.log(JSON.stringify({version:proof.version,status:proof.status,results:proof.results,errors:proof.errors,evidence},null,2));
}
