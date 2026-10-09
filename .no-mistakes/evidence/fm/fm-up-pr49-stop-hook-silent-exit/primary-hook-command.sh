#!/usr/bin/env bash
set -u
bin/fm-lock.sh || exit 1
printf 'LAB_LOCK_READY\n' > "$FM_HOME/primary.ready"
while [ ! -e "$FM_HOME/direct.go" ]; do sleep 0.1; done
printf 'LAB_STOP_READY\n'
exit 0
