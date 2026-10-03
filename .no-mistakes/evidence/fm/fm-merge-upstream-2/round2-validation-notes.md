# Targeted live validation — upstream merge

Submitted and final feature-branch head: `109825e2d232b179d8880c2cb123f3f1176a0b2f`.

## Product evidence from this turn

- `hold-cli.log` and `hold-snapshot.json`: real tasks-axi plus Firstmate CLI preserve multiline, parentheses, Unicode, and literal encoding-like hold reasons; wrong-origin and self-inventories refuse without changing the origin; a valid inventory verifies before and after the captain answer.
- `fleet-sync-cli.log`: real Git remote/clone fixtures update a symlink-aliased clone to v2 and skip a non-clone without changing the enclosing gate checkout.
- `remote-delta-live.json`: real delta reader returns exit 75 silently on no change, waits for complete lines, detects same-inode/same-size/same-second prefix rewrites and truncation, and rejects path traversal.
- `remote-worker.log`: real job worker preempts only the same home's long poll (exit 76), completes its short job, and leaves the other home's poll running until its own reply arrives.
- `contribution-actors.log`: real verdict CLI persists captain/fleet/maintainer/nobody actors and rejects an unknown actor without mutating the record.
- `watcher-live.log` and `watcher-ownership.tsv`: real watcher arm takeover replaces exactly the owned watcher, preserves its acknowledged downtime generation, then surfaces and acknowledges new queued work.
- `pi-live-spawn.log`: real home seeder and spawner run the unchanged submitted product materialized inside a disposable source copy; the secondmate home is outside that copy's root but inside the gate worktree. Real Pi 1.0 first prompts without approval, then product spawn passes project trust with actual tracked extensions and leaves disposable trust.json unchanged. This is intentionally offline startup validation, not a model-response or login test. `pi-seeded-stall.png`, `pi-seeded-approved.png`, and `pi-unseeded-stall.png` show the terminal surfaces.
- `claude-composer.log`: real Claude 2.1.288 under a named non-default Herdr lab has an empty titled composer; typed grey `/exit` remains readable and is protected against injection over its draft. The real adapter clears the draft, delivers a rename, then exits to the shell, confirmed by real process-info. Herdr prepare/provision/run/viewer/teardown used only the lab helper, and teardown verified its unchanged default-session tripwire. `claude-titled.png` and `claude-slash.png` are rendered from the actual captured ANSI viewport, not mock UI.
- `round2-merge-proof.log`: real Git merge-tree reproduces the merge. Every non-conflicted path matches exactly; the sole test-call-list conflict retains the fork cleanup wrapper and all upstream/fork cases. There are ten upstream commits and exactly one new first-parent merge commit.

## Focused regression execution and setup retries

`round2-supervision-regressions.log` records the seven changed hand-back/takeover/failure-notice cases. `round2-targeted-regressions.log` records the two changed watch-arm cases and the initial Pi fixture refusal. The Pi fixture was initially inside the product root and also inherited the operator's Herdr backend selection. Its local unchanged-product copy and explicit tmux backend corrected that test setup; `round2-pi-spawn-regressions.log` records the successful Pi/pi-signed approval, ordinary-worker omission, and unsupported-flag cases. These stub-assisted regression tests are supporting evidence, not live harness proofs.

A first Pi live attempt closed its last baseline tmux session immediately before making another, racing server shutdown. Keeping a second session alive fixed the disposable setup. A later clean-shell re-drive passed; the latest Pi log and images are from that successful run.

## Limits and phase boundaries

The real Claude primary acquired the isolated session lock and fired its native Stop callback, but the shipped primary-scope predicate rejects linked gate worktrees. `primary-supervision.log` and `primary-final.png` show the attempted check. Full native supervision hand-back is **untested**: this turn did not forge a primary identity, relocate the required primary launch root, or bypass the guard. The real watcher takeover and focused host/hook regressions cover the changed lower-level behavior. A separately authorized normal-primary lab run or a trusted runbook/product accommodation for gate-root primary validation is needed for the full native loop.

The ShellCheck memory-ceiling retry is **untested in this phase**, whose instructions expressly prohibit linters/static analysis. It belongs to the separately owned Lint/CI phases. PR creation, exact PR title, publication, and merge-method enforcement also remain with the outer executor; this turn did not perform them.

No complete repository suite, linter, formatter, pipeline-control command, push, PR, or CI phase ran. All intentionally created fixtures stayed inside this worktree; normal harness/toolchain ephemeral files were incidental. Both rounds' scratch selectors, downloaded local tools, copied product trees, caches, private sockets, and disposable labs were removed. Final `git status --porcelain` is empty, the feature head is unchanged, and no product-source fix or pipeline-fix commit was added. The previously declined interrupted-reassociation concern was not changed or re-reported.

Reproduction drivers are retained under `drivers/`; their `.test-phase-tmp` dependencies were disposable and removed, so rebuild local tool/product fixtures before reusing them.
