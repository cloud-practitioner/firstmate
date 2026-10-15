# Catch-up merge: targeted Test evidence

Head: `478d89cfd6489d8df86eea4cf0fccaae9f0a7879`.
Base: `71019c365917666ca19398f8968e0d5815c6c87b`.

## Live product checks

`python3 live-scenarios.py`, launched from the assigned worktree, drove the actual tracked CLI scripts with marked disposable homes, real Git repositories, persisted state, a real foreground watcher, and a live lifecycle-lock holder. All eight final scenarios passed. It removed its fixture homes after execution. `live-results.json` indexes their final product transcripts.

- Away entry counts ordinary task records, excludes secondmates, retains the floor, honors an explicit cap, rejects zero, and refuses a new spawn at the cap without changing worker metadata.
- A foreground checkpoint announces an outstanding recovery only once, retains the unacknowledged queue, and releases its singleton lock on timeout.
- Self-repository brief generation refuses absent/wrong-target consent, accepts the exact fork target, and refuses overwrite. No hosted publication occurred.
- A real Git commit strips Command Code attribution, preserves a human coauthor and inherited credential-helper configuration in the repository hook. A real local-only Git transport cannot bypass the project's refusing pre-push hook.
- An old-generation Stop callback cannot idle a replacement or publish its turn-ended marker; a matching callback can.
- Explicit Forgejo registry binding generates the right delivery contract and rejects the nonsensical local-only combination. The registry's Forgejo yolo setting remains unchanged; the Gerrit-specific yolo restriction was not incorrectly applied to Forgejo.
- An unsupported GitLab contribution stays unmeasured, not captain/fleet work or proven silence, and polling generates no wake.
- Both control-plane and direct-spawn relaunch calls refuse an actually held lifecycle lock without changing the secondmate's metadata or active dialog.

`generated-forgejo-brief.md` is actual public output from the scaffold, not a snapshot of implementation source.

## Supplemental behavioral tests and setup corrections

Original component commands (not the repository-wide test suite):

- `bash tests/fm-afk-contract.test.sh`: passed.
- `bash tests/fm-git-strip-ai-trailers.test.sh`: passed, exercising real Git repositories and hooks.
- `bash tests/fm-watch-checkpoint.test.sh`: passed.
- `bash tests/fm-contributions.test.sh`: initially reported three cross-home fixture failures. With TMPDIR inside the gate worktree, the child fixtures were descendants of the actual code root; the product correctly rejects those as secondmate homes. This was setup, not a merged behavior failure.
- `bash tests/fm-pr-merge.test.sh`: the bounded invocation timed out after 210 seconds; it did not establish a complete suite pass. Selected merge cases were subsequently run to completion.
- `bash tests/fm-spawn-orca-worktree.test.sh`: stopped at its first real-tmux prerequisite because tmux is not installed. No Orca live success is claimed.

`python3 targeted-checks.py` copied the unchanged bin tree into a disposable sibling code root, leaving all fixture homes inside the worktree but outside that code root, and selected existing executable behavioral cases. The selected contribution cases (all three initial fixture failures plus HTTP 500 retry/500 exhaustion/404 no-retry), Forgejo pagination/rejected-merge/refusal cases and GitHub UNKNOWN retry, and watcher captain-hold/background-job-timeout/exit-picker cases all passed. These use mocked forge/backend dependencies and are supplemental, not live claims about those integrations. No static-analysis commands were run.

The first exploratory Forgejo-binding driver used an incorrect flag order and mistakenly expected the Gerrit-only yolo restriction to apply to Forgejo. The driver was corrected to the documented interface; a later incorrect expectation of status 2 instead of the actual refusal status 1 was also corrected. `forgejo-binding-and-manual-merge-policy.log` is a superseded driver-setup artifact; `forgejo-binding-and-invalid-mode-refusal.log` is the final passing result. No product or tracked test changes were made for these corrections.

## What remains untested live

See `live-tool-and-isolation-constraints.log`: tmux, Orca, tea, Command Code and OpenCode are not on PATH. The native Herdr alternative was investigated only through the approved lab helper: a normal prepare/teardown probe completed without provisioning a session; an XDG-isolated workspace-local prepare cannot pass the required already-running-default tripwire, and its socket path exceeds Unix sun_path capacity. Starting or modifying a default session, using operator configuration for lab writes, creating a short home elsewhere, fabricating an agent, and changing credentials were not used as workarounds.

Consequently successful real worker spawn/relaunch/long-launch integration, Orca environment delivery, real Forgejo API integration, and the OpenCode/Command Code rendered TUI changes are not proven live here. There are no screenshots because those rendered harnesses cannot be launched with the available tools and allowed session setup. CLI transcripts and generated Markdown are provided instead, but do not substitute for missing TUI evidence.

`merge-history.log` separately confirms both parents of the catch-up merge are ancestors of this head, lists the upstream commits, and shows the preexisting Pi extension blob was retained. This is Git metadata evidence, not runtime testing. Future PR creation, merge-method selection at eventual landing, CI execution, and publication remain the outer executor's phases and were not performed.

Overall: no product failure was reproduced in the driven scenarios, but live integration coverage of the merged runtime changes is incomplete. Review the stated tool/session constraints before deciding whether to proceed or rerun with those capabilities.
