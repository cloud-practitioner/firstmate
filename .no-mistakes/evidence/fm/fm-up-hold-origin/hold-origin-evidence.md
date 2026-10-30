# Hold-origin live validation

Target: `309160b761e27ab52fb8232b6c161ff64e0763e1`  
Before-fix comparison: `05196e30ead54796dfbe986db61abe9d8df9e3d2`

## Method and isolation

The live checks invoked the real `bin/fm-captain-hold.sh` and installed `tasks-axi 0.2.6`. Each scenario used disposable marked homes created with `bin/fm-lab-home.sh create`, their own Markdown backlog/configuration, and isolated HOME/XDG directories. No backend stub, live agent login, fleet session, shared backlog, or network service was used for these live checks.

A Bash DEBUG barrier paused the actual CLI immediately before the backend hold or origin publication. The interruption scenarios sent SIGTERM to that actual process. The write-failure scenarios removed write permission from the disposable backlog and its data directory, letting the real backend operations fail. Permissions were restored before inspecting state and retrying. All disposable homes were removed afterward.

This is a CLI/state change, not a rendered UI change; actual CLI output and durable parent-channel records are the product evidence.

## Results against the running target

| End-user scenario | Observable result | Transcript |
| --- | --- | --- |
| Move an answered A call to B, then answer B | Before backend hold, origin is still A and task is not held. Successful hold publishes B; both held and genuinely answered B inventories complete and verify. | `live-hold-origin.log`, lines 2–150 |
| Interrupt moving active, expired, or released A work to B | A remains the only recorded origin. B completion and verification refuse. Active A remains held; expired A retains annotations. Replaying A's answer or ordinarily completing released work still cannot certify B. | `live-hold-origin.log`, lines 152–683 |
| Refuse the backend hold and the restoration write | Real filesystem permission failures cause both operations to fail. A's answer/origin survive; B is refused before and after replay/normal completion. Released work beneath an incomplete hold stamp is also refused at the durability boundary. A genuine retry to B succeeds. | `live-hold-origin.log`, lines 685–1228 |
| Fail origin publication after a successful secondmate hold | For new, active, and released calls, the parent needs-decision event already exists before origin publication. Origin write fails nonzero without losing the live hold. A successful retry publishes B and does not duplicate the parent event. | `live-hold-origin.log`, lines 1230–1654 |
| Supply an invalid origin slug | `../outside-home` is refused before any task mutation; A remains completable and verifiable. | `origin-boundary-recheck.log`, lines 85 onward |

### Before-fix reproduction

The original script was executed from a temporary sibling file in `bin/`, using the same real backend and isolation. It was interrupted before the backend hold. Actual persisted task output then showed:

```text
held: no
hold_kind: "-"
body: "Captain hold set: ...\nCaptain hold origin: origin-b\n\nResolution recorded by fm-captain-hold.\n...\nResolution mode: released\n\nCaptain decision:\nRelease this work for A.\n..."
```

Both original consumers wrongly accepted that state:

```text
complete: origin-b captain-call inventory reviewed (call)
exit=0
verified: origin-b captain-call inventory
exit=0
```

See `before-fix.log`, lines 75–122. This demonstrates the reported failure against the real before-fix runtime, not a source-string assertion.

### Target refusal after interruption / failed restoration

Representative actual target output:

```text
fm-captain-hold: could not restore the body of call after an incomplete hold
fm-captain-hold: could not hold task call for the captain
exit=1
```

An active or expired A call cannot satisfy B:

```text
fm-captain-hold: captain-held task call was held for origin origin-a, not origin-b; hold a task for origin-b or list the right one
exit=1
```

A released answer beneath an incomplete stamp cannot establish durability:

```text
fm-captain-hold: captain-held task call carries a recorded answer from an earlier call, but its newer hold never completed; re-run the hold or answer it again
exit=1
```

The tests also attempted `verify B` after explicitly putting the old task into B's reviewed inventory, so verification refusal was not merely absence of an attestation.

### Parent delivery despite a real origin-write failure

Actual parent record, captured **before** the origin write:

```text
needs-decision [key=captain-hold-call-1] [at=1793327373]: captain hold call: Choose for B
```

The subsequent real write failed:

```text
fm-captain-hold: could not record the hold origin on call
exit=1
```

The backlog still reported `held: yes` / `hold_kind: captain`. After restoring write permissions and retrying the command, the parent file was byte-for-byte identical, and B completed and verified successfully. Re-held calls exercised the distinct `captain-hold-call-2` occurrence as well.

## Targeted repository tests and scope

The initial `bash tests/fm-captain-hold-lifecycle.test.sh` run completed the new origin-ordering matrix, the interrupted-move regression, and related identity/provenance/completion checks. Its unrelated remainder was deliberately stopped with SIGTERM to keep this phase targeted; `captain-hold-suite.exit` is therefore **143**, not a full-suite success. The earlier four `Terminated` lines in that log are expected from the regression's deliberately interrupted hold subprocesses.

The two changed regression functions were then dispatched alone from the unchanged suite definitions:

- `test_hold_origins_follow_backend_holds`
- `test_interrupted_origin_move_does_not_inherit_the_previous_answer`

The duplicate focused replay completed the origin-ordering matrix again but exhausted its 720-second command bound before the interrupted-move function finished; `selected-origin-regressions.exit` is **124**. There was no reported assertion failure. This replay is **not** claimed as a clean test-command pass. The original invocation's explicit success line for the interrupted-move regression remains in `captain-hold-suite.log`, and the independent real-CLI interruption/failure scenarios completed successfully. A clean full-suite exit was not obtained in this Test phase; broader regression confirmation remains with remote CI. No complete repository suite, linter, formatter, static analysis, push, PR update, or CI phase was run here.

## Corrected test-driver assumption

The first live driver also tried an absent-but-valid origin ID and incorrectly expected lookup refusal. The public CLI deliberately preserves absent IDs as usable origin identities, so that extra assertion was a test-driver error, not a product failure. The original transcript/results retain the failed assertion for transparency. The driver was corrected to exercise a genuinely invalid origin slug and that scenario passed on rerun (`origin-boundary-recheck.log` / `origin-boundary-recheck-results.json`). The four core live scenarios had already passed before this correction.

## Cleanup

Disposable live homes, the temporary before-fix executable, and selected-test dispatch copy are removed after their runs. No tracked project changes were made by Test. Evidence remains only in this evidence directory; repository test fixtures use the test toolchain's self-cleaning temporary directories.
