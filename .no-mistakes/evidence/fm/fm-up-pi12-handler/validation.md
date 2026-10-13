# Pi supervision: targeted live validation

## Product and isolation

Ran real Pi 1.2.0 and installed Pi 1.1.0 AgentSessions through their public SDK, loading the tracked Firstmate extensions through Pi's real TypeScript extension loader. The upstream model service was a disposable loopback OpenAI-compatible SSE endpoint; the Pi SDK, extension event dispatch, nested branch sessions, watcher, and fleet-record scripts were not mocked. This tests lifecycle behavior, not model interpretation.

Each run used a fresh marked FM_HOME under the validation worktree, an isolated Pi agent directory, synthetic records, and no production credentials. Sessions, HTTP endpoints, watcher children, homes, and agent directories were stopped/removed in the same command. No Herdr/default fleet session was used. The live driver is retained as `live-driver.mjs`; transient project dependencies and test drivers were removed after validation.

## Observed behavior

- `pi12-branch-live.json`: Pi emitted `before_agent_start` with `messageType: custom`, `hasPrompt: false`, and `customType: lab-custom`. The run completed without extension errors. Its resource-report-looking custom text did not enter the persisted `fm-main-mirror` context, while the ordinary user request did.
- The same transcript shows an `fm-branch-process` custom opening with no prompt. An away record was created after the opening handler and before context assembly. The processing run added **zero provider requests**, its seq 2 outcome stayed unprocessed, and the subsequent ordinary user prompt produced `Local endpoint completed the requested run.` with no processing custom message in model context.
- `pi12-watch-live.json`: the real watcher detected the disposable `lab.status`, queued a follow-up, and kept it unconsumed after an actual custom run carrying the exact same text. Reload persisted one pending wake, replayed that wake as a user prompt, and removed the handoff record after real user consumption.
- `pi11-branch-live.json`: ordinary Pi 1.1 prompts still entered the mirror; custom context did not become captain dialog. An existing away record suppressed processing presentation, kept the outcome unprocessed, and allowed an ordinary user response.
- `pi11-watch-live.json`: the real Pi 1.1 watcher delivery survived an unconsumed custom run and was replayed/consumed through the legacy user-prompt path.

## Regression controls

The base handler was temporarily loaded through real Pi 1.2 in `baseline-custom-regression-live.json`. Custom runs produced `Cannot read properties of undefined (reading 'trim')`; the dedicated processing run also reached the provider despite the away record. The target handler produced neither failure.

A supplemental focused run of the added branch behavioral test against the base handler failed at `prompt.trim()`, then passed against the target. The watcher behavioral case passed at both base and target: it provides boundary coverage, not a runtime regression reproduction of the reported declaration/type error.

Ordinary-user mirror duplication observed in the live setup was also reproduced with the unchanged base handler (`baseline-mirror-live.json`). Exact-once mirroring is therefore not claimed by these live artifacts; the changed custom-message exclusion boundary passed.

## Lab limitations

The watcher launcher supplies FM path overrides that the gate's marked-lab rule refuses. A supported, disposable `config/x-mode.env` cleared those overrides before arm launch. No bypass was used. The separate handling-confirmation call still supplies overrides and was refused; both watcher transcripts truthfully contain that diagnostic. Real detection, delivery, custom-event handling, replacement persistence/replay, and user consumption were nonetheless exercised successfully. This is not evidence of a clean full watcher-continuity cycle.

No TUI/rendering change is involved, so evidence is JSON session/event/provider-request transcripts rather than screenshots. No static analysis, typecheck, linter, formatter, full repository suite, remote CI, or pipeline-control phase was run. In particular, `tests/fm-pi-primary-types.test.sh` remains for the outer validation/CI owner.

## Exact focused behavioral selectors

Definitions from the two tracked test scripts were executed via temporary selector-only drivers, without invoking their unrelated test cases:

- `tests/fm-pi-branch-extension.test.sh::test_requested_healthy_outcome_and_unsolicited_routine_outcome_delivery`
- `tests/fm-pi-branch-extension.test.sh::test_away_record_parks_main_and_presents_after_archive`
- `tests/fm-pi-branch-extension.test.sh::test_branch_mirror_filters_order_and_cursor`
- `tests/fm-pi-watch-extension.test.sh::test_pi_streaming_time_delivery_keeps_the_successor_chain`
- `tests/fm-pi-watch-extension.test.sh::test_pi_streaming_followup_is_replayed_after_replacement`

These use the repository's stubbed Pi test harness and are supporting behavioral coverage, **not** the live evidence above.
