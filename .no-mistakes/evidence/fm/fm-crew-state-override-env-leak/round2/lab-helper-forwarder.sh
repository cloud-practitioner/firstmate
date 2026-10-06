#!/usr/bin/env bash
set -eu
cd "$V_ROOT"
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) [ "${2:-}" = "$V_SESSION" ] || exit 2; shift 2;;
    --session=*) [ "${1#*=}" = "$V_SESSION" ] || exit 2; shift;;
    *) args+=("$1"); shift;;
  esac
done
export PATH="$V_ROOT/.v/raw:$V_BASE_PATH"
if [ "${args[0]:-}" = server ]; then
  exec "$V_ROOT/bin/fm-herdr-lab.sh" provision "$V_SESSION"
fi
exec "$V_ROOT/bin/fm-herdr-lab.sh" run "$V_SESSION" "${args[@]}"
