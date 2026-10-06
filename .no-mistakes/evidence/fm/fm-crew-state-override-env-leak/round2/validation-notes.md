# Herdr environment-leak validation — round 2

Target: `c45bd4a6f9fb75dfed226027c9ed956fcea8e9cf`.
Original baseline: `06a89438bead6193fd300248c5366941a30789d9`.
Pre-round-2-fix revision: `b819bc343b0947af4c7c1618d47aaa1b305860fd`.
Runtime: real installed Herdr 0.9.3, protocol 22; real Treehouse; Bash and Python telemetry workloads.

## Result

**Go.** Every derived environment-isolation scenario was exercised live and passed on the target. No project source or test files were changed.

### Read a captured snapshot without leaking its overrides

`captured-read.log` shows the real `fm-crew-state.sh` resolving a captured record absent from the home's ordinary metadata, reaching the real Herdr CLI, and passing none of the snapshot-only variables to that CLI. `fleet-snapshot.json` and `fleet-snapshot-boundary.log` also exercise the actual `fm-fleet-snapshot.sh --json` producer and its captured-record read chain. The real pane is agent-free: `unknown · source: pane · harness state unavailable` is its truthful result, not a fabricated working agent.

### Start a server from a snapshot read without contaminating descendants

A named lab session was provisioned, given a real pane, and stopped through the lab helper. A scoped `fm-crew-state.sh` read then started that server again through the adapter's server-ensure path, forwarded to the helper's provision operation. This is not a claim that the installed Herdr CLI itself automatically started it: the boundary log explicitly records the adapter's `server` call.

`baseline-stopped-read.json` proves that the original baseline's startup path retained both captured crew-record overrides in the real restored shell's `/proc/<pid>/environ`. `current-stopped-read.json` proves that the target started a real running server whose restored shell has no snapshot overrides. `baseline-server.json` and `clean-server.json` independently compare direct server startup through the adapter.

### Spawn ship workloads into an already contaminated server

`spawn-results.json` entries `ship-absent`, `ship-all`, and `ship-paths-only` are outputs written by real processes launched by the public raw-command interface of `fm-spawn.sh`, into real Herdr panes and real Treehouse worktrees. The server was deliberately provisioned with all twelve scoped variables, including all five path overrides and marker `1`.

No snapshot-only variable or nonempty marked path reached these workloads. Both allowlist variants explicitly retain the five path names; the paths-only variant omits their marker. Legitimate `FM_HOME` and the telemetry toolchain's isolation variables are retained so the subsequent real crew-state reads can resolve both metadata and the lab endpoint. All final target observations report `source: pane`, never `no metadata`.

The spawn caller was additionally contaminated with planted record and summary values. Its actual backend subprocess log contains none of those planted values.

### Relaunch a workload into the same contaminated pane

Before relaunch, all twelve variables were re-exported into the existing pane shell. The launch allowlist retained paths but omitted the marker. `relaunch.json` proves the replacement workload started without the scoped variables and resolved the real task metadata through the correct home.

`prior-ship.json` reproduces the previous round's failure using real code from `b819bc3`: all five marked paths survive that revision's paths-only filter, and the real crew-state read reports `no metadata for prior-ship`. Removing only those inherited paths restores `source: pane`. Target ship/relaunch outputs demonstrate the fix without that manual repair.

### Spawn and relaunch a secondmate without snapshot-only values

`secondmate-absent.json`, `secondmate-all.json`, and `secondmate-paths-only.json` show a real secondmate launch and two relaunches. The secondmate receives its own legitimate `FM_HOME`; record/summary overrides are absent, and all five path overrides are empty, as the secondmate launch contract specifies. A seeded child metadata record in that home resolves through the real crew-state interface.

### Arm the real watcher from a contaminated environment

`baseline-watcher.json` shows the real baseline watcher retaining the planted overrides. `current-watcher.json` shows the unmodified target watcher owning its home-local lock and beacon, running with none of the twelve scoped variables. Both watchers were stopped through `fm-watch-arm.sh --stop`, and their arm processes exited.

The repository's documented `tests/lib.sh` sandbox authorization seam was used for deliberately contaminated arm calls, since the gate guard intentionally refuses nonempty overrides before arm's cleanup. This was a marked disposable home, not an operator home or a primary harness session; the watcher was not replaced with a stub.

### Preserve legitimate unmarked path overrides

`unmarked-client.log` shows the real CLI retaining an unmarked `FM_STATE_OVERRIDE` while always removing the crew-record override. `unmarked-absent.json` and `unmarked-enabled.json` show real relaunched workloads retaining all five legitimate home paths with marker `0`, with and without filtering. The always-scoped variables remain absent.

## Focused executable regressions

`python3 .v/targeted.py` ran only these selected author-provided regression entrypoints, from a disposable byte-for-byte runtime/fixture copy:

- `tests/fm-backend-herdr.test.sh::test_herdr_client_calls_never_receive_snapshot_scoped_env`
- `tests/fm-crew-state.test.sh::test_snapshot_override_read_never_reaches_herdr`
- `tests/fm-spawn-compact-adviser-disable.test.sh::test_snapshot_scoped_variables_are_cleared_from_the_launch`
- `tests/fm-spawn-compact-adviser-disable.test.sh::test_launch_preserves_unmarked_path_overrides`
- `tests/fm-spawn-compact-adviser-disable.test.sh::test_spawn_process_clears_snapshot_scoped_variables_before_backend_calls`
- `tests/fm-spawn-compact-adviser-disable.test.sh::test_relaunch_clears_snapshot_scoped_variables`
- `tests/fm-watch-arm.test.sh::test_arm_clears_snapshot_scoped_variables_before_forking_the_watcher`

All passed. Crew-state's top-level initialization also ran its existing cancellation/disposition fixture checks; those incidental checks are retained transparently in `targeted-regressions.log`. The complete repository suite was not run. No linter, formatter, static analyzer, pipeline, push, PR, or CI phase was invoked.

## Isolation, setup corrections, and evidence

Every live Herdr operation passed through `bin/fm-herdr-lab.sh` for session `fm-lab-e2`, using its prepare/provision/run/stop/teardown contract. Every lifecycle turn ended with guarded teardown and the default-session tripwire check. The operator's default session and fleet panes were never restarted, relaunched, or otherwise operated on.

Herdr configuration, socket/session files, lab-helper state, home directories, repositories, runtime copies, and test fixtures were confined to `.v/` in the gate worktree. The thin Herdr wrappers forward to the real installed executable through the helper; they do not simulate its responses. The session-list wrapper combines the real read-only default tripwire inventory with the real worktree-local lab inventory. Relative `XDG_CONFIG_HOME=.v` avoids the Unix-domain socket path length limit of this long worktree path.

Initial setup assertions were corrected and scenarios re-driven: agent-free panes cannot prove a paused status from a wake log; generated briefs must have their placeholders filled; allowlists must retain legitimate `FM_HOME` and fixture wrapper controls; a secondmate's own task record lives in its parent's home, so its workload reads seeded child metadata in its own home. These were fixture corrections, not target product failures. Read-only spawn-owned fixture directories were made owner-writable solely for cleanup.

No harness executable or login was faked. These environment-contract checks deliberately use the product's raw-command workload interface and do not claim a real Claude/Pi model session. No production credentials were read or mutated. This is not a visual UI change, so workload JSON, persisted state, process environments, and CLI transcripts are the relevant evidence; screenshots are unnecessary.

Final drivers and forwarding wrappers are preserved beside the evidence. Disposable labs, watchers, launch fixtures, and worktree-local runtime copies were cleaned up before returning the test result.
