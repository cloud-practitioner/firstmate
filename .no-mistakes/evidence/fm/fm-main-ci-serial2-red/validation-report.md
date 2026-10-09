# Supervision-host downtime hand-back validation

Change: `6b4a40f3b63d49968d0d522c2d58a353e8b4d9f0` → `fcf59688775397e5403a9a23d78b18e5542f94fd`.

## Result

All three live product scenarios passed. This is a timing-dependent runtime regression, not merely an inadequate test wait budget: an empty failed hand-back can be mistaken for a dead host, and the Stop owner retries into a quiet second park. The added diagnostic prevents that misclassification without becoming an actionable wake.

## Live scenarios (real Claude Code 2.1.295, normal existing login)

Each run used `bin/fm-lab-home.sh create` on a fresh directory **inside the gate worktree**, a private `TMUX_TMPDIR=<lab>/tmux`, and `tmux -L fm-lab new-session -d -s primary -x 120 -y 40 -c "$PWD" -e FM_HOME=<lab> claude`. Inherited gate/fleet path overrides were unset. A temporary `.fm-secondmate-home` marker allowed the linked gate checkout's tracked primary hooks to run; no memory files were changed. Each primary was stopped through the same private socket and its lab was removed.

The real host, Stop hook, arm, watcher, dispatcher, queue, and ledger ran unmodified. A separate sleeping lab tmux window supplied a disposable supervised endpoint. The node dependency shim paused at the second offer, then executed the **real node dispatcher**; it never supplied an eligibility answer. Decision transitions were created through a real status append or the queue owner's `fm_wake_append` interface. The mktemp shim injected an actual dependency failure only for downtime-marker temporary-file creation. No Claude CLI, login, engine response, dispatcher result, or product output was fabricated.

1. **Normal main-only hand-back reaches Claude.** `python3 .validation/live.py live-success success` appended a needs-decision status while the real second offer was held. The dispatcher computed main-only, the Stop-owner ledger committed `outcome=rewake`, the marker returned to downtime, the queue remained durable, and Claude displayed watcher-wake feedback. See `live-success/claude-terminal.txt`, `live-success/result.json`, and that directory's persisted queue/ledger/host log.
2. **Downtime write failure is reported despite a healthy successor.** `python3 .validation/live.py live-write-failure fault` enqueued a decision-owned wake without another status append and refused downtime temporary-file creation. The host logged `downtime-unrestored`, the Stop ledger committed `outcome=failed`, the real `fm_watcher_healthy` predicate still verified the successor, and Claude displayed the complete failure notice including `supervision-host hand-back failed: watcher downtime could not be restored for the main hand-back` and `exited 1 without a wake`. The original wake remained queued. See `live-write-failure/claude-terminal.txt` and `live-write-failure/result.json`.
3. **Early close before readiness cannot become a silent retry/hang.** `python3 .validation/live.py live-early-close fault early` repeated the failure with a one-time 3-second delay delivering the real `od` identity-read bytes from the host's first arm. This changes scheduling, not identity bytes or product decisions. Claude's feedback contained the failed-hand-back diagnostic but **no initial `watcher: started` line**, establishing that readiness had not already made the output nonempty. The failure committed, the successor remained healthy, and the wake stayed durable. See `live-early-close/claude-terminal.txt` and `live-early-close/result.json`.

`live-driver.py` preserves the exact disposable live driver used for these checks. Terminal captures are product-level CLI evidence; this change is not a visual/layout change.

## Focused executable regression checks (supplemental, not live-primary proofs)

A temporary driver selected existing cases from `tests/fm-supervision-host.test.sh`, retaining its fixture/cleanup machinery and saving public output and persisted state before cleanup. These checks use the suite's fake harness and stub engine, so they are **not** counted as live Claude scenarios.

Run through `timeout 180 bash tests/.validation-supervision-targeted.sh` with workspace-local `TMPDIR`, isolated `FM_HOME`, cleared fleet-path overrides, and evidence capture enabled:

- `test_at_turn_downtime_write_failure_is_never_silent`
- `test_claude_stop_hook_notifies_when_at_turn_downtime_write_fails`
- `test_claude_stop_hook_delivers_a_close_that_turns_main_only_at_its_turn`
- `test_successor_left_at_the_turn_survives_the_hook_process_group_teardown`
- `test_claude_stop_hook_notifies_when_closed_successor_downtime_restore_fails`
- `test_claude_stop_hook_notifies_when_closed_announced_successor_downtime_restore_fails`

All passed (`targeted.log`). The first two cases were then repeated in three separate clean fixture runs, all passing (`fixed-repeat-1.log` through `fixed-repeat-3.log`). Their saved host output, hook stderr, exit codes, recovery markers, and ledgers are under the corresponding evidence directories.

### Before/after evidence

- The **unaltered pre-fix host**, obtained with `git show 6b4a40f:bin/fm-supervision-host.sh`, failed the new direct-host regression: its output lacked the failed-hand-back diagnostic (`baseline.log`, `baseline/turns-main-only-write-fails/host.out`). This run happened to emit readiness, showing why silence depends on scheduling.
- Seven ordinary pre-fix Stop-hook fixture runs passed. A signal-suspension probe did not reliably remove readiness either; it is not claimed as a reproduction.
- To pin the known early-close schedule, disposable pre-fix and fixed host copies received the **same single scheduling-only `sleep 3` after first-arm startup and before the host close loop**. This is instrumentation, not an untouched-baseline or live-primary claim. The pre-fix copy reproduced exactly `not ok - hook write failure: the Stop hook did not finish` (`baseline-early-close.log`); its host ledger shows downtime-unrestored followed by a second host start. The fixed copy completed with exit-2 failure feedback (`target-early-close.log`, `target-early-close/hook-turns-main-only-write-fails/hook.err`). The subsequent unmodified real-primary early-close scenario above independently verified the runtime fix.

## Isolation, setup, and cleanup

Tmux was absent from PATH. It was built from the 3.5a release inside `.validation/tools`, with Bison 3.8.2 likewise built locally after the first configure attempt reported missing yacc. No system/user packages or configuration were installed or altered. Two initial live-driver setup mistakes (selecting the sleeping worker window and submitting before the TUI was ready) were corrected and the scenarios re-driven successfully; neither was a product failure.

No full repository suite, linter, formatter, static analyzer, pipeline-control command, push, PR creation, or remote CI phase was run. Broad regression and remote CI remain the outer executor's responsibility. Temporary drivers, host copies, tools/build outputs, markers, and lab directories were removed from the worktree. Evidence is retained here.
