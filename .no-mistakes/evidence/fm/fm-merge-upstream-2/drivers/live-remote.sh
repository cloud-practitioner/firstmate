#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EV=/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C
export TMPDIR="$ROOT/.test-phase-tmp"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null
mkdir -p "$LAB/account" "$LAB/other/state"
export FM_HOME="$LAB" FM_REMOTE_JOB_STATE_ROOT="$LAB/jobs" FM_REMOTE_JOB_PLATFORM_OVERRIDE=Linux
export FM_REMOTE_JOB_QUEUE_TIMEOUT=30 FM_REMOTE_JOB_TIMEOUT=30 FM_REMOTE_JOB_WAIT_GRACE=5
. "$ROOT/bin/fm-remote-job-lib.sh"
cleanup() { if [ -f "$LAB/jobs/worker.pid" ]; then fm_remote_job_stop_worker_tree "$(head -1 "$LAB/jobs/worker.pid")" || true; fi; rm -rf "$LAB"; }
trap cleanup EXIT
{
  echo 'Real worker and real tracked commands, private account/home/job queue; no SSH or command stubs'
  : > "$LAB/state/replies.status"
  : > "$LAB/other/state/replies.status"
  EMPTY=$(printf '' | sha256sum | awk '{print $1}')
  fm_remote_job_ensure_worker "$ROOT" "$LAB/account" || { echo "$FM_REMOTE_JOB_ERROR"; exit 1; }
  fm_remote_job_stage "$LAB/account" "$ROOT" "$LAB" fm-remote-delta-read.sh state/replies.status 0 "$EMPTY" 20 </dev/null
  POLL=$FM_REMOTE_JOB_ID
  fm_remote_job_stage "$LAB/account" "$ROOT" "$LAB/other" fm-remote-delta-read.sh state/replies.status 0 "$EMPTY" 20 </dev/null
  OTHER=$FM_REMOTE_JOB_ID
  for i in $(seq 1 80); do
    if [ "$(head -1 "$FM_REMOTE_JOB_JOBS/$POLL/state")" = running ] && [ "$(head -1 "$FM_REMOTE_JOB_JOBS/$OTHER/state")" = running ]; then break; fi
    sleep .1
  done
  printf 'Both independent home lanes: own=%s other=%s\n' "$(head -1 "$FM_REMOTE_JOB_JOBS/$POLL/state")" "$(head -1 "$FM_REMOTE_JOB_JOBS/$OTHER/state")"
  test "$(head -1 "$FM_REMOTE_JOB_JOBS/$POLL/state")" = running
  test "$(head -1 "$FM_REMOTE_JOB_JOBS/$OTHER/state")" = running
  fm_remote_job_stage "$LAB/account" "$ROOT" "$LAB" fm-operational-input.sh encode launch-brief <<< 'Short interactive job payload'
  SHORT=$FM_REMOTE_JOB_ID
  fm_remote_job_wait "$LAB/account" "$POLL"
  printf 'Same-home long poll preemption exit=%s\n' "$FM_REMOTE_JOB_EXIT"
  test "$FM_REMOTE_JOB_EXIT" = 76
  test ! -s "$FM_REMOTE_JOB_STDOUT"
  test ! -s "$FM_REMOTE_JOB_STDERR"
  fm_remote_job_reap "$LAB/account" "$POLL"
  printf 'Other-home long poll state after preemption=%s\n' "$(head -1 "$FM_REMOTE_JOB_JOBS/$OTHER/state")"
  test "$(head -1 "$FM_REMOTE_JOB_JOBS/$OTHER/state")" = running
  fm_remote_job_wait "$LAB/account" "$SHORT"
  test "$FM_REMOTE_JOB_EXIT" = 0
  cp "$FM_REMOTE_JOB_STDOUT" "$EV/remote-short-payload.txt"
  printf 'Short command output:\n'; head -5 "$EV/remote-short-payload.txt"
  fm_remote_job_reap "$LAB/account" "$SHORT"
  printf 'Remote reply arrived\n' >> "$LAB/other/state/replies.status"
  fm_remote_job_wait "$LAB/account" "$OTHER"
  test "$FM_REMOTE_JOB_EXIT" = 0
  cp "$FM_REMOTE_JOB_STDOUT" "$EV/remote-job-delta.txt"
  printf 'Other-home completed result:\n'; head -15 "$EV/remote-job-delta.txt"
  fm_remote_job_reap "$LAB/account" "$OTHER"
  grep -q '^status=delta$' "$EV/remote-job-delta.txt"
  grep -q '^Remote reply arrived$' "$EV/remote-job-delta.txt"
  printf 'No pending consumer records: '; ls "$FM_REMOTE_JOB_JOBS" | wc -l
} > "$EV/remote-worker.log" 2>&1
