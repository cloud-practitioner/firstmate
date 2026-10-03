# Captain-call archive live validation

## Result: no-go

The real `fm-captain-hold.sh`, `fm-tasks-axi.sh` / tasks-axi 0.2.6, and `fm-teardown.sh` were driven in seven disposable marked FM_HOME directories beneath the gate worktree. The cleanup check used a real tmux 3.3a server on a lab-private socket, with a 120x40 shell pane representing a finished scout. No model, harness login, fleet home, shared/default session, or operator data was used. No full repository suite, linter, formatter, or static analyzer was run.

### Behaviors demonstrated

- Answers retained in the backlog's Done section satisfy both verify and complete. Verification leaves data and state byte-identical.
- After real tasks-axi prune, the default archived answer satisfies verify and complete; the base-commit script refuses the same fixture.
- Legacy short inventory keys resolve answered archived derived task ids.
- Real tasks-axi-produced archives are discovered with an unset archive option, trailing comments, indented/single-quoted settings (including a # in the path), inherited user configuration, project-over-user precedence, and absolute archive paths.
- Closed unanswered records are refused while retained in Done and after pruning, including a mixed answered/unanswered inventory. Refused verification leaves data and state byte-identical.
- An untransferred open keyed status decision blocks verification and scout teardown. The report, metadata, and actual private scout pane survive the refusal. A fresh origin cannot attest --none while a keyed decision remains open.
- After transferring and answering the outstanding call and pruning the answer, scout teardown succeeds, removes its metadata and private pane, preserves its report, and closes its backlog row with the report link.

### Reproduced blocker

1. Captain call `live-review-decision-route` is held, answered, and pruned into the archive.
2. Origin metadata records the legacy inventory key `route`.
3. The same full task id is added again, placed on a new captain hold, and closed via tasks-axi done without recording a captain answer. Its current live-backlog row is Done with hold-kind captain and only a hold timestamp in its body.
4. **Base commit:** verify refuses the current unanswered Done row.
5. **Target:** verify and complete(route) return success, accepting the older archive rather than the current derived row. Complete(full task id) correctly refuses.

The target archive probe runs before resolving the live derived identity. The new focused executable regression test `test_verify_refuses_a_live_legacy_row_despite_an_old_archived_answer` passes against the base script and fails against the target. Only this test was added; the product failure was not masked or changed.

## Evidence

- `captain-archive-live-cli.log`: complete real CLI output, serialized archives, task show responses, refusal diagnostics, and cleanup effects.
- `captain-archive-live-highlights.log`: selected product outputs showing the regression and successful/refused cleanup.
- `captain-archive-targeted-regression.log`: only the seven added archive E2E variants and the new precedence regression, run selectively, not the full lifecycle suite.
- `captain-archive-live-driver.py` and `captain-archive-selected-test-driver.py`: exact disposable drivers used (saved from the worktree before removing transient tools and scripts).

## Setup and cleanup

The first fixture attempt used the public wrapper's forbidden add --start combination; it correctly refused. Setup was corrected to add queued, create the dispatch fixture metadata, then use the documented start transition. Initial stale-legacy validation found a real product failure, not an environment issue, and was repeated using a captain-held current row closed without an answer.

Tmux was absent on PATH. Apt's existing cache had no candidate; available libevent/ncurses development tooling lacked yacc/bison for a source build. As a workspace-local route, Debian's tmux_3.3a-3_amd64.deb was downloaded and unpacked under .fm-live-validation/tools. Its missing libutempter.so.0 dependency was likewise downloaded/unpacked from libutempter0_1.2.1-3_amd64.deb. The driver used only that local executable and local LD_LIBRARY_PATH; no package manager installation or user/global configuration changes occurred.

Every disposable lab home and private tmux server was torn down in the same live-driver run. The downloaded packages, extracted binaries, temporary baseline script, selected-test runner, and other transient worktree test artifacts were removed. The intentional regression-test addition remains. Evidence remains in this directory. This change has a CLI-only runtime surface; no visual UI change was involved.
