#!/usr/bin/env bash
# fm-secondmate-dormant.sh - stand a persistent LOCAL secondmate down on purpose,
# keep everything it holds, and bring it back later.
#
# Usage: fm-secondmate-dormant.sh stand-down <exact-secondmate-id> [--reason <text>]
#        fm-secondmate-dormant.sh resume <exact-secondmate-id>
#        fm-secondmate-dormant.sh list
#        fm-secondmate-dormant.sh --help
#
# Why this exists. `bin/fm-control.sh <id> exit` stops a secondmate's agent and
# keeps its home, but the liveness sweep (bin/fm-secondmate-liveness-lib.sh,
# driven by session start and the supervision poll) reads a stopped mate as dead
# and relaunches it within about a minute. A mate with no work for now still
# costs memory while its agent runs, so "spin it down but keep its information"
# needs a durable stood-down state the relaunch machinery respects. That state is
# the dormant record, state/<id>.dormant in the PARENT home
# (bin/fm-secondmate-dormant-lib.sh owns its storage).
#
# stand-down stops the agent through bin/fm-control.sh <id> exit and then records
# dormancy. The mate's home, lease, registry route (data/secondmates.md), backlog,
# held decisions and reports are not touched, and neither are its state/<id>.meta
# and state/<id>.status. It refuses, changing nothing and naming every blocker,
# when the mate:
#   - is remote (a remote mate's agent is stopped on another host; out of scope),
#   - is already dormant, unregistered, or has no durable record here,
#   - has in-flight work in its own home: any task record under its state/, or
#     an item under `## In flight` in its own backlog,
#   - has an unresolved parent pending-reply expectation
#     (bin/fm-pending-reply-lib.sh), an unacknowledged steer in its inbox, or an
#     undelivered backlog-handoff wake.
# The stop is verified by fm-control; if it fails, no record is written.
#
# resume brings the mate back through the ordinary guarded launch,
# `bin/fm-spawn.sh <id> --secondmate`, run by the shared liveness relaunch path
# so the stopped endpoint is replaced exactly as a recovery would replace it.
# The new agent reconciles from the mate's own records. Dormancy is cleared only
# after that launch succeeds; a failed launch leaves the mate dormant. A mate
# whose agent is already running is just cleared. Only resume may launch a
# dormant mate: it names the id in FM_SECONDMATE_RESUMING, which is the single
# exception to the refusal in bin/fm-spawn.sh.
#
# While dormant the mate is never relaunched, never reported as dead, and never
# woken for. The session-start liveness sweep and the supervision poll skip it,
# bin/fm-send.sh and bin/fm-backlog-handoff.sh refuse it by name, fleet sync,
# config push and update leave it alone, and the session-start digest and fleet
# views list it as dormant. Retirement (bin/fm-teardown.sh) is unchanged.
#
# list prints each dormant mate in this home with its since-time and reason.
#
# Exit status: 0 success; 1 refused or failed (nothing recorded unless stated);
# 2 invalid use.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

usage() {
  sed -n '2,/^set -u/p' "$0" | sed '$d; s/^# \{0,1\}//'
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  '') usage >&2; exit 2 ;;
esac

if [ -z "${FM_HOME:-}" ]; then
  echo "error: FM_HOME is not set; fm-secondmate-dormant refuses to resolve second mates without an explicit firstmate home" >&2
  exit 1
fi
[ -d "$FM_HOME" ] || { echo "error: FM_HOME '$FM_HOME' is not a directory" >&2; exit 1; }
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
[ -d "$STATE" ] || { echo "error: state dir '$STATE' is missing; fm-secondmate-dormant cannot resolve second mates for FM_HOME '$FM_HOME'" >&2; exit 1; }
REG="$DATA/secondmates.md"

# shellcheck source=bin/fm-backend.sh
. "$SCRIPT_DIR/fm-backend.sh"
# shellcheck source=bin/fm-secondmate-registry-lib.sh
. "$SCRIPT_DIR/fm-secondmate-registry-lib.sh"
# shellcheck source=bin/fm-pending-reply-lib.sh
. "$SCRIPT_DIR/fm-pending-reply-lib.sh"
# shellcheck source=bin/fm-secondmate-liveness-lib.sh
. "$SCRIPT_DIR/fm-secondmate-liveness-lib.sh"

VERB=$1
shift

