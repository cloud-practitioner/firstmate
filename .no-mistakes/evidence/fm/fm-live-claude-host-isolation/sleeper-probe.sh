#!/usr/bin/env bash
# NON-LIVE launch interception probe; both possible engines are inert fixtures.
set -eu
. "$PWD/tests/fixtures.sh"
EVIDENCE=/home/node/.no-mistakes/evidence/01M5GVXJC6CT9JTBDTZCKVK98P
CASE=$(fm_test_tmproot fm-sleeper-probe)
HOME_DIR="$CASE/home"
PROJ="$CASE/project"
WT="$CASE/wt"
SLEEPER="$CASE/sleeper"
GUARD="$CASE/guarded-engine"
mkdir -p "$SLEEPER" "$GUARD"
cat > "$GUARD/claude" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in --help|--version|-v|-V) exit 0 ;; esac
printf 'ENGINE WOULD RECEIVE: %s\n' "$*" >> "$FM_INTERCEPTION_ENGINE_LOG"
exit 0
SH
cat > "$SLEEPER/claude" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in --help|--version|-v|-V) exec "$FM_INTERCEPTION_GUARD/claude" "$@" ;; esac
printf 'SLEEPER INTERCEPTED: %s\n' "$*" >> "$FM_INTERCEPTION_SLEEPER_LOG"
exit 0
SH
chmod +x "$SLEEPER/claude" "$GUARD/claude"
FAKEBIN=$(make_spawn_fakebin "$CASE/tools" gh gh-axi)
fm_test_spawn_home "$HOME_DIR" claude
fm_git_worktree "$PROJ" "$WT" wt-sleeper-probe
fm_test_spawn_brief "$HOME_DIR" SLEEPER-PROBE
export FM_INTERCEPTION_GUARD="$GUARD"
export FM_INTERCEPTION_ENGINE_LOG="$EVIDENCE/sleeper-engine.log"
export FM_INTERCEPTION_SLEEPER_LOG="$EVIDENCE/sleeper-intercept.log"
: > "$FM_INTERCEPTION_ENGINE_LOG"
: > "$FM_INTERCEPTION_SLEEPER_LOG"
FM_LIVE_CLAUDE_SHIM="$SLEEPER" FM_FAKE_LAUNCH_LOG="$EVIDENCE/sleeper-launch.txt" \
  PATH="$SLEEPER:$GUARD:$PATH" \
  fm_test_run_spawn "$HOME_DIR" "$WT" "$FAKEBIN" SLEEPER-PROBE "$PROJ" --mode no-mistakes --yolo off
# Simulate a daemon-created pane where the guarded engine is initially first.
# Only the real spawn's emitted command may restore the sleeper's precedence.
env -i HOME="$CASE/pane-home" PATH="$GUARD:$FAKEBIN:/usr/bin:/bin" \
  FM_INTERCEPTION_GUARD="$GUARD" FM_INTERCEPTION_ENGINE_LOG="$FM_INTERCEPTION_ENGINE_LOG" \
  FM_INTERCEPTION_SLEEPER_LOG="$FM_INTERCEPTION_SLEEPER_LOG" \
  bash -c "$(< "$EVIDENCE/sleeper-launch.txt")"
[ -s "$FM_INTERCEPTION_SLEEPER_LOG" ] || fail 'the spawn brief bypassed the sleeper'
[ ! -s "$FM_INTERCEPTION_ENGINE_LOG" ] || fail 'the guarded engine received the launch brief'
printf 'initial pane PATH leader: %s\nselected marker: %s\n' "$GUARD" "$SLEEPER"
while IFS= read -r line; do printf '%s\n' "$line"; done < "$FM_INTERCEPTION_SLEEPER_LOG"
printf 'guarded engine launch events: 0\n'
