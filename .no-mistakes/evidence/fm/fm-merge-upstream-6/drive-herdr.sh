#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M4H5KP1VG2X9YFP5CNNAPNGA
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_BACKEND FM_GATE_REFUSE_BYPASS
# Only discover the real default socket for the helper's read-only tripwire;
# never issue default pane or lifecycle commands.
default_socket=$(env -u XDG_CONFIG_HOME bin/fm-herdr-lab.sh run fm-lab-preflight session list --json | jq -er '.sessions[] | select(.default == true and .running == true) | .socket_path')
mkdir -p "$ROOT/.test-phase/x/herdr" "$ROOT/.test-phase/lab-state" "$ROOT/.test-phase/tmp"
if [ ! -L "$ROOT/.test-phase/x/herdr/herdr.sock" ]; then
  ln -s "$default_socket" "$ROOT/.test-phase/x/herdr/herdr.sock"
fi
export XDG_CONFIG_HOME=.test-phase/x
export FM_HERDR_LAB_STATE_DIR="$ROOT/.test-phase/lab-state"
export HOME="$ROOT/.test-phase/user-home"
export TMPDIR="$ROOT/.test-phase/tmp"
export FM_HOME="$ROOT/.test-phase/probe-home"
export LAB_SESSION=fm-lab-p
export LAB_ROOT="$ROOT" LAB_REAL_PATH="$PATH"
export LAB_TRACE="$EVIDENCE/herdr-probe-commands.log"
mkdir -p "$HOME" "$ROOT/.test-phase/route-bin" "$ROOT/.test-phase/owned" "$ROOT/.test-phase/foreign"
rm -rf "$FM_HOME"
bin/fm-lab-home.sh create "$FM_HOME"
: > "$LAB_TRACE"
: > "$HOME/.zshrc"
# All state for new named sessions is local. The sole external reference is
# the default socket alias created above for READ-ONLY fleet tripwire checks.
# Clear the preflight's prepared-but-absent ownership record, then provision:
# provision owns prepare automatically for an absent session.
if [ -f "$FM_HERDR_LAB_STATE_DIR/$LAB_SESSION.fleet-state.json" ]; then
  bin/fm-herdr-lab.sh teardown "$LAB_SESSION"
fi
cleanup() {
  rc=$?
  PATH="$LAB_REAL_PATH" bin/fm-herdr-lab.sh teardown "$LAB_SESSION" || rc=1
  printf 'guarded teardown exit=%s (default fleet tripwire checked)\n' "$rc"
  rm -rf "$FM_HOME"
  exit "$rc"
}
trap cleanup EXIT
bin/fm-herdr-lab.sh provision "$LAB_SESSION"
printf '\n=== Installed real Herdr in local named lab ===\n'
bin/fm-herdr-lab.sh run "$LAB_SESSION" status --json
# This is a transport guard, not a fake CLI: every request is forwarded intact
# to the installed Herdr through the mandated lab helper. Log refused mutations
# too, so an unexpected server-start attempt fails the scenario rather than
# disappearing behind the guard.
cat > "$ROOT/.test-phase/route-bin/herdr" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
session=
args=()
while [ "$#" -gt 0 ]; do
  if [ "$1" = --session ]; then session=$2; shift 2; else args+=("$1"); shift; fi
done
[ "$session" = "$LAB_SESSION" ] || { echo "unexpected session: $session" >&2; exit 90; }
{ printf 'session=%q ' "$session"; printf '%q ' "${args[@]}"; printf '\n'; } >> "$LAB_TRACE"
if [ "${args[0]}" = server ] && [ "${#args[@]}" -eq 1 ]; then
  # The product requests actual startup. Use the helper's guarded provision
  # path, not run (which correctly refuses server commands).
  PATH="$LAB_REAL_PATH" exec "$LAB_ROOT/bin/fm-herdr-lab.sh" provision "$session"
