# Relaunch PR metadata validation

Compared base `09a587bc201b9d7f8ada8a601ebca12f2fdc72ca` with target `1f3ea3a9bd8c6131def7d001ea69c9391e5ee4db`.

## Targeted regression

Executed only these existing test functions from `tests/fm-control-relaunch.test.sh`, using a temporary selector in `tests/.pr-meta-focused.sh`:

- `test_relaunch_keeps_the_recorded_pr_identity_parseable`
- `test_traced_relaunch_keeps_the_recorded_pr_identity_parseable`

Commands: `env TMPDIR="$PWD/.v/tmp" HOME="$PWD/.v/test-home" TRACE_CASE=0 bash tests/.pr-meta-focused.sh` and the same with `TRACE_CASE=1`.

Both pass on the target. Both fail on the base implementation at the PR-identity assertion. The baseline was a disposable copy of `bin/`, `.agents/`, and `.tasks.toml` inside the worktree with only `bin/fm-spawn.sh` replaced by `git show 09a587bc201b9d7f8ada8a601ebca12f2fdc72ca:bin/fm-spawn.sh`; the selector ran with `BASELINE_ROOT="$PWD/.v/baseline"`. Baseline artifacts show the generated persisted metadata contract, not implementation-source matching. The untraced record puts `control_relaunch_tx` after the PR; the traced record additionally puts `traceparent` after it.

The selector used the shared writable-directory cleanup for spawn-owned read-only hook directories. Early attempts with the baseline copy lacked `.agents/` and failed setup; those attempts were corrected and are not counted as regression reproductions.

## Real runtime validation

`bash .v/drive-live.sh` (retained as `live-driver.sh`) drove real `bin/fm-pr-check.sh`, `bin/fm-control.sh`, `bin/fm-spawn.sh`, `bin/fm-watch.sh`, and wake-drain acknowledgement, with the installed Pi 1.1.0 CLI on an actual private tmux server. No multiplexer, harness, GitHub CLI, or watcher was stubbed. The terminal was initialized at 120 columns by 40 rows; tmux owns and drains its pty.

1. Registered a PR and forge-supplied head through the real PR-check command. Relaunched with tracing off. The generated record retained the PR/head/X fields, carried the transaction before the PR, parsed successfully, and authenticated the original poll.
2. Relaunched with tracing on, then again with the already-recorded carrier. The carrier stayed valid, unchanged on reuse, and present exactly once before the PR block. The original poll remained authenticated.
3. Appended a non-PR transaction line after the PR block. The real watcher rejected the original poll as an unauthenticated state check, kept its artifacts, and did not produce a merge-notified marker.
4. Restored the exact good record, acknowledged the rejection through the real wake protocol, and ran the watcher again without rearming the poll. It read GitHub's merged state, emitted `prlab.check.sh: merged`, persisted `check: merge landed: ... external`, published the identity-bound notification marker, and retired the original poll.

Used historical public PR `https://github.com/cli/cli/pull/1`, already merged, as a read-only forge fixture. No PR was created, pushed, or merged. This proves detection on the next poll after relaunch, not observation of a newly occurring remote merge.

Scope is Firstmate process replacement, metadata publication, authentication of its merge poll, and watcher notification. **No authenticated model turn was exercised.** Pi used a disposable config/home; its TUI reported no model credentials. Its actual running process was stopped and replaced by the real control plane, and the resulting record was consumed by the real watcher. No claim about worker inference or normal Pi login availability is made. Normal Claude login was confirmed by `claude auth status` but not used for relaunch because that path preregisters trust in the operator's config store; no production credential or tool configuration was changed.

## Isolation and cleanup

The marked home, fixture Git repository and linked worktree, Pi config, tmux sockets, local tool builds, and temporary selectors all lived inside this gate worktree. Lifecycle used the marked-home allowance, not a bypass. tmux was absent on PATH and apt had no candidate, so tmux 3.6a and its Bison build prerequisite were materialized locally, without global installation. All were removed after testing; each runtime attempt killed only its private `fm-lab` server and removed its lab home. Home-bound incidental `/tmp` launch staging was removed by exact generated identity.

An initial named Herdr-lab prepare probe used the trusted helper with a worktree-local tripwire directory. No Herdr lab server was provisioned; the prepare-only lab was torn down through the same helper, which verified the default-session tripwire. No fleet panes were touched.

Early live attempts met Pi's session-trust dialog, and one watcher attempt hit the wake recovery protocol because the fixture removed its queue instead of acknowledging it. These fixture problems were corrected: trust was accepted only for the disposable session, and rejection wakes were acknowledged with the product's exact sequence/generation. The final full runtime driver exited 0.

No complete suite, linters, formatters, static analyzers, pipeline phases, pushes, PR operations, or CI runs were invoked. This change is persisted CLI state, not a visual-layout change; evidence is CLI transcripts, generated metadata and durable watcher outputs rather than screenshots.
