# Scoped test-step evidence

## Live product checks

`product-cli-transcript.log` records public Firstmate commands against a disposable marked FM_HOME, a real Git project, a real Treehouse pool, a private tmux server, a local rule-driven SystemOne HTTP service, and an actual refused SSH connection. The final driver completed successfully. It demonstrates:

- Registry `pr=manual` resolves without changing branch or delivery posture; the generated public brief retains the fork's evidence contract. Invalid manual/local-only and registry/manual combinations refuse.
- Git's ordinary status hides an untracked file, but teardown names it and refuses without changing its bytes, HEAD, or metadata. Removing only that disposable file lets the same task return through real Treehouse; the pool reports the slot available.
- The delta-reader emits the owned `fm-remote-delta.v1` protocol and leaves its source unchanged. Failed SSH source reads emit zero stdout bytes and create no cursor.
- A real local SystemOne provider receives the HTTP request and the CLI selects a concrete profile. The never-send list prevents a second request. The provider is a small rule-driven disposable service, not an external LLM evaluation; OpenAI was not contacted.

`claude-primary-launch.log` records a real authenticated Claude invocation through `bin/fm-live-claude.sh`, launched as the command on a private tmux session with a 120x40 grid. It returned `FM_MERGE15_LIVE_READY`, exited zero, and left the host launcher target unchanged. The accompanying HTML renders the captured terminal text and is not a screenshot. Lab servers, homes, sockets, and downloaded workspace-local tmux dependencies were removed.

`merge-topology.log` is structural Git evidence, not a live runtime test: the target has fork base 61b74893 and upstream b936f040 as its two parents, brings seven upstream commits, and leaves both contrib add-on trees unchanged. No forge publication, pipeline control, or merge was performed.

## Failures and live limits

`openai-valid-response-repro.log` is a narrowed behavioral regression using the existing fixture transport and real dispatch script. A valid Decisions response produces `status: error`. The validator's jq binding receives a boolean and errors with `boolean (true) has no length`. This is not a live OpenAI API call; no OpenAI credential was supplied.

The new Agy hook fixture suite failed its total-budget assertion in the initial run and two isolated reproductions. `agy-timing-diagnostic.log` records one-second and two-second settings, observed hook durations, and arm-start counts. Durations include hook setup; they are not precise measurements of the park interval. The remaining-cases attempt also failed its five-second park-readiness assertion. These are fixture-level timing failures, not demonstrated live Agy hook failures.

`agy-live-blocker.log` records the installed real Agy CLI requesting authentication in a disposable HOME. No authentication was completed and no operator credentials were read, copied, or changed. Full model-driven primary/secondmate hooks and their rendered UI therefore remain untested; there is no Agy screenshot.

Newest-run crew-state cases were exercised with the existing no-mistakes protocol fixtures, not a live gate daemon. Creating or controlling another pipeline is forbidden in this assigned phase, so a real competing-run experiment was not performed. The declined review concerns were not changed or re-raised.

## Targeted regression execution and setup corrections

- Initial targeted files: project-mode passed; manual-PR spawn initially inherited `FM_BACKEND=herdr`, then passed with that variable removed; dispatch stopped at the reproducible OpenAI failure; Agy stopped at the timeout assertion; the PR-evidence attempt hit its 240-second command bound after several fixtures passed.
- Selected existing functions: hidden-untracked teardown, ten newest-run crew-state cases, Pi MCP-off/override/support guards, steering-inbox busy grace, and secondmate stand-down preservation/refusal passed. The secondmate resume fixture was refused because the workspace boundary places its home inside the code root; this was a fixture-placement constraint, not a product regression.
- Initial selected crew-state and PR-evidence attempts also reached their bounds because additional top-level fixture loops still ran. A corrected crew-state selector subsequently completed all chosen attribution cases. The evidence-gate merge guard selected function passed; the broader gate/Bitbucket attempt did not finish and is not claimed complete.
- Live teardown setup was corrected from an empty endpoint to a real private tmux endpoint, and from a hand-created worktree to an actual leased Treehouse pool slot. These were setup failures, not findings.
- A fully isolated Herdr HOME could not satisfy the lab helper's mandatory running-default tripwire. The normal host's read-only prepare probe succeeded, but no host Herdr session was provisioned or mutated; the live checks instead used a workspace-local tmux binary and private lab sockets.

No complete repository suite, linter, formatter, static analyzer, push, PR, CI, or pipeline-control command was run. No source or test changes remain.