fi
PATH="$LAB_REAL_PATH" exec "$LAB_ROOT/bin/fm-herdr-lab.sh" run "$session" "${args[@]}"
SH
chmod +x "$ROOT/.test-phase/route-bin/herdr"
created=$(bin/fm-herdr-lab.sh run "$LAB_SESSION" workspace create --cwd "$ROOT/.test-phase/owned" --label lab-owned --env "HOME=$HOME" --no-focus)
printf '%s\n' "$created"
pane=$(printf '%s' "$created" | jq -er '.result.root_pane.pane_id')
target="$LAB_SESSION:$pane"
bin/fm-herdr-lab.sh run "$LAB_SESSION" pane run "$pane" "printf '%s_%s\\n' LIVE PROBE_SENTINEL"
bin/fm-herdr-lab.sh run "$LAB_SESSION" pane wait-output "$pane" --match LIVE_PROBE_SENTINEL --timeout 10000
export PATH="$ROOT/.test-phase/route-bin:$PATH"
. "$ROOT/bin/fm-backend.sh"
printf '\n=== Running owned endpoint: real visible capture and real input ===\n'
printf 'backend=herdr\nwindow=%s\nworktree=%s\n' "$target" "$ROOT/.test-phase/owned" > "$FM_HOME/state/mine.meta"
screen=$(fm_backend_visible_capture herdr "$target" fm-mine)
printf '%s\n' "$screen"
[[ "$screen" = *LIVE_PROBE_SENTINEL* ]]
PATH="$LAB_REAL_PATH" bin/fm-herdr-lab.sh run "$LAB_SESSION" pane send-text "$pane" "printf '%s_%s\\n' OWNED INPUT_RECEIVED"
fm_backend_send_key herdr "$target" Enter fm-mine
PATH="$LAB_REAL_PATH" bin/fm-herdr-lab.sh run "$LAB_SESSION" pane wait-output "$pane" --match OWNED_INPUT_RECEIVED --timeout 10000
printf '%s\n' "$(fm_backend_visible_capture herdr "$target" fm-mine)"
printf 'owned Enter delivered and executed printf, visible capture succeeded\n'
printf 'shell composer state=%s\n' "$(fm_backend_composer_state herdr "$target" fm-mine)"
identity=$(fm_backend_herdr_pane_process_identity "$LAB_SESSION" "$pane")
[ -n "$identity" ]
printf 'herdr_process_identity=%s\n' "$identity" >> "$FM_HOME/state/mine.meta"
[ -n "$(fm_backend_visible_capture herdr "$target" fm-mine)" ]
printf 'real process-bound owned capture succeeded: %s\n' "$identity"
cp "$LAB_TRACE" "$EVIDENCE/herdr-owned-commands.log"
printf '\n=== Adversarial identity mismatch despite a matching live cwd ===\n'
printf 'backend=herdr\nwindow=%s\nworktree=%s\nherdr_process_identity=%s-stale\n' "$target" "$ROOT/.test-phase/owned" "$identity" > "$FM_HOME/state/mine.meta"
: > "$LAB_TRACE"
composer=$(fm_backend_composer_state herdr "$target" fm-mine)
rc=0
screen=$(fm_backend_visible_capture herdr "$target" fm-mine) || rc=$?
printf 'same-cwd foreign identity composer=%s visible_capture_exit=%s bytes=%s\n' "$composer" "$rc" "${#screen}"
[ "$composer" = unknown ] && [ "$rc" -ne 0 ] && [ -z "$screen" ]
if grep -E 'pane (read|send)| server ' "$LAB_TRACE"; then exit 1; fi
cp "$LAB_TRACE" "$EVIDENCE/herdr-foreign-identity-commands.log"
printf '\n=== Adversarial reused address: recorded worktree does not own this pane ===\n'
printf 'backend=herdr\nwindow=%s\nworktree=%s\n' "$target" "$ROOT/.test-phase/foreign" > "$FM_HOME/state/mine.meta"
: > "$LAB_TRACE"
composer=$(fm_backend_composer_state herdr "$target" fm-mine)
rc=0
screen=$(fm_backend_visible_capture herdr "$target" fm-mine) || rc=$?
printf 'foreign composer=%s visible_capture_exit=%s bytes=%s\n' "$composer" "$rc" "${#screen}"
[ "$composer" = unknown ] && [ "$rc" -ne 0 ] && [ -z "$screen" ]
if grep -E 'pane (read|send)| server ' "$LAB_TRACE"; then exit 1; fi
cp "$LAB_TRACE" "$EVIDENCE/herdr-foreign-commands.log"
printf '\n=== Stopped real session: passive piped probes reach EOF without startup ===\n'
PATH="$LAB_REAL_PATH" bin/fm-herdr-lab.sh stop "$LAB_SESSION"
PATH="$LAB_REAL_PATH" bin/fm-herdr-lab.sh run "$LAB_SESSION" status --json
: > "$LAB_TRACE"
start=$SECONDS
composer=$(timeout 5s bash -c '. "$LAB_ROOT/bin/fm-backend.sh"; (fm_backend_composer_state herdr "$1" fm-mine) 2>&1 | head -20' _ "$target")
rc=0
screen=$(fm_backend_visible_capture herdr "$target" fm-mine) || rc=$?
printf 'stopped composer=%s piped_elapsed_seconds=%s visible_capture_exit=%s bytes=%s\n' "$composer" "$((SECONDS-start))" "$rc" "${#screen}"
[ "$composer" = unknown ] && [ "$rc" -ne 0 ] && [ -z "$screen" ]
if grep -E 'pane (read|send)| server ' "$LAB_TRACE"; then exit 1; fi
PATH="$LAB_REAL_PATH" bin/fm-herdr-lab.sh run "$LAB_SESSION" status --json
cp "$LAB_TRACE" "$EVIDENCE/herdr-stopped-commands.log"
printf '\n=== Invalid endpoint: no Herdr command is needed ===\n'
: > "$LAB_TRACE"
[ "$(fm_backend_composer_state herdr invalid-target)" = unknown ]
if fm_backend_visible_capture herdr invalid-target; then exit 1; fi
[ ! -s "$LAB_TRACE" ]
printf 'malformed composer=unknown visible_capture_exit=1 CLI_requests=0\n'
printf '\n=== Active input still starts the owned stopped session ===\n'
printf 'backend=herdr\nwindow=%s\nworktree=%s\n' "$target" "$ROOT/.test-phase/owned" > "$FM_HOME/state/mine.meta"
: > "$LAB_TRACE"
fm_backend_send_key herdr "$target" Enter fm-mine
PATH="$LAB_REAL_PATH" bin/fm-herdr-lab.sh run "$LAB_SESSION" status --json
PATH="$LAB_REAL_PATH" bin/fm-herdr-lab.sh run "$LAB_SESSION" pane send-text "$pane" "printf '%s_%s\\n' RESTARTED INPUT_RECEIVED"
fm_backend_send_key herdr "$target" Enter fm-mine
PATH="$LAB_REAL_PATH" bin/fm-herdr-lab.sh run "$LAB_SESSION" pane wait-output "$pane" --match RESTARTED_INPUT_RECEIVED --timeout 10000
printf '%s\n' "$(fm_backend_visible_capture herdr "$target" fm-mine)"
printf 'public active send started the real stopped lab server through guarded provision and restored owned input\n'
cp "$LAB_TRACE" "$EVIDENCE/herdr-active-restart-commands.log"
