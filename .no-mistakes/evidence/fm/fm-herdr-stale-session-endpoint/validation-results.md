# Targeted stale-Herdr-endpoint validation

Target: `3f8ce587ad1fb7754fea76d56a0bbd4cd4b9f1f2` relative to `17a7b57015e3b3c8575d7e8775782e4b08b44869`.

## Real product evidence from this turn

- `live-reused-endpoint.log`: real Herdr 0.9.3, real Treehouse, unmodified Firstmate entrypoints. The original spawn published `ps:<pid>:<UTC-start-time>`. An `exec` preserved that binding. Deleting and recreating the same named lab reused `w1:p2` with a different process identity despite matching label and cwd. Main and secondmate-home records read `missing`; capture, key and text refused, and guarded close retained the unrelated pane. Relaunch selected `w1:p3`, preserved the worktree and unlanded sentinel, and published the new identity. A real running Claude executable was registered through Herdr's public registry: its current record read `alive`, and the stale binding read `missing`. This proves process-backed liveness, not Claude authentication or model completion; its config was isolated for the final run. Stale-child and owned-endpoint teardown completed. A real failed Treehouse acquisition left no B metadata, pane, or workspace despite stale A claiming the response-derived address.
- `live-original.meta` and `live-rebound.meta`: persisted public endpoint contracts before and after recovery.
- `focused-herdr-recovery.log` and `focused-recovery-details/`: the edited recovery sections of `tests/fm-backend-herdr-presentation-e2e.test.sh`, replayed with real binaries. Process-bound records reject replacement shells. Legacy primary, repeated primary, secondmate-child, and concurrent cross-home recovery preserve their exact projected workspace and replace only the exact husk. Final run exited 0 in 201.7 seconds.
- `herdr-presentation-live.log`: the bounded presentation suite reached and passed the real flat/projected metadata comparison and create/abort/teardown checks. It was stopped at 360 seconds during the later, unchanged focus-wave section. It is not reported as a complete-suite pass. The edited recovery sections were then driven separately to completion.

Every live server call used `bin/fm-herdr-lab.sh` with a non-default `fm-lab-*` name. The final drivers put session state, sockets, homes and Treehouse pools under disposable `FM_TASK_TMP`; the default-session tripwire stayed unchanged. Lab teardown completed and owned test processes/scratch were removed. The abandoned worktree scratch was removed and `git status --porcelain` is empty. No runtime source or test files were changed.

## Targeted deterministic checks

All exited 0:

- `bash tests/fm-backend-herdr.test.sh`
- `bash tests/fm-remote-secondmate-control.test.sh`
- `bash tests/fm-teardown-endpoint-safety.test.sh`

These are explicitly not claimed as live evidence. They also cover portable identity failure/fallback, unreadable ownership refusal, task-selected claimant context, response-owned cleanup and parent-route ownership.

## Limit

The host-local remote-control command hardcodes session `fm-remote`; the mandatory lab helper refuses that name (`remote-lab-boundary.log`). No live call was made against that session or any remote/shared host. The remote public-command integration therefore remains deterministic-only. To exercise it live under this runbook, provide an approved remote-control lab mode that selects a named `fm-lab-*` session without a gate bypass. This does not block the rebuild/reused-address intent demonstrated live in both home contexts.

## Setup corrections and bounds

Initial manual fixtures incorrectly shared the parent's worktree with a child's record, then used a non-Treehouse-managed child worktree. They were corrected to an independently managed child fixture. The abort fixture's stale A record was retired after its assertions before owned teardown, which correctly refuses conflicting worktree claims. The focused recovery fixture initially omitted secondmate parent workspaces; creating the actual labeled parents corrected flat fallback. Final runs passed. None of these setup mistakes is reported as a product failure.

This is CLI/backend behavior, not a UI-layout or copy change. Evidence is product CLI output and persisted metadata, not screenshots. No full repository suite, lint, formatting, static analysis, pipeline control, push, PR or CI phase was run.
