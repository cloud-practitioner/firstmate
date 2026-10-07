# Live process-identity validation

Runtime: Linux, real Herdr 0.9.3 and real Pi 1.0.4. No canned Herdr or harness responses were used for the live scenarios. All Herdr traffic used `bin/fm-herdr-lab.sh` through named `fm-lab-*` sessions. Disposable marked homes, an unchanged archived product checkout, and linked task worktrees stayed inside the gate worktree. Lab teardown verified the default-session fleet tripwire.

## Drift and safety evidence

[`live-identity.log`](live-identity.log) shows repeated identical kernel identities, live Pi classification under legacy timestamps offset by -1/0/+1 seconds, and the pre-fix adapter reporting `missing` for the same real pane and +1-second record. The real secondmate sweep probe returned `alive` with `kill=0`. The no-/proc route used the actual `ps` utility and also accepted the offsets. Removing both identity readers returned `unreadable` and refused active Ctrl+C. Mismatched identities returned `missing`, refused Ctrl+C, and left the unrelated real agent intact.

The legacy offsets were deliberate persisted-record fixtures; this does not claim the host's clock happened to jitter naturally during the run. The no-/proc and missing-ps cases used disposable process-reader configuration/PATH isolation, not a BSD host or a fake ps executable.

## Public recovery evidence

[`live-recovery.log`](live-recovery.log) records the real `fm-control.sh` worker relaunch, named-session stop/reprovision, worker rebind with a different root identity, and real `fm-secondmate-restart.sh` completion. The secondmate restart was invoked from a real sanitized Pi primary using Pi's shell-command interface in the disposable unchanged product checkout. Its persist request was acknowledged manually through the actual `fm-secondmate-report.sh` parent-channel protocol for the empty fixture; this proves restart/identity publication, not autonomous LLM interpretation of /stow.

| Persisted state | Endpoint | Root-process identity |
| --- | --- | --- |
| Worker before | `fm-lab-recovery-2971997-3994:w1:p1` | `ps:2973522:Wed Oct  7 02:48:46 2026` |
| Worker after legacy refresh | `fm-lab-recovery-2971997-3994:w1:p1` | `proc:2973522:df641d85-7c77-431d-8f5f-c3a804278bd8:44071834` |
| Worker after actual process replacement/rebind | `fm-lab-recovery-2971997-3994:w1:p2` | `proc:2989582:df641d85-7c77-431d-8f5f-c3a804278bd8:44073352` |
| Secondmate before | `fm-lab-recovery-2971997-3994:w2:p1` | `ps:2998471:Wed Oct  7 02:49:10 2026` |
| Secondmate after public restart | `fm-lab-recovery-2971997-3994:w2:p1` | `proc:2998471:df641d85-7c77-431d-8f5f-c3a804278bd8:44074226` |

The generated `.meta` files are retained alongside this report. Each refreshed record has exactly one identity line; every published identity equaled a fresh read of its real pane root. Worker recovery preserved the linked worktree. CLI pane captures and raw Herdr responses are also retained.

## Targeted regression checks

Only these executable test functions from `tests/fm-backend-herdr.test.sh` were run, by loading the suite definitions without its full invocation list:

- `test_process_identity_is_portable_and_distinguishes_pid_reuse`
- `test_process_identity_is_stable_across_ps_lstart_drift`
- `test_lstart_drift_does_not_make_a_live_pane_foreign`
- `test_relaunch_refreshes_the_recorded_process_identity`
- `test_spawn_and_relaunch_continue_without_process_identity`

[`targeted-regressions.log`](targeted-regressions.log) is supplemental fixture-based evidence, not live product evidence. No full suite, lint, formatter, static-analysis, push, PR, or CI phase was run.

## Reproduction drivers

The executed temporary drivers are preserved as `live-identity-driver.sh` and `live-recovery-driver.sh`; run from the gate worktree. Before invoking the identity driver, create `.identity-validation/live` and populate its `base-herdr.sh` using `git show e2b97788aa9a750d0cb51a3e2cd4eded8a6cea00:bin/backends/herdr.sh`. Both drivers tear down their labs in the same run. Initial setup retries resolved duplicate prepare/provision tripwires, inherited FM_* overrides, the restart subprocess's gate environment, and read-only generated hook-directory cleanup. Final live runs succeeded.

No UI/layout/copy change is involved: persisted identities, CLI outputs, and process/agent API responses are the acceptance surface; no screenshots were needed.
