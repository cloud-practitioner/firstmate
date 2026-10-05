#!/usr/bin/env bash
set -eu
cd /home/node/.no-mistakes/worktrees/c98b859efde5/01M469KHGAXW3MXGQ83EVZD7E8
# Route the real executable through the repository's sole lab lifecycle owner.
args=(); session=; passthrough=0
while [ "$#" -gt 0 ]; do
  if [ "$passthrough" = 0 ] && [ "$1" = --session ]; then session=$2; shift 2; continue; fi
  if [ "$passthrough" = 0 ] && [[ "$1" == --session=* ]]; then session=${1#*=}; shift; continue; fi
  [ "$1" != -- ] || passthrough=1
  args+=("$1"); shift
done
export PATH="$(dirname "$FM_REAL_HERDR"):${PATH#*:}"
if [ "${args[0]:-}" = --version ] || [ "${args[0]:-}" = --help ]; then exec "$FM_REAL_HERDR" "${args[@]}"; fi
session=${session:-${HERDR_SESSION:-}}
# Only the pinned installer's non-mutating status probe is allowed without a session.
if [ -z "$session" ] && [ "${args[0]:-}" = status ]; then exec "$FM_REAL_HERDR" "${args[@]}"; fi
case "${args[0]:-} ${args[1]:-}" in
  'server ')
    . bin/fm-herdr-lab.sh
    # Existing tests prepare before asking the adapter to start a server.
    # provision auto-prepares an absent session, so finish that read-only
    # tripwire interval first; provision then records its own unchanged snapshot.
    if ! fm_herdr_lab_session_list "$session" | jq -e --arg n "$session" '.sessions[]? | select(.name == $n)' >/dev/null; then
      fm_herdr_lab_verify_tripwire "$session"
    fi
    exec bin/fm-herdr-lab.sh provision "$session"
    ;;
  'session stop') exec bin/fm-herdr-lab.sh stop "$session" ;;
  # This command is emitted by the test's already-running helper teardown.
  # Keep its tripwire ownership with that outer teardown, not a second one.
  'session delete') exec "$FM_REAL_HERDR" "${args[@]}" --session "$session" ;;
  'session list')
    # Preserve the actual socket identity, but return its absolute spelling
    # to the adapter, which intentionally refuses relative identities.
    bin/fm-herdr-lab.sh run "$session" "${args[@]}" | jq --arg root "$PWD/" '.sessions |= map(if .default == false and (.socket_path | startswith("/")) == false then .socket_path = ($root + .socket_path) else . end)'
    exit "${PIPESTATUS[0]}"
    ;;
esac
if [ -n "${FM_API_EVIDENCE:-}" ]; then
  case "${args[0]:-} ${args[1]:-}" in
    'pane report-agent'|'pane process-info'|'agent get')
      tmp=$(mktemp "$TMPDIR/response.XXXXXX")
      rc=0
      bin/fm-herdr-lab.sh run "$session" "${args[@]}" > "$tmp" 2>&1 || rc=$?
      {
        printf '\n$ herdr'; printf ' %q' "${args[@]}"; printf ' --session %q [exit=%s]\n' "$session" "$rc"
        /usr/bin/python3 -c 'import sys; print(open(sys.argv[1]).read(), end="")' "$tmp"
      } >> "$FM_API_EVIDENCE"
      /usr/bin/python3 -c 'import sys; print(open(sys.argv[1]).read(), end="")' "$tmp"
      rm -f "$tmp"
      if [ "${args[0]:-} ${args[1]:-}" = 'pane report-agent' ] && [ -n "${FM_REPORT_AGENT_SETTLE:-}" ]; then sleep "$FM_REPORT_AGENT_SETTLE"; fi
      exit "$rc"
      ;;
  esac
fi
if [ "${args[0]:-} ${args[1]:-}" = 'pane report-agent' ] && [ -n "${FM_REPORT_AGENT_SETTLE:-}" ]; then
  bin/fm-herdr-lab.sh run "$session" "${args[@]}"
  sleep "$FM_REPORT_AGENT_SETTLE"
  exit 0
fi
exec bin/fm-herdr-lab.sh run "$session" "${args[@]}"
