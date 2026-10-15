# Targeted live validation

Target: d0e7e358c107902604b7ae7ad2036abd5bbd3a6a, compared with 925d677dfc13bac087cd8ef66ac6e90fdfcd7704.

## Acceptance scope

The latest captain decision drops status-derived inbox acknowledgement. The retained contract is busy-grace extension, task-scoped recent activity, idle/unheard delivery recovery, symlink-canonical watcher ownership, and accurate watcher-down reminders. An inbox record is acknowledged by its move to `handled/`, not by status evidence.

## Baseline checks

Ran only these selected regressions, not the repository-wide suite, with isolated FM_HOME/TMPDIR and inherited Herdr pane routing removed:

```
bin/fm-test-run.sh --jobs 1 --per-script-timeout-secs 300 \
  tests/fm-composer-lib.test.sh \
  tests/fm-task-inbox.test.sh \
  tests/fm-guard-stale-banner.test.sh
```

Then ran the retained away/quiet consumer boundary with the same isolated environment:

```
bin/fm-test-run.sh --jobs 1 --per-script-timeout-secs 300 tests/fm-daemon.test.sh
```

All four selected scripts completed successfully with no gate skips. `targeted-regressions.log` and `daemon-regressions.log` contain the full output. This is supporting regression evidence, not the live proof.

## Live product checks

### Real busy Claude and idle recovery

`python3 .test-live/live-inbox.py` drove Claude Code 2.1.299 using its existing account in a 120-column, 40-row private tmux session. The session command launched the real CLI from the validation worktree, with the gate/path-override variables removed as required. Temporary settings installed the production `fm-busy-event.sh` lifecycle hooks; they did not alter user-level settings. Only a real `sleep 80` tool call was permitted. Claude executed it and its actual UserPromptSubmit/Stop hooks published busy and idle states.

- `fm-send.sh live ...` durably enqueued instruction A. A recovered, already-spent two-attempt delivery ladder was seeded through the production inbox bookkeeping interface. The real watcher refreshed the task's activity observation without increasing that ladder or queuing stale wakes while Claude was working.
- A successor record was enqueued through the production inbox writer, A was moved into `handled/`, and the watcher was restarted through `fm-watch-arm.sh --restart`. The ordinary recovery wake was allowed to complete and a new arm resumed polling. The same pane's activity protected the successor across that restart.
- After Claude's actual Stop hook, a real unsent draft containing `esc to interrupt` was typed into its composer. Within the six-second activity grace there was no delivery attempt or stale wake. After real wall-clock grace and ladder spacing expired, two blocked delivery attempts led to exactly one `unread firstmate instruction ... with an idle pane` wake. The draft and unhandled record were preserved.
- The stale wake was presented and generation-acknowledged through the real `fm-wake-drain.sh` interface. Re-arming did not duplicate the instruction escalation. Moving the remaining record to `handled/` left the inbox quiet.

The six-second grace and two-attempt budget accelerate the experiment; normal defaults were not changed. Only marked disposable homes were used. The real private server and home were removed before the command returned.

Evidence: `inbox-live-events.json`, `inbox-live-driver.log`, `inbox-watcher.log`, and the exact captured terminal frames in `inbox-live-terminal.html`. The HTML renders captured product output, not a predicted UI or a textual test summary.

### Real watcher identity, banner recovery, and reminder wording

`python3 .test-live/live-guard.py` started a real `fm-watch.sh` process in another marked disposable home. Its owner tracked/reaped the process and awaited complete lock identity publication before checking health. A durable pending task record kept supervision required; no operator task or endpoint was involved.

- No beacon produced the full stale-beacon alarm and then the concise grace-bearing reminder.
- A fresh beacon without a live watcher still alarmed, but the reminder accurately named the missing process rather than blaming beacon grace.
- With the actual watcher running, guard calls through both a symlinked home and symlinked code root were silent and removed the episode marker.
- An arm through those logical paths attached to that exact existing PID instead of starting a duplicate.
- Adversarially changing the disposable lock's recorded code path or home to a genuinely different path caused the guard to refuse the claim. Restoring each identity returned the guard to silence and cleared its episode marker.
- A real home-scoped watcher stop caused a later outage to print the full banner again; its next reminder named the missing process while the beacon was still fresh.

Evidence: `guard-live-events.json`, `guard-live-driver.log`, `guard-symlinked-arm.log`, and rendered actual CLI output in `guard-live-terminal.html`. The process, disposable home, and symlinks were removed before returning.

## Composer-only live gap

No system package or global tool was installed. tmux 3.3a and its missing runtime library were extracted from Debian packages under the disposable worktree to make the primary lab possible. A real Codex CLI 0.162.1 was also installed under that directory with a local npm cache.

The normal account was probed with `.test-live/codex/node_modules/.bin/codex login status`; it returned exit 1 and `Not logged in`. A separate marked private lab then launched the actual Codex TUI, whose login chooser is captured in `codex-startup.txt` / `codex-startup.log`. The isolated home is not used to infer normal account availability; the separate normal-login probe establishes that blocker. No sign-in, sign-out, credential-store edit, fabricated CLI, or fabricated login was attempted. Consequently an actual Codex working-composer-only grace extension could not be driven. It needs an operator-provided authenticated Codex session/account before rerunning. The deterministic composer and watcher regressions exercised that predicate, but are not labelled live.

## Setup retries

Earlier disposable attempts were setup retries, not product failures: one launch initially failed to inherit the selected Claude account path, an overly-fast manual paste/Enter left text unsubmitted, a raw restart correctly returned the recovery wake instead of immediately polling, and the first guard driver read lock publication too early and failed to reap its tracked child during stop. The final drivers preserved the existing selected login, allowed paste settling, respected the recovery handoff, waited for complete ownership publication, and reaped the child while stop checked liveness. Final event logs and HTML show the successful re-drives. Any intermediate `inbox-failure.txt` capture is superseded by those final results.

The Herdr lab helper's named-session prepare/teardown safety probe also completed; no Herdr lab was provisioned or live fleet pane operated on. No lint, formatter, static analysis, broad suite, pipeline control, push, PR, or CI phase was run. All transient workspace tools, npm cache, generated state, and driver scripts were removed after validation; only evidence remains outside the worktree.
