# Targeted live validation — upstream merge

Target: `bdc969f0f6a5caba5f140af36ea6a5b822c1589b`.
Baseline: `72563c7d9189659cfd81e57bd583d8646ffa16eb`.

## Acceptance context and merge conflicts

Read-only Git inspection confirms the target has exactly two parents: the requested fork baseline and upstream `f470a01c098c1536d83b802874bd954a2c04b506`. Its first-parent delta is one merge commit, not a squash or rebase. Upstream contributes precisely the eight requested commits: #6575, #6431, #6518, #6505, #6490, #6530, #5863, and #5489.

The merge commit records two conflicts:

- `bin/fm-brief.sh`: retained upstream #6505's proof/scratch placement, authorization, and clean-worktree guidance; retained the fork PR #32 task-private scratch-root rule alongside it. The actual emitted brief was generated through `bin/fm-brief.sh` and saved as `round2-generated-brief.md`. This proves the generated prompt contract, not how a model interprets it.
- `tests/fm-calm-pi-extension.test.sh`: selected upstream #6530's version over fork PR #38. `git diff --exit-code HEAD^2 HEAD -- tests/fm-calm-pi-extension.test.sh` returned zero. Its focused renderer contract and an actual Pi 1.0.1 `/export` were exercised.

No tracked source or test changes were made by this Test turn. The previous timeout's `.validation/` directory and all new disposable fixtures are removed before returning. Publication, PR title `Merge upstream firstmate into the fork`, and eventual merge-commit landing remain owned by the outer executor; no PR or pipeline control was invoked here.

## Product-level evidence

| Scenario | Observed result | Evidence |
| --- | --- | --- |
| Serving during a due sequence-claim sweep | Real worker completed a queued command in 1 second with 17,460 seeded claim directories; 8,730 expired claims removed, fresh boundary retained. | `remote-claim-receipt.txt` |
| Unchanged worker retention and independent heartbeat | Three ensure calls retained the owner without repair. Holding the serving process with SIGSTOP for 12 seconds did not cause replacement. Its real heartbeat recreated a deleted ready file for the same owner with mode 0600. | `remote-claim-receipt.txt` |
| Busy worker instruction escalation | Actual Pi CLI held an active provider turn in a private 120×40 tmux session. The real inbox/watcher queued a stuck-busy wake after two due deferrals without typing a doorbell; instruction remained durable. Wake acknowledgement and a successor watcher did not duplicate the escalation. | `live-inbox-wake.txt`, `live-inbox-queue.txt`, `live-inbox-busy-state.txt`, `live-inbox-pane.txt`, `live-inbox-ack.txt` |
| Dirty teardown refuses without data loss | Real `fm-teardown.sh` refused tracked, untracked-only, and mixed dirt in both local-only and no-mistakes modes, even with committed work already landed. Every refusal preserved Git state, task metadata and the actual private tmux endpoint. Paths with spaces were named, exemptions omitted, lists bounded to ten entries. | Six `round2-teardown-*.txt` transcripts |
| Quota transient failures, timeout recovery and streak reset | Real `fm-procevent-quota.sh` and installed quota-axi 0.1.55 used its supported disposable snapshot input. A Node preload fault injector deliberately failed or hung the real dependency process; it did not replace the CLI or generate its successful JSON output. Two failures or timeouts recovered on read 3; a successful healthy read reset the budget, permitting two further failures before exhaustion on read 6; three uninterrupted failures surfaced error. | `round2-real-quota.log`, `round2-real-quota-{transient,reset,persistent,timeout}.txt`, matching `-calls.jsonl` traces |
| Pi hidden-processing retries | Real Pi 1.0.1 SDK sessions, extension event runner, stock assistant renderer and persistence suppressed repeated/empty retry finals, retained first/differing replies across reopen, buffered retry streaming, preserved retryable outcomes, and displayed a subsequent genuine user answer. Model replies were disposable local provider input; the Pi runtime/extension/renderer were real. | `round2-branch-live.log`, `pi-retry-{repeated,differing,empty,first-empty}.jsonl`, `pi-retry-repeated.html`, `pi-retry-repeated.png` |
| Watcher successor gap and opt-in diagnostics | Actual Pi CLI with the real watcher extension and shell watcher was stopped across predecessor exit, leaving a three-second successor gap. Both first and successor events reached the local provider; the watcher chain continued. Diagnostic log was absent by default and present within a 20-line bound with opt-in. | `live-watcher-{default,optin}.txt`, matching deliveries, provider-inputs, pane and session artifacts; `live-watcher-optin-extension-log.txt` |
| Pi 1.0.1 Calm HTML export | Actual Pi 1.0.1 TUI executed real grep/find/watcher tools, preserved successful tool results, hid tool-result detail in Calm, and exported through its `/export` command. A real Chromium browser rendered the export and retry transcript; screenshots show tools and genuine replies. | `native-pi101-calm-session.jsonl`, `native-pi101-calm-pane.txt`, `native-pi101-calm-export.html`, `native-pi101-calm-export.png`, `round2-visual.log` |

