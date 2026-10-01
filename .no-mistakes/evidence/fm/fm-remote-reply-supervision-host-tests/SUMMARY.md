# Test-phase evidence: supervision-host leak fix and remote-reply recapture bound

Host: 4 cores, WSL2, other lanes active (load average 3-7 when the runs started).

## tests/fm-supervision-host.test.sh
| tree | cases | wall time | peak live fixture hosts | peak live fixture watchers | peak load1 |
|---|---|---|---|---|---|
| HEAD e389c56 (run_case per-case stop) | 65/65 ok, rc=0 | 599s (< 900s cap) | 3 | 1 | 5.59 |
| base fc795e5 (stopped after 450s) | 36/65 done in 450s | would exceed 900s at that pace | 11 | 12 | 17.49 |

Per-10s samples: supervision-host-head-procs.tsv, supervision-host-base-procs.tsv
(only processes whose FM_HOME is under the suite's fm-supervision-host.* fixture root).

## tests/fm-remote-reply.test.sh (HEAD)
33/33 ok, ALL TESTS PASSED, 166s. Instrumented copy timed every await_reply_result:
the two whole-log recapture waits took 19.6s (replay-identity, orig line 678) and
21.9s (cursor-loss recapture, orig line 942); all others <= 5.6s. New bound 120s.

## Live e2e variants
Both gate-skip without their opt-in env and exit 0 (live-e2e-gate.log); unchanged by this change.
