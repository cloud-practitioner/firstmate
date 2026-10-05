# Per-home task temp storage — live validation

Validated target `6c07974dff72857d1eae4f3c4b678d6c4e1e0874` against base `98d80a1616467b522d454261b0833aa538c467ca`.

## Product-level observations

| Scenario | Observed result | Transcript |
| --- | --- | --- |
| Launch the same task ID from two homes | Distinct `state/<id>.tasktmp` roots, mode 0700, correct child-process GOTMPDIR; no shared legacy root created | `live-temp-home.log` (successful rerun starts after the two corrected driver attempts) |
| Launch from home paths containing spaces | The real pane shell and its child received the exact quoted GOTMPDIR | `live-temp-home.log` |
| Tear down home A's task while home B's equal-ID task remains | A's root removed; B's scratch, Go temp directory, metadata, and captured pane remained; B then tore down independently | `live-temp-home.log` |
| Preplant a world-writable directory, symlink, or regular file at the selected root | Spawn refused each before launch/publication; existing contents and symlink target remained untouched | `live-temp-home.log` |
| Reuse an owned private directory | Mode tightened from 0750 to 0700 without losing existing scratch; teardown removed it | `live-private-reuse.log` |
| Relaunch a stopped task with a recorded legacy root | Exact legacy root, prior scratch, and child's GOTMPDIR preserved; teardown removed the recorded legacy root | `live-legacy-temp-home.log` |
| Relaunch a rootless old task record | A home-scoped root was created, without a shared legacy directory | `live-legacy-temp-home.log` |
| Recover an existing secondmate without `--relaunch`, then explicitly relaunch it | Both operations kept the recorded legacy root and scratch; no replacement home-scoped root; final teardown removed it | `live-legacy-temp-home.log` |
| Bring down a disposable lab containing legacy task roots | Real private tmux server and recorded processes stopped; own mate/worker legacy roots removed, including the failed-spawn worker with no metadata; unrelated legacy root retained | `live-lab-down.log` |

Herdr sessions used only `bin/fm-herdr-lab.sh` named non-default labs. `provision` performs its own `prepare` for a new session; explicitly preparing first caused an ownership refusal, corrected before rerunning. An initially incorrect `terminal capture` call was changed to `pane read`. Every lab's guarded teardown returned zero, which includes verification of the default-session tripwire.

Live spawns used the product's supported raw shell-command launch interface, with real Herdr, Treehouse, pane shells, child processes, metadata publication, and teardown. No harness CLI or login was faked. Secondmate validation refuses homes inside the code root, so a byte-for-byte copy of this worktree's executable scripts was materialized in a sibling fixture code directory inside the worktree. This kept both code and secondmate homes within the workspace boundary without changing product guards. Legacy fixtures used unique, exclusively created ephemeral test directories and were removed in the same test invocation.

## Focused automated checks

- `TMPDIR="$PWD/.test-phase/tmp" bash tests/fm-gotmp.test.sh`: recorded-root removal, absent field, and already-missing directory.
- Kimi selectors: `test_kimi_launch_then_send_is_verified`, `test_kimi_spawn_refuses_shared_task_temp_root`, `test_task_temp_root_is_scoped_to_the_spawning_home`.
- Relaunch selectors: `test_relaunch_keeps_a_legacy_task_temp_root_and_scopes_a_missing_one`, `test_secondmate_recovery_preserves_a_legacy_task_temp_root`.
- Only the setup and teardown block of `tests/fm-live-lab.test.sh` was executed, against real private tmux and processes. Its product output is in `live-lab-down.log`.
- The home-scoping regression was also executed against a fixture copy of the base commit's `fm-spawn.sh`. It failed as expected: `home A did not record a temp root inside its own home` (exit 1); the target's version passed.

The first Kimi selector attempt inherited the host's Herdr backend choice instead of its modeled tmux backend; its rerun cleared those environment signals. The first secondmate regression attempt used a fixture inside the original code root; the sibling fixture-code layout resolved the product's deliberate containment refusal. These were test setup issues, not product failures.

`tmux` was initially absent from PATH. Release 3.6a was downloaded, compiled, and installed only inside `.test-phase/tools`, using the release's shipped generated parser C file and existing libevent/ncurses. The resulting real tmux binary drove the lab teardown test; no packages or global configuration were installed or changed. Namespace alternatives (`unshare -Ur`, bubblewrap) were unavailable because this host denies unprivileged namespaces.

Temporary selector scripts, downloaded/build artifacts, private fixtures, and test-created launch namespaces were removed. Read-only hook fixture directories required permission restoration before workspace cleanup. No intentional source changes remain. The full repository suite, lint/static analysis, and other gate phases were not run.

The live drivers are archived as `live.py`, `legacy.py`, and `reuse.py` for inspection. This is a CLI/filesystem behavior change; pane transcripts and persisted-state observations, rather than visual screenshots, are the relevant evidence.
