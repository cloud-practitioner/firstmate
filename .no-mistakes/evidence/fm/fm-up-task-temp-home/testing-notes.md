# Task-temp home validation

Target: `40b3ad9e3d95795d3a18592873623170c08e67e5`
Baseline: `05196e30ead54796dfbe986db61abe9d8df9e3d2`

## Live product evidence

All target scenarios below passed. Firstmate's real executable CLI, Treehouse, and Herdr 0.9.5/protocol 22 were used. Tasks were actual `/usr/bin/python3` jobs launched through Firstmate's documented raw launch-command interface; these jobs recorded their inherited environment and working directory into their actual `GOTMPDIR`. No AI CLI, login, backend, or task-temp implementation was simulated. The secondmate scenario used an unchanged disposable copy of the runtime so its secondmate home could be a sibling of the runtime while remaining inside the assigned worktree.

Every Herdr command used the guarded `bin/fm-herdr-lab.sh` transport and named non-default sessions. Provision performed its own prepare; teardown succeeded, including the default-session tripwire. No primary AI session or credentials were needed or modified.

| Scenario | Product transcript |
| --- | --- |
| Equal task IDs in two homes get distinct 0700 roots; spaces and an apostrophe in one home are handled correctly | `live-tasktmp.log` |
| Teardown removes A's root without removing B's output | `live-tasktmp.log` |
| A rootless task gets a home-scoped root on relaunch | `live-tasktmp.log` |
| Recorded legacy `/tmp/fm-<id>` roots retain earlier scratch output across relaunch and are removed by teardown | `live-tasktmp.log` |
| World-writable and symlink task roots refuse before metadata/task output; sentinel targets remain unchanged | `live-tasktmp.log` |
| Fresh secondmate uses its parent's home-scoped root; recovery and explicit relaunch preserve a legacy root; teardown removes it | `live-secondmate-managed.log` |
| Real `fm-live-lab.sh down` removes home roots, owned launch directories, and unique lab legacy roots, while preserving an unrelated shared legacy root | `live-lab-cleanup.log` |

The baseline's real executable was also run in a separate lab. It reproduced the original bug: equal IDs in two homes shared `/tmp/fm-<id>`, and teardown in A deleted B's scratch directory. See `live-baseline.log`. Both baseline tasks and that lab were subsequently torn down.

## Focused automated checks

- `bash tests/fm-gotmp.test.sh`: passed.
- Selected existing functions from `tests/fm-kimi-harness.test.sh`: `test_kimi_launch_then_send_is_verified`, `test_kimi_spawn_refuses_shared_task_temp_root`, `test_task_temp_root_is_scoped_to_the_spawning_home`: passed (`fm-kimi-targeted.log`).
- Selected existing functions from `tests/fm-control-relaunch.test.sh`: `test_relaunch_keeps_a_legacy_task_temp_root_and_scopes_a_missing_one`, `test_secondmate_recovery_preserves_a_legacy_task_temp_root`, `test_relaunch_serializes_concurrent_durable_metadata_publication`: passed (`fm-control-targeted.log`).
- Selected existing lab cleanup setup/assertions, additionally printing the actual `down` CLI output: passed (`live-lab-cleanup.log`).

The selected functions used their original fixture and function definitions in temporary scripts located alongside the original tests. Those scripts did not assert implementation text. Kimi/control checks use test doubles and are supplemental, not claimed as live scenarios.

## Wider attempts and limitations

No complete repository suite, linter, formatter, static analysis, publication, PR, or CI phase was run.

Initial wider file runs were **not all clean**:

- The Kimi file exceeded its 240-second command budget after its changed temp-root cases had passed. Its focused cases were then rerun successfully.
- The control-relaunch file initially failed its short trace-delivery wait. The relevant legacy tests had passed; those and the trace/metadata case passed on the focused rerun.
- The live-lab file initially could not execute tmux in its clean environment. A workspace-local tmux package and dependency were extracted without system installation; a local wrapper supplied its library path even under `env -i`. After this correction, changed lab cleanup assertions passed. Wider runs intermittently failed the unrelated fixed elapsed-time and immediate process-exit assertions. The PID-identity case passed on both baseline and target when rerun separately; an additional isolated TERM-resistant-process case exceeded a 50-second budget. These wider attempts are retained as logs; no full-file or full-suite pass is claimed.
- The first secondmate fixture was an unmanaged Git worktree, so Treehouse correctly refused to return it. It was replaced by a real Treehouse-leased fixture and the complete secondmate scenario then passed. The original disposable legacy scratch survived into that successful recovery test.

These limitations did not prevent direct live demonstration of the requested temp-root behavior. No tracked source or test files were changed. Evidence is CLI/state-oriented because the change does not alter a rendered UI.
