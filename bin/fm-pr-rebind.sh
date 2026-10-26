#!/usr/bin/env bash
# Refresh registered PR merge watches of one home after bin/fm-pr-poll.sh changed.
# bin/fm-pr-check.sh arms a watch by publishing a byte copy of that template as
# state/<id>.check.sh, bound to it by state/<id>.pr-poll-registration. A
# self-update rewrites the template in place, so every watch armed before the
# update stops matching the strict validation and the watcher refuses it as
# unauthenticated, though nothing was tampered with and no merge would then be
# detected.
# Per-watch output reports replacements and refusals:
#   rebound: <id>       the check was exactly the byte copy the registration
#                       records, from an older template, so it was replaced by
#                       the current one under the task's control and poll
#                       publication locks (fm_pr_poll_registration_rebind_template
#                       in bin/fm-pr-lib.sh owns the proof).
#   actionable: ...     anything the proof does not cover, such as a hand-edited
#                       or swapped check or a tampered sidecar. It is never
#                       trusted, and the line names the task and a
#                       bin/fm-pr-check.sh re-arm command (<pr-url> means the
#                       URL must be supplied).
# A final summary counts rebound, unchanged, and unsafe watches. Already-valid
# watches, pending retirement receipts, and volume renumbers the watcher itself
# re-records count as unchanged and produce no per-watch line.
# The exit status is 1 when any watch needs the re-arm, 0 otherwise.
# bin/fm-update.sh's header owns automatic update-time invocation; the watcher
# repeats the rebind on its next check sweep, so other update paths heal too.
# The template is bin/fm-pr-poll.sh under FM_ROOT_OVERRIDE, defaulting to this
# script's code root. FM_HOME selects the home; FM_STATE_OVERRIDE can select
# its state directory. Missing state is a successful no-op; a missing template
# with state present exits 1.
# Regression coverage: tests/fm-pr-check-security.test.sh and tests/fm-update.test.sh.
# Usage: fm-pr-rebind.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
TEMPLATE="$FM_ROOT/bin/fm-pr-poll.sh"

# shellcheck source=bin/fm-pr-lib.sh
. "$SCRIPT_DIR/fm-pr-lib.sh"
# shellcheck source=bin/fm-wake-lib.sh
. "$SCRIPT_DIR/fm-wake-lib.sh"

if [ "$#" -ne 0 ]; then
  echo "usage: fm-pr-rebind.sh" >&2
  exit 2
fi

[ -d "$STATE" ] && [ ! -L "$STATE" ] || { echo "pr-rebind: no state directory"; exit 0; }
[ -f "$TEMPLATE" ] || { echo "actionable: $TEMPLATE is missing, so no PR merge watch can be checked" >&2; exit 1; }

# Use the task's recorded pr=, or the sidecar URL only when pr= is empty.
# An invalid selected URL becomes a placeholder, never unvalidated command text.
rearm_url() {  # <id>
  local id=$1 url
  url=$(grep '^pr=' "$STATE/$id.meta" 2>/dev/null | tail -1 | cut -d= -f2- || true)
  if [ -z "$url" ]; then
    url=$(sed -n 2p "$STATE/$id.pr-poll" 2>/dev/null || true)
  fi
  if fm_pr_url_parse "$url"; then
    printf '%s\n' "$FM_PR_URL"
  else
    printf '<pr-url>\n'
  fi
}

control_lock=
publish_lock=
release_locks() {
  [ -z "$publish_lock" ] || fm_lock_release "$publish_lock" || true
  [ -z "$control_lock" ] || fm_lock_release "$control_lock" || true
  publish_lock=
  control_lock=
}
trap release_locks EXIT
trap 'exit 1' HUP INT TERM

# Take the same two locks, in the same order, as the watcher's own re-record.
rebind_locked() {  # <id>
  local id=$1 rc=1
  control_lock="$STATE/.control-$id.lock"
  fm_lock_acquire_wait_max "$control_lock" 60 || { control_lock=; return 1; }
  publish_lock="$STATE/.pr-poll-publish-$id.lock"
  if fm_lock_acquire_wait_max "$publish_lock" 60; then
    fm_pr_poll_registration_rebind_template "$STATE" "$id" "$TEMPLATE" && rc=0
  else
    publish_lock=
  fi
  release_locks
  return "$rc"
}

rebound=0
unchanged=0
broken=0
for registration in "$STATE"/*.pr-poll-registration; do
  [ -e "$registration" ] || [ -L "$registration" ] || continue
  id=$(basename "$registration" .pr-poll-registration)
  if ! fm_pr_task_id_valid "$id"; then
    continue
  fi
  if fm_pr_poll_artifacts_valid "$STATE" "$id" "$TEMPLATE" \
    || [ -e "$STATE/$id.pr-poll-retirement" ] || [ -L "$STATE/$id.pr-poll-retirement" ] \
    || fm_pr_poll_registration_device_shifted "$STATE" "$id" "$TEMPLATE"; then
    unchanged=$((unchanged + 1))
    continue
  fi
  if fm_pr_poll_registration_template_stale "$STATE" "$id" "$TEMPLATE" && rebind_locked "$id"; then
    rebound=$((rebound + 1))
    printf 'rebound: %s\n' "$id"
    continue
  fi
  broken=$((broken + 1))
  printf 'actionable: the PR merge watch for %s cannot be re-recorded safely and will not detect a merge; re-arm it with: bin/fm-pr-check.sh %s %s\n' \
    "$id" "$id" "$(rearm_url "$id")"
done
printf 'pr-rebind: %s rebound, %s unchanged, %s need a re-arm\n' "$rebound" "$unchanged" "$broken"
[ "$broken" -eq 0 ]
