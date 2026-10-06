# Herdr environment isolation — live validation

Target: `b819bc343b0947af4c7c1618d47aaa1b305860fd`.
Baseline: `06a89438bead6193fd300248c5366941a30789d9`.
Installed Herdr: 0.9.3, protocol 22.

## Outcome

**No-go:** the emitted ship/relaunch command removes `FM_SNAPSHOT_SCOPED_ENV` but retains marked snapshot path overrides inherited from a pane. A worker launched into the contaminated lab server still receives nonempty `FM_ROOT_OVERRIDE`, `FM_STATE_OVERRIDE`, `FM_DATA_OVERRIDE`, `FM_PROJECTS_OVERRIDE`, and `FM_CONFIG_OVERRIDE`. The same happens when the launch allowlist explicitly includes those names.

`live-ship.json` and `live-relaunch.json` show the concrete consequence: the real `fm-crew-state.sh live-ship` reports `state: unknown · source: none · no metadata for live-ship`. Calling the same executable after removing only the inherited snapshot paths resolves its metadata and reaches the pane-state source instead. A secondmate's existing launch prefix assigns these path variables empty values, so the secondmate does not have this effective path-override failure.

The pane's marker was `FM_SNAPSHOT_SCOPED_ENV=1` before launch. Its absence in the workload is part of the failure: the launch removed the marker without first clearing the paths it marked as snapshot-scoped.

## Successful checks

- The baseline adapter's real server-start path propagated crew-state overrides into a new Herdr shell (`baseline-server-descendant.json`). The target adapter's equivalent path did not (`clean-server-descendant.json`).
- A real crew-state read used captured metadata that did not exist in the ordinary state directory, reached the real Herdr CLI, and kept all snapshot-scoped values out of those CLI environments (`captured-crew-state.log`). The pane was intentionally agent-free, so its truthful result was unknown, not an invented live-agent status.
- Real ship, allowlisted ship, relaunch, and secondmate launches removed both crew-record overrides and all five other always-scoped names from the workload environment (`spawn-results.json`).
- The unmodified real watcher owned its lock and fresh beacon and ran without inherited snapshot overrides (`watcher-override-process-environment.json`). It was stopped through the home-scoped stop entrypoint.
- Selected author-added executable regression functions passed. Initial fixture failures were resolved by clearing inherited Herdr backend identity and using a worktree-local sibling runtime copy for secondmate fixtures, rather than creating a secondmate illegally inside the runtime root. Crew-state's existing cancellation/disposition cases also executed as incidental fixture checks; no complete repository suite was run.

## Isolation and what was actually driven

All live Herdr operations used `bin/fm-herdr-lab.sh` and named session `fm-lab-e`. Provision owns prepare for a new session; teardown was performed in each evidence turn. The helper verified its default-session tripwire at teardown. No default-session lifecycle or fleet-pane operation was performed.

The runtime wrappers do not fake Herdr: they forward to the installed real binary through the lab helper. Herdr state was relocated under `.v/` in the gate worktree. A relative `XDG_CONFIG_HOME=.v` avoided Linux's Unix-socket pathname limit for this unusually long worktree path. The session-list wrapper combines two actual read-only inventories: the operator default's mandatory tripwire record and the worktree-local lab sessions. Operational commands are restricted to the exact lab name.

Spawn/relaunch checks used the product's supported raw-command launch interface with a finite Python telemetry workload. This exercises real Firstmate scripts, real Herdr panes, real Treehouse worktrees, emitted launch execution, and real crew-state reads; it is not a fake harness executable or a fake login. No Claude/Pi model session was claimed or needed to observe the process-environment contract. A byte-for-byte worktree-local copy of the product scripts was used for sibling secondmate-home fixtures because secondmate homes may not be nested under the runtime source root.

The watcher override check used the repository's existing `tests/lib.sh` sandbox gate seam with a marked disposable lab home and the **unmodified real watcher**, not the stub used by the unit regression. Direct contaminated arm calls without that test seam were refused by the existing gate check before watcher startup; clean marked-lab arm was also verified without the seam.

A crew-state-only read against a stopped lab did **not** auto-start Herdr 0.9.3, on either baseline or target (`autostart-reproduction.json`). Therefore the explicit server-start boundary supplies the before/after inheritance reproduction; the suspected automatic-start mechanism is not presented as observed on this installed release.

All labs, watcher processes, local runtime copies, fixture projects, and generated launch data were torn down. No source files were changed. This is an environment-handling change, not a visual UI change; CLI transcripts and process/workload JSON are the relevant evidence.
