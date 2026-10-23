# PR evidence gate: local Test-phase evidence

Validated target: `9512699506a2e867f9fd2bf9633ea138c3f25320`.
Base inspected: `5958dc34f9507bdd6c3df70a62e6b68df22dfda7`.

## What the visual artifacts prove

`live-gallery.png` presents PNGs produced by the real `bin/fm-pr-evidence.sh` executable, not by the forge stub. Each original PNG is also retained separately.

- `before-terminal.png` and `after-terminal.png`: real CLI captures of a refused semicolon purpose and an accepted corrected purpose, with purpose banners and drawn difference marks.
- `before-http.png` and `after-http.png`: real POST requests to a disposable localhost service, with 422 and 201 responses. The images show request headers/body, response headers/body, status code/message, masking of conventional authorization/password/cookie values, purpose banners, and drawn difference marks.
- `image-annotation.png`: the explicit screenshot rectangle-and-label annotation path, using a generated terminal capture as its input.
- `composed/comment.md`: the real composer's output, including the ui+api declaration, target head, four image hashes, annotations, and complete masked HTTP text.

These are scenario captures of the target tooling, not recordings of the historical base and target builds. The HTML gallery is a local reviewer presentation, not a GitHub-rendered PR comment. No actual upload, hosted display, PR merge, or this PR's self-gate is claimed.

## Other live observations

`live-cli-transcript.log` records exact CLI invocations, refusals, FIX messages, and exit statuses. It covers intake declarations, malformed configuration, Firstmate's refusal of none, strict English rules and warning-only passive voice, both annotation paths, insertion context marks, identical/missing evidence refusals, incomplete HTTP data, away-mode waiver refusal, legacy task notice, default-off Bitbucket, and old-CLI refusal.

`inherited-policy.log` records real propagation to an isolated child home's gitignored config. A new CLI process enforces the copied policy after runtime state is removed. This is a local persistence/inheritance check; no real secondmate, fleet, devcontainer rebuild, or primary was launched.

## Targeted tests and the test-only correction

- The first bounded invocation of `tests/fm-pr-evidence.test.sh` timed out after 240 seconds. Its partial transcript is retained in `targeted-evidence-tests.log`.
- The unbounded retry reached the annotation test after the preceding forge-fixture checks passed. It then failed on a stale literal command assertion: it expected `$ echo hello world`, whereas capture now correctly preserves the argument boundary as `$ echo 'hello world'`. See `targeted-evidence-tests-retry.log`.
- Only this assertion in `tests/fm-pr-evidence.test.sh` was changed. It now parses the generated command with `shlex.split` and compares the argv list to `["echo", "hello world"]`.
- A transient focused runner reused that test file's setup and executed `test_annotation_tools_draw_marks`, `test_brief_block_and_list_commands_print`, and the opt-in live guard. The corrected annotation test and remaining local check passed; the live guard reported its missing sandbox URL. The Python regression tests also ran in this focused invocation. See `focused-annotation-retest.log`.
- `tests/fm-pr-evidence-retrofit.test.sh` completed successfully; see `targeted-retrofit-tests.log`.
- No full repository test suite, formatter, package installer, pipeline controller, push, PR, or CI phase was executed.

Forge-fixture tests are supplemental evidence, not live proof of GitHub or Bitbucket behavior.

## Hosted proof still required

The default `gh` is 2.96.0, but `/usr/bin/gh` (already on PATH) is 2.102.0 and supports attachments. The product successfully gets past capability selection on normal PATH. A restricted PATH containing the real old binary proves its actionable refusal without mocking gh.

No sandbox PR URL or isolated worker credential was supplied. With operator tokens removed and `GH_CONFIG_DIR` redirected into the lab, `publish` refuses the PR read. Operator credential stores were not intentionally inspected or changed. Local forge fixtures and the real localhost HTTP service cannot establish GitHub attachment rendering, author-owned comment replacement, merge-time head binding on a real PR, or this PR's self-gate.

To finish that proof, provide an authorized private cloud-practitioner sandbox PR (`FM_PR_EVIDENCE_LIVE_PR`), a scoped worker credential in an isolated environment, and explicit permission for sandbox service mutations outside the worktree-only boundary. The non-IQX Bitbucket proof additionally needs the captain-selected workspace; its production arm remains off.
