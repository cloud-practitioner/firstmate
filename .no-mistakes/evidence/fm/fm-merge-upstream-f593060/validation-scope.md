# Merge-upstream targeted validation

Target: 016f7fca9b6e75709846fadd9c3bc969404af932
Base: c79ae08554f0a59e206d66635c8c29c7d364115b

Only this repository's existing tests and sources were used. No downloads, outside builds, package installs, production sessions, or credential mutations were performed. Git archive materialized disposable copies of the target and base under `.gate-test-scratch/`. All copies, fixture repositories, test data, and runners were removed before completion. No source changes or feature-branch commits were made.

## Invocation environment

Commands cleared FM_HOME, FM_BACKEND, FM_ROOT_OVERRIDE, FM_STATE_OVERRIDE, FM_DATA_OVERRIDE, FM_CONFIG_OVERRIDE, FM_PROJECTS_OVERRIDE, and PI_CODING_AGENT. TMPDIR was the worktree's `.gate-test-scratch/tmp`. Evidence-producing runs set FM_TEST_EVIDENCE=1. Timeouts used TERM with a bounded KILL fallback.

## Completed checks

- `timeout --signal=TERM --kill-after=20 150 bash -x tests/fm-parent-channel-scan-exclusion.test.sh`: passed. Real wake drains omitted the outbound remote channel, retained genuine task content, and discarded old phantom channel cursors. Supporting function-level checks covered main/local home shapes, watcher scans, and both heartbeat scans. Function-level checks alone are not live daemon evidence.
- `timeout --signal=TERM --kill-after=20 90 bash -x .gate-test-scratch/code/tests/fm-backend-targeted.test.sh`: passed. Selected the existing `test_backend_source_shell_portable` and `test_backend_source_requires_adapter_file` functions, retaining their setup and assertions. These are shell-library compatibility checks, not a live multiplexer session.
- `timeout --signal=TERM --kill-after=30 300 bash .gate-test-scratch/code/tests/fm-supervision-targeted.test.sh`: passed after restoring the complete source fixture. Selected the existing half-second probe case and all six park-boundary/clock/limit cases. Existing real host, watcher, arm, drain, lease and outcome scripts ran; the suite's existing fake primary and engine remained test dependencies. This does not prove delivery to an authenticated real harness primary. Added output collection at the suite's cleanup boundary only, preserving test assertions.
- `timeout --signal=TERM --kill-after=30 150 bash .gate-test-scratch/base/tests/fm-remote-job-queue-targeted.test.sh` and the same target-code command: passed. Selected each revision's own suite through `queued jobs receive a fresh bounded execution window`, and printed the returned exit and persisted job fields before its existing assertion. Base and target both returned exit 0 with an independent execution deadline.
- `timeout --signal=TERM --kill-after=30 300 bash .gate-test-scratch/code/tests/fm-remote-reply-targeted.test.sh`: passed. Retained original source lines 1–434 (setup/capture/documents/decisions/replays), 871–930 (continuous listener and transport failure), and 1027–end (quiet watermark/cursor-loss/truncation/retirement). Set GEN=4 at the selection boundary to reflect omitted generations; assertions were unchanged. Added output collection for the rebuilt cursor and mirror. The SSH shim routed calls to the real entrypoint, worker, reader and relay, all operating on disposable local homes.
- `timeout --signal=TERM --kill-after=30 150 bash .gate-test-scratch/code/tests/fm-remote-job-poll-targeted.test.sh`: passed. Selected the original suite through sibling-poll non-preemption, printing its actual preemption exit/time and re-armed delta response. The real worker preempted a long poll with exit 76, ran the queued command in two seconds, and delivered the preserved-cursor delta on re-arm.
- `git merge-base --is-ancestor f593060 HEAD`: succeeded. `git diff --exit-code c37a5f4228aeec31f4e5046a1e01fe3a4269e967 HEAD`: empty. The elapsed-age auto-fix remains reverted and the merge tree is unchanged. Final git status and diff were clean.

## Earlier attempts and limitations

The initial remote-reply run from the gate checkout failed capture with exit 64 because its fixture home was beneath its real code root; the remote protocol refuses overlapping root/home paths. Copying this repository's code beside, rather than around, its fixture homes resolved that setup error.

A broader unchanged remote-reply suite attempt reached successful capture, mirroring, decision folding and document/storage-failure cases, then exceeded its 480-second bound before finishing the receipt-failure/cursor-loss sequence. The smaller targeted selection subsequently exercised ordinary cursor loss and completed successfully; this is not a claim that the broader suite finished or that receipt-failure recapture was freshly validated.

An incomplete copied supervision fixture lacked imported dispatch material and failed branch eligibility. Repeating the same selected cases with the complete tracked source fixture passed.

A broad remote-job run under `bash -x` failed its three-second queued execution assertion. Subsequent untraced targeted base and target comparisons both passed; the untraced target preemption selection passed as well. No stable merge regression was established, and tracing overhead is not treated as normal-product timing proof.

An initial backend selection inadvertently retained unrelated history-conformance setup and demanded a default-branch ref in the disposable copy. Keeping only setup and the selected existing function definitions resolved that selection error without fetching history.

The previously confirmed elapsed-age supervision flake was not fixed or re-reported: the human decision explicitly keeps it as a separate follow-up. Real authenticated primary delivery was not attempted under the suite-only instruction; no fake primary is presented as a successful login or harness proof. No UI change was validated, so no visual capture was required.
