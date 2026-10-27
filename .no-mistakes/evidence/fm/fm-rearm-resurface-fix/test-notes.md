# Focused live validation: process-event duplicate follow-ups

## Scope and environment

Target: `55b25f3ba9c3b0202b074ae068d57492b5d13aec`.
Baseline: `bcfc00fea6ef9c88d4695816738555fecc0d757d`.

Ran the actual Pi 1.4.0 CLI, tracked watch extension, watch-arm, watcher, process-event registration/capture/reconcile, wake drain and acknowledgement commands. Pi ran in the worktree on a private tmux `fm-lab` server, with a 120×40 terminal and an FM_HOME minted by `bin/fm-lab-home.sh create`. HOME, Pi configuration, claims, caches and temporary fixture state were isolated inside the worktree. No fleet state, default tmux server, operator credentials, or real model account was used.

A disposable HTTP streaming-provider dependency kept a real Pi turn busy. This is not a live-LLM evaluation: the real Pi queue, session lifecycle, extension API and shell product ran unchanged; only the external model response and external process result were controlled fixture inputs. `pi-user-messages.json` records actual user-message consumption events, and `model-requests.json` records the resulting requests to that dependency.

Host tmux was absent. `apt-get download tmux` had no candidate; tmux 3.5a was downloaded and built locally, using a locally extracted Debian bison package after configure reported missing yacc. No system/global package installation occurred. A Herdr helper prepare preflight succeeded, but no Herdr lab was provisioned; its unused tripwire was removed. The actual live proof used the isolated tmux route.

## Live results

- A genuinely captured terminal-feedback result remained at exactly one durable row across five explicit reconciles and 15 seconds of one-second watcher polls. Queue bytes and recovery generation did not change; the successor watcher remained alive.
- Draining and acknowledging the wake without marking its result handled caused exactly one republished row, with a fresh queue sequence. The row, marker and cycle count then stayed unchanged for a further 10 seconds.
- `handled` plus wake acknowledgement removed the result from publication; no copy returned over five further polls.
- While the main stream remained held, four independent real wake appends forced additional actionable recovery closes, bypassing the process-event guard as an adversarial test of the Pi coalescer. When the stream was released, real Pi consumed exactly one recovery follow-up, one original result wake, and one distinct result wake.
- Starting another real stream and forcing the same recovery text after consumption delivered it again. Coalescing did not become permanent suppression.
- A separate real CLI scenario captured two rounds of the same source. Twelve simultaneous reconciles preserved exactly one queued copy of each sequence, without changing either row or the recovery generation.

## Regression proof and supporting checks

The same live reproduction against isolated copies of the baseline runtime files reproduced the reported fault: 25 rows for the same result and repeated identical recovery follow-ups. Its expected assertion failure is in `baseline-reproduction.log` and the underlying state/UI evidence is under `baseline/`.

Executed selected behavioral tests, not the repository suite:

- `test_pi_identical_unconsumed_wakes_are_coalesced`
- `test_pi_streaming_followup_is_replayed_after_replacement`
- `test_pi_streaming_time_delivery_keeps_the_successor_chain`
- `test_pi_successor_failure_during_delivery_is_retried_after_delivery`
- `test_pi_suite_leaves_no_orphaned_processes`
- `test_unhandled_procevent_result_does_not_loop_rearm_resurface`
- `test_procevent_reannouncement_after_ack_without_handled_is_bounded`

All selected target tests passed. The new coalescing test failed as expected when pointed at the baseline extension (`baseline-pi-regression.log`). These API/fixture tests are supporting evidence, not the basis for marking scenarios live.

The first target driver attempt incorrectly expected the lifecycle ledger to contain the full wake text; that ledger intentionally records the normalized `reason=actionable-check`. Its nonterminal source fixture also permitted a registration/relaunch race. The driver was corrected to observe the real TUI wake and use terminal feedback, then rerun successfully. The earlier `error-*` artifacts and `pi-error.txt` are retained setup-attempt diagnostics, not outstanding target failures.

## Reviewer-visible output and cleanup

`terminal-captures.html` and `terminal-before-after.png` render the unmodified captured real Pi terminal text for review; the PNG is a browser screenshot of those rendered captures, not a native desktop screenshot. Original text captures remain available separately. No UI styling or layout change is under validation.

Both live runs killed only their private tmux server, swept only the lab process-event home, stopped the lab watcher, and removed the disposable home in the same execution turn. Temporary drivers, selected-test wrappers, dependency downloads/builds and copied baseline runtime files were removed from the worktree afterward. No tracked source or test file was changed, and no lint, formatting, static-analysis, push, PR or CI phase was executed.
