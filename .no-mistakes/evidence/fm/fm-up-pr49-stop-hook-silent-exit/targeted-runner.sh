#!/usr/bin/env bash
set -u
ROOT_PHASE=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M65FDJ7V1ZRZQYN2CFPEWZJF
mkdir -p "$ROOT_PHASE/.test-phase/tmp"
export TMPDIR="$ROOT_PHASE/.test-phase/tmp"
. tests/supervision-host-helpers.sh
[ -z "${PHASE_CONTROL_HOST:-}" ] || HOST=$PHASE_CONTROL_HOST
capture_homes() {
  local home f
  while IFS= read -r home; do
    [ -d "$home" ] || continue
    printf '\n=== fixture %s (fake harness; real host/hook/watcher) ===\n' "${home##*/}"
    for f in host.out host.err host.rc hook.out hook.err hook.rc state/.supervision-host.log state/.watcher-down state/.claude-autoarm-epoch state/.wake-queue; do
      [ ! -f "$home/$f" ] || { printf '\n--- %s ---\n' "$f"; /bin/cat "$home/$f"; }
    done
  done < "$HOMES_FILE"
}
fm_test_run() {
  local name
  for name in $PHASE_SELECT; do
    printf '\n=== executing %s ===\n' "$name"
    "$name"
  done
}
trap 'capture_homes > "$EVIDENCE/targeted-${PHASE_GROUP}-product-outputs.log"; suite_cleanup' EXIT
. "$PHASE_SUITE"
