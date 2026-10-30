// Firstmate semantic busy-state events + turn-end notification; written by
// fm-spawn under the contract owned by bin/fm-busy-lib.sh.
// Semantic state: "agent_start" -> busy when a low-level agent run begins;
// "agent_settled" -> idle only when ctx.isIdle() confirms Pi will not
// continue automatically - auto-retries, auto-compaction retries, tool
// loops, and queued continuations all keep the run un-settled, and a settle
// that raced another extension's fresh run keeps state busy via isIdle().
// "turn_end" fires at every inner turn boundary (one LLM response plus its
// tool calls) and stays a wake NOTIFICATION touch for the watcher, never
// current-state truth.
import { execFile } from "node:child_process";
import { appendFileSync } from "node:fs";
const notifyTurnEnd = true;
const excludeTools = "mcp__tracker__editIssue,mcp__tracker__createIssue".split(",").filter(Boolean);
const excludeFile = "/home/node/.no-mistakes/worktrees/5e28e613310e/01M65MFBQHY7METR56JHMH28BV/.test-phase/tmp/fm-spawn-dispatch-profile.IFHVsY/excl-registry-pi-scout-reconnect/home/config/crew-exclude-tools";
const statusFile = "/home/node/.no-mistakes/worktrees/5e28e613310e/01M65MFBQHY7METR56JHMH28BV/.test-phase/tmp/fm-spawn-dispatch-profile.IFHVsY/excl-registry-pi-scout-reconnect/home/state/excl-registry-pi-scout-reconnect.status";
const busyEvent = (state: string, event: string) =>
  new Promise<void>((resolve) => {
    execFile("/home/node/.no-mistakes/worktrees/5e28e613310e/01M65MFBQHY7METR56JHMH28BV/bin/fm-busy-event.sh", [
      "apply", "/home/node/.no-mistakes/worktrees/5e28e613310e/01M65MFBQHY7METR56JHMH28BV/.test-phase/tmp/fm-spawn-dispatch-profile.IFHVsY/excl-registry-pi-scout-reconnect/home/state", "excl-registry-pi-scout-reconnect", state,
      "--gen", "g1793339614.2969251.4687", "--source", "pi-ext", "--event", event,
    ], () => resolve());
  });
export default function (pi: any) {
  // Pi removes excluded names from the registry getAllTools() reads, so a
  // correctly excluded name is always absent and absence is never reported.
  // Only a listed name that IS registered is a real exclusion failure.
  const warned = new Set<string>();
  const checkExclusions = () => {
    if (!excludeTools.length) return;
    // Verify only this worker's registry, never connect servers from Firstmate.
    let loaded: string[];
    try {
      loaded = pi.getAllTools().map((tool: any) => String(tool.name));
    } catch {
      return;
    }
    const present = excludeTools.filter((name) => !warned.has(name) && loaded.includes(name));
    if (present.length) {
      appendFileSync(statusFile, "note [state=none] [at=" + Math.floor(Date.now() / 1000) + "]: warning: " + excludeFile
        + " exclusion not in effect: these listed tools are still present in the worker's tool registry: "
        + present.join(", ") + "\n");
      for (const name of present) warned.add(name);
    }
  };
  // Backstop: Pi routes codemode's nested calls through tool_call as well.
  pi.on("tool_call", (event: any) => {
    if (event && excludeTools.includes(event.toolName)) {
      return { block: true, reason: event.toolName + " is excluded by config/crew-exclude-tools" };
    }
  });
  pi.on("agent_start", async () => {
    await busyEvent("busy", "agent-start");
    checkExclusions();
  });
  pi.on("agent_settled", (_event: any, ctx: any) => {
    if (ctx && typeof ctx.isIdle === "function" && !ctx.isIdle()) return;
    return busyEvent("idle", "agent-settled");
  });
  pi.on("turn_end", () => {
    if (notifyTurnEnd) execFile("touch", ["/home/node/.no-mistakes/worktrees/5e28e613310e/01M65MFBQHY7METR56JHMH28BV/.test-phase/tmp/fm-spawn-dispatch-profile.IFHVsY/excl-registry-pi-scout-reconnect/home/state/excl-registry-pi-scout-reconnect.turn-ended"]);
    checkExclusions();
  });
  // A native harness can make progress inside one Pi turn. This separate
  // marker prevents false wedge alarms without fabricating a completed turn.
  let lastProgress = 0;
  pi.events?.on?.("codex-native:progress", () => {
    const now = Date.now();
    if (now - lastProgress < 1000) return;
    lastProgress = now;
    execFile("/home/node/.no-mistakes/worktrees/5e28e613310e/01M65MFBQHY7METR56JHMH28BV/bin/fm-busy-event.sh", [
      "progress", "/home/node/.no-mistakes/worktrees/5e28e613310e/01M65MFBQHY7METR56JHMH28BV/.test-phase/tmp/fm-spawn-dispatch-profile.IFHVsY/excl-registry-pi-scout-reconnect/home/state", "excl-registry-pi-scout-reconnect", "--gen", "g1793339614.2969251.4687",
    ]);
  });
}
