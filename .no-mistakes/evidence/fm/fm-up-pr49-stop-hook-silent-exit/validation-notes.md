# Stop-hook silent-exit live validation

Target: f030295e1da7741dd668312b313178009b5c1b88. Baseline: 19fcbbde12c4e916e0d5faa60c399d2fd2845740.

## Results and owned output contracts

| Scenario | Product evidence | Observed result |
| --- | --- | --- |
| Failed main-only hand-back, including a close before readiness is streamed | `live-direct.log` | stdout contains only `supervision-host hand-back failed: watcher downtime could not be restored for the main hand-back`; stderr empty; exit 1; no wake output; queued event persists. |
| Real Claude Stop hook sees typed failure despite a healthy successor | `live-hookfail.log` | One host start, failure epoch committed, successor PID alive at commit, actual Claude `Stop` hook response records exit 2 and failure stderr, followed by the model's `LAB_NOTICE_RECEIVED`. No readiness line appears in that failure feedback. |
| Successful main-only hand-back still wakes main | `live-hooknormal.log` | Downtime marker restored, rewake epoch committed, successor alive, actual exit-2 wake feedback delivered to Claude. |
| Host death remains retryable | `live-death.log` | SIGKILL sent only to the recorded lab host; a second host starts, resurface close delivered, rewake epoch committed and Claude acknowledges feedback. |
| Ordinary failure-path hand-back remains a wake | `live-ordinary.log` | Actual unreadable-dialog-mirror failure takes `to-main`, prints the original signal and ordinary `supervision-host:` wake diagnostics, including restoration failure, and exits 1. This is intentionally unlike the non-wake main-only failure. |
| Baseline reproduces the silent branch | `live-pre-fix-direct.log` | Same early-close and downtime-publication fault against baseline host produces empty stdout and stderr, exit 1, and a `downtime-unrestored` ledger entry; new diagnostic assertion fails as expected. |

The changed owning host header and `docs/supervision-host.md` Failure direction section were manually checked against these observed distinctions. Upstream PR-description references are delivery-phase context; this test phase did not create or control a PR/pipeline.

## Environment and isolation

- Real installed Claude Code 2.1.295 used the machine's existing login. No sign-in, sign-out, credential inspection/copying, or trust/global configuration changes were performed.
- `tmux` was absent from PATH. Debian `tmux_3.3a-3_amd64.deb` and `libutempter0_1.2.1-3_amd64.deb` were downloaded from deb.debian.org and extracted with `dpkg-deb -x` into worktree-local `.gate-test/tools/tmux`, not installed on the system.
- Private `tmux -L fm-lab` sessions used 120-column, 40-row grids and were drained via pipe-pane. The default server and real fleet were never accessed.
- Each home was created with `bin/fm-lab-home.sh create`, used stock FM_HOME paths and the supervision-host opt-in, and was deleted in the same driver invocation after killing its private server and recorded home-local survivor processes.
- The long worktree path exceeded UNIX socket limits with the normal `fm-lab.XXXXXX` home name. Compact worktree-local `l.XXXXXX` names made the same private `TMUX_TMPDIR=$LAB/tmux` / `-L fm-lab` contract work without writing a lab home outside the worktree.
- A temporary `.fm-secondmate-home` runtime marker activated the shipped primary-scope predicate in this linked worktree. It was removed after each run. No AGENTS.md or CLAUDE.md edits were made. Gate SessionStart intentionally stood down; real Claude's Bash tool acquired the disposable session lock through `bin/fm-lock.sh`.
- Interactive Claude showed a workspace-trust prompt. Its documented print-mode route skipped that prompt without changing trust configuration. `cat | claude -p --input-format stream-json ...` kept the real primary running, with tracked `.claude/settings.json` hooks explicitly loaded and only project settings enabled. Prompts were sent, output captured, and the primary stopped through the same private tmux socket. The cat pipe only adapts stdin to the real CLI's documented streaming protocol; it is not a fake harness or login.
- Each disposable worker endpoint was a real private tmux window (`fm-demo`, running sleep), with home-local task metadata/status. No canned crew-state function, fake tmux, or stub supervision engine was used in live scenarios.
- Fault injection was confined to the lab's dependency PATH: the node wrapper appended a real needs-decision status immediately before the second real dispatch calculation; the mktemp wrapper denied only watcher-downtime publication; the sleep wrapper delayed only the recorded host's 0.5-second park probe to exercise an early close without streamed readiness. These wrappers never replace the host, arm, watcher, Stop hook, or dispatch calculation. The ordinary fallback's actual cause was an unreadable dialog mirror, not a claimed engine response.

## Targeted deterministic regression checks

Only definitions from `tests/fm-supervision-host.test.sh` were loaded into a temporary selector runner, stopping before its top-level suite calls. The following existing scenarios were invoked, not the full suite:

```
TMPDIR="$PWD/.gate-test/tmp" bash tests/.gate-supervision-selected.sh \
  test_at_turn_downtime_write_failure_is_never_silent \
  test_claude_stop_hook_notifies_when_at_turn_downtime_write_fails \
  test_claude_stop_hook_delivers_a_close_that_turns_main_only_at_its_turn
```

`targeted-regressions.log` preserves actual host stdout/stderr/exit status, Stop-hook stderr/exit status, and generated recovery/queue/epoch state. These fixture tests are supplemental deterministic checks, not claimed as real-primary live runs.

The direct regression was also executed with `GATE_HOST` pointing to a worktree-local baseline host copy and then a copy with the new diagnostic redirected to stderr. Both failed specifically because the required diagnostic was absent from stdout (`pre-fix-direct-regression.log`, `stderr-mutant-direct-regression.log`). This validates the previously requested stdout/stderr separation.

## Live-driver commands

The driver and two primary helper scripts are attached beside this note; during execution they lived under `.gate-test/` in the worktree. Commands run:

```
python3 .gate-test/live-handback.py direct
python3 .gate-test/live-handback.py hookfail
python3 .gate-test/live-handback.py hooknormal
python3 .gate-test/live-handback.py death
python3 .gate-test/live-handback.py ordinary
GATE_HOST_ENTRY=bin/.gate-base-host.sh GATE_EVIDENCE_LABEL=live-pre-fix-direct \
  python3 .gate-test/live-handback.py direct
```

All generated worktree test files, downloaded/extracted binaries, homes, caches, and the runtime scope marker were removed. No source/test changes were needed. No linter, formatter, static-analysis tool, broad test suite, PR/push/CI phase, or pipeline-control command was run. Evidence is textual because the changed end-user surface is the CLI stdout and Claude Stop-hook feedback contract, not a rendered UI.
