import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";
import { appendFileSync, writeFileSync } from "node:fs";
export default function(pi) {
  pi.on("session_start",()=>writeFileSync(`${process.env.FM_HOME}/state/.lock`, `${process.pid}\n`));
  pi.registerProvider("watch-proof", {
    baseUrl:"http://127.0.0.1/unused",apiKey:"disposable-data-feed",api:"watch-proof-api",
    models:[{id:"quick",name:"Local watcher proof provider",reasoning:false,input:["text"],cost:{input:0,output:0,cacheRead:0,cacheWrite:0},contextWindow:8192,maxTokens:128}],
    streamSimple(model,context,options) {
      appendFileSync(`${process.env.FM_HOME}/provider-inputs.jsonl`,JSON.stringify(context.messages)+"\n");
      const stream=createAssistantMessageEventStream();
      const output={role:"assistant",content:[{type:"text",text:"Watcher notification handling complete."}],api:model.api,provider:model.provider,model:model.id,usage:{input:0,output:0,cacheRead:0,cacheWrite:0,totalTokens:0,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}},stopReason:"stop",timestamp:Date.now()};
      setTimeout(()=>{stream.push({type:"done",reason:"stop",message:output});stream.end();},100);
      return stream;
    }
  });
}
