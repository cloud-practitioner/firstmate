# Targeted validation of upstream merge coherence

Target: `71dedadd5fb959559b680dff3cd4ca6e88f8c349` against `b3592056cc2d314eb927e292d69abde4af139f9f`.
No source or permanent test files were changed.

## Real product scenarios

- `drive-herdr.sh`: installed Herdr 0.9.3/protocol 22, disposable named `fm-lab-p` session. The public visible-capture interface returned executed shell output on the owned endpoint. A real process-bound record was also accepted. Corrupting that process identity while keeping the correct cwd rejected composer and capture probes; a foreign legacy cwd record was likewise rejected. Neither refusal read the pane. After guarded session stop, the public piped composer probe returned `unknown` within the same second and visible capture failed with no screen. Its command trace contains exactly two real `status --json` requests, no server-start or pane-read request. A malformed target issued no CLI requests. Finally, an active public key-send requested startup and restored real input, proven by executed `RESTARTED_INPUT_RECEIVED` output.
- Herdr session lifecycle used only `bin/fm-herdr-lab.sh`. The transparent CLI transport forwards real requests to helper `run`; actual startup requests go to helper `provision`, never a fake CLI or an unguarded server call. All named-session state and shell home files resided in `.test-phase/` under the worktree. A local socket alias let the helper make its required read-only default-session tripwire check without writing in the operator's Herdr directory. No default panes, default lifecycle, fleet homes, or credentials were touched. Guarded teardown succeeded after every live attempt.
- `drive-git-isolation.sh`: the real `bin/fm-test-run.sh` executed `tests/fm-test-fixtures.test.sh` with all four repository-location variables simultaneously pointing at a disposable linked worktree. It exited zero. Before/after Git snapshots demonstrate unchanged ambient refs, worktree registrations, both indexes, and tracked sentinel bytes. The fixture suite separately exercised each variable and both helper entrypoints.
- `drive-watcher.sh`: six actual `bin/fm-watch.sh` successor processes competed over a verified-dead watcher lock in a marked disposable home, with no fake binaries. One live process held the published identity and produced a beacon; all competitors exited, the same owner survived two further poll cycles, and TERM removed its lock. All spawned processes and the home were torn down.

These are CLI/probe and test-fixture changes, not layout, CSS, or UI-copy changes. CLI transcripts and actual pane output are the relevant end-user artifacts; screenshots were not needed. No model prompts or primary harness sessions were involved.

## Targeted baseline and execution caveats

Ran, with Herdr pane identity, fleet-path overrides, FM_HOME, FM_BACKEND, and forge tokens unset and TMPDIR inside the worktree:

`bin/fm-test-run.sh --jobs 1 --per-script-timeout-secs 600 tests/fm-backend-herdr.test.sh tests/fm-test-fixtures.test.sh tests/fm-watcher-lock.test.sh`

The transcript records zero exits for the Herdr and fixture suites, including the stopped-server public-dispatch regression and inherited Git-location regression. The tool's 700-second command deadline interrupted the outer runner while the bounded watcher child was still executing; the child subsequently completed all its cases and wrote exit `0` to the timeout helper's status file. That status was read directly before cleanup, and the retained transcript contains its final watcher case. This was not treated as a successful outer-runner exit or as live evidence. Independent actual watcher CLI validation is retained separately.

The test-inventory guard, `bin/fm-test-run.sh --check-coverage`, was first interrupted at tool deadlines of 15 and 120 seconds. It was then allowed to complete in the background with local TMPDIR; the guard reported success and its captured exit was `0`. This inventories tests and does not run the complete repository suite. No linters, formatters, static-analysis tools, broad regression suites, push, PR, CI, or pipeline-control phases were executed.

Read-only Git checks confirmed both the fork base and upstream `fb75c1f9` are ancestors of HEAD and that `398265e` has parents `b359205` and `fb75c1f`. PR creation, merge-only delivery wording, and remote checks remain the outer executor's later-phase responsibility; this phase did not create or merge a PR.

## Artifacts

- `herdr-live.log`: real API responses, public capture output, probe verdicts, executed input after restart, and teardown result.
- `herdr-owned-commands.log`, `herdr-foreign-identity-commands.log`, `herdr-foreign-commands.log`, `herdr-stopped-commands.log`, `herdr-active-restart-commands.log`: actual product-request traces through the transparent lab transport.
- `git-isolation-live.log`, `git-ambient-before.txt`, `git-ambient-after.txt`: real runner and unchanged disposable Git state.
- `watcher-live.log`: actual owner process, persisted lock identity, beacon, competitor diagnostics, and cleanup.
- `targeted-suites.log`: targeted regression baseline, not a substitute for live product proof.
- `drive-herdr.sh`, `drive-git-isolation.sh`, `drive-watcher.sh`: repeatable evidence-producing drivers, run with Bash from the target worktree. Their transient setup lives only under `.test-phase/`.
