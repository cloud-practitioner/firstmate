import {createAssistantMessageEventStream} from "@earendil-works/pi-ai";
import {writeFileSync} from "node:fs";
export default function(pi) {
  let calls=0;
  pi.on("session_start",()=>writeFileSync(`${process.env.FM_HOME}/state/.lock`,`${process.pid}\n`));
  pi.registerProvider("export-proof",{baseUrl:"http://127.0.0.1/unused",apiKey:"local-input-fixture",api:"export-proof-api",models:[{id:"local",name:"Local tool-execution fixture",reasoning:false,input:["text"],cost:{input:0,output:0,cacheRead:0,cacheWrite:0},contextWindow:8192,maxTokens:128}],streamSimple(model){
    calls++;
    const stream=createAssistantMessageEventStream();
    const output={role:"assistant",content:calls===1 ? [
      {type:"toolCall",id:"live-grep",name:"grep",arguments:{pattern:"alpha",path:`${process.env.FM_HOME}/projects/probe`}},
      {type:"toolCall",id:"live-find",name:"find",arguments:{pattern:"*.txt",path:`${process.env.FM_HOME}/projects/probe`}},
      {type:"toolCall",id:"live-watch",name:"fm_watch_arm_pi",arguments:{}}
    ] : [{type:"text",text:"The real grep, find and watcher checks are complete."}],api:model.api,provider:model.provider,model:model.id,usage:{input:0,output:0,cacheRead:0,cacheWrite:0,totalTokens:0,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}},stopReason:calls===1 ? "toolUse" : "stop",timestamp:Date.now()};
    setTimeout(()=>{stream.push({type:"done",reason:output.stopReason,message:output});stream.end();},50);
    return stream;
  }});
}
