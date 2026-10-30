# Silent main-only hand-back: targeted live validation

Target: `4553bd56a5b51327d5de0a07f9f68db56c24dc0a`.
Historical negative control: `05196e30ead54796dfbe986db61abe9d8df9e3d2:bin/fm-supervision-host.sh`.

## Result

All target scenarios passed against real running product scripts under real Claude Code 2.1.314 using the existing normal login, with tmux 3.5a on private `fm-lab` sockets.
No fake harness or engine was used for the live scenarios.
The historical host reproduced the empty-stdout exit, and the new regression failed against that host for the missing stdout diagnostic, as expected.

| Scenario | Observed product behavior | Evidence |
| --- | --- | --- |
| Failed main-only hand-back | Exit 1; stdout contains `supervision-host hand-back failed: watcher downtime could not be restored for the main hand-back`; stderr empty; no wake line | [product output](live-direct-fail-product.log), [real Claude tool transcript](live-direct-fail-claude.jsonl) |
| Early close, before any readiness line | The diagnostic is the entire stdout; exit 1; no readiness or wake output. The historical host under the same scheduling and I/O fault exits 1 with empty stdout and stderr. | [target](live-direct-early-product.log), [historical control](live-direct-control-product.log) |
| Native Claude Stop hook receives failed hand-back | Real `asyncRewake` hook finishes with exit 2 after one host start; ledger records `outcome=failed`; successor is still alive at hook exit; native feedback includes the diagnostic and Claude reports it without repair commands | [hook/state output](live-hook-fail-product.log), [native feedback and Claude response](live-hook-fail-claude.jsonl) |
| Successful main-only hand-back | Exit 0; original `signal:` close; no added `supervision-host` line; downtime restored; event remains durable | [product output](live-direct-ok-product.log) |
| Ordinary failure-path hand-back | Missing dialog-mirror data causes the original close plus `supervision-host: ... dialog mirror could not be read`; downtime restored; exit 0 | [product output](live-direct-ordinary-product.log) |
| Host actually dies | SIGKILL of the first real host causes a second host start; native Stop hook delivers a recovery wake and records `outcome=rewake`, rather than treating host death as the reported hand-back failure | [hook/state output](live-hook-death-product.log), [native feedback](live-hook-death-claude.jsonl) |

## Isolation and fault injection

Each live scenario created a fresh stock home through `bin/fm-lab-home.sh create`, entirely inside the gate worktree, and removed it in the scenario's cleanup trap.
All tmux operations used that home's private socket directory with `-L fm-lab`, and panes were explicitly sized 120x36.
A transient supported `.fm-secondmate-home` declaration allowed the linked worktree through the existing primary-scope predicate; it was removed after testing.
No operator fleet state, default tmux socket, credential store, or user-level configuration was edited.
Claude print mode avoided accepting a persistent workspace-trust prompt and still exercised native async Stop-hook feedback.

The fixture appended a decision to the disposable task's status immediately before the second offer; a wrapper delegated the actual offer computation to the real Node executable.
Another wrapper delegated all `mktemp` operations except the selected watcher's downtime publication, which returned an I/O failure.
The early-close scenario temporarily SIGSTOPed the real host while its real first arm closed, then resumed it, so no readiness line had been streamed before the failing path.
The host-death control used SIGKILL on the exact host PID registered in that lab.
No hook, host, arm, watcher, dispatcher, wake queue, or engine implementation was replaced in the target scenarios.
The historical comparison used a disposable bin copy with only the host restored from the base commit.

The native Stop wrapper captured the real hook's stdout, stderr, status, and successor PID liveness, then removed the disposable task metadata only after the hook completed, to avoid an unbounded repair/Stop loop.
The native Claude transcript contains the delivered failure feedback, not merely a manually invoked hook result.

## Targeted deterministic checks

Only the following named checks were selected through the test runner adapter, not either complete test file or the repository suite:

- `tests/fm-supervision-host.test.sh::test_at_turn_downtime_write_failure_is_never_silent`
- `tests/fm-supervision-host.test.sh::test_attended_close_that_turns_main_only_before_its_turn_passes_to_main`
- `tests/fm-supervision-host-hook.test.sh::test_claude_stop_hook_notifies_when_at_turn_downtime_write_fails`
- `tests/fm-supervision-host-hook.test.sh::test_claude_stop_hook_delivers_a_close_that_turns_main_only_at_its_turn`
- `tests/fm-supervision-host-hook.test.sh::test_claude_stop_hook_notifies_when_closed_successor_downtime_restore_fails`

All selected target checks passed.
Their fake-harness fixtures are supplemental regression evidence, not the basis for the live labels above.
The direct-host fixture captures stdout and stderr separately, and its exact stdout diagnostic assertion fails against the historical host.
See [direct fixture outputs](targeted-direct-product-outputs.log), [hook fixture outputs](targeted-hook-product-outputs.log), and [expected historical regression failure](targeted-negative-execution.log).

## Commands and setup notes

The archived [live driver](live-scenario-driver.sh) was invoked as:

```bash
bash .test-phase/live-scenario.sh direct-fail
bash .test-phase/live-scenario.sh direct-early
bash .test-phase/live-scenario.sh hook-fail
bash .test-phase/live-scenario.sh direct-ok
bash .test-phase/live-scenario.sh direct-ordinary
bash .test-phase/live-scenario.sh hook-death
LIVE_HOST="$PWD/.test-phase/control/bin/fm-supervision-host.sh" LIVE_ROOT="$PWD/.test-phase/control" bash .test-phase/live-scenario.sh direct-control
```

The archived [targeted adapter](targeted-runner.sh) sourced each existing test file with `fm_test_run` restricted to the named selectors.
The historical regression used `PHASE_CONTROL_HOST="$PWD/.test-phase/control/bin/fm-supervision-host.sh"` and selected only `test_at_turn_downtime_write_failure_is_never_silent`; exit 1 was expected and observed.

`tmux` was initially absent.
A worktree-local source build could not configure without `yacc`; instead Debian tmux and its missing jemalloc shared library were downloaded and extracted only inside `.test-phase`, without installing packages or changing system configuration.
The real Claude login was verified by `claude auth status` and a successful `LAB_READY` prompt; credential details are not included in evidence.
Setup-only misdrives were corrected before recording final results: explicitly restore fault-wrapper PATH inside Claude Bash commands, use real host scheduling instead of a prequeued recovery event for the early-close case, and match the historical copy's allowed root override.
All affected scenarios were re-driven successfully.

This change owns a CLI/stdout contract, not visual layout; product logs and native Claude stream transcripts are the reviewer-visible evidence.
No screenshots are claimed from the blank tmux panes used to host print-mode Claude.
No linter, formatter, static analyzer, full test suite, push, PR update, or pipeline-control command was run in this Test phase.
Temporary tooling, home data, control copies, and the linked-home declaration were removed; no tracked source or test file was changed.
