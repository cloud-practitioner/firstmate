# PR merge-watch live validation

Target: `226ae9f37078984ef2495c85898ddfdf89fecf46`
Base: `9f5d793627dcde5bb99d5ac76fd7e6de08bd3b48`

## Results

| Scenario | Observed product behavior | Evidence |
| --- | --- | --- |
| Self-update preserves armed watches across homes | The real `fm-pr-check.sh` armed one GitHub watch in the primary home and nine Bitbucket watches in a secondmate home. The real `fm-update.sh` fast-forwarded both disposable checkouts from their local origin and reported every repaired task. Every original watch subsequently emitted its own `merged` wake and retired its poll. | `live-cli-transcript.log`, scenario 1, lines 3–249 |
| Rebinding is idempotent and preserves task identity | Repeating the real `fm-pr-rebind.sh` reported zero rebound watches, one unchanged primary watch and nine unchanged secondmate watches. The driver compared the persisted metadata/sidecar byte contracts and private artifact permissions. A separate deliberately edited watch remained unchanged and was reported with its re-arm command. | `live-cli-transcript.log`, scenario 1 |
| A home sharing externally changed code heals on its next watcher start | A watch armed in an unregistered home survived a changed template without calling the rebind command: the real watcher logged its template re-record and emitted the merge wake. | `live-cli-transcript.log`, scenario 2, lines 251–287 |
| An already-running watcher heals without restart | The same watcher process first polled an OPEN PR. The driver changed the deployed template while that process was running, then changed the disposable API record to MERGED. That process logged the re-record, emitted `merged`, and retired its poll. | `live-cli-transcript.log`, scenario 2B, lines 289–309; corresponding OPEN/MERGED responses in `disposable-forge-http.jsonl` |
| Unsafe watches fail loudly, not open | After template change, real rebind and watcher entrypoints refused edited check bytes, an inode-swapped check, changed sidecar data, and a changed registered template hash. Both outputs named each task's exact re-arm command. The persisted artifacts stayed unchanged; no refused Bitbucket poll reached the API. | `live-cli-transcript.log`, scenario 3, lines 311–351 |

## Isolation and meaning of “live”

The product under test was the repository's actual executable shell scripts, using the installed real `git`, `gh`, `curl`, `jq`, file identity checks, locks, wake queues, and retirement logic. No Firstmate script or installed CLI was stubbed. Homes, metadata, local git origin, and code checkouts were disposable and confined to `.fm-validation/` in the gate worktree.

Only the external forge dependency was a disposable local TLS HTTP fixture. Child-only proxy and CA environment variables routed GitHub/Bitbucket reads to that fixture; it accepted only the named forge hosts and never forwarded traffic. Its credentials were disposable dummy values, not a normal login. `disposable-forge-http.jsonl` records actual HTTP requests/responses without authorization headers. These checks prove the live Firstmate product against disposable forge records, not live GitHub/Bitbucket account authentication or provider availability. The separate optional contribution-review observer check was removed from fixture state to keep supervision scoped to merge monitoring. No harness primary, TUI, Herdr session, real tmux server, or fleet state was driven.

The live driver source is retained as `live-driver.py`. It was executed as `python3 .fm-validation/live_driver.py`; all four scenario sections completed with exit 0. Its teardown stopped the HTTP fixture and removed every live fixture home and checkout. A short command timeout during an earlier attempt interrupted setup; the fixture was removed and the complete driver rerun successfully with a 600-second command budget.

## Targeted regression checks

- `TMPDIR="$PWD/.fm-validation/tmp" bash tests/fm-update.test.sh` — completed successfully, including the new real rebind/update integration case T13.
- An initial `bash tests/fm-pr-check-security.test.sh` attempt exceeded the enclosing 200-second command budget before reaching the new cases. It is **not** claimed as a completed passing run.
- A temporary focused runner loaded the existing security test definitions and invoked only `test_template_change_poll_is_rebound`, `test_template_change_rebind_command`, and `test_template_change_refuses_unproven_polls`. All completed successfully. See `focused-security.log`.
- The same focused runner, with its code root pointing to a disposable `git archive` of the base commit's `bin/`, failed on the first template-change scenario with `watcher refused a poll whose only change was the template: check: rejected unauthenticated state checks: ...`. This is the expected pre-fix reproduction, not a target-code failure. See `baseline-reproduction.log`.

The security regression tests use their existing fake external tools, so those test executions are supporting regression evidence, not the basis for marking the separate product-driving scenarios live.

No linters, formatters, static analysis, complete repository suite, push, PR, CI, or pipeline-control commands were run. This is CLI-only behavior; CLI transcripts and HTTP responses are the reviewer-visible evidence. No screenshots are applicable. All temporary validation files were removed from the worktree; no source changes were required.
