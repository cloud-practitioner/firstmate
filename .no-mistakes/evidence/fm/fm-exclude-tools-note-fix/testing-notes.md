# Targeted worker-exclusion validation

## Result

All six intent-derived runtime scenarios passed. No tracked files were changed. No full repository suite, lint, formatting, push, PR, or CI phase was run.

## What ran live

- Built tmux 3.5a and extracted its missing bison build dependency inside the worktree; no system packages or global settings were changed.
- Minted `.l` with `bin/fm-lab-home.sh create "$PWD/.l"`. Created an isolated Git project, local bare origin, Treehouse pool, Pi agent directory, and private `fm-lab` tmux socket inside that marked home. The terminal grid was 120 columns by 40 rows.
- Ran the real `bin/fm-spawn.sh exclusion-scout "$PWD/.l/project" --scout --harness pi --model gate/fixture --backend tmux` and the real Pi CLI. After trusting only the disposable project, a local stdio MCP server connected during the turn. Native exclusions removed the listed tools; registry observations showed the unlisted read tool appearing and the status file stayed quiet.
- Loaded that real spawn's generated extension into the real `pi --mode rpc` CLI. A deliberately omitted native denylist injected an actual registry-presence fault, rather than replacing Pi's registry or lifecycle handlers with mocks. The extension emitted one warning naming the two actually registered exclusions, never the absent typo entry. A later agent start did not duplicate it.
- A completed scout's `done:` declaration remained current after a late warning, and the warning remained visible through `scan_unread_surface_lines`. With the private endpoint live and the owning socket inherited, `bin/fm-crew-state.sh exclusion-scout` returned `state: done · source: status-log · completed disposable scout`.
- A resolution was appended while an agent turn was active, followed by an actual MCP registration and turn-end warning. A separate run connected between agent runs, exercising the next agent-start check. Neither warning replayed the blocked opener; open-decision queries stayed empty. The targeted regression additionally interleaved resolution immediately at the warning-append boundary, in both ordering directions.
- Direct MCP calls and calls nested in real codemode scripts were blocked with the configured exclusion reason. The fixture server's side-effect record contained only the unlisted `readIssue` call.
- Kept a real worker disconnected for 105 prompts / at least 210 lifecycle scans, then connected its MCP server. The late warning still appeared.
- Exercised public declaration readers on persisted status protocol data containing a genuinely emitted non-state warning: failed, working, paused, needs-decision, captain-held, ordinary note, warning-only fallback, and a pause outside a 210-warning tail remained correct.
- Real spawn attempts with `mcp__lab-server__editIssue` and `mcp__lab.server__editIssue` refused with the sanitized spelling and published no task metadata or status.

The external model endpoint was a loopback deterministic OpenAI-compatible fixture serving prescribed tool calls. This drove the real Pi tool pipeline without using production credentials or pretending to authenticate a real model. The MCP service was disposable test data; Pi, its built-in MCP/codemode extensions, the generated Firstmate extension, and Firstmate's public commands were real.

## Targeted regressions and baseline

Executed only these existing functions from `tests/fm-spawn-dispatch-profile.test.sh`, using a temporary selector runner:

- `test_pi_exclude_tools_reach_ship_and_scout_launches`
- `test_pi_exclude_tools_worker_registry_reports`
- `test_pi_exclude_tools_absent_and_empty_lists`
- `test_exclude_tools_non_pi_runtime_refuses_non_empty_list`
- `test_pi_exclude_tools_malformed_entry_refuses_before_endpoint`
- `test_pi_exclude_tools_server_shape_refuses_before_endpoint`
- `test_pi_exclude_tools_read_failure_refuses_before_launch`
- `test_pi_exclude_tools_do_not_leak_across_homes_or_to_secondmates`

An initial short command timeout interrupted the long registry matrix; the completed rerun passed its registry and declaration assertions. The final secondmate-scope fixture was initially refused because the required workspace boundary put its home inside the product source root. Re-ran only that function against an identical workspace-local copy of `bin/`, with fixture homes outside that copied root; it passed. This was a test-layout issue, not a change failure.

For base commit `afd6bd5f02aa43fb98fe465281ed9d731e1e258b`, copied the three relevant executable libraries into a disposable product root and executed the same registry behavior check. Since the base has no optional `tool_call` backstop, skipped only that check to isolate the original regression. The base failed the absence assertion with the old `unmatched exclusion entries (unverified ...)` warning. The target passed that assertion. These regression drivers used mocked Pi handlers and are supplemental, not the live evidence.

## Evidence and cleanup

`live-exclusions.log` contains product registry observations, actual status lines, supervisor unread output, real direct and nested tool results, resolution folds, and launch-refusal output. RPC transcripts are saved separately. `backstop-session.html` was produced by the real `pi --export` command from the recorded backstop session, not a hand-built HTML rendering. A browser screenshot was attempted, but the Playwright server lacks Chromium at `/opt/google/chrome/chrome`; no system browser was installed. The product-generated HTML remains available for visual review.

Herdr's guarded `prepare`/`teardown` preflight succeeded without provisioning or touching fleet panes; runtime tests used the private tmux route instead. The disposable scout was retired with the real lab-scoped teardown, including its launch staging. The private server was stopped, and all workspace-local labs, copied product roots, build dependencies, and temporary test runners were removed.