die() { echo "error: $*" >&2; exit 1; }

# Resolve <id> to a local registered secondmate with a durable record here.
# Sets ID, META, HOME_DIR. Refuses anything else with the concrete reason.
resolve_mate() {  # <raw-id>
  local raw=$1
  ID=$raw
  case "$ID" in ''|*[!A-Za-z0-9._-]*) die "invalid second mate id: $raw" ;; esac
  META="$STATE/$ID.meta"
  [ -f "$META" ] && [ ! -L "$META" ] || die "no durable record for second mate $ID in this home ($META)"
  [ "$(fm_meta_get "$META" kind)" = secondmate ] || die "$ID is not a second mate"
  if [ -n "$(fm_meta_get "$META" remote_host)" ]; then
    die "second mate $ID is remote (host $(fm_meta_get "$META" remote_host)); stand-down is for local second mates only, because a remote agent is stopped on another host"
  fi
  secondmate_registry_line_for_id "$REG" "$ID" || die "second mate $ID has no single valid route in $REG"
  [ "$SECONDMATE_REGISTRY_REMOTE" -eq 0 ] || die "second mate $ID is registered as a remote route; stand-down is for local second mates only"
  HOME_DIR=$SECONDMATE_REGISTRY_HOME
  [ -d "$HOME_DIR" ] || die "second mate $ID's home $HOME_DIR is not a directory, so its work cannot be inspected"
  [ "$(cat "$HOME_DIR/.fm-secondmate-home" 2>/dev/null || true)" = "$ID" ] \
    || die "home $HOME_DIR is not marked as second mate $ID's home"
}

