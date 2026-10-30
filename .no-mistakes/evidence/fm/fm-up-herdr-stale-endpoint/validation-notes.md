# Focused live validation

Target: `bdd369fd5dc5a255cf5e6b8915c41dd111a5a302`

## Product environment and isolation

- Real Herdr 0.9.5, protocol 22; actual shell processes, actual process table, real Treehouse pool, actual Claude CLI, actual Pi 1.4.0 TUI.
- All Herdr lifecycle and operational commands ran through `bin/fm-herdr-lab.sh` in unique `fm-lab-*` sessions. Provision itself performs prepare; calling prepare separately before provision was an initial setup mistake, corrected before live probes.
- Every successful live probe deleted its named session in the same invocation, checked the helper's unchanged default-session tripwire, and removed its disposable homes. No default-session pane was controlled.
- Scratch and Treehouse root were inside `.test-live/` in the gate worktree. `TREEHOUSE_ROOT` was set before provisioning, so panes inherited the isolated pool location. The scratch directory was removed at the end.
- Adapter CLI wrappers forwarded responses from real Herdr unchanged. Race injection stopped or deleted/reprovisioned only the named lab at a selected transport/retirement boundary; no canned Herdr replies, fake harnesses, fake credentials, or model providers were used.
- Retirement probes ran an unchanged disposable copy of `bin/`, with a marked primary home and sibling secondmate homes. This accommodates both the real gate marker contract and the real refusal to remove a secondmate home located inside its code root. The source copy was never edited except in the explicitly labelled pre-fix comparison.

## Results and direct evidence

| Scenario | Evidence |
| --- | --- |
| Same real process accepts portable one-second `ps` timestamp drift; missing `/proc` reads fall back portably, but loss of a recorded `proc` binding stays unreadable | `live-endpoints.log` |
| A deleted/recreated Herdr session recycles the address, label and cwd; old task liveness reads missing even with a competing bound claimant | `live-endpoints.log` |
| Stale capture, viewport, key and text-submit refuse; teardown retains the foreign process, cwd and task records | `live-endpoints.log` |
| A no-identity legacy no-agent husk is replaced without closing the new endpoint | `live-endpoints.log` |
| Passive busy inspection tolerates a real mid-probe server stop without restart; stopped composer and viewport also refuse | `live-endpoints.log` |
| Fresh Claude spawn and recycled-address relaunch publish the actual pane process identity; relaunch leaves the foreign old address alive | `live-spawn.log` |
| A real Claude external-import permission dialog emits native blocked state; reconnect subscription and the real push handler choose the bound claimant behind stale paused `a.meta`, enqueue a wake, and commit its markers | `live-spawn.log` |
| A real Pi idle composer reads empty through its lazy native identity path; stopping the server after capture makes it unknown without restart | `live-pi-composer.log` |
| Direct and recursive late home-removal refusals restore real swept process-event registrations and runners; wake-staging and changed pending-reply validation restore the wake/reply contract; ordinary direct and recursive removal still commit | `live-retirement-all.log` |

Claude remained at its real external-import permission prompt. No permission acceptance, credential mutation, model response or login-success claim is part of this evidence. The Pi composer check made no model request and used a disposable config, no session persistence, no project-resource trust, and no extensions. Herdr reported its actual terminal viewport as 40 rows (the normal 120-column lab grid); this was not a zero-grid pseudo-terminal.

This change is backend/CLI ownership behavior, not a visual layout change. Evidence consists of actual CLI/API responses, captured live terminal viewports, persisted-record assertions and process-event list output, rather than screenshots.

## Regression comparison

`BASELINE_RETIREMENT=1 bash live-retirement-driver.sh direct-sweep` substitutes only the teardown script from `bdd369fd^` in the disposable code copy. The same real reset after production sweep reproduces the original bug: `wait.source` is absent when retirement refuses. Exit 2 is expected for this pre-fix comparison, not a target regression. The current-target counterpart passes with the source restored and a real live runner.

## Targeted shell suites

- `tests/fm-herdr-endpoint-boundaries.test.sh`: passed.
- `tests/fm-backend-herdr.test.sh`: passed.
- `tests/fm-remote-secondmate-control.test.sh`: passed on bounded standalone rerun. The first aggregate invocation reached its overall 240-second command budget after the other two suites had passed; this was not a demonstrated remote test assertion failure. A traced standalone run and a subsequent clean standalone run both passed.

These are offline behavior tests and are not represented as live scenarios. No full repository suite, linter, formatter, static analysis, publication or CI phase ran.

## Live limitation

Host-local remote secondmate control is not claimed live: its executable requires the literal session `fm-remote` and rejects a task record naming an `fm-lab-*` session. The required lab helper refuses that non-lab session name. Moreover its key subprocess exports `state/parent-route`, which the gate's marked-home allowance does not accept as a stock state override. The targeted remote-control suite covers this boundary offline. A supported lab-session override and a permitted isolated parent-route gate recipe, or explicit authority for a dedicated remote environment, are needed to drive that exact executable live without substituting its transport namespace or bypassing the gate. The core ownership classifier, data-plane guards and selected-home teardown paths were exercised live separately.

## Reproduction

From the gate worktree, create `.test-live/tmp` first, then execute each evidence driver with Bash. `live-lab-common.sh` is a fixture library, not a standalone scenario. The retirement driver accepts `direct-sweep`, `recursive-sweep`, `direct-stage`, `direct-pending`, `direct-owned`, and `recursive-owned`. All evidence drivers and logs are retained alongside this note. There are no intentional source changes from this test phase.
