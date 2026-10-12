# Targeted fixture validation

Head: `59f4ea5638b690afe37cf6baf1276d4f4efd2d18`.
All eleven requested suites passed without gate skips on their final invocation.
This is fixture-only validation, not live harness/backend evidence.
Live scenarios were not attempted under the recorded user decision.
`fm-busy-adapter-wiring.test.sh` was not rerun because that decision records it as already passed.

## Invocations

Initial: `TMPDIR="${TMPDIR:-/tmp}" FM_TEST_SKIP_ORPHAN_REAP=1 bin/fm-test-run.sh --jobs 1 --json "$EVIDENCE/fixture-suite-timings.json" tests/fm-spawn*.test.sh tests/fm-backlog-handoff.test.sh tests/fm-control-relaunch.test.sh tests/fm-teardown.test.sh tests/fm-secondmate-safety.test.sh`.

Retry: `env -u HERDR_PANE_ID -u HERDR_BIN_PATH -u HERDR_ENV -u HERDR_TAB_ID -u HERDR_SOCKET_PATH -u HERDR_WORKSPACE_ID -u FM_BACKEND -u FM_HOME -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u PI_CODING_AGENT -u FM_PI_HARNESS -u CLAUDECODE -u GROK_AGENT -u GEMINI_CLI -u CURSOR_AGENT -u CURSOR_INVOKED_AS -u FM_OMP_HARNESS FM_TEST_SKIP_ORPHAN_REAP=1 bin/fm-test-run.sh --jobs 1 --json "$EVIDENCE/fixture-rerun-timings.json" tests/fm-spawn-compact-adviser-disable.test.sh tests/fm-spawn-dispatch-profile.test.sh tests/fm-spawn-pool-base-freshen.test.sh tests/fm-spawn-worktree-settle.test.sh`.

`EVIDENCE=/home/node/.no-mistakes/evidence/01M4Q7H328Y5N60RR37G308KCE`.

## Setup correction

The initial run had four failures caused by inherited Herdr backend/pane selectors conflicting with disposable fixture homes.
The four affected suites were rerun serially with inherited backend, home, and harness selectors removed; all passed.
Three disposable-home Herdr servers were inadvertently started by the contaminated fixture run before the cross-session guard refused the launches.
Their six server/launcher processes were stopped only after verifying exact fixture paths and disposable HOME values; no operator session was targeted.
No source or test edits, live laboratory scenarios, tmux builds, linters, formatters, or complete-suite runs were performed.
Test helpers owned temporary-directory cleanup; orphan reaping of unrelated fixtures was disabled.

## Final per-suite results

| Suite | Result | Final invocation |
| --- | --- | --- |
| `tests/fm-spawn-batch.test.sh` | PASS (exit 0; no gate skip) | initial invocation |
| `tests/fm-spawn-compact-adviser-disable-remote.test.sh` | PASS (exit 0; no gate skip) | initial invocation |
| `tests/fm-spawn-compact-adviser-disable.test.sh` | PASS (exit 0; no gate skip) | clean-environment retry |
| `tests/fm-spawn-dispatch-profile.test.sh` | PASS (exit 0; no gate skip) | clean-environment retry |
| `tests/fm-spawn-orca-worktree.test.sh` | PASS (exit 0; no gate skip) | initial invocation |
| `tests/fm-spawn-pool-base-freshen.test.sh` | PASS (exit 0; no gate skip) | clean-environment retry |
| `tests/fm-spawn-worktree-settle.test.sh` | PASS (exit 0; no gate skip) | clean-environment retry |
| `tests/fm-backlog-handoff.test.sh` | PASS (exit 0; no gate skip) | initial invocation |
| `tests/fm-control-relaunch.test.sh` | PASS (exit 0; no gate skip) | initial invocation |
| `tests/fm-teardown.test.sh` | PASS (exit 0; no gate skip) | initial invocation |
| `tests/fm-secondmate-safety.test.sh` | PASS (exit 0; no gate skip) | initial invocation |

## Workspace

`git status --short --untracked-files=all --ignored` produced no entries; `.test-phase/` was absent throughout.

## Logs

[Initial fixture transcript](fixture-suites.log)
[Corrected fixture transcript](fixture-rerun.log)
[Initial timing records](fixture-suite-timings.json)
[Corrected timing records](fixture-rerun-timings.json)
