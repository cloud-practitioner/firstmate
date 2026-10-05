import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";
import { spawnSync } from "node:child_process";
export default function(pi) {
  const event = (state, name) => {
    const r = spawnSync(`${process.cwd()}/bin/fm-busy-event.sh`, ["apply", `${process.env.FM_HOME}/state`, "steer", state, "--gen", process.env.PROOF_BUSY_GEN, "--source", "pi-ext", "--event", name], { encoding: "utf8" });
    if (r.status !== 0) throw new Error(r.stderr);
  };
  pi.on("agent_start", () => event("busy", "agent-start"));
  pi.on("agent_settled", () => event("idle", "agent-settled"));
  pi.registerProvider("merge-proof", {
    baseUrl: "http://127.0.0.1/unused", apiKey: "local-fixture", api: "merge-proof-api",
    models: [{ id: "hold", name: "Disposable slow-provider fixture", reasoning: false, input: ["text"], cost: {input:0, output:0, cacheRead:0, cacheWrite:0}, contextWindow:4096, maxTokens:128 }],
    streamSimple(model, context, options) {
      const stream = createAssistantMessageEventStream();
      const output = { role: "assistant", content: [], api:model.api, provider:model.provider, model:model.id, usage:{input:0,output:0,cacheRead:0,cacheWrite:0,totalTokens:0,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}}, stopReason:"stop", timestamp:Date.now() };
      void (async () => {
        await new Promise(resolve => { const t = setTimeout(resolve,60000); options?.signal?.addEventListener("abort",()=>{clearTimeout(t);resolve();},{once:true}); });
        if (options?.signal?.aborted) { output.stopReason="aborted"; stream.push({type:"error", reason:"aborted", error:output}); }
        else {output.content=[{type:"text",text:"Slow provider completed."}];stream.push({type:"done",reason:"stop",message:output});}
        stream.end();
      })();
      return stream;
    }
  });
}
