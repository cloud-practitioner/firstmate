# Targeted validation

Target: `791c507bc21d52563f59e2e410087668d6ac8783`

## Result

Local CLI and HTTP scenarios passed. No source or test files were changed.
Hosted acceptance remains unverified under the workspace-only authority of this turn.
The final verdict is inconclusive, not a hosted-gate pass.

## Product-level evidence

- [Terminal before](ui-before.png) and [terminal after](ui-after.png): the real plain-English checker rejects banned wording, then accepts short wording. Both images contain the purpose and drawn difference marks.
- [HTTP before](api-before.png) and [HTTP after](api-after.png): the real capture CLI calls a disposable HTTPS endpoint through a real CONNECT tunnel. The final status, message, folded header, optional whitespace, empty field, request body, response body and folded trailer survive. Proxy and interim-response headers do not appear. Synthetic authorization, password and cookie values are masked.
- [HEAD exchange](head.json): status 200, Content-Length 23, and an empty response body. Capture completes without waiting for a nonexistent body. GET and POST body retention were also exercised.
- [Generated comment](composed/comment.md): the real composer produces a UI+API review comment bound to the target head, with hash-bound annotation records and complete HTTP text. This is pre-upload output; its local image paths are not hosted image URLs.
- [Generated brief](generated-brief.md), [filled brief](filled-brief.md), and [brief/intake transcript](brief-intake-transcript.txt): the real scaffold reaches the unfilled-declaration refusal; filling it produces `evidence=ui+api`. Local-only intake emits no evidence requirement.
- [CLI transcript](live-cli-transcript.txt) and [local scenario results](live-scenario-results.json): intake refusals, Firstmate's none restriction, excluded lanes, invalid configuration, persisted policy inheritance, strict/warning English rules, legacy notice, away-mode waiver refusal, terminal capture, HTTP capture, annotation and composition.
- Composition actively refused absent annotation records and stale image hashes for both phases of both kinds. It also refused a real annotated image whose only box was drawn outside its bounds.

These before/after images illustrate the evidence workflow against deliberately changed text and a disposable endpoint. They are **not historical before/after evidence for this branch**, and no hosted upload or display is claimed.

All four images were opened and visually inspected. The visible purpose, pink rectangles, masked fields, HTTP sections and status changes match the captured output.

## Focused automated checks

Commands used a worktree-local TMPDIR and ran no real agent or Herdr lifecycle:

```sh
TMPDIR="$PWD/.test-evidence-tmp" PYTHONDONTWRITEBYTECODE=1 bash tests/fm-pr-evidence.test.sh
TMPDIR="$PWD/.test-evidence-tmp" PYTHONDONTWRITEBYTECODE=1 bash tests/fm-pr-evidence-retrofit.test.sh
python3 /home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH/live-validation.py
python3 /home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH/brief-intake-validation.py
python3 /home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH/reproduce-regressions.py
```

The evidence suite also runs its Python regression suite. Its forge fixture covers publication, republishing, metadata ordering, worker-added kinds, file mismatches, image display refusals, changed heads, foreign authors, immediate merges, waivers and Bitbucket Downloads behavior. Those simulated forge results are **not live hosted proof**.

[Historical regression transcript](historical-regression-transcript.txt) reproduces the trailer boundary failure at `163827e5`, and HEAD and folded-header failures at `38d81698`. The same selectors pass at the target commit. Historical snapshots were created only inside disposable worktree-local directories.

No complete repository suite, lint, formatting, static-analysis, push, PR or CI phase was run.

## Hosted checks that remain untested

The installed GitHub CLI is 2.102.0 and advertises `pr comment --attach`. A missing CLI is not the blocker. `FM_PR_EVIDENCE_LIVE_PR` is unset; this turn has no authorized sandbox PR, isolated publishing identity or remote-write authority. The opt-in hosted guard therefore did not run. No production credential store was inspected or changed.

A disposable local endpoint solves HTTP capture and rendering, but a simulated forge cannot establish GitHub's actual image rendering, worker identity, merge semantics, fresh PR state, or posted waiver text. Completing those checks requires an authorized sandbox PR and explicit authority for the intended remote actions. A read-only sandbox identity and PR records would suffice for the retrofit-list check.

Bitbucket remains off by default. No captain-named non-IQX sandbox was supplied, and ambient production credentials were not used. Its real upload/display proof requires that sandbox and scoped credentials with explicit sandbox-write authority.

This turn did not attach historical evidence to this change's own PR or run another pipeline/publication phase. The outer executor owns publication and subsequent gate phases.

## Cleanup

Disposable operational homes, Git repositories, historical snapshots, TLS certificate/key, HTTP server, TLS server and CONNECT proxy were removed or stopped in their evidence turns. The empty worktree-local scratch directory was removed. Reviewer evidence remains in this directory.
