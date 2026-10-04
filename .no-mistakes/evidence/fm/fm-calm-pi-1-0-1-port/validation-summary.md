# Calm renderer compatibility validation

Target: `104b70f1309fed605e42120963503528bd9d70be`
Baseline: `93d82355e4c37dbe4b91aba8d4e16f2789e7938e`

## Targeted regression check

Executed only the existing `test_rendering_and_session_lifecycle` function from `tests/fm-calm-pi-extension.test.sh`, retaining its definitions and assertions unchanged. Temporary selector scripts were created in `tests/` so the existing relative helper paths remained correct, then removed after validation. `TMPDIR` and `HOME` pointed inside the disposable workspace.

| Fixture revision | Real npm Pi version | Result |
|---|---|---|
| Baseline | 1.0.1 | Expected regression reproduced: `grep disappeared from /export calm.html HTML while calm mode was on` |
| Target | 1.0.1 | Passed |
| Baseline | 1.0.0 | Passed |
| Target | 1.0.0 | Passed |

The focused check includes the existing `/export`, remapped non-submit, `/share` renderer-trigger, session-choice persistence, stock-renderer restoration, and execution-data preservation assertions. This is a fixture-driven contract check, **not** evidence of a live hosted `/share` upload.

Initial use of the machine's managed Pi 1.0.0 package failed because its flattened dependency layout does not contain the nested `pi-tui` path required by this existing test. Retried successfully using disposable npm global-prefix installations entirely under the worktree for both versions; the machine installation was unchanged.

## Live CLI and browser evidence

Executed the real Pi 1.0.1 and 1.0.0 CLIs against separate disposable saved-session data, with the production Calm and watcher extensions copied unchanged. No provider request, watcher lifecycle operation, real account, shared fleet state, or hosted upload was used. The fixture data includes saved grep, find and watcher results; the product, extension loader, terminal handler, export pipeline, HTML renderer, and HTML viewer are real.

For each version:

1. Started a 160-column / 44-row pseudo-terminal, sizing the slave before the CLI launched and continuously draining the master.
2. Loaded a Calm-on session, toggled `/calm` off and back on with Alt+s, and verified persisted choices.
3. Typed `/export <path>` and pressed Enter while submit was remapped to Alt+s. No export file appeared.
4. Pressed Alt+s. Pi wrote the HTML and displayed `Session exported to:`.
5. Verified session bytes were identical before these actions and after quitting. The baseline was taken after startup because Pi normally appends a `thinking_level_change` entry while opening the session.
6. Opened each generated HTML in real Chromium 153.0.8010.12 using Playwright, decoded the generated `session-data` contract, verified nonempty custom call and expanded result HTML for grep, find and `fm_watch_arm_pi`, expanded tool outputs, and verified their result text was visible. No viewer JavaScript errors occurred.
7. Captured screenshots of the real rendered exports.

The first browser launch lacked `libnspr4`, `libnss3`, `libgbm`, `libasound`, and `libdrm`. Resolved this by downloading Debian library archives and extracting them under the disposable worktree, using a process-local `LD_LIBRARY_PATH`. No system packages or global settings were changed. The optional Playwright MCP browser route also lacked Chrome; the final browser evidence uses the workspace-local browser instead.

Live driver commands:

```sh
python3 .test-calm-validation/live.py 101
python3 .test-calm-validation/live.py 100
LD_LIBRARY_PATH="$PWD/.test-calm-validation/browser-libs/root/usr/lib/x86_64-linux-gnu" \
  PLAYWRIGHT_BROWSERS_PATH="$PWD/.test-calm-validation/browser-binaries" \
  TMPDIR="$PWD/.test-calm-validation/tmp" \
  node .test-calm-validation/render.mjs
```

The live driver and browser check are preserved alongside this report as `live-driver.py` and `render-check.mjs`. Their disposable relative dependency paths existed only during this validation. CLI arguments, pty size, session hashes, and individual steps are recorded in `pi-101-live-result.json` and `pi-100-live-result.json`; custom rendered call/result text is recorded in `pi-101-rendered-output.json` and `pi-100-rendered-output.json`.

No full repository suite, linter, formatter, static analysis, pipeline-control, push, PR, or CI phase was run. All disposable installations, fixture homes, copied extensions, and temporary selector scripts were removed. No source changes were required.
