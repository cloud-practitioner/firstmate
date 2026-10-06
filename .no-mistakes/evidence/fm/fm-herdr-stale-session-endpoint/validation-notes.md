# Herdr stale-session endpoint validation

Target: `d479baf8d8f40545c22593627d3aafe4f80079f7`  
Baseline: `06a89438bead6193fd300248c5366941a30789d9`  
Runtime: real Herdr 0.9.3 (protocol 22), real Claude Code 2.1.290, real Treehouse.

## Product evidence

- [live-endpoints.log](live-endpoints.log): delete/re-provision an owned named lab, reproduce recycled workspace/tab/pane counters, refuse capture/input despite matching label and cwd, check owning child-home records and both secondmate recovery probes, restore a stopped server before guarding input, execute real relaunch to a fresh endpoint, preserve uncommitted work and the foreign pane, confirm owned removal, retain legacy fallback, continue relaunch when portable `ps` fails, and abort a real projected spawn before publication.
- [live-agent-recursive.log](live-agent-recursive.log): a real running Claude process with a real Herdr registration remains alive for its owner. The same real pane and stale record report **alive under the baseline** and **missing under the target**. An unavailable identity blocks capture/input and leaves the pane intact without authorizing absence. Forced recursive teardown removes stale secondmate records/homes without closing any of three foreign endpoints.
- [live-fresh-fallback.log](live-fresh-fallback.log): a real fresh `fm-spawn` acquires an isolated Treehouse worktree and launches real Claude even when `ps -o lstart= -p` fails; metadata omits the identity and removal is confirmed afterward.
- [projected-abort.log](projected-abort.log): a deliberately invalid isolated Treehouse pool causes the real projected spawn to time out before publishing B. B's response-owned pane/workspace is removed despite stale A claiming exactly that address; A remains. The final real workspace list in `live-endpoints.log` contains only the parent `w1`.
- [recovered-endpoint.meta](recovered-endpoint.meta): actual published recovery record showing the replacement endpoint and its PID/start-time identity.

The executed disposable drivers are retained as `live-scenarios.sh`, `extra-scenarios.sh`, and `fresh-fallback.sh`; `probe-lab.sh` owns the preparatory config fixture. They were executed from the run worktree's `.live-validation/` directory, then all disposable worktree files were removed. No tracked product/test source was changed.

## Isolation and limitations

All operational Herdr commands went through `bin/fm-herdr-lab.sh` with a unique non-default `fm-lab-*` session. Each turn tore its session down and verified the helper's default-session tripwire. A workspace-local HOME housed Herdr state. Relative socket names avoid AF_UNIX's path-length limit in the long gate worktree; the transport wrapper canonicalized real session-list socket paths for Firstmate's lock owner. A default-socket symlink was used solely for the helper's read-only default-session tripwire, never for pane commands.

For host-local remote read/observation/inbox checks, the transport wrapper mapped logical `fm-remote` to the owned `fm-lab-*` session. No shared `fm-remote` server was used. State/capture/observe and durable send were exercised live with conflicting parent-route and ordinary-home records. **The remote key subprocess was not validated live:** its internally supplied `FM_ROOT_OVERRIDE` and parent-route state override make the gate refuse it even against a marked lab. No bypass or pipeline-control authority was used. The focused remote regression exercises that subprocess with canned infrastructure, which is supplementary, not live evidence. A separate authorized non-gate sandbox or a gate-approved remote-route lab mechanism is needed to exercise that subprocess live.

Claude's real CLI was launched only with workspace-local config and reached onboarding. These artifacts prove endpoint allocation/rebinding and real process handoff, not authenticated task completion. The normal machine login was confirmed available using `claude auth status`; it was not copied, changed, or replaced. Using the ordinary spawn with that login would mutate its trust store, outside this run's workspace authority, and an attempted read-only filesystem namespace workaround was refused by the host (`bwrap`: unprivileged namespaces unavailable).

The change is CLI/backend ownership logic, not UI/copy/layout; CLI transcripts, real server responses, and persisted metadata are its product-level evidence. No screenshot is claimed.

## Supplementary targeted tests

Only these executable cases from `tests/fm-backend-herdr.test.sh` were selected into a disposable runner and executed (not the whole suite):

- `test_recorded_endpoint_from_a_previous_session_is_never_the_tasks_agent`
- `test_process_bound_endpoint_rejects_matching_labels_and_worktrees`
- `test_process_identity_is_portable_and_distinguishes_pid_reuse`
- `test_spawn_and_relaunch_continue_without_process_identity`
- `test_projection_abort_cleans_response_owned_pane_despite_stale_record`
- `test_active_operations_check_ownership_after_server_restore`
- `test_secondmate_probe_cannot_borrow_another_tasks_binding`
- `test_teardown_uses_descendant_state_and_confirms_closed_bound_panes`

Also executed the focused `tests/fm-remote-secondmate-control.test.sh`. These supplementary tests passed. They were not treated as live scenarios or published as product evidence. No linters, formatters, static analysis, full-suite runs, pipeline operations, push, PR, or CI phases were executed.

Setup-only failures were corrected and re-driven: real CLI positional arguments and format names, exact Task heading and scaffolded branch contract, relative-socket canonicalization, disposable code-root topology for the recursive removal guard, and an overly strict kill-return assertion (the product's kill API is best-effort, so authoritative continued pane/process presence was asserted instead). None was a final product failure.
