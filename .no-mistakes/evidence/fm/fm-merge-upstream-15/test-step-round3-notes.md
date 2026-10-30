# Scoped Test phase, round 3

Target: `3215e957a4c3176a7a6adf28b34de9fa355d376c`.

## Recorded decision and structural contract

The author requested restoring `bin/fm-dispatch-resolve.sh` and `tests/fm-agy-primary.test.sh` to upstream `b936f040`, carrying the known mapper/timing problems as upstream offers rather than fork patches. Read-only Git checks in `round3-merge-byte-contract.log` confirm both exact byte contracts. The current tracked tree equals merge commit `73970992`'s tree; the intermediate fix has no remaining tree changes. That commit has fork base `61b74893` and upstream `b936f040` as its two parents and brings seven upstream commits. Both contrib add-on trees are unchanged from the fork base. These are structural checks, not live runtime scenarios.

## Product-level evidence produced again in this turn

- `round3-manual-pr-live.log` and `round3-manual-pr-brief.md`: real project-mode and scaffold commands in a marked disposable home. Manual PR binding leaves the two-word posture intact, emits worker-written PR delivery instructions, and refuses incompatible modes. The brief is public generated output, not proof of model compliance.
- `round3-hidden-untracked-live.log`: an actual linked Git worktree hides untracked files from ordinary status. Real teardown still names the untracked path and refuses; hidden file bytes, metadata and HEAD are unchanged. No backend or pool stub supplies this refusal.
- `round3-remote-reply-live.log`, `round3-remote-reply-capture.txt` and `round3-remote-reply-status.txt`: real OpenSSH talks to a disposable ssh2 loopback server running the tracked remote entrypoint, real job worker and real delta reader. Parent ingestion appends one line; replay appends zero. Fault-injected exit-255 diagnostic bytes and exit-zero non-schema bytes produce no source stdout, no cursor advancement and no mirrored-status change. The owned remote worker is stopped.
- `round3-systemone-live.log` and `round3-systemone-http-requests.json`: real curl and quota-axi against a disposable local System One endpoint. A valid typed answer is accepted. With no measured Agy quota in the isolated user home, the resolver correctly escalates instead of inventing a ranking. Never-send prevents another HTTP request; an incomplete probability map produces an error without a profile. No external model quality or hosted compatibility is claimed.
- `round3-claude-primary.log`: real authenticated Claude, launched only through `bin/fm-live-claude.sh`, as the command on a private tmux lab session with a 120x40 grid. It returns `FM_MERGE15_ROUND3_READY`, exits zero, and leaves the host launcher target unchanged. Only the lab server is stopped. No Herdr operation or default terminal operation was performed.
- `round3-cli-evidence.html` renders these actual command transcripts for review; it is not an interactive-agent screenshot.

Drivers are retained in this evidence directory as `round3-live-checks.py`, `round3-remote-live.py`, `round3-claude-primary.sh`, and `round3-agy-probe.sh`; the SSH server implementation is the previously saved `round2-ssh-server.cjs`. Its workspace-local ssh2 dependency was installed with npm --prefix/--cache; tmux and libutempter were downloaded and extracted under the disposable worktree root after apt-get download reported no package candidate. No package was installed globally and no system package index was updated.

## Targeted existing checks

- `env -u FM_BACKEND bash tests/fm-project-mode.test.sh` and `env -u FM_BACKEND bash tests/fm-spawn-manual-pr-text.test.sh` pass.
- Six selected crew-state cases pass: stale failed overview, same-head stale failure, unverifiable timestamp, older-live/newer-completed, newer-live/not-hiding-a-newer-failure, and competing live runs. These are protocol fixtures, not genuine pipeline histories.
- Selected Agy SessionStart/scope, actionable follow-up, supervision-host park, arm denial, cd denial and subagent denial checks pass. These use the existing fake harness, not a model-driven Agy session. The restored known timing cases were not changed or characterized as fixed.
- Selected Pi/pi-signed MCP-off ship/scout launches, per-task overrides and unsupported-runtime refusals pass.
- Selected steering-inbox busy grace and later idle escalation checks pass.
- Selected secondmate stand-down preservation, in-flight refusal and dormant sweep checks pass.
- Selected PR-evidence arming/merge guards and Bitbucket off-by-default/opt-in evidence guards pass with the local forge. The file's top-level existing Python evidence checks also execute. No real PR is created or merged.

Exact function selections are in `round3-selected-cases.json`; `round3-select-tests.py` prepares disposable selectors without editing original tests. An initial selector escaping mistake allowed extra existing cases to run: the broader spawn and dormant fixtures hit their existing inside-code-root home placement refusal, and the task-inbox attempt hit its command time bound. After correcting the selector, a mistakenly added shell errexit interrupted an expected-refusal spawn check; removing it restored the test file's original shell semantics. The first filtered evidence PATH omitted cmp and then SHA-256 helpers; adding links to the existing real tools fixed those setup failures. Final selected runs pass. These were driver/setup mistakes, not demonstrated product regressions. Intermediate diagnostic logs are retained but are not claimed as passing acceptance evidence.

## Accepted live limits, rechecked where possible

- The real Agy CLI again requests authentication in an empty isolated user home; see `round3-agy-auth-probe.log` (120x40 private tmux). No credentials were copied or read, no login was completed, and no production configuration was changed. A pre-authenticated disposable Agy home is required to exercise model-driven primary/secondmate SessionStart, PreToolUse and Stop hooks. No authenticated Agy screenshot can be supplied because the session never gets past authentication.
- The real OpenAI provider again reports `OPENAI_API_KEY absent`; see `round3-openai-live-credential-check.log`. Hosted Decisions compatibility requires an authorized test key. The known valid-response mapper defect is intentionally retained by the exact-upstream restoration decision and is not reported as a new finding or silently described as fixed.
- Real competing no-mistakes history requires pipeline initialization/control, prohibited in this assigned phase. No such control command was attempted; only selected existing protocol fixtures were run. A separately authorized genuine fixture history is needed for that live proof.

The user previously accepted these three evidence limits; no duplicate warning finding is raised. No claim is made that hosted OpenAI, authenticated Agy hooks or genuine competing-run attribution passed.

No complete repository suite, linter, formatter, static analyzer, pipeline-control, push, PR-publication, CI or real merge phase was run. PR wording, remote CI and eventual merge method remain the outer executor's phases. No source, test or agent-memory changes are intended; disposable selectors, dependencies, homes and caches are removed before handoff.
