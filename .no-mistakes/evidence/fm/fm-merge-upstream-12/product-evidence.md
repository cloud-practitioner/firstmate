# Merge-sensitive product validation

Target: `6ed8354606febe990a522245fe49ed7e6fb10b86`.
Base: `244d8368fb436e31962c91fc2d60cb2c7d78f16e`.

## Direct observations

- `retained-artifacts-cli.log`: real `fm-captain-hold.sh` and installed `tasks-axi`, with disposable lab homes and pending-retention records written through the production transition library. The pre-fix script closed the GitHub task with only a note. The target preserved structured GitHub and Forgejo links and a structured report link; Bitbucket and Gerrit URLs survived as notes. A malformed retention record refused closure and left the captain-held task in flight. No forge API was contacted.
- `retention-before.png` / `retention-after.png`: the shipped evidence renderer marked the differences in the actual public task displays above. These are rendered CLI transcripts, not browser screenshots.
- `fork-contracts-cli.log`: the real named-head gate rejected a Bitbucket checks-green claim for an unpublished commit, accepted it after a push to a disposable local bare remote, and rejected a subsequent private commit. The evidence intake rejected a missing declaration and a forbidden `none`, then accepted `ui`. Real wake presentation did not consume the event; acknowledging the first event left a subsequently appended event pending, and its own acknowledgement emptied the queue. An independent generation test consumed a presented row through its valid sequence cutoff but kept the recovery episode pending when the generation mismatched. A subsequent acknowledgement with the matching generation settled the episode, and the next drain requested no acknowledgement.
- `watch-recovery-cli.log`: two fresh real `fm-watch.sh` processes, before acknowledgement, each emitted `check: rearm-resurface` for the same durable event. After running the exact generation-bound acknowledgement printed by the real drain, a fresh watcher stayed alive and quiet for the bounded observation. This exercised the fork's recovery-wake failure mode without a mock watcher or live harness, and did not execute the prohibited live wedge suite.
- `claude-launcher-cli.log` / `claude-lab-pane.png`: real Claude Code 2.1.309 started with the normal login through `bin/fm-live-claude.sh` on a private, non-zero 120x40 tmux terminal. The host launcher symlink target was identical before and after. The private server was stopped and its lab removed. The image is rendered from the actual pane capture.
- `secondmate-live-cli.log`: a deployment of the exact target tree, entirely inside the worktree, provisioned and spawned a real Claude secondmate. Stand-down refused an active child record without creating dormancy. With the child removed, the agent was still at an external CLAUDE.md import-consent dialog, so the safe-composer guard refused to type `/exit` and did not claim a verified stop. This is not evidence of a successful stand-down/resume cycle. No import dialog was accepted and no sign-in or sign-out was performed. The private server and disposable deployment were removed.
- `merge-history.log`: the existing two-parent merge retains the fork base and incorporates upstream `af1c6817`; the upstream range `83b70ef4..af1c6817` contains 36 commits. The checked fork-only modules and `contrib/iqx-ixia-hook` remain unchanged from the fork base. No push or PR operation was performed by this phase.

## Limits

- The live wedge suite was syntax-checked only, as explicitly required by the recorded user decision. Its non-live suite was executed in full. Mock-backed suite results are not represented as live harness evidence.
- Completing the ordinary live secondmate stop/resume scenario requires a disposable authenticated Claude configuration with the necessary external-import consent already authorized. The normal login itself was available; an empty isolated configuration was not used to claim otherwise.
- No real Bitbucket Cloud merge or evidence-publication operation was performed against an operator repository. The targeted Bitbucket/evidence regression suites use isolated API fixtures and are not real-cloud evidence.

## Test-environment correction

The initial targeted runner placed test temp roots below `.test-phase/tmp`. That invalidates suites whose secondmate fixtures must live outside their code repository, and puts dot-prefixed path components into a shell-metacharacter branch-name fixture. Failed affected suites were scheduled for rerun with the normal `/tmp` test-toolchain temp location and sanitized fleet/forge environment. Original and retry logs are retained separately. The retry result JSON files record the final outcomes; the original setup failures are not presented as final-head product defects.
