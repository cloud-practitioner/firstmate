# Scoped Test phase, round 2

Target: `e1917df0d95bb8e00756f41486cd42d468e30d46`; fork base: `61b748936d05158279c53cefb63db770463283aa`.

## Live evidence from this turn

- `manual-pr-live.log` and `manual-pr-brief.md`: actual registry and scaffold commands in a marked disposable home. Manual PR text preserves the default two-word delivery posture; invalid mode/PR combinations refuse. The brief is generated public output, not proof of subsequent model compliance.
- `hidden-untracked-live.log`: real linked Git worktree with `status.showUntrackedFiles=no`. Ordinary status is empty, but real teardown refuses and names the untracked path. File bytes, task metadata, and HEAD remain unchanged. No backend or pool stub was used for this refusal. The clean-control return also passed the selected existing regression (that regression uses fake terminal/pool dependencies).
- `remote-reply-live.log`, `remote-reply-capture.txt`, and `remote-reply-status.txt`: actual OpenSSH client connecting to a disposable loopback SSH server built with workspace-local ssh2. That server executes the tracked remote entrypoint, real job worker and real delta reader. Real parent ingestion appends one line; replay appends none. Fault injection at the SSH server returns diagnostic bytes with exit 255, then non-schema bytes with exit 0. Both are rejected with zero source stdout; neither changes the saved cursor or mirrored status. The owned remote worker was stopped successfully.
- `systemone-live.log` and `systemone-http-requests.json`: actual curl HTTP exchange with a disposable decision endpoint; real quota-axi runs with an empty isolated user home. The typed answer is accepted. With no measured Agy quota, the resolver honestly escalates rather than inventing a ranking. Endpoint never-send matching prevents a second request; a partial probability map yields an error without a profile. This is a local provider protocol proof, not a live external LLM calibration.
- `herdr-claude-round2.log`: real authenticated Claude launched only through `bin/fm-live-claude.sh`, in a named non-default Herdr lab with its fixed-size attached viewer. Claude returns `FM_MERGE15_ROUND2_READY`, exits zero, and leaves the host launcher target unchanged. Herdr teardown succeeds and verifies its default-session tripwire. All Herdr operations used `bin/fm-herdr-lab.sh`; no default pane or session was controlled.
- `round2-cli-evidence.html` renders the actual transcripts for review. It is not a screenshot of Agy.

The new evidence-producing driver scripts are retained as `round2-live-checks.py`, `round2-remote-live.py`, `round2-ssh-server.cjs`, and `round2-herdr-claude-live.sh`. The SSH dependency was materialized with `npm install --prefix "$PWD/.test-validation/ssh" --cache "$PWD/.test-validation/npm-cache" --no-package-lock --ignore-scripts ssh2` and removed with the disposable test root.

## Targeted regressions and setup corrections

- `bash tests/fm-dispatch-resolve.test.sh` passed. `openai-before-after-round2.log` additionally executes the pre-fix and fixed CLIs against the identical valid Decisions response and quota fixture: the pre-fix CLI errors, the fixed CLI emits a clear Cursor profile. Neither is a hosted OpenAI call. The narrowed driver is `round2-openai-differential.sh`.
- `bash tests/fm-agy-primary.test.sh`: the first run exceeded a 240-second command bound after supersession passed. A 600-second rerun completed all registered cases, including the revised total-budget and FIFO-readiness assertions. This is fake-harness regression coverage, not live model-hook evidence.
- `bash tests/fm-project-mode.test.sh` passed.
- `bash tests/fm-spawn-manual-pr-text.test.sh`: an initial inherited `FM_BACKEND=herdr` selected the wrong fixture backend. Removing that variable produced a clean pass for agreement and both mismatch refusals.
- Selected `tests/fm-teardown.test.sh::test_hidden_untracked_work_refuses_before_return` passed (dirty refusal plus clean control).
- Six selected `tests/fm-crew-state.test.sh` cases passed: stale failed overview, same-head stale failure, unverifiable timestamp, older-live/newer-completed, newer-live/not-hiding-a-newer-failure, and competing live runs. These used protocol fixtures, not a new real pipeline.
- Selected fork-preservation cases passed: Pi and pi-signed ship/scout MCP-off launches, per-task overrides and unsupported-runtime refusal; steering-inbox busy grace and later idle escalation; secondmate stand-down preservation, in-flight refusal and dormant sweep behavior.
- Selected evidence-gate/Bitbucket cases passed. The initial 200-second attempt expired while repeatedly constructing filtered executable paths from the host's large `/usr/bin`. A traced retry confirmed that setup bottleneck and was stopped deliberately. The final rerun used a workspace-local `FM_TEST_BASE_PATH` containing only real required executables, and passed both `test_arming_and_merge_go_through_the_gate` and `test_bitbucket_arm_is_off_by_default_and_works_when_on`. Its top-level setup also runs the existing Python evidence regressions. All forge interactions in these regressions were with the local stub forge; no real PR was created or merged.

Early versions of the disposable live driver corrected two assertion assumptions about generated output (`--skip pr,ci` spelling and the never-send diagnostic), and changed its quota expectation to the real empty-home escalation. Those setup corrections are not product failures.

## Live limits and phase ownership

- Installed Agy 1.4.10 requests authentication in an isolated HOME. The probe was interrupted without signing in or reading/copying production credentials. Model-driven primary/secondmate SessionStart, PreToolUse and Stop behavior remains untested. No Agy screenshot exists because the CLI did not reach an authenticated session.
- The real OpenAI provider reports `OPENAI_API_KEY absent`; see `openai-live-credential-check.log`. No authorized disposable key with Decisions API access was provided. The mapper regression passes, but a fixture cannot establish hosted API compatibility.
- Creating genuine historical and concurrent no-mistakes runs requires pipeline initialization/control, which is expressly forbidden to this assigned phase. Real competing-run attribution remains untested; a separate authorized fixture history or out-of-phase validation is required.
- Read-only Git checks in `merge-topology-round2.log` show a two-parent upstream merge, seven upstream commits, preserved fork-base ancestry and unchanged contrib add-on trees. These are structural evidence, not live runtime scenarios. PR publication, eventual merge method and remote CI remain the outer executor's phases.

No complete repository suite, linter, formatter, static analyzer, pipeline-control, push, PR publication, or real merge command was run. No source or test-file edits were made. Disposable homes, workers, sessions, downloaded dependencies, caches and temporary selectors were removed from the worktree; dedicated evidence remains.