# Print one line per reason this mate must keep running; return 0 when there is
# at least one. A blocked stand-down changes nothing, so every blocker is listed.
collect_blockers() {
  local found=0 child child_id n marker value
  for child in "$HOME_DIR/state"/*.meta; do
    [ -f "$child" ] || continue
    child_id=$(basename "$child" .meta)
    printf 'in-flight work: its home has task %s (%s)\n' "$child_id" "$child"
    found=1
  done
  if [ -f "$HOME_DIR/data/backlog.md" ]; then
    n=$(awk '
      /^##[[:space:]]+/ { section = $0; sub(/^##[[:space:]]+/, "", section); sub(/[[:space:]]+$/, "", section); next }
      section == "In flight" && /^- \[[ x]\] / { count++ }
      END { print count + 0 }' "$HOME_DIR/data/backlog.md")
    if [ "$n" -gt 0 ]; then
      printf 'in-flight work: its backlog lists %s item(s) under In flight (%s)\n' "$n" "$HOME_DIR/data/backlog.md"
      found=1
    fi
  fi
  if fm_pending_reply_task_has_open "$STATE" "$ID"; then
    printf 'pending reply: this home still waits on an unresolved reply from it (state/pending-replies)\n'
    found=1
  fi
  if compgen -G "$STATE/$ID.inbox/*.msg" >/dev/null 2>&1; then
    printf 'unread steer: an instruction in %s has not been acknowledged\n' "$STATE/$ID.inbox"
    found=1
  fi
  marker="$STATE/.backlog-handoff-$ID.wake-pending"
  if [ -e "$marker" ] || [ -L "$marker" ]; then
    value=$(cat "$marker" 2>/dev/null || true)
    case "$value" in
      confirmed|confirmed:*) ;;
      *)
        printf 'undelivered handoff wake: %s still owes the mate a wake for routed work\n' "$marker"
        found=1
        ;;
    esac
  fi
  [ "$found" -eq 1 ]
}

cmd_stand_down() {
  local reason='' arg='' blockers out rc=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --reason)
        [ "$#" -ge 2 ] || die "--reason needs a value"
        reason=$2
        shift 2
        ;;
      --reason=*) reason=${1#--reason=}; shift ;;
      -*) echo "error: unexpected argument '$1'" >&2; exit 2 ;;
      *)
        [ -z "$arg" ] || { echo "error: stand-down takes one second mate id" >&2; exit 2; }
        arg=$1
        shift
        ;;
    esac
  done
  [ -n "$arg" ] || { echo "usage: fm-secondmate-dormant.sh stand-down <secondmate-id> [--reason <text>]" >&2; exit 2; }
  resolve_mate "$arg"
  fm_secondmate_liveness_lock "$ID" || die "a liveness check is in progress for $ID; nothing was changed - retry"
  ADMISSION_LOCK=
  trap 'fm_sm_admission_unlock "$ADMISSION_LOCK"; fm_secondmate_liveness_unlock "$ID"' EXIT
  fm_sm_admission_lock "$STATE" "$ID" || exit 1
  ADMISSION_LOCK=$FM_SM_ADMISSION_LOCK
  if fm_sm_dormant_is "$STATE" "$ID"; then
    die "second mate $ID is already dormant ($(fm_sm_dormant_describe "$STATE" "$ID"))"
  fi
  if blockers=$(collect_blockers); then
    {
      printf 'refused: second mate %s cannot be stood down yet; nothing was changed:\n' "$ID"
      printf '%s\n' "$blockers" | sed 's/^/  - /'
    } >&2
    exit 1
  fi
  out=$(FM_HOME="$FM_HOME" FM_ROOT_OVERRIDE="$FM_ROOT" "$SCRIPT_DIR/fm-control.sh" "$ID" exit 2>&1) || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out" >&2
    die "could not confirm second mate $ID's agent stopped; dormancy was not recorded"
  fi
  fm_sm_dormant_write "$STATE" "$ID" "$reason" \
    || die "second mate $ID's agent stopped, but its dormant record could not be written to $STATE; the liveness sweep may relaunch it until it is recorded - rerun stand-down"
  printf 'stood down %s: agent stopped; home, route, backlog, held decisions and reports kept\n' "$ID"
  printf 'bring it back with: bin/fm-secondmate-dormant.sh resume %s\n' "$ID"
}

cmd_resume() {
  [ "$#" -eq 1 ] && [ -n "$1" ] || { echo "usage: fm-secondmate-dormant.sh resume <secondmate-id>" >&2; exit 2; }
  case "$1" in -*) echo "error: unexpected argument '$1'" >&2; exit 2 ;; esac
  resolve_mate "$1"
  fm_secondmate_liveness_lock "$ID" || die "a liveness check is in progress for $ID; nothing was changed - retry"
  trap 'fm_secondmate_liveness_unlock "$ID"' EXIT
  fm_sm_dormant_is "$STATE" "$ID" || die "second mate $ID is not dormant; nothing to resume"
  export FM_SECONDMATE_RESUMING=$ID
  fm_secondmate_liveness_probe_endpoint "$META" "$ID" full
  case "$FM_SM_LIVE_STATUS" in
    alive)
      fm_sm_dormant_clear "$STATE" "$ID" || die "second mate $ID is running, but its dormant record could not be cleared"
      printf 'resumed %s: its agent was already running; dormancy cleared\n' "$ID"
      ;;
    relaunchable)
      if fm_secondmate_liveness_relaunch "$META" "$ID"; then
        fm_secondmate_liveness_ledger_add "$ID" rearmed || true
        fm_sm_dormant_clear "$STATE" "$ID" \
          || die "second mate $ID was relaunched, but its dormant record could not be cleared; rerun resume"
        printf 'resumed %s: relaunched through the guarded secondmate launch; dormancy cleared\n' "$ID"
      elif [ "$FM_SM_LIVE_STATUS" = skipped ]; then
        die "second mate $ID was not relaunched and stays dormant: $FM_SM_LIVE_REASON"
      else
        die "relaunch of second mate $ID failed and it stays dormant: $(fm_sm_live_first_line "$FM_SM_LIVE_OUT")"
      fi
      ;;
    *)
      die "second mate $ID was not relaunched and stays dormant: ${FM_SM_LIVE_REASON:-its endpoint has no recorded window}"
      ;;
  esac
}

cmd_list() {
  local id n=0
  [ "$#" -eq 0 ] || { echo "usage: fm-secondmate-dormant.sh list" >&2; exit 2; }
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    n=$((n + 1))
    printf '%s\t%s\n' "$id" "$(fm_sm_dormant_describe "$STATE" "$id")"
  done < <(fm_sm_dormant_ids "$STATE")
  [ "$n" -gt 0 ] || printf '(no dormant second mates)\n'
}

case "$VERB" in
  stand-down) cmd_stand_down "$@" ;;
  resume) cmd_resume "$@" ;;
  list) cmd_list "$@" ;;
  *) echo "error: unknown verb '$VERB'" >&2; usage >&2; exit 2 ;;
esac
