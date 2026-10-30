#!/usr/bin/env bash
# Shared disposable lab setup for the focused live probes in this evidence turn.
set -eu
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M65NDEZRAT81MFEX2NMZGR4B
export ROOT E TMPDIR="$ROOT/.test-live/tmp" FM_HERDR_LAB_STATE_DIR="$ROOT/.test-live/lab-state" TREEHOUSE_ROOT="$ROOT/.test-live/treehouse"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
LAB=$(mktemp -d "$ROOT/.test-live/phase.XXXXXX")
export LAB REAL_PATH=$PATH REAL_HERDR=$(command -v herdr)
export LAB_HELPER="$ROOT/bin/fm-herdr-lab.sh"
export LAB_SESSION=$("$LAB_HELPER" name focused)
cleanup() {
  local status=$?
  if [ "$status" != 0 ]; then
    echo "PROBE EXIT=$status; retained command diagnostics follow before disposable cleanup"
    for log in "$LAB"/*.err "$LAB"/*.out "$LAB"/scaffold.log; do
      [ ! -f "$log" ] || tail -50 "$log"
    done
  fi
  env PATH="$REAL_PATH" "$LAB_HELPER" teardown "$LAB_SESSION" || return 1
  # Stop and retire only registrations created by this probe before deleting its home.
  for home in "$LAB/mate" "$LAB/parent"; do
    [ ! -d "$home/state/procevent" ] || env FM_HOME="$home" "$ROOT/bin/fm-procevent.sh" sweep-home >/dev/null
  done
  find "$LAB" -type d -exec chmod u+rwx {} +
  rm -rf "$LAB"
  echo 'TEARDOWN: named lab deleted; default-session tripwire unchanged; disposable homes removed'
}
trap cleanup EXIT
"$ROOT/bin/fm-lab-home.sh" create "$LAB"
export FM_HOME="$LAB" FM_PROCEVENT_CLAIM_ROOT="$LAB/claims"
mkdir -p "$LAB/wrappers" "$LAB/wt"
cat > "$LAB/wrappers/herdr" <<'SH'
#!/usr/bin/env bash
set -eu
printf '%q ' "$@" >> "$LAB/operations.log"; printf '\n' >> "$LAB/operations.log"
args=("$@")
n=${#args[@]}
if [ "$n" -ge 2 ] && [ "${args[n-2]}" = --session ] && [ "${args[n-1]}" = "$LAB_SESSION" ]; then
  unset 'args[n-1]' 'args[n-2]'
fi
if [ "${args[0]:-}" = --version ]; then
  exec env PATH="$REAL_PATH" "$REAL_HERDR" --version --session "$LAB_SESSION"
fi
out=$(env PATH="$REAL_PATH" "$LAB_HELPER" run "$LAB_SESSION" "${args[@]}") || { r=$?; printf '%s\n' "$out"; exit "$r"; }
if [ -f "$LAB/stop-after-read" ] && [ "${args[0]:-} ${args[1]:-}" = 'pane read' ]; then
  rm "$LAB/stop-after-read"
  env PATH="$REAL_PATH" "$LAB_HELPER" stop "$LAB_SESSION" >/dev/null
  echo 'FAULT: actual named server stopped after viewport read' >> "$LAB/fault.log"
fi
printf '%s\n' "$out"
SH
chmod +x "$LAB/wrappers/herdr"
export PATH="$LAB/wrappers:$REAL_PATH" HERDR_SESSION="$LAB_SESSION"
lab() { env PATH="$REAL_PATH" "$LAB_HELPER" run "$LAB_SESSION" "$@"; }
provision() { env PATH="$REAL_PATH" "$LAB_HELPER" provision "$LAB_SESSION"; }
provision
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
