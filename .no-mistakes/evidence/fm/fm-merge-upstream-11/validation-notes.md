# Merge-upstream local validation

Target: `569dbec967e0c0327a7fa198804bcb7d02bd225f`  
Base: `dc1235ef0e8609d5280e5c06afc44cec9fef1182`

## Result

No product failures found in the exercised scenarios. The target is a real two-parent merge of fork main and upstream `83b70ef4`, carrying exactly 12 upstream commits since `a65dceee`. Both parents remain ancestors. The fork-only Ixia folder and PR-check, PR-merge, PR-poll, PR-library, and named-head-gate files are unchanged from the base.

This was only the Test phase: no gate was initialized, advanced, pushed, or merged; no external PR was opened, modified, or merged. Final PR publication, description, and remote CI remain the outer executor's responsibility.

## Product evidence

| Scenario | Evidence |
| --- | --- |
| Capacity counts ordinary lanes separately from secondmates, honors its target, and rejects malformed input | [CLI transcript](live-cli-transcript.txt) |
| A mate-specific runtime pin survives a default change; duplicate pins refuse on every reader | [CLI transcript](live-cli-transcript.txt) |
| Generated ship/scout briefs preserve the per-home scratch-path contract and emit the new shell-path rule | [ship brief](ship-brief.md), [scout brief](scout-brief.md) |
| Paseo is never selected by inherited app markers, but explicit selection is honored and missing CLI is actionable | [CLI transcript](live-cli-transcript.txt) |
| Fork merge topology, real Ixia install/verify, commit/amend trailer deduplication | [fork transcript](fork-and-resolver-transcript.txt) |
| Opt-in NM-home resolver, explicit NM_HOME precedence, invalid-answer fallback against the real read-only no-mistakes CLI | [resolver transcript](fork-and-resolver-transcript.txt) |
| Actual no-run verdict reaches a live worker's current status; Bitbucket CI-ready claims bind the exact durably published head, including an unpublished follow-up | [live worker + local Git publication](live-no-run-transcript.txt) |
| Open worker blocker wakes supervision; opt-in defers wedge escalation; opt-out restores it; real sender closes the exact decision key | [live watcher and sender](live-worker-watch-transcript.txt) |
| Unknown-but-alive endpoint alarms initially, bounds repeats with recent progress, and alarms again without progress | [live unknown-state watcher](live-unknown-alive-transcript.txt) |
| Real external file-signal adapter binds, waits, captures external evidence, classifies, and retires | [extension example](extension-example-transcript.txt) |
| Bitbucket PR registration and custom-message merge attempt fail closed without credentials and publish no watch | [credential refusal](bitbucket-auth-refusal.txt) |
| Capped-inventory explicit-no-run regression fails on the base implementation and passes on the merge head | [before/after regression](crew-state-before-after.txt) |

## Isolation and interpretation

- tmux 3.5a and libjemalloc were downloaded and extracted only into the disposable worktree tooling directory, not installed globally. Every real primary used a marked lab home and its private `fm-lab` socket, with a 120-column/40-row terminal. Every lab server was killed through that exact socket, and its home was removed.
- The actual machine Claude CLI/login executed the worker commands. Busy/idle/unknown records were deliberately seeded through the public `fm-busy-event.sh` interface to isolate state/watch scenarios. These checks do not claim automatic native-hook coverage.
- The no-run check used the real no-mistakes CLI against its real schema in an isolated NM_HOME, with only a disposable repository-registration fixture row and no runs. No pipeline-control command was executed.
- Named-head publication used a disposable local bare Git repository. It did not publish to GitHub or Bitbucket; the Bitbucket URL was the worker's readiness-report input, not a claimed real PR.
- The resolver used a disposable executable site hook and real `no-mistakes daemon status` reads. It never started a daemon.
- Herdr feasibility checks used only the named-lab helper. The ambient prepare record was torn down without provisioning a server. An isolated XDG namespace could not satisfy the helper's required running-default tripwire, so real-agent scenarios used the private tmux route instead. No default Herdr session or fleet pane was mutated.
- Initial supplemental-test failures were fixture-placement issues: secondmate homes and external extension packages intentionally refuse checkout-contained paths, and one branch-name fixture embedded a dot-prefixed TMPDIR. Rerunning those suites with their normal temporary-directory behavior passed. Only incidental toolchain temporary files used that allowed exception.

## Focused regression checks

The following completed successfully on the target; this was not the full repository suite, and no lint/static-analysis phase ran:

- `tests/fm-capacity.test.sh`
- `tests/fm-secondmate-harness.test.sh`
- `tests/fm-brief.test.sh`
- `tests/fm-composer-lib.test.sh`
- `tests/fm-backend-paseo.test.sh`
- `tests/fm-pr-bitbucket.test.sh`
- `tests/fm-gotmp.test.sh`
- `tests/fm-dod-lib.test.sh`
- `contrib/iqx-ixia-hook/ixia-hook.test.sh`
- `tests/fm-watch-triage.test.sh` selectors: `test_unknown_alive_stale_is_bounded_after_its_first_alarm`, `test_unknown_alive_stale_without_progress_keeps_surfacing`, `test_wedge_threshold_defers_to_a_worker_blocker`, `test_wedge_threshold_worker_wait_is_off_until_armed`
- `tests/fm-extension-binding.test.sh` segments: `early-bind`, `lifecycle-flow`, `example`
- `tests/fm-crew-state.test.sh` selector: `test_no_run_overview_zero_branch_falls_through` (target pass; base failure reproduced)
- `tests/fm-session-start.test.sh` selectors: `test_omp_supervision_block_and_diagnostic`, `test_omp_diagnostic_checkout_home_keeps_restart_wording_and_names_cause`, `test_omp_diagnostic_accepts_prelock_loaded_marker`

Temporary copies added only selector entrypoints or evidence printing and were removed. Mock-backed checks above are supplemental, not live proof of the mocked service or native harness.

## Remaining native/integration gaps

- Real Paseo lifecycle: this is Linux, with no Paseo CLI or macOS GUI daemon. Needs a macOS host with Paseo >=0.8 running. Selection and missing-dependency behavior were exercised here; real tab lifecycle was not.
- Real Grok approval-titled UI: `grok` is absent from PATH and the repository supplies an adapter, not the CLI. Captured composer regressions passed, but no native Grok approval interaction was driven. Needs the supported CLI and an existing authorized login.
- Real OMP relaunch/extension registration: `omp` is absent from PATH. The three executable diagnostic regressions passed, but a native OMP session was not relaunched. Needs the supported CLI and its existing login.
- Native Windows Bash resolution: only Linux/Node/POSIX execution was available. The actual POSIX extension flow and wrapper conformance passed; Windows Git-Bash execution needs a Windows Node host with supported MSYS/Cygwin Bash.
- Authenticated Bitbucket API success/custom merge message: no authorized disposable Bitbucket Cloud repository and test credentials were supplied, and operator credentials/shared services were not used. The API is Cloud-specific, so a local mock is not live replacement evidence. The unchanged fork API paths passed the focused mock-backed suite; real credential absence failed closed. A live positive check needs a sandbox repository plus explicitly authorized test credentials and mutation authority.

No changed-UI screenshot is claimed: the changed native Paseo/Grok surfaces were unavailable. Claude terminal transcripts show the actual CLI interactions rather than a fabricated visual rendering.
