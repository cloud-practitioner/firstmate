# Targeted remote-reply wait validation

Target: `e72d75ae7bd00a193d6e9116716a6c6edabc54bb`.

## Scope and isolation

Only `tests/fm-remote-reply.test.sh` changes: two whole-log recaptures now invoke a three-attempt wrapper around the unchanged 800-poll wait.
The focused existing end-to-end test was run, not the repository-wide suite.
No linters, formatters, publication commands, or fleet lifecycle commands were run.

All intentional sandbox writes stayed under `.test-phase/` inside the gate worktree.
A snapshot created with `git archive HEAD` supplied an isolated, locally indexed Firstmate code root, with temporary homes alongside it rather than nested inside that code root.
This preserved the product's root/home non-overlap check without writing test homes outside the worktree.

For additional live validation, a workspace-local `ssh2` dependency supplied an authenticated SSH server listening only on loopback.
The installed OpenSSH client connected using disposable sandbox keys and a sandbox-only SSH configuration and known-hosts file.
No operator credentials or configuration were used or changed.
The endpoint executed the actual `fm-remote-entrypoint.sh`, job worker, file reader, and delta reader; the parent executed the actual `fm-on.sh`, process-event runner, and reply adapter.
Only the dependency's response latency was deliberately increased; no product output or product implementation was mocked.

The live driver loaded the unchanged wait and changed recapture helper from the target test for executable invocation, adding diagnostic logging around calls.
Its assertions checked durable acknowledgements, cursor contents, source and mirrored document bytes, parent status bytes, decision folding, wake signatures, and listener identity—not implementation text.
For each delayed replay, the old single-budget wait and extended wait observed the same real in-flight generation concurrently.

## Results

| Scenario | Former 800-poll wait | Extended wait | Observable result |
| --- | --- | --- | --- |
| Resolved-decision cursor-loss replay; 13 documents; 1 second extra per SSH document fetch | Timed out after 44 seconds with no acknowledgement | Completed after 55 seconds, on attempt 2 | Generation 2 acknowledged; all documents byte-identical; parent status unchanged; resolved decision closed; no duplicate wake; listener unchanged |
| Quiet cursor-loss replay; 13 documents; 3 seconds extra per SSH document fetch | Timed out after 43 seconds with no acknowledgement | Completed after 79 seconds, on attempt 2 | Generation 3 acknowledged; lost cursor restored to byte 816; no duplicate status or wake; listener unchanged |
| Missing generation on an otherwise healthy empty remote channel | Not a success case | Returned failure after exactly 3 expired attempts, 132 seconds elapsed | No generation 4 result was invented; the same listener retained ownership at all retry boundaries |

The wait is bounded by poll attempts, not a strict wall-clock deadline.
The nominal 40/120-second budgets stretch with process and scheduler overhead, as expected on a loaded runner.

`remote-reply-baseline.log` ends with `ALL TESTS PASSED`, including both actual whole-log recapture call sites, ordinary deltas, listener continuity, and failure recovery.
`live-recapture.log` records the live timing comparison and all three final scenario outcomes.
`state-proof.json` contains observed persisted acknowledgement state, document hashes, parent before/after hashes, actual captured delta protocol output, and restored cursors.
The individual `.result.txt`, `.cursor.txt`, and `.parent-status.txt` files retain those product outputs directly.
`loopback-ssh.jsonl` retains the actual endpoint request trace, including setup retries.

## Setup corrections and teardown

Initial sandbox attempts were corrected before the final scenarios: a home nested inside the code root was refused by the product; inherited Git configuration failed after the remote entrypoint deliberately unset HOME; and reusing a sandbox path before a prior worker teardown completed interfered with that worker.
The final run used sibling code/home roots, disabled operator Git configuration in the sandbox endpoint, and allocated a unique home/state directory for each driver invocation.
Both delayed recaptures were then re-driven successfully without changing tracked source or tests.

The real process-event listener and remote job worker were stopped through home-scoped cleanup, the loopback server was stopped, and the entire `.test-phase/` directory—including dependencies, disposable SSH keys, fixtures, and copied code—was removed.
`git status --short` and `git diff --exit-code` were clean after teardown.
PR publication and linkage to upstream PR #6241 remain the outer executor's delivery responsibilities; this phase did not perform them.
