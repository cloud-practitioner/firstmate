# OpenCode 2 primary-plugin port - API verification

API compatibility findings recorded 2026-10-01 against OpenCode v2.0.21.
The port is implemented; the [adapter reference](../.agents/skills/harness-adapters/references/harness/opencode.md) and [turn-end guard](turnend-guard.md) own the current contracts.
[Runtime backend verification](verification/runtime-backends.md#opencode-2-launch-and-brief-delivery) owns the later end-to-end evidence and refresh entry points.

All facts below were exercised first-hand on v2.0.21 (`opencode run --standalone --print-logs --auto`, model `openai/gpt-5.5-fast`) unless marked as read from the installed binary or the `@opencode-ai/plugin`/`sdk` packages.

## What changed in the plugin model

OpenCode 2 rejects the v1 plugin module and requires a default export.
The load failure for the v1 shape is `PluginModule.LoadError: Plugin must export a default definition with an id and an effect or setup function.`.
A default export of `{ id, setup }` loads with no failure.

The v1 `server` entrypoint and the hooks it returned are not honored on v2.
A sentinel plugin exporting `{ id, server, setup }` showed only `setup` running: the `server` function was never invoked, and neither its `event` hook nor its `tool.execute.before` hook fired, even though the turn ran a real bash tool call.
A no-op `setup(){}` therefore makes a legacy plugin load without activating its `server` hooks; the implemented dual-export plugins install their OpenCode 2 behavior through `setup(ctx)`.
The managed Herdr plugins use the same `{ id, server, setup(){} }` shape and document the same conclusion: their `server` hooks are legacy and their live behavior runs through a separate entrypoint (`herdr-tui-session.js`, the `tui`/`setup` object).

## The v2 server-plugin context

The `setup(ctx)` context on a server plugin exposes these domains (read from the live sentinel):
`app, location, options, agent, aisdk, command, event, experimental, generate, model, provider, integration, mcp, permission, plugin, reference, rpc, skill, storage, tool, vcs, websearch, worktree, session, shell`.

Relevant members:

- `ctx.tool.hook("execute.before" | "execute.after", fn)` registers tool-lifecycle hooks.
- `ctx.event` is `{ subscribe }`; `ctx.event.subscribe({ signal, onActivity })` returns an async-iterable server-sent-event stream consumed with `for await`, the same call the built-in effect plugins use.
- `ctx.session` is `{ hook, create, get, switchAgent, switchModel, prompt, generate, command, synthetic, interrupt, update, move, wait, context }`.
- `ctx.session.hook(name, fn)` accepts only its fixed set (`context`, `compaction`, `generate`, `retry`, `title`, `model.request`, `http.request`, `http.response`); it silently accepts other names but never fires them, so it cannot stand in for the old event bus.

The SDK also exposes the matching server operations `EventSubscribe`, `SessionPrompt`, `SessionPromptAsync`, and the `Tui*` operations (`TuiShowToast`, `TuiSubmitPrompt`, `TuiAppendPrompt`, `TuiExecuteCommand`, `TuiPublish`).

## Event and follow-up surfaces

Activity, turn-end, and session-created events are reachable from a v2 server plugin through `ctx.event.subscribe`.
The live 2.0.21 stream expressed turn and activity state as `session.execution.*`, not the v1 `session.idle`/`session.status`.
The event types observed for one tool-using turn, in order, were:
`session.inbox.enqueued`, `session.execution.started`, `session.instructions.updated`, `session.inbox.delivered`, `session.usage.updated`, `session.renamed`, `session.step.started`, `session.tool.input.started`, `session.tool.input.ended`, `session.tool.called`, `shell.created`, `session.tool.progress`, `session.step.streamed`, `shell.exited`, `session.tool.success`, `session.step.ended`, `session.text.started`, `session.text.delta`, `session.text.ended`, `session.execution.succeeded`, `location.shutdown`.

The follow-up surface is `ctx.session.prompt` and the `SessionPromptAsync` operation; `session.created` also remains an event type reachable through this subscription.
The probe ended at `location.shutdown`; it does not establish child-session isolation, subscription lifetime across a long TUI session or session switches, or long-session heartbeat behavior.

## Seatbelts (cd-guard and pre-tool)

`ctx.tool.hook("execute.before", fn)` fires on the tool call, and throwing from it blocks the tool: the model reported the bash command denied with the thrown message and did not run it.
[The cd-guard](cd-guard.md#harness-wiring) and [watcher-arm seatbelt](arm-pretool-check.md#harness-wiring) own their current adapter wiring.
