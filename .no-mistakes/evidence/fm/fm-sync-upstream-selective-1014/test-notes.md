# Selective upstream sync: targeted runtime validation

Validated target `90f23df1b95b46fd9d87a62ac23be1dacefe39fc` against base `51f0a7c05a39712cbfd02139ff0767210e4e7dc5`.

## Product-level evidence

- `pi-custom-message.log`: real Pi 1.2.0 AgentSession loads both tracked Firstmate extensions. A user run, a promptless custom run, and real `fm-branch-process` custom runs complete without extension errors. An outcome stays parked while away, surfaces on return, and is acknowledged through the real `fm_branch_processed` tool.
- `pi-session.jsonl`: the real session's persisted protocol, including user, custom, and assistant messages.
- `pi-model-requests.json`: requests received by the disposable local HTTP model endpoint. This endpoint supplies deterministic text only; no Pi, extension API, session, event emitter, fleet script, backend, or worktree provider was mocked in these live scenarios. No provider credentials were needed.
- `role-cli-transcript.log`: real role, brief, spawn, and promotion commands. Covers default refusal, matching maintainer scope, one-task consent normalization/non-persistence, wrong scope, symlink refusal, consent/brief disagreement, non-ship consent rejection, local-only scope, and consented promotion's persisted metadata.
- `secondmate-lifecycle.log`: real Pi CLI processes on an isolated tmux 3.3a `fm-lab` socket, with a nonzero 120x40 grid. Actual parallel bootstrap recovery relaunches both missing mates; real backend probes classify both alive. Attempt ledgers show serialized launches. The next sweep preserves both process IDs and ledgers. A separate lock holder causes a one-second bounded refusal without endpoint or ledger changes. Parent role propagation, revocation, and refusal of replanted child grants are checked through the real role CLI.
- The same lifecycle transcript includes actual ship spawns, using real Treehouse 3.1.3 worktrees and real Pi CLIs on an offline clone sharing the fixture code root's history. Both maintainer and consented dispatch reach a running worker and local model reply. A third task without authority is refused, with no task metadata.
- `mate-a-pane.txt`, `mate-b-pane.txt`, `ship-grant-pane.txt`, `ship-consent-pane.txt`: captured live terminal output. The two ship captures show their actual local model replies after accepting trust only for disposable worktrees.

## Before/after reproduction

- `pi-custom-message-baseline.log`: the identical real-Pi promptless custom delivery, loading the two extension files from the base commit, records `Cannot read properties of undefined (reading 'trim')` at `before_agent_start`. The current files complete the same delivery without an exception.
- `secondmate-lifecycle-baseline.log`: restoring only the pre-fix liveness library causes one parallel secondmate recovery to record `attempt` then `failed`; current code records `relaunched` for both. The baseline's nonzero driver exits are expected regression reproductions, not failures of the target.

## Targeted automated checks

The following scripts passed; the complete repository suite, linters, formatters, and static analysis were not run:

- `bash tests/fm-self-repo-role.test.sh`
- `FM_PI_PACKAGE_DIR="$PWD/.validation/pi-package" bash tests/fm-pi-branch-extension.test.sh`
- `bash tests/fm-pi-watch-extension.test.sh`
- `bash .validation/product/tests/fm-secondmate-liveness.test.sh`

All used isolated `FM_HOME`/`TMPDIR`. The installed Pi package uses a flattened dependency layout, so a workspace-local package facade supplied the nested dependency paths these tests expect. The liveness suite needed an unchanged, separately git-initialized product copy inside the workspace: production correctly rejects secondmate homes beneath its code root, and its remote-command guard requires commands to be tracked. After these fixture corrections all targeted scripts passed.

## Live driver commands

- `python3 .validation/live-role.py`
- `TMPDIR="$PWD/.validation/tmp" node .validation/pi-live.mjs` with fleet/backend overrides removed from the environment
- `LAB_BASELINE=1 LAB_EXTENSION_ROOT="$PWD/.validation/baseline" TMPDIR="$PWD/.validation/tmp" node .validation/pi-live.mjs` (expected pre-fix exception)
- `python3 .validation/lifecycle-live.py`
- `LAB_BASELINE=1 LAB_PRODUCT="$PWD/.validation/liveness-baseline" python3 .validation/lifecycle-live.py` (expected pre-fix relaunch failure)

Copies of the final temporary drivers are included as `role-driver.py`, `pi-driver.mjs`, and `lifecycle-driver.py`. Their `.validation` paths describe disposable test setup, not tracked project additions.

## Isolation and limits

All intentional setup, tool extraction, git fixtures, provider data, and homes stayed under the gate worktree. Since tmux was absent on PATH, its Debian binary and libutempter were unpacked locally without system installation. The attempted source build lacked yacc; this was worked around using the locally unpacked binary. A private tmux default command preserved the fixture PATH so real Treehouse could run. No live default tmux or Herdr session was used. No source changes were necessary; copied `bin/` and `.pi/` remained byte-identical to the target.

Bootstrap emitted expected empty-fixture diagnostics: no GitHub login, independently seeded mates lacking the fixture code-root commit, and gate refusal of override-bearing CONFIG_REREAD notification sends. Role inheritance/revocation assertions concern actual on-disk receipt enforcement and fresh role resolution; successful model-side CONFIG_REREAD notification delivery is not claimed. No operator credential, fleet state, or checkout was modified.

All private tmux servers, lab homes, temporary worktrees, downloaded tools, copied products, and test caches were removed. No worktree-scoped live processes remained. Runtime behavior, not layout or visual copy placement, changed here; evidence is CLI transcripts, protocol data, and live terminal captures rather than screenshots.

Publication, PR creation/body (including recording the deliberately omitted Forgejo/Gitea and Codex-only changes), and CI remain owned by the outer phases. No publication or pipeline control was performed by this Test phase.
