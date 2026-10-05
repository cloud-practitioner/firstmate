# Targeted upstream-merge validation

Target: `81c1c738c264f2213f5d6ef49b5933817220ab7c`
Base: `44950a2847b371308d1a3780430dd74ed7f64f38`

## Live results

- A genuine Linux remote worker completed a job during the due sweep of 17,460 claim directories in **1 second**. The expired boundary was deleted, the fresh boundary survived, and 8,731 claims remained (8,730 fresh seeds plus the staged job).
- The real claim sweeper retained `0`, `notes`, `1x`, `.private`, and a fresh numeric claim while removing aged `1`, `00`, and `01` directories.
- Removing the real worker's ready file did not change its serving PID. Its heartbeat restored readiness, and three subsequent ensure calls retained that PID.
- Actual worker supervisors, serving children, and heartbeat children under a path containing spaces and glob characters were discovered and stopped without stopping the neighboring fixture's worker.
- A real Pi 1.0.1 primary in a private 120×40 tmux lab emitted genuine agent-start events to the production busy-event interface. The production watcher escalated the unhandled instruction after two busy deferrals without typing a doorbell. The durable record and single stale wake remained; a restarted watcher did not issue another stuck-busy escalation.
- Real teardown calls refused untracked-only, tracked-only, and mixed dirt, preserved metadata and worktree status, and limited listed untracked paths to ten with an omission notice.
- Real brief scaffolding and scout promotion emitted the new proof/scratch guidance. Promotion instructions were also enqueued through real `fm-send.sh` into the disposable primary's durable inbox. These checks establish the emitted instruction contract, not a model's interpretation of it.
- The real `quota-axi` CLI consumed its supported disposable snapshot input. The real quota poll survived an absent snapshot restored after its first read failure, then reported exhaustion on poll two. A permanently absent snapshot terminated after exactly three read failures with the named failure detail. No vendor credentials were used.
- Real Pi 1.0.1 CLI/model-transport/TUI/persistence paths were driven against a disposable local HTTP provider. The **base version reproduced two identical handling finals**, whereas the target retained only one. A subsequent user question remained visible. The target session was exported by Pi's actual HTML exporter. The local HTTP provider supplies deterministic scenario data; it is not a fake Pi CLI or an LLM interpretation test.
- With a genuine live watcher owning its lock, a confirmation after the recovery episode had already been acknowledged succeeded without changing the marker or watcher PID. A superseded generation still returned status 3.
- The real Pi watcher extension wrote no default diagnostic log on an exercised failure/delivery path. Setting its opt-in retention to four produced a real two-line diagnostic log. A later optional one-line-retention follow-up hit its 45-second driver budget and provides no additional validation; its private server and watcher were explicitly stopped before cleanup.

## Supplemental focused regression checks

Passed: `tests/fm-remote-job-claim-reap.test.sh`, `tests/fm-remote-job-claim-retention.test.sh`, `tests/fm-test-fixture-cleanup.test.sh`, `tests/fm-task-inbox.test.sh`, `tests/fm-procevent-quota.test.sh`, and `tests/fm-remote-job-launchagent.test.sh`.

Passed selected functions from:
- `tests/fm-teardown.test.sh`: the three dirty-refusal diagnostic functions (both local-only and remote-reachable cases).
- `tests/fm-calm-pi-extension.test.sh`: `test_rendering_and_session_lifecycle`, using the locally installed Pi 1.0.1 package, including its renamed HTML-renderer lookup.
- `tests/fm-watch-arm.test.sh`: handling-window acknowledgement, moved-generation acknowledgement, live-announced-watcher wake append, already-acknowledged confirmation, and superseded-generation confirmation.

`FM_PI_BRANCH_LIVE_E2E=1 FM_PI_PACKAGE_DIR=<workspace Pi 1.0.1> bash tests/fm-pi-branch-live-e2e.test.sh` passed. Its SDK probes include mocked transports/watch scripts; they are supplemental rather than proof of a complete live watcher chain.

The initial broader watcher-arm file invocation reached its imposed 180-second budget while progressing through unrelated cases. The changed selectors were subsequently run separately and passed. The complete repository suite was not run. The optional one-line-log follow-up also reached its 45-second driver budget; the earlier default-off and four-line opt-in runs remain the validated logging cases.

## Limits and setup findings

1. **Complete automatic Pi watcher continuity through successor gaps remains untested.** A stock marked lab was tried with a genuine Pi primary. The extension injects `FM_ROOT_OVERRIDE` and `FM_CONFIG_OVERRIDE` into its child environment, which the gate's lab guard refuses. An isolated `config/x-mode.env` normalization allowed real arm creation, successor creation, and wake delivery, but the extension's direct `--handling-delivered` call still reintroduced those overrides and was refused. Its durable wake survived; this is not evidence that ordinary successful continuity works. Full proof requires a trusted allowance for exact stock-layout overrides, or an authorized non-gate runtime environment. No lifecycle guard was bypassed. The same override injection predates this merge.
2. **macOS LaunchAgent/Aqua behavior remains untested live.** The host is Linux and has no `launchctl` or Aqua login session. Real Linux workers were driven and the focused LaunchAgent model passed, but emulating launchd is not live macOS evidence. Provide a disposable, authorized macOS runner with a logged-in Aqua account to exercise the actual launchd path.
3. **Screenshot capture could not run.** The Playwright MCP browser expected absent `/opt/google/chrome/chrome`. A browser was then obtained entirely inside the worktree, but could not launch because the host lacks `libnspr4`, `libnss3`, `libgbm1`, and `libasound2t64`. No system packages were installed. Reviewer-visible artifacts include Pi's actual exported HTML and faithful HTML renderings of the captured TUI panes.

## Merge acceptance context

Read-only Git checks confirmed the upstream tip `f470a01` and fork base `44950a2` are ancestors of the target. The upstream integration is a two-parent merge, followed by the two-parent fork-main merge. The original merge records conflicts in `bin/fm-brief.sh` and `tests/fm-calm-pi-extension.test.sh`; the latter is byte-identical to upstream at the integration merge. The later merge records conflicts in `bin/fm-remote-job-lib.sh` and `tests/fm-test-fixture-cleanup.test.sh`. Conflict-resolution inspection with Git's remerge diff confirmed:

| Merge | Conflict | Resolution |
| --- | --- | --- |
| Upstream integration | `bin/fm-brief.sh` | Retained upstream's proof/scratch and clean-worktree rules, followed by the fork's existing task-private temp-root rule. |
| Upstream integration | `tests/fm-calm-pi-extension.test.sh` | Preferred upstream's shared `createInstalledToolHtmlRenderer` implementation supplying both renderer lookup hooks; the integration file matches upstream exactly. |
| Fork-main refresh | `bin/fm-remote-job-lib.sh` | Kept upstream's generalized recorded-owner helper and used the fork's process-start matching helper within it. |
| Fork-main refresh | `tests/fm-test-fixture-cleanup.test.sh` | Kept both upstream's git-root registry test and the fork's spaced-root worker cleanup test, including both invocations. |

The recorded human decision retaining the later heartbeat-child cleanup-test adaptation was respected and that test was exercised.

Publication, PR title/body, and eventual merge method were not executed: those remain the outer delivery phases' responsibility.

All labs, private tmux servers, real workers/watchers, downloaded dependencies, and temporary test drivers are torn down before return. Production source files are unchanged by this test turn.