The first screenshot assertion counted a reply in both the sidebar and conversation. That disposable driver error was corrected to assert on `main .assistant-text`; the rerun passed. Missing browser shared libraries were downloaded and extracted only under the worktree and removed after use. No host packages or configuration were installed or changed.

## Before/after reproduction

The same claim-sweep driver against the baseline worker/library failed as expected: the job stayed queued for 15 seconds during the due sweep. The target completed the same workload in 1 second. See `round2-baseline-claim.log` and `remote-claim-receipt.txt`. The baseline files existed only in a disposable worktree-local fixture.

## Focused non-live checks and explicit limitation

`tests/fm-remote-job-launchagent.test.sh` passed against the real worker/library with simulated launchctl. This checks stale predecessor readiness, missing-ready recovery during a blocked sweep, concurrent ensure serialization, unchanged tracked-owner retention, stale/untracked-code replacement, repair-lock recovery, and asynchronous bootout. It is **not** native launchd evidence.

Native macOS LaunchAgent integration is untested: this runner is Linux and has no launchctl/launchd. Linux worker serving and independent heartbeat were exercised live; the Darwin branch was exercised with the repository's focused launchctl simulation. Downloading or building another Linux CLI cannot supply a macOS service manager. To validate native integration, provide an authorized disposable macOS runner/account with launchctl and a writable isolated LaunchAgents home. No remote/shared host or production service was accessed.

The renderer contract copied into the previous round's disposable `.validation/calm-renderer.sh` was rerun against Pi 1.0.1. Its evidence is `round2-calm-renderer.log`. Only targeted checks ran; no full repository suite, linter, formatter, static analyzer, or other gate phase ran.

## Reproduction commands executed

- `TMPDIR="$PWD/.validation/tmp" timeout 180 bash .validation/remote-proof.sh` (rerun with independent-heartbeat adversary under a 90-second bound).
- `TMPDIR="$PWD/.validation/tmp" timeout 180 bash .validation/quota-proof.sh` (initial isolated provider-feed check; subsequently strengthened using the actual quota CLI).
- `timeout 50 bash .validation/quota-real-live.sh`.
- `TMPDIR="$PWD/.validation/tmp" timeout 180 bash .validation/live-inbox.sh`.
- `TMPDIR="$PWD/.validation/tmp" timeout 180 bash .validation/live-watcher.sh`.
- `TMPDIR="$PWD/.validation/tmp" timeout 180 bash .validation/live-export.sh`.
- `TMPDIR="$PWD/.validation/tmp" FM_PI_PACKAGE_DIR="$PWD/.validation/pi101" FM_PI_BRANCH_LIVE_E2E=1 timeout 180 bash .validation/branch-live.sh`.
- `TMPDIR="$PWD/.validation/tmp" timeout 120 bash .validation/dirty-live.sh`.
- `TMPDIR="$PWD/.validation/tmp" timeout 150 bash tests/fm-remote-job-launchagent.test.sh` (simulated launchctl, not live macOS).
- `TMPDIR="$PWD/.validation/tmp" FM_PI_PACKAGE_DIR="$PWD/.validation/pi101" timeout 90 bash .validation/calm-renderer.sh`.
- Real Pi `exportFromFile` exported the newly persisted retry session; `LD_LIBRARY_PATH="$PWD/.validation/libdeps/root/usr/lib/x86_64-linux-gnu" PLAYWRIGHT_BROWSERS_PATH="$PWD/.validation/browsers" timeout 30 node .validation/visual-live.cjs` rendered and captured both exports.
- `TMPDIR="$PWD/.validation/tmp" timeout 100 bash .validation/baseline-claim.sh` (expected baseline starvation failure).

Disposable drivers are archived under `round2-drivers/` for auditability. Their original worktree-local dependency/fixture directories are deliberately removed, so reruns require materializing those dependencies locally again.
