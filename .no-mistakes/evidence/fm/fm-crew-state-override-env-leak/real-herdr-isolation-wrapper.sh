#!/usr/bin/env bash
set -eu
cd "$V_ROOT"
# Two real inventories: the operator default is read only for the mandatory
# fleet-state tripwire; disposable named sessions live inside this worktree.
if [ "${1:-} ${2:-}" = 'session list' ]; then
  operator=$(env -u XDG_CONFIG_HOME -u HERDR_SOCKET_PATH HOME="$V_OPERATOR_HOME" "$V_REAL_HERDR" "$@")
  local_inventory=$(env -u HERDR_SOCKET_PATH HOME="$V_ROOT/.v/home" XDG_CONFIG_HOME=.v "$V_REAL_HERDR" "$@")
  jq -cn --argjson a "$operator" --argjson b "$local_inventory" '{sessions:([$a.sessions[]|select(.default==true)]+[$b.sessions[]|select(.default!=true)])}'
  exit
fi
session=
for ((i=1;i<=$#;i++)); do
  if [ "${!i}" = --session ]; then j=$((i+1)); session=${!j}; fi
done
[ "$session" = "$V_SESSION" ] || { echo "refused non-lab target: $session" >&2; exit 2; }
{
  printf 'HERDR command:'; printf ' %q' "$@"; printf '\n'
  for var in FM_SNAPSHOT_SCOPED_ENV FM_CREW_STATE_META_OVERRIDE FM_CREW_STATE_STATUS_OVERRIDE FM_HOME_SUMMARY_IF_IDLE FM_HOME_SUMMARY_WORKER_BEST_EFFORT FM_HOME_SUMMARY_PARENT_ERROR FM_HOME_SUMMARY_PARENT_STAMP FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_PROJECTS_OVERRIDE FM_CONFIG_OVERRIDE FM_HOME; do
    if [ -n "${!var+x}" ]; then printf '%s=%s\n' "$var" "${!var}"; fi
  done
} >> "$V_EVIDENCE/client-boundary.log"
exec env -u HERDR_SOCKET_PATH HOME="$V_ROOT/.v/home" XDG_CONFIG_HOME=.v "$V_REAL_HERDR" "$@"
