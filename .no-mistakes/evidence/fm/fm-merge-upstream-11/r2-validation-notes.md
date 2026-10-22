# Targeted live-validation round 2

The actual Firstmate scripts ran from target e4683355 in marked disposable homes. Every lifecycle driver explicitly set FM_BACKEND=tmux and used the lab's private `fm-lab` tmux socket. No default Herdr lifecycle call was made. Native tools were obtained only inside `.test-live/`; all such downloads and lab homes were removed at completion.

## Demonstrated product behavior

- `r2-cli-transcript.txt`: real capacity report (including actual CPU constraint), malformed target refusal, per-mate harness/model/effort selection and duplicate refusal, explicit-only Paseo selection and missing-dependency refusal before allocation. The generated ship/scout briefs are emitted public contracts, not evidence of model compliance.
- `r2-spawn-transcript.txt`: actual Claude primary, Treehouse scout lease, 0700 home-local task temp and GOTMPDIR, peek/state reads, and teardown removing the recorded temp and metadata. The worker used a disposable Claude config and reached onboarding; authenticated worker execution is **not** claimed.
- `r2-watch-transcript.txt`: actual live Claude endpoint; initial stale alarm, bounded repeat while recent progress exists, then renewed alarm with no progress. Recovery-grade liveness was explicitly asserted. Earlier attempts using the damaged launcher were setup failures, not product results.
- `r2-wait-transcript.txt`: real watcher arm, home watch.env overriding ambient polling, bounded worker-blocker recheck when opted in, and ordinary wedge escalation without the opt-in. An active-job semantic recovery event was disposable input data, not a claim that a model was running that job.
- `r2-head-transcript.txt`: real current-state CLI blocked an unpreserved named head despite a CI-ready Bitbucket report, then read done after local-only publication to a disposable bare remote. No real forge API or pipeline was used.
- `r2-fork-transcript.txt`: actual hook installation/idempotence and git commit preserving the # subject and human trailer with exactly one Ixia trailer; unrelated-origin installation refused. Actual Bitbucket merge CLI refused missing credentials. No authenticated merge was attempted.
- `r2-history.txt`: the retained two-parent merge has the fork base and upstream 83b70ef4 as parents, includes 12 commits after a65dceee, and retains both ancestries. No push/PR/CI phase was executed.

## Focused non-live checks

Selected composer, crew-state, watcher, relaunch, and NM-home-resolver tests passed. The targeted Bitbucket PR, task-temp, IQX hook, Paseo adapter, supervision-output, and extension-binding checks passed. No linter, formatter, static analyzer, or complete repository suite ran.

The first extension-binding invocation rejected its package fixtures because TMPDIR was inside a Git worktree. Re-running with disposable test-evidence fixtures outside the Git tree passed both the changed early-bind segment and the whole targeted extension-binding file. Its remote-fixture missing-include diagnostics did not make the suite fail; the local shipped file-signal adapter was actually bound, invoked, captured, and retired.

## Limits and safety incident

`r2-native-availability.txt` records Linux, absent native Paseo/OMP/Grok CLIs, and the supported Herdr prepare helper refusing the worktree-local namespace because it lacks the required running-default tripwire. No alternate/default session was provisioned to bypass that guard. Native Paseo GUI behavior, native Grok/OMP interaction, and authenticated Bitbucket API checks remain untested. The disposable no-mistakes reader reported an uninitialized repository; creating or controlling a pipeline is outside this phase. Emitted OMP instructions and portable tests are not native-harness evidence.

There are no screenshots: the changed runtime surfaces were exercised as CLIs/TUIs with actual pane transcripts, not browser/layout changes; Paseo's macOS GUI is unavailable here.

**No-go: validation safety incident.** Claude's native installation/updater activity repointed the existing user launcher into the disposable XDG data tree. The lab teardown temporarily left that launcher broken. Subsequent tests used an independently downloaded worktree-local Claude binary with auto-updates disabled. A final read-only observation found the normal launcher pointing back to `/home/node/.local/share/claude/versions/2.1.307` with an executable target, without any explicit agent repair command. `r2-launcher-incident.txt` and `r2-launcher-final-state.txt` record both observations. The operator must verify that this final target is their intended installation and decide whether to accept the out-of-worktree mutation incident. This was not an identified Firstmate code regression. No previous-round external resources were inspected or changed.
