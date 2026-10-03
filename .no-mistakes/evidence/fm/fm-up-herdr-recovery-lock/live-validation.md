# Herdr recovery-lock live validation

Target: `44eef00296b31462f361625f9b3898dbc7b2b39e`
Baseline: `1f3e769616fdf9f31f85f4c3e6a9f71606634238`
Runtime: existing Herdr 0.9.3 / protocol 22 and real Treehouse.

## Results

| User action | Observed product behavior | Evidence |
| --- | --- | --- |
| Start an ordinary new worker while another process holds the session presentation lock | Acquisition attempts spanned 4.524 seconds, then the public spawn command succeeded with the flat-layout warning. Metadata pointed to the existing primary workspace, no presentation journal was created, and focus stayed unchanged. | `ordinary-new.out`, `ordinary-new.err`, `ordinary-acquisition-attempts.log`, `live-lock-transcript.log` |
| Recover behind a holder that never releases | With the **unmodified production 120-second budget**, recovery refused 119.663 seconds after the first observed attempt. Metadata remained byte-identical, the recorded real Herdr operations contained no create/close/focus/move mutation, and focus was unchanged. | `stuck-holder.err`, `stuck-acquisition-attempts.log`, `live-lock-transcript.log` |
| Recover two workers from different homes after a real named-session restart | The second recovery remained pending for more than eight seconds after reaching acquisition, made 61 attempts (exceeding the former 50-attempt limit), and did not reach replacement creation while the first held the lock. After release, both public spawn commands succeeded, retained their exact workspace identities, replaced their own panes, removed the old husks, and preserved focus. | `bravo-acquisition-attempts.log`, `serialized-replacement-events.log`, `primary-resume.out`, `bravo-resume.out`, endpoint API responses in `live-lock-transcript.log` |
| Release a holder only after the acquisition deadline has elapsed | A six-second delayed acquisition operation used a shortened five-second recovery budget. The holder was released 5.4 seconds after the attempt began; recovery still refused, did not mutate Herdr or metadata, and left no acquired lock behind. | `regression/late-acquisition.err`, `regression/live-lock-transcript.log` |

## Before/after regression

The baseline's unmodified `bin/fm-spawn.sh` was materialized as a disposable executable beside the existing scripts, without changing tracked source or using a fleet bypass. Under the same synchronized real-session contention, the baseline second recovery exited with `refusing a concurrent resume` before the first holder was released. The target remained pending under that contention and completed both recoveries successfully.

See `regression/bravo-resume.err` and `regression/live-lock-transcript.log`. The disposable baseline executable was removed afterward.

## Isolation and cleanup

- All fixture homes were minted with `bin/fm-lab-home.sh create`; lifecycle calls used those marked homes, no `FM_*_OVERRIDE` relocation, and no gate-refusal bypass.
- Herdr lifecycle and API calls went through `bin/fm-herdr-lab.sh` with generated non-default `fm-lab-lock6454-*` names. Provision performed its own prepare contract; teardown succeeded and verified the default-session tripwire.
- Fixture homes, shell configuration, Herdr session data, git projects, origins, and Treehouse pools were all workspace-local. A short `/proc/<driver-pid>/fd/9` directory alias avoided the Unix socket pathname limit. The real workspace mover used that same real lab socket through a path-shortening adapter.
- The helper's required default-session tripwire used a read-only socket symlink; no pane or lifecycle operation was directed at the default session.
- The idle-shell workers exercised the actual public Firstmate spawn interface; no harness CLI, authentication, Herdr response, or Treehouse response was faked. Instrumentation only logged real calls, coordinated contention, and delayed the explicitly adversarial acquisition operation.
- Initial disposable-driver setup problems (duplicate prepare, shell selection, an overlong interactive pool lock, and a stale release marker) were corrected and scenarios re-driven. Their transcripts remain in `setup-attempt-*.log` for transparency; they were not product failures.
- Both completed proof labs were torn down in their evidence turn. All transient worktree files, pools, and the baseline executable were removed; the worktree has no test-created changes.

Commands: `python3 .gate6454/live.py` and `python3 .gate6454/regression.py`. Exact disposable drivers are retained as `live-driver.py` and `regression-driver.py` alongside this report; product CLI/API output is in the transcripts. No full repository suite, lint, formatter, static analysis, push, PR, or CI phase was run. This is a CLI wait-policy change, not a rendered UI change; CLI output, timing, endpoint state, and mutation audit are the relevant evidence rather than screenshots.
