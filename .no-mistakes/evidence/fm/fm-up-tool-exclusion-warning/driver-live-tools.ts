import { appendFileSync } from "node:fs";
import { Type } from "typebox";

// Disposable load/race fixture: tools are real Pi registrations; no lifecycle
// callbacks or production handlers are mocked or called by this fixture.
export default function(pi: any) {
  const scenario = process.env.LIVE_SCENARIO;
  const log = (entry: any) => appendFileSync(process.env.LIVE_EVENTS!, JSON.stringify(entry) + "\n");
  const status = (line: string) => appendFileSync(process.env.LIVE_STATUS!, line + "\n");
  const register = (name: string) => {
    pi.registerTool({
      name, label: name, description: "Disposable tool for tool-exclusion live validation",
      parameters: Type.Object({}),
      async execute() {
        log({executed: name});
        return {content: [{type: "text", text: "Executed allowed fixture tool " + name}], details: {name}};
      },
    });
    log({registered: name});
  };
  if (scenario !== "mcp-absent") register("mcp__tracker__readIssue");
  if (scenario === "absent" || scenario === "present") register("mcp__tracker__editIssue");
  if (scenario === "absent") register("mcp__tracker__createIssue");
  let runs = 0;
  let turns = 0;
  pi.on("agent_start", () => {
    runs++;
    log({event: "agent_start", runs, tools: pi.getAllTools().map((t: any) => t.name), active: pi.getActiveTools()});
  });
  pi.on("turn_start", () => {
    turns++;
    if (runs === 1 && turns === 1 && ["present", "late"].includes(scenario!)) {
      status("done [at=1700000000]: completed fixture task before late registration");
      if (scenario === "late") register("mcp__tracker__editIssue");
      register("mcp__tracker__createIssue");
    }
  });
  pi.on("tool_execution_end", (event: any) => log({event: "tool_execution_end", ...event}));
  pi.on("agent_end", () => {
    log({event: "agent_end", runs});
    if (runs !== 1) return;
    if (scenario === "next-start") {
      status("needs-decision [key=shape]: choose a shape");
      status("resolved [key=shape]: shape chosen before next agent start");
      register("mcp__tracker__editIssue");
    }
    if (scenario === "present" || scenario === "late") {
      // A server replaces its tool registration on reconnect.
      register("mcp__tracker__editIssue");
      register("mcp__tracker__createIssue");
    }
    pi.sendUserMessage("Run the follow-up fixture turn.", { deliverAs: "followUp" });
  });
  pi.on("agent_settled", () => log({event: "agent_settled", runs, turns}));
}
