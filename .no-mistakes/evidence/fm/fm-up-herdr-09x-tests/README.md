# Focused real-Herdr validation

Target: a379184082fce2b45f63f13a4907617b370f3f01. Baseline: 98d80a1616467b522d454261b0833aa538c467ca.

## Results

All three changed executable tests passed against actual Herdr 0.7.4, 0.9.2, and 0.9.3. No complete repository suite, linters, static analysis, publication, PR, or CI phases were run.

- [Version matrix](herdr-version-matrix.log): `bash tests/fm-backend-herdr-smoke.test.sh`, `bash tests/fm-backend-herdr-respawn-idem-e2e.test.sh`, and `bash tests/fm-control-herdr-smoke.test.sh` on each version. The default fixture shell started with `❯`; the changed control test itself selected and cleared its neutral shell. Each final invocation returned exit 0. The unrelated opt-in real-Claude busy-state branch was not enabled: this change explicitly uses agent-named stand-in processes, not authenticated model sessions.
- [Before/after regressions](before-after-regressions.log): the unmodified baseline duplicate tests happened to pass without settling. With a two-second observation delay immediately after real `pane report-agent`, both baseline duplicate cases failed while both target cases passed. With a two-second delay after the foreground process exits, the baseline control test failed because the top-shell registration disappeared; the target retained its nested-shell registration and passed. A target control variant retaining the nested-shell fix but omitting neutralization reproduced the `❯` composer-pending-text misclassification. The checked-in target control test also passed from a plain prompt (`0.9.3-control-plain-prompt.log`). Delays change observation timing only; there are no canned API responses.
- [Registration probes](registration-probes.log): real Herdr 0.9.2 and 0.9.3 both cleared a top-shell registration by the two-second observation; both retained a foreground nested-shell registration. A real `claude`-named symlink to `sleep` held registration, and after killing that fixture process the remaining nested shell still retained the registry entry while Firstmate classified it `stale-agent` / recovery `dead`. This directly verifies the documentation correction.
- [Live shell viewports](shell-viewports.html): rendered HTML of the actual initial and neutralized pane-read captures. These are terminal viewport renderings, not native screenshots. The change alters test fixtures and verification prose, not product UI.
- [Lab cleanup](lab-cleanup.log): no named fixture sessions remain. Every completed lab interval used the helper's default-session tripwire; the live default was read only for that tripwire, never controlled. All worktree fixtures, downloaded binaries, transient baseline variants, and drivers were removed; the worktree is unchanged.

## Isolation and execution mechanics

Fixtures lived in disposable `.v/` under the run worktree, with isolated HOME, FM_HOME, TMPDIR, XDG configuration/data/cache, Git projects/worktrees, shell startup file, and `FM_HERDR_LAB_STATE_DIR`. No production credentials were used. The only link to the real default session was a socket symlink supporting the helper's read-only session-list tripwire.

The existing Herdr 0.9.3 on PATH was used. Herdr 0.7.4 was downloaded inside the worktree using `bin/fm-install-herdr.sh <worktree>/.v/0.7.4`, including its pinned SHA-256 and protocol checks. Herdr 0.9.2 was fetched from its official release and checked against GitHub's asset digest `74de34746f96236f76d599f8f5d2439f884351eabe25b7495e0edab75414064a` before execution. Both downloaded binaries were removed afterward.

The absolute isolated config path first exceeded Linux's Unix-domain socket-name limit. The driver used a worktree-relative XDG_CONFIG_HOME and kept real CLI invocations at the worktree root instead. The transparent lab relay canonicalized only the named-session socket path returned by session list to its equivalent absolute spelling, because Firstmate correctly refuses relative socket identities. Other agent/process API bodies came directly from real Herdr. Server startup was delegated to `bin/fm-herdr-lab.sh provision`; operational calls to `run`; stop and deletion remained inside the test's lab-helper teardown. Since these tests prepare before adapter startup but provision auto-prepares absent sessions, the relay verified and finished that initial read-only tripwire interval before provision recorded its own identical snapshot.

Initial fixture runs produced cleanup-only permission errors from deliberately read-only Git hook directories. A fixture-only removal relay restored write permissions exclusively beneath `.v/tmp/` before disposal. The control smoke test was then re-driven on all three versions and passed without those disposal errors. No product or checked-in test was modified to accommodate the environment.

Reproduction drivers are retained as evidence: `isolation-driver.sh`, `herdr-lab-relay.sh`, `registration-probe-driver.sh`, and `fixture-cleanup-relay.sh`. Example exact invocations used before disposal:

```sh
FM_REAL_HERDR="$PWD/.v/0.7.4/herdr" .v/drive.sh timeout 180 bash tests/fm-backend-herdr-smoke.test.sh
FM_REAL_HERDR="$PWD/.v/0.9.2/herdr" .v/drive.sh timeout 180 bash tests/fm-control-herdr-smoke.test.sh
.v/drive.sh timeout 180 bash tests/fm-backend-herdr-respawn-idem-e2e.test.sh
FM_REPORT_AGENT_SETTLE=2 .v/drive.sh timeout 180 bash tests/.baseline-fm-backend-herdr-smoke.test.sh
FM_REPORT_AGENT_SETTLE=2 .v/drive.sh timeout 180 bash tests/fm-backend-herdr-smoke.test.sh
.v/drive.sh timeout 180 bash tests/.settled-baseline-control.test.sh
.v/drive.sh timeout 180 bash tests/.settled-target-control.test.sh
.v/drive.sh timeout 180 bash tests/.adversarial-control-unpinned.test.sh
.v/drive.sh timeout 90 bash .v/manual.sh
```

Baseline variants were generated from the base commit with `git show`; settled-control variants added only the two-second observation delay before reading the registry after process exit. The unpinned-prompt variant omitted only neutral-shell initialization, preserving the nested-shell fix. They were removed after execution. The raw individual test transcripts and agent/process-info API logs remain available beside the combined evidence.
