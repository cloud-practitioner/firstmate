#!/usr/bin/env bash
set -u
bin/fm-lock.sh || exit 1
printf 'LAB_LOCK_READY\n' > "$FM_HOME/primary.ready"
while [ ! -e "$FM_HOME/direct.go" ]; do sleep 0.1; done
"${GATE_HOST_ENTRY:-bin/fm-supervision-host.sh}" park > "$FM_HOME/host.out" 2> "$FM_HOME/host.err"
rc=$?
printf '%s\n' "$rc" > "$FM_HOME/host.rc"
rm -f "$FM_HOME/state/demo.meta"
printf 'DIRECT_HOST_FINISHED exit=%s\n' "$rc"
exit 0
