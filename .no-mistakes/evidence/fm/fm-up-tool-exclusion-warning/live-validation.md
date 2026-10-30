# Worker tool-exclusion live validation

Target: `5caceb07322029df64961a140763e404a45d0f6a`  
Base: `05196e30ead54796dfbe986db61abe9d8df9e3d2`

## Result

The focused regressions and all live scenarios passed after disposable-driver setup corrections. No product fix was needed. No lint, static-analysis, full-suite, publication, PR, or CI phase was run.

## Live scenarios and product evidence

| Scenario | Observed result | Evidence |
| --- | --- | --- |
| Launch a worker with correctly excluded tools | Real Pi removed both listed tools from its registry and appended no warning across two agent runs. An unlisted tool executed. | [Pi registry/events](pi-absent-events.jsonl), [status file](pi-absent-status.log) |
| Connect an MCP server after the first agent start | A real disposable stdio MCP server delayed its tools/list response by 500 ms. First agent_start had no MCP tools; the second had only readIssue. Native Pi exclusions kept editIssue/createIssue absent, while a codemode call to the real server's readIssue succeeded. No false warning was appended. | [MCP wire requests/responses](pi-mcp-server.jsonl), [Pi events](pi-mcp-absent-events.jsonl), [status](pi-mcp-absent-status.log) |
| Detect an exclusion failure already present at agent start | editIssue was genuinely registered at first agent_start and warned once; createIssue was registered later and warned separately at turn end. Re-registering both before a second agent run caused no repeated warning. | [Events](pi-present-events.jsonl), [actual warning lines](pi-present-status.log) |
| Detect tools that register during a turn | The first agent_start registry contained neither excluded tool. Both registered during turn_start, after the initial check; turn_end appended one warning naming both. The warning followed a done declaration without replaying it. Reconnection plus a second agent run produced no duplicate. | [Events](pi-late-events.jsonl), [status](pi-late-status.log) |
| Recheck on the next agent start | A tool registered at first agent_end, after the final turn_end. The next agent_start detected it. The warning followed a resolved decision; it did not replay the decision opener. | [Events](pi-next-start-events.jsonl), [status](pi-next-start-status.log) |
| Attempt direct and codemode bypasses | A direct editIssue call and a nested codemode createIssue call both returned the production exclusion reason. Neither tool executed. The unlisted readIssue executed successfully. | [Real Pi HTML transcript](pi-late-tools.html), [nested/direct execution events](pi-late-events.jsonl) |
| Refuse impossible MCP server spelling, but accept punctuation in the tool part | Public fm-spawn rejected `mcp__iqx-jira__editJiraIssue`, `mcp__my.srv__tool`, and `mcp__a-b`, with sanitized suggestions, before creating task metadata or a worktree pool. `mcp__srv__tool-x.v2` then launched through real Herdr, real Treehouse, and real Pi and reached a disposable model endpoint with no exclusion warning. | [Refusals](spawn-invalid-entries.json), [spawn command transcript](spawn-live-commands.json), [metadata](spawn-valid-meta.txt), [actual terminal output](spawn-valid-pane.txt), [warning-free status](spawn-valid-status.txt) |
| Read worker state after late warning notes | Against a private live Herdr/Pi endpoint, crew-state before/after results were identical for done, failed, working, paused, blocked, needs-decision, captain-held, resolved, ordinary note, and no prior event. Voice, fleet snapshot, inbox, and bearings were driven through their real CLI interfaces with 210 appended warnings. Ordinary notes remained ordinary notes; a warning-only log had no event. | [Structured reader outputs](status-readers-live.json), [commands and raw responses](status-readers-commands.json) |
| Surface warnings without replaying completed work | Within the wake backstop's documented 64-KiB snapshot boundary, the first real wake drain surfaced both the original completion and the warning. A subsequent appended warning remained visible, without another completion backstop. | [First drain](wake-first-drain.txt), [second drain](wake-second-drain.txt) |

## Isolation and what was real

