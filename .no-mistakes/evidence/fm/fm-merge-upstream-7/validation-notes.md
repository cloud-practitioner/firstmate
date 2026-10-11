# Targeted test-phase evidence

Target: `9e38c3a32b56dc307e61c80ef8ed12928310f09c`.
Base: `a9c92e0bce3f44027d269ac96e1a13c4c1f4d28a`.

## Product scenarios

`drive-contributions.py` drives the real committed CLI scripts from the gate worktree with disposable operational homes, clean environments, real Bash and jq, and no backend or forge mocks.
`contribution-live-transcript.log` and the generated contribution JSON files are the final evidence.
The oversized backlog is 488,226 bytes serialized; the task document is independently 178,562 bytes.
Both lose output and report `Argument list too long` on the base version, while the target returns all records losslessly.
The base version masks the jq error with an exit status of zero; regression reproduction therefore asserts missing output plus the actual error, not a nonzero base exit.
The target's normal authority context is `attended`, not `unknown`; the initial disposable driver incorrectly expected `unknown` and was corrected to the documented contract before re-driving all scenarios.
`driver-console.log` is the initial diagnostic run, not final scenario evidence.
`driver-console-final.log` and `contribution-live-results.json` record the corrected run.

`drive-staging-failure.py` additionally invokes the real target with a process-local 1,024-byte file-size limit and ignored SIGXFSZ.
`staging-failure.log` shows a partial backlog-file write failure, nonzero exit, empty stdout, unchanged operational files, and no remaining temporary entries.

## Existing targeted suites and isolation corrections

All commands used a clean `env -i` retaining only PATH and setting a disposable HOME, workspace-local TMPDIR, and LANG=C.UTF-8.
No fleet FM_HOME, FM_BACKEND, Herdr pane identity, forge credentials, or inherited Git-location overrides were retained.

Initial command:

```sh
bash bin/fm-test-run.sh --jobs 1 tests/fm-contributions.test.sh tests/fm-fleet-snapshot-view.test.sh tests/fm-bearings-snapshot.test.sh tests/fm-home-summary-refresh.test.sh
```

`targeted-suites.log` records the original run, including setup-induced failures.
Keeping scratch inside the worktree exposed legitimate seeded-home refusal: cross-home fixtures beneath the active code root cannot be consumed.
The contribution suite's three affected assertions and home-summary large-child assertion passed after placing byte-identical committed scripts in `.test-local/runtime-head` and operational homes beside that disposable code root.
`isolated-suites.log` records successful re-runs of contributions, fleet snapshot/view, and home-summary refresh through the original repository runner with absolute copied-suite paths.

Bearings' copied-suite remote-ledger checks initially issued no fake-SSH reads because the real fm-on command requires the remote helper to be tracked by the selected code checkout.
An empty disposable Git repository alone did not meet that allowlist; indexing the copied committed scripts did.
`isolated-bearings.log` and `isolated-bearings-final.log` record those unsuccessful fixture setups.
`isolated-bearings-tracked.log` then records successful remote-ledger and all subsequent cases through the PR repository-cap case.
The latter still reported six repositories rather than five: the fixture's deliberately nongit worktree directories inherited the enclosing gate checkout's origin.

The remaining three original cases were invoked from an unchanged function-definition prefix of the suite in a disposable selector file:

```sh
GIT_CEILING_DIRECTORIES="$PWD/.test-local/tmp" bash bin/fm-test-run.sh --jobs 1 "$PWD/.test-local/runtime-head/tests/bearings-remaining.test.sh"
```

The selector calls `test_pr_repository_cap_and_expansion`, `test_per_repository_pr_cap_is_disclosed`, and `test_projection_and_toon_fail_closed`.
`bearings-remaining.log` shows all three pass with Git discovery bounded to fixture scratch.
Together the original/corrected runs exercised all four proposed targeted subjects; no complete suite, linter, formatter, or static analyzer was run.
No permanent source or test changes were needed.

## Scope and history

`merge-history.log` records the actual two-parent merge, retaining both the fork base and upstream 1a868710 as ancestors, and the single upstream addition since fb75c1f9 (#6830).
Only the contribution-input transport changed relative to the fork base.
PR creation, publishing, eventual merge method, PR-body accuracy, and remote CI belong to the outer executor and were not executed in this test phase.
No real Herdr session, operator fleet home, or credential store was touched.
This change is a machine-readable CLI transport fix, not a UI/layout change; screenshots are not applicable.
All disposable code copies, homes, selected-test wrappers, caches, and generated workspace data are removed at test completion.
