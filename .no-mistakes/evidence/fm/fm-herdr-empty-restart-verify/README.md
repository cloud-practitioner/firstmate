# Empty-layout restart validation

Target: `df28e3fc7da62bbd42c0ba22c3d8927408b951ac` (only `docs/herdr-backend.md` changes).

## Product evidence

- `empty-restart-transcript.log`: real Herdr 0.9.5 / protocol 22. Stop named `fm-lab-empty`, move its actual `session.json` and `session-snapshots` aside, provision again, observe zero workspaces and a recorded pane classified `missing`. Recreate `w1:p2` with the original label and cwd but a different root-process identity. Input and capture refuse it, guarded close preserves it, and replacement creation uses `w1:p3` without deleting the foreign pane.
- `secondmate-restart-transcript.log`: two project-less registered homes, `alpha` and `beta`, seeded with the real product and launched with the real Claude CLI using the existing normal login. Each has a real live agent before restart. After moving the layout aside, both are `relaunchable|missing`, both relaunch through `fm_secondmate_liveness_relaunch` and `fm-spawn.sh`, their process identities change, exactly two one-tab secondmate workspaces remain, and repeat probes report `alive`. The captured Claude output includes the actual lab-readiness response. Safe mode prevents unrelated user customizations from running; no login or credential store was changed intentionally.
- `teardown-sessions.json`: after guarded teardown, only the still-running default session remains. Both successful drivers also finish with `teardown_exit=0`; the helper's default-session tripwire passed.

The change has no rendered UI/layout-code surface. CLI/API and real terminal transcripts are the evidence; no screenshots were needed for these documentation corrections.

## Isolation and reproduction

All intentional fixture/tool writes were under the run worktree's `.test-herdr-runtime/`. Evidence is in this directory. Herdr's helper still owned every named-session lifecycle call. No live-run gate bypass was enabled. Source scripts ran from the original gate worktree. Claude was not replaced by a stub, and no fake login or registration was used.

This host rejects Bubblewrap user namespaces. `HERDR_CONFIG_PATH` does not relocate Herdr's session storage. `XDG_CONFIG_HOME` does relocate it, but the full worktree prefix exceeds Unix-socket pathname limits. A workspace-local PRoot therefore mapped local config storage to the short **virtual** `/fm-config` path. Only the existing default-session socket was additionally exposed for the helper's tripwire. For secondmates, local `virtual-main`, `virtual-alpha`, and `virtual-beta` storage was mapped to virtual `/fm-main`, `/fm-alpha`, and `/fm-beta`. This satisfied the sibling-home and marked-lab guards without relocating the source root, modifying the guard, or writing outside the worktree. These are sandbox runtime paths, not host-created root directories.

The PRoot binary was downloaded locally from:

`https://raw.githubusercontent.com/proot-me/proot-static-build/master/static/proot-x86_64`

SHA-256: `8007ba1ac74bba3147035a2643b394abc0e71cf9b7c8bdb3646b88af9fe2e987`.

`PROOT_NO_SECCOMP=1` was required by this build. Its old syscall translator also required a process-local compatibility filter returning `ENOSYS` for `statx` and `renameat2`, allowing standard libc/coreutils fallbacks. The retained `proot-legacy-syscalls.c` is that filter; compile it locally with `cc ... -o .test-herdr-runtime/tools/legacy-syscalls`. It does not mock any product behavior or change host-wide settings.

Retained executable inputs:

- `isolated-backend-runner.sh` and `isolated-secondmate-runner.sh`: PRoot environment and filesystem mappings.
- `scoped-herdr-client.sh`: forwards adapter Herdr operations through `bin/fm-herdr-lab.sh run`, validating the requested session. Only the read-only version query directly invokes the installed binary.
- `empty-restart-driver.sh` and `secondmate-restart-driver.sh`: exact successful behavioral checks.

To reproduce, recreate the local runtime's `tools`, `tmp`, `config/herdr`, `home`, `tripwires`, and empty `virtual-*` directories; place the downloaded PRoot, compiled filter, and scoped client at `tools/proot`, `tools/legacy-syscalls`, and `tools/herdr`. Run each corresponding isolation runner with `bash <driver-path>`. The driver traps perform guarded Herdr teardown. Remove the local runtime afterward (its generated Git-hook directories need owner write permission restored before recursive removal).

## Supporting targeted test and corrected setup attempts

`FM_TEST_BASE_PATH="$PATH" FM_TEST_SKIP_ORPHAN_REAP=1 bash tests/fm-secondmate-liveness.test.sh` passed. This is supporting stub-based behavior coverage, **not** the basis for any `live: true` result. No complete repository suite, linter, formatter, or static-analysis tool was run.

Setup-only attempts retained separately show: a corrected `pane process-info` flag, a correctly refused source-root override, the old PRoot/coreutils incompatibility, a corrected `pane read` flag, and a read-only fixture reset that needed owner write permission restored. An initial focused-suite run with `TMPDIR` inside the source tree likewise hit the intended sibling-home guard; its normal ephemeral test-root rerun passed. These were setup issues, not product regressions. All successful live runs used the actual product and guarded teardown. No source or test changes were needed, and all downloaded tools and fixture data were removed before returning.
