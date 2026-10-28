# Live MCP worker validation

## Scope and isolation

Real `bin/fm-brief.sh`, `bin/fm-spawn.sh`, `bin/fm-control.sh`, treehouse, workspace-built tmux 3.5a, and installed Pi 1.4.0 were exercised in this run.
A marked disposable FM_HOME, private `fm-lab` tmux socket, private Git project/origin, and 120-column by 40-row terminal panes were used. All lab files were inside the gate worktree. The lab was removed in the same execution turn.
No existing worker/helper was stopped, no operator login or configuration was copied, and no credentials were read or changed.

Two disposable Python stdio MCP servers (`sap-lab`, `browser-lab`) implemented initialize/tools-list for the real Pi MCP client. A loopback OpenAI-compatible deterministic provider asked Pi to execute its real codemode tool and enumerate the available MCP tools. This is a startup/tool-routing probe, not proof of an LLM interpreting task instructions or of production SAP/browser tool behavior.

## Observed end-user results

- PASS: Absent and on home settings preserve configured MCP helpers.
- PASS: MCP off suppresses helpers for ship and scout while codemode and exclusions work.
- PASS: Per-task overrides work in both directions and batch forwards MCP off.
- PASS: Invalid settings and unsupported launch kinds refuse before provisioning.
- PASS: Malformed setting and unsupported replacement preserve the running worker.
- PASS: Relaunch preserves recorded or legacy posture and explicit on enables helpers.

The off worker's actual codemode result was:

```json
{"probe":"codemode-ran","mcpTools":[]}
```

The default worker's actual codemode result was:

```json
{"probe":"codemode-ran","mcpTools":["mcp__sap_lab__ping","mcp__browser_lab__ping"]}
```

The running scout with `crew-exclude-tools=read` retained `codemode` and excluded `read`. Invalid config values, a directory in place of the config file, an invalid CLI value, a raw command, and a Claude launch with MCP off all refused before any new endpoint, metadata record, or helper was created. `--mcp` on a secondmate spawn was also refused.

For refused relaunches, the original Pi process remained alive with the same PID. A successful relaunch preserved the recorded off posture despite home config changing to on; a second relaunch with `--mcp on` started both helpers on the same endpoint/worktree. A legacy task without an MCP field retained its helpers after a home change to off.

## Per-new-worker fixture measurement

These are **disposable fixture helper measurements, not production SAP/Fiori/browser measurements and not evidence for the original 12 GB estimate**. The previously declined production-measurement review concern was not reopened. The measured comparison is unconfigured/on versus off with the same fixture MCP configuration, not a pre-change versus post-change production deployment.

| Worker | Effective posture | Live fixture helpers | Combined helper RSS (KiB) |
| --- | --- | ---: | ---: |
| lab-default | unconfigured | 2 | 38984 |
| lab-on | on | 2 | 38860 |
| lab-off | off | 0 | 0 |
| lab-scout | off | 0 | 0 |
| lab-override-on | on | 2 | 38936 |
| lab-override-off | off | 0 | 0 |
| lab-batch-a | off | 0 | 0 |
| lab-batch-b | off | 0 | 0 |
| lab-off | off | 0 | 0 |
| lab-off | on | 2 | 38808 |
| lab-default | unconfigured | 2 | 38864 |

Each helper PID and its `ps` RSS output is recorded in `live-mcp-scenarios.log`. The real MCP initialize/tools-list traffic is in `mcp-events.jsonl`; enabled Pi tool sets are in `tool-observations.jsonl`; actual tool-result content received back by the local provider is in `local-provider-requests.jsonl`.

## Setup corrections

The first attempt paused at project trust rather than proving MCP startup. The driver was corrected to handle the disposable project's trust prompt and wait for an actual completed tool call. An initial batch attempt used single-task positional syntax; the completed run used the documented `id=repo` batch interface. Read-only spawn-hook directories required restoring owner write permission before removing the disposable lab. These were test setup issues, not product failures.

The initial targeted suite invocation put TMPDIR inside the checkout, causing the product's deliberate secondmate-home containment guard to reject fixture homes. The rerun uses the development toolchain's permitted incidental `/tmp` test space. Test-suite results are recorded separately.

This change exposes CLI launch/control behavior, not a new rendered UI. Product terminal transcripts are retained; no screenshot was captured. No permanent source or test files were changed; no lint, formatting, static-analysis, push, PR, or CI phase was run.

## Targeted baseline result

`TMPDIR=/tmp bin/fm-test-run.sh tests/fm-spawn-dispatch-profile.test.sh tests/fm-control-relaunch.test.sh tests/fm-dod-lib.test.sh` completed successfully (exit 0), with `FM_BACKEND` and all `HERDR_*` variables unset. All three selected scripts passed, including their added MCP cases. This was not the complete repository test suite. The initial rejected fixture-location attempt remains in `targeted-tests.log`; the completed rerun is `targeted-tests-rerun.log`.

A post-teardown `ps` check restricted to this run's observed Pi/helper PIDs found no remaining processes (`lab-process-cleanup.log`).
