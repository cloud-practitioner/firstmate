#!/usr/bin/env bash
# lab stub for the external no-mistakes CLI: reports one terminal passed run for fm/task-bb4
echo "lab stub: no-mistakes $*" >> "/tmp/fm-lab.fka9Bl/ext/stub-calls.log"
if [ "${1:-}" = axi ] && { [ "$#" = 1 ] || [ "${2:-}" = status ]; }; then cat <<EOF
run:
  id: "01RUNLAB"
  branch: fm/task-bb4
  status: completed
  head: "e65b17d7220778b5c99277e19bfa9d612a585e71"
  pr: "https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/8"
  findings: none
outcome: passed
EOF
fi
exit 0