- Pi 1.4.0 was the installed real CLI. Its registry, lifecycle dispatcher, tool authorization, built-in codemode, MCP client, and HTML exporter were not mocked.
- The worker extension used for adversarial lifecycle checks was **unmodified generated fm-spawn output**: [generated extension](generated-worker-extension.ts). Generation used the existing captured-backend spawn fixture; its production handler was subsequently loaded into real Pi, never invoked through fake lifecycle callbacks in the live checks.
- Healthy cases supplied the real `--exclude-tools` flag. Adversarial presence cases deliberately omitted Pi's native flag while retaining the generated extension's configured list, making exclusions genuinely ineffective and exercising the production warning/backstop behavior.
- A local deterministic OpenAI-compatible endpoint supplied tool-call inputs and final responses. It stood in for model output, not for Pi or Firstmate. A separate disposable MCP server was driven over its actual stdio protocol. No operator credentials, shared services, or login stores were used.
- The successful spawn scenario additionally exercised the entire real `fm-spawn -> Herdr -> Treehouse -> Pi` launch. Its trust dialog was answered with **Trust (this session only)**.
- Herdr work used named non-default `fm-lab-*` sessions solely through `bin/fm-herdr-lab.sh`. The helper attached a 40x120 viewer before TUI launch, drained its pty, and tore down both successful labs in the same execution turn. Its default-session tripwire was verified by successful teardown; the command artifacts include the teardown exit results.
- Status fixtures were persisted inputs inside a marked disposable lab home. Reader commands were not replaced with stubs. The 210-warning declaration-reader flood exceeds 64 KiB with these long workspace paths; wake-backstop assertions were separately kept inside its documented fixed bound.
- All workspace fixtures and temporary test drivers were removed after evidence collection. No tracked code was changed.

## Targeted regressions and before/after reproduction

- `tests/fm-status-nonstate-note.test.sh` ran directly: [log](nonstate-reader-regressions.log). It covers voice counts/full scopes, tail/fallback behavior, shared state and decision folds, fleet/inbox/bearings, and Pi/attended-host wake routing.
- A temporary focused selector ran these existing `tests/fm-spawn-dispatch-profile.test.sh` functions: `test_pi_exclude_tools_reach_ship_and_scout_launches`, `test_pi_exclude_tools_worker_registry_reports`, `test_pi_exclude_tools_absent_and_empty_lists`, `test_exclude_tools_non_pi_runtime_refuses_non_empty_list`, `test_pi_exclude_tools_malformed_entry_refuses_before_endpoint`, `test_pi_exclude_tools_server_shape_refuses_before_endpoint`, and `test_pi_exclude_tools_read_failure_refuses_before_launch`: [log](focused-regressions.log). The expensive registry semantics matrix was scoped to Pi scouts; the argument matrix retained Pi/pi-signed ships/scouts.
- The base and target voice executables were run on an identical `done` plus actual emitted warning log. Base reported `note`; target reported `done`: [before/after public CLI output](voice-before-after.json).
- `verify-evidence.py` checked the actual recorded runtime outputs, warning cardinality, direct/nested blocking reasons, successful allowed tool execution, reader parity, wake receipts, successful real spawn, and guarded teardown. Its checks are behavioral assertions over product output, not source-text tests.

### Driver setup corrections, not product failures

The first temporary selector accidentally reached unrelated launch-environment tests and a secondmate fixture that refuses homes inside this repository. It was corrected to only the targeted functions. An un-narrowed registry matrix exceeded a 300-second execution bound; the Pi-scout matrix then completed. Early real-Pi driver attempts were corrected to activate the intended tools and queue the second run as followUp. Herdr capture syntax and the successful spawn's metadata field/trust prompt were corrected before final validation. An initial wake assertion exceeded its documented snapshot bound and was separated from the deliberately larger declaration-reader stress case. These setup attempts did not produce product findings.

## Visual evidence

[pi-late-tools.html](pi-late-tools.html) was produced by Pi's own `--export` command from the real session, including direct/nested denied calls and the allowed call. The warning itself is a plain-text append-only status protocol, so its placement and consumer behavior are evidenced by actual status logs, CLI transcripts, and JSON responses rather than synthesized screenshots.

## Driver provenance

Disposable-driver copies are retained as `driver-live-pi.py`, `driver-live-tools.ts`, `driver-mcp-server.py`, `driver-live-status.py`, `driver-live-spawn.py`, and `driver-verify-evidence.py`. Their workspace fixture paths intentionally no longer exist after teardown.
