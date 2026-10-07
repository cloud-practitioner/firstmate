# Hold-origin live validation

## Outcome

All twelve current-product CLI scenarios passed. No source or test files were changed during validation, and all disposable homes were removed.

The product was `bin/fm-captain-hold.sh` with the real installed `tasks-axi` markdown backend, invoked through `bin/fm-tasks-axi.sh`. No CLI, backend, login, or product output was mocked. `fault-env.sh` injects faults in the running Bash process by sending TERM before the backend hold or revoking write permission on the disposable backlog and its directory. The secondmate checks use the real local parent-channel publisher. No default runtime session or fleet data was used.

## Product evidence

[Current CLI transcript](live-hold-origin.log) includes commands, return codes, persisted task bodies, refusal diagnostics, and parent-channel events:

| Scenario | Transcript lines |
| --- | --- |
| Successful reassociation and new answer accepted for B | 2–126 |
| Active hold interrupted; A retained and B refused | 128–256 |
| Active hold/backend and rollback refused; A retained and B refused | 258–388 |
| Expired hold interrupted; A retained and B refused | 390–518 |
| Expired hold/backend and rollback refused; A retained and B refused | 520–650 |
| Released hold interrupted, earlier answer replayed; B still refused | 652–817 |
| Released hold/backend and rollback refused, earlier answer replayed; B still refused | 819–986 |
| Released hold interrupted, ordinary work completed; B still refused | 988–1143 |
| Released hold/backend and rollback refused, ordinary work completed; B still refused | 1145–1302 |
| Secondmate new hold: origin write refused, decision delivered once, retry succeeds | 1304–1457 |
| Secondmate active hold: origin write refused, decision delivered once, retry succeeds | 1459–1616 |
| Secondmate re-hold after release: origin write refused, decision delivered once, retry succeeds | 1618–1779 |

[Before-fix reproduction](before-fix-reproduction.log) executes the script from base commit `47aff866dbe0612bd43df66d8fa76576e06a2b3e`, changing only its library-directory binding to this worktree. With the real backend hold and rollback denied by filesystem permissions, its persisted task is unheld and associated with B but carries only A's answer. Both `complete origin-b call` and `verify origin-b` incorrectly exit zero. The current-product transcript demonstrates refusal for the corresponding failure and interruption cases.

## Targeted automated checks

The captain-hold lifecycle suite's initial ten-minute invocation completed the touched origin-ordering/parent-publication test, the expanded interrupted-origin regression, and the suite prefix, then hit the imposed time limit. Only its remaining cases were resumed; they exited zero. The first continuation launcher exceeded the OS argument-size limit; feeding its Bash program on stdin fixed that setup issue. Beads migration cases reported their existing markdown-only-host skips. No broad test tree, lint, formatting, static analysis, push, PR, or CI commands ran.

Evidence: [suite prefix](captain-hold-suite.log), [remaining cases](captain-hold-suite-remaining-retry.log), [scenario results](live-hold-origin-results.json).

This is a CLI/storage change, not a visual UI change; product transcripts and persisted state are the reviewer-visible artifacts.
