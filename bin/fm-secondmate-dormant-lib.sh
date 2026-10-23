#!/usr/bin/env bash
# shellcheck disable=SC2034 # Output globals are read by sourcing callers.
# fm-secondmate-dormant-lib.sh - the durable stood-down (dormant) record for a
# persistent LOCAL secondmate, and the one question every relaunch, wake and
# routing path asks of it. Source only; no side effects on source.
#
# A dormant mate is stopped on purpose: its agent is gone, but its home, lease,
# registry route, backlog, held decisions and reports are all intact, so it can
# be brought back at any time. bin/fm-secondmate-dormant.sh is the one command
# pair that creates and clears the record (stand-down / resume) and owns the
# contract; this library owns only the record's storage and the read side.
#
# Record: <state-dir>/<id>.dormant, a key=value file written atomically by the
# parent home only:
#   schema=fm-secondmate-dormant.v1
#   id=<secondmate id>
#   since=<epoch the stand-down completed>
#   reason=<one line, may be empty>
# Its mere existence is the verdict; a record that cannot be parsed still reads
# as dormant, because the safe error is to leave a stopped mate stopped. A
# symlinked or non-regular path at the record location is not a record.
# Teardown removes the record with the mate's other per-task state, so a retired
# id can never inherit a stale stood-down verdict.

fm_sm_admission_lock() {
  local state=$1 id=$2 lock owner
  FM_SM_ADMISSION_LOCK=
  if ! command -v fm_lock_try_acquire >/dev/null 2>&1; then
    # shellcheck source=bin/fm-wake-lib.sh
    . "${BASH_SOURCE[0]%/*}/fm-wake-lib.sh"
  fi
  lock="$state/.secondmate-admission-$id.lock"
  owner=$(cat "$lock/pid" 2>/dev/null || true)
  if [ -n "${FM_SM_ADMISSION_PARENT:-}" ] && [ "$owner" = "$FM_SM_ADMISSION_PARENT" ] \
    && fm_pid_alive "$owner" && fm_pid_descends_from "$PPID" "$owner"; then
    return 0
  fi
  if ! fm_lock_try_acquire "$lock"; then
    printf 'error: task %s has a lifecycle or work admission in progress; nothing was changed - retry\n' "$id" >&2
    return 1
  fi
  FM_SM_ADMISSION_LOCK=$lock
}

fm_sm_admission_unlock() {
  [ -z "$1" ] || fm_lock_release "$1"
}

fm_sm_dormant_path() {  # <state-dir> <id>
  printf '%s/%s.dormant\n' "$1" "$2"
}

fm_sm_dormant_valid_id() {  # <id>
  case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
  return 0
}

# fm_sm_dormant_is <state-dir> <id>: 0 when <id> is stood down in this home.
fm_sm_dormant_is() {
  local path
  fm_sm_dormant_valid_id "$2" || return 1
  path=$(fm_sm_dormant_path "$1" "$2")
  [ -f "$path" ] && [ ! -L "$path" ]
}

# fm_sm_dormant_get <state-dir> <id> <key>: one record field, empty when absent.
fm_sm_dormant_get() {
  local path line value=''
  path=$(fm_sm_dormant_path "$1" "$2")
  [ -f "$path" ] && [ ! -L "$path" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$3="*) value=${line#*=} ;;
    esac
  done < "$path" 2>/dev/null || true
  printf '%s' "$value"
}

# fm_sm_dormant_write <state-dir> <id> [reason]: publish the record atomically.
# The reason is flattened to one line so the record stays a plain key=value file.
fm_sm_dormant_write() {
  local state=$1 id=$2 reason=${3:-} path tmp
  fm_sm_dormant_valid_id "$id" || return 1
  reason=$(printf '%s' "$reason" | tr '\r\n\t' '   ')
  path=$(fm_sm_dormant_path "$state" "$id")
  tmp="$path.tmp.$$"
  {
    printf 'schema=fm-secondmate-dormant.v1\n'
    printf 'id=%s\n' "$id"
    printf 'since=%s\n' "$(date +%s)"
    printf 'reason=%s\n' "$reason"
  } > "$tmp" 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$path" 2>/dev/null || { rm -f -- "$tmp"; return 1; }
}

# fm_sm_dormant_clear <state-dir> <id>: remove the record; absent is success.
fm_sm_dormant_clear() {
  fm_sm_dormant_valid_id "$2" || return 1
  rm -f -- "$(fm_sm_dormant_path "$1" "$2")"
}

# fm_sm_dormant_ids <state-dir>: one dormant id per line, sorted.
fm_sm_dormant_ids() {
  local rec id
  for rec in "$1"/*.dormant; do
    [ -f "$rec" ] && [ ! -L "$rec" ] || continue
    id=${rec##*/}
    id=${id%.dormant}
    fm_sm_dormant_valid_id "$id" || continue
    printf '%s\n' "$id"
  done | sort
}

# fm_sm_dormant_describe <state-dir> <id>: the one human line every refusal and
# listing uses, e.g. "stood down since 2026-10-23T10:00:00Z (no work for now)".
fm_sm_dormant_describe() {
  local since reason when
  since=$(fm_sm_dormant_get "$1" "$2" since)
  reason=$(fm_sm_dormant_get "$1" "$2" reason)
  case "$since" in
    ''|*[!0-9]*) when='at an unrecorded time' ;;
    *)
      when=$(date -u -d "@$since" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
        || date -u -r "$since" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
        || printf 'epoch %s' "$since")
      when="since $when"
      ;;
  esac
  printf 'stood down %s' "$when"
  [ -z "$reason" ] || printf ' (%s)' "$reason"
  printf '\n'
}

# fm_sm_dormant_refusal <state-dir> <id> <what>: the shared stderr refusal for a
# path that would launch, wake or queue to a stopped mate.
fm_sm_dormant_refusal() {
  printf 'error: secondmate %s is dormant (%s); %s - bring it back first with bin/fm-secondmate-dormant.sh resume %s\n' \
    "$2" "$(fm_sm_dormant_describe "$1" "$2")" "$3" "$2" >&2
}
