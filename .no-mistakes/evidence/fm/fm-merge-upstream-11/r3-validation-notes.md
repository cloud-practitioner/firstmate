# Targeted live validation, round 3

Target: e468335538241080eadf51ea60a1b91706351ac6; base: dc1235ef0e8609d5280e5c06afc44cec9fef1182.

## Isolation

All runtime drivers started with an empty inherited environment, explicit `FM_BACKEND=tmux`, and no operator FM_HOME/path overrides. Lifecycle calls used marked homes inside the gate worktree and private `TMUX_TMPDIR=<lab>/tmux`, `tmux -L fm-lab` servers at 120 columns by 40 rows. Claude and Treehouse were copied to the worktree; tmux was built locally with a locally extracted byacc executable. No system install or global configuration command ran.

Claude used disposable HOME, CLAUDE_CONFIG_DIR, and XDG directories, with DISABLE_AUTOUPDATER=1 and nonessential traffic disabled. Its real onboarding UI was used as the live endpoint; authenticated model execution is NOT claimed, and this is NOT evidence about availability of the operator's normal login. No login, logout, or credential-store operation ran. Launcher target, executable checksum, symlink inode, mtime, and ctime matched before and after the live checks. The installed Treehouse executable still matched the original worktree-local copy. Prior-round external incidents were not investigated or repaired by this turn.

The only Herdr action was the supported helper's `prepare` against an isolated HOME/XDG namespace and a generated `fm-lab-*` name. It refused for lack of its required running-default tripwire; no provision, run, default-session lifecycle, or fleet-pane command followed.

## Live product evidence

- `r3-cli-final-transcript.txt`: capacity with no target, real CPU headroom constraint, ship/scout counts excluding secondmate lanes, malformed capacity refusal; public per-mate pin resolution, default fallback, and duplicate-pin refusal; leaked Paseo ancestry ignored; explicit Paseo missing dependency refuses before publishing task metadata. Also records generated brief output and database-path resolution only, not an actual no-mistakes service query.
- `r3-spawn-transcript.txt`, `r3-spawn-meta.txt`, `r3-spawn-worker.txt`: real Treehouse allocation and Claude scout launch to onboarding, home-local 0700 task temp and GOTMPDIR, actual peek/current-state output, and teardown removing the task temp and metadata.
- `r3-watch-retry-transcript.txt`: first unknown-but-recovery-grade-alive endpoint alarms; a genuinely changed viewport with recent progress is bounded while completed polls and fresh beacon prove monitoring continues; another genuinely changed viewport without recent progress alarms again.
- `r3-wait-transcript.txt`: watch.env overrides ambient 30-second polling; an opted-in worker blocker produces the long-cadence clearing action; removing the opt-in restores ordinary wedge escalation. Busy recovery events and worker status records are disposable input data, not claims of a model executing a job.
- `r3-head-transcript.txt`: a CI-ready Bitbucket status cannot conceal an unpreserved detached head; preserving that exact head to a local disposable bare remote changes the actual crew-state output from blocked to done. No real forge or pipeline was used.
- `r3-fork-final-transcript.txt`: actual IQX hook installation/idempotence, real git commit preserving its subject and human trailer with one Ixia trailer, and refusal for an unrelated origin; actual Bitbucket merge CLI refuses missing credentials, whitespace-only messages, and invalid UTF-8. No remote merge ran.
- `r3-extension-retry-transcript.txt`, `r3-extension-captured.result`: the real shipped file-signal extension is bound and verified through the Bash lifecycle, waits for a real file, captures its contents, classifies the result, retires the terminal source, acknowledges the result, and retires the binding. No stub product or protocol responder was substituted for this scenario.
- `r3-history.txt`: Git's actual merge state shows fork base and upstream 83b70ef4 as the merge's two parents, twelve upstream commits since a65dceee, both ancestries retained, and unchanged fork hook/Bitbucket merge implementation files. This is a history check, not a live Firstmate lifecycle claim.

## Focused portable checks

Completed: fm-capacity, fm-backend-paseo, fm-gotmp, fm-supervision-instructions, IQX hook, and extension-binding's example segment. Selected original executable tests also completed for per-mate pins and malformed-pin spawn refusal; per-mate/legacy/malformed relaunch pins; Bitbucket merge-message payload, refusals, file validation, and read-once normalization; Grok titled-composer geometry; authoritative no-run crew fallback; and NM resolver selection, explicit precedence, and unusable-response fallback. These portable/mocked checks are not native GUI, authenticated forge, or actual no-mistakes service evidence.

Two initial broader single-file invocations, fm-secondmate-harness and fm-pr-bitbucket, exhausted their local execution budgets after their earlier cases had passed. Their relevant selected cases were then run successfully with narrower entrypoints. No complete repository suite, linter, formatter, static analyzer, push, PR, or CI phase ran.

## Corrected test setup, not product failures

The first watcher driver typed text into an onboarding theme picker, which did not alter the viewport. Its no-progress stage timed out because it had not created a new stale hash. The retry uses Down to change the real rendered selection, asserts distinct actual capture hashes, and passes both progress and no-progress paths. The first manual extension driver completed every lifecycle operation but its cleanup could not remove immutable package directories; making only that disposable lab writable and re-driving the whole scenario passed. Test-created late Claude shutdown files and all remaining disposable homes, fixtures, local tool binaries, and builds were removed at completion.

## Untested limits

Native Paseo requires macOS and the running GUI app; this host is Linux without its CLI. Native xAI Grok and OMP are absent from PATH and have no supplied repository-local binaries. Their public parser/rendering checks ran, but those do not prove native harness interpretation or GUI delivery. Herdr prepare could not satisfy its mandatory default-session tripwire inside the isolated namespace, and creating or changing a default session to bypass it is forbidden. Actual Bitbucket API/merge behavior requires a sanctioned disposable repository and phase-owner authorization; ambient credentials were deliberately not used. A real registered no-mistakes workspace is not provisioned here, and initializing or controlling one belongs to the outer executor, not this phase. No screenshot is claimed: native changed Paseo/Grok UI surfaces were unavailable; CLI and real terminal captures are retained instead. Generated brief and OMP text artifacts are emitted-output contracts, not proof of model compliance.
