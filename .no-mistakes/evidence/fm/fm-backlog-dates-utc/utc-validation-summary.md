# UTC backlog live validation

Result: all exercised scenarios passed. No product or test-source changes were required.

## Setup

- Executed the real Firstmate scripts and installed tasks-axi 0.2.6, with disposable markdown backlog homes inside the assigned worktree.
- Froze Node's Date constructor/Date.now at controlled instants; Date's timezone-sensitive getters, tasks-axi's implementation, and Firstmate's scripts remained real. A preload also recorded real process arguments and TZ.
- Used the public snapshot time overrides for fleet and Bearings. Registry checks used a clock adapter delegating to the real GNU date executable, honoring TZ and `-u`.
- Downloaded real tasks-axi 0.2.5 into the disposable worktree-local toolchain to exercise bootstrap's outdated-version diagnostic, without changing any installed tool.
- Registry homes/code roots were sibling generated snapshots of the tracked product. This retained the seed command's root-containment guard while respecting the worktree boundary.

## Product scenarios

| Scenario | Observable result |
| --- | --- |
| Create, start, and finish work in Sydney at 2026-10-26T20:00:00Z (local date 2026-10-27) | Firstmate showed `created: 2026-10-26`, persisted `since 2026-10-26`, and closed work on 2026-10-26. |
| Repeat west of UTC at 2026-10-27T03:00:00Z in Los Angeles (local date 2026-10-26) | Firstmate used 2026-10-27 for creation, transitions, and completion. |
| Query holds due today and tomorrow in both zones | The UTC-day hold was ready/not held; tomorrow's hold remained held. Fleet `captain_actionable` and Bearings `decisions_open`/dated gates agreed. Unwrapped tasks-axi controls reproduced the original wrong-day stamp and opposite hold-boundary failures. |
| Use lifecycle helpers and create/answer a captain call in both zones | Plain and timeout-bounded mutations, bounded reads, direct captain-hold operations, and archived-body answer normalization completed with UTC backlog dates. The answer remained in persisted task state. |
| Detect current and outdated real tasks-axi releases under Sydney | Bootstrap accepted 0.2.6 and reported `OUTDATED: tasks-axi (installed: 0.2.5; ...)`. All captured Firstmate-originated tasks-axi processes, including both outdated-version probes, had `TZ=UTC`. |
| Seed a local secondmate and record a pending unreachable remote route under Sydney | Both persisted registry records had `added 2026-10-26`, not the Sydney calendar day. The local registry passed the real validator. The remote case used real OpenSSH against a disposable loopback endpoint that could not complete SSH; Firstmate reported unknown completion and preserved the UTC-dated route. No remote home was created. This does not claim successful remote provisioning. |

## Evidence

- `utc-live-cli.log`: complete product command transcript with environment, output, and exit status. The remote preflight nonzero exit is intentional and asserted.
- `tasks-axi-real-processes.jsonl`: real process launch timezone/argument observations; local-zone entries are the deliberately unwrapped controls.
- `sydney-backlog.md`, `los-angeles-backlog.md`: actual persisted final backlogs.
- `*-fleet.json`, `*-bearings.json`: actual product snapshot responses before completing the sample work.
- `utc-results.json`: selected snapshot records and process-timezone observations, asserted against the generated artifacts.
- `utc-registries.md`: actual persisted local and pending-remote registry records.
- `fm-tasks-axi-targeted.log`: the existing focused behavior suite run under `TZ=Australia/Sydney`.

## Boundaries and limitations

Only targeted tests and manual CLI checks were run; no linter, formatter, static analysis, full repository suite, pipeline control, PR, push, or CI phase was executed. The native BSD-date path was not exercised on this Linux/GNU-date host. No screenshot was captured because the exercised surfaces are command output, JSON, and persisted Markdown; no rendered UI or live primary was launched. Accepted host-local display exceptions were not changed. All disposable fixtures/tool downloads were removed after evidence capture.
