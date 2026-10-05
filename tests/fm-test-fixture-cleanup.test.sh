#!/usr/bin/env bash
# Behavior tests for tests/lib.sh's shared fixture-tempdir helper
# (fm_test_tmproot / fm_test_cleanup / fm_test_reap_orphans).
#
# The near-universal call pattern across this suite is
# `TMP_ROOT=$(fm_test_tmproot prefix)`, which forks a subshell to capture the
# function's stdout. These tests spawn real, separate bash processes that use
# that exact pattern and assert the fixture root is actually gone once the
# owning process's guarded teardown has run - on a normal exit and on a
# terminating signal - plus that a stale marked fixture from a killed prior
# run gets reaped on the next source. Nothing here inspects tests/lib.sh's
# source text; it only observes filesystem state around the real helper.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LIB="$ROOT/tests/lib.sh"

test_fixture_root_gone_after_normal_exit() {
  local child_out child_dir
  child_out=$(bash -c '
    # shellcheck source=tests/lib.sh
    . "'"$LIB"'"
    d=$(fm_test_tmproot fm-test-cleanup-exit)
    printf "%s\n" "$d"
    if [ -d "$d" ]; then printf "mid:present\n"; else printf "mid:missing\n"; fi
  ')
  child_dir=$(printf '%s\n' "$child_out" | sed -n '1p')
  assert_contains "$child_out" "mid:present" \
    "the fixture root was not present while its owning process was still alive"
  assert_absent "$child_dir" \
    "fm_test_tmproot's fixture root survived its owning process's normal exit"
  pass "fm_test_tmproot cleans up its fixture root on normal exit"
}

test_fixture_root_gone_after_sigterm() {
  local harness dirfile child_dir pid tries
  harness=$(fm_test_tmproot fm-test-cleanup-sigterm-harness)
  dirfile="$harness/child-dir"
  bash -c '
    # shellcheck source=tests/lib.sh
    . "'"$LIB"'"
    d=$(fm_test_tmproot fm-test-cleanup-term)
    printf "%s\n" "$d" > "'"$dirfile"'"
    while :; do sleep 0.1; done
  ' &
  pid=$!
  tries=0
  while [ "$tries" -lt 100 ]; do
    [ -s "$dirfile" ] && break
    sleep 0.05
    tries=$((tries + 1))
  done
  [ -s "$dirfile" ] || fail "the child never published its fixture root before the wait timed out"
  child_dir=$(cat "$dirfile")
  assert_present "$child_dir" "the child's fixture root did not exist before it was signaled"
  kill -TERM "$pid"
  wait "$pid" 2>/dev/null
  assert_absent "$child_dir" \
    "fm_test_tmproot's fixture root survived SIGTERM to its owning process"
  pass "fm_test_tmproot cleans up its fixture root on SIGTERM"
}

test_cleanup_registry_resists_precreation() {
  local harness shared_tmp victim
  harness=$(fm_test_tmproot fm-test-cleanup-registry-harness)
  shared_tmp="$harness/shared-tmp"
  victim="$harness/victim"
  mkdir -p "$shared_tmp" "$victim"

  TMPDIR="$shared_tmp" bash -c '
    printf "%s\n" "$1" > "$TMPDIR/.fm-test-cleanup.$$"
    . "$2"
  ' _ "$victim" "$LIB"

  assert_present "$victim" \
    "a precreated predictable cleanup registry injected an arbitrary deletion target"
  pass "the cleanup registry cannot be injected through path precreation"
}

test_fixture_registration_failure_rolls_back_root() {
  local harness failure_tmp registry_dir output leaked_root
  harness=$(fm_test_tmproot fm-test-cleanup-registration-harness)
  failure_tmp="$harness/tmp"
  registry_dir="$harness/registry-dir"
  mkdir -p "$failure_tmp" "$registry_dir"

  if output=$(TMPDIR="$failure_tmp" FM_TEST_CLEANUP_REGISTRY="$registry_dir" \
    fm_test_tmproot fm-test-cleanup-registration-failure 2>/dev/null); then
    fail "fm_test_tmproot succeeded after its cleanup registry rejected registration"
  fi
  [ -z "$output" ] || fail "fm_test_tmproot published an unregistered fixture root"
  for leaked_root in "$failure_tmp"/fm-test-cleanup-registration-failure.*; do
    [ ! -e "$leaked_root" ] || fail "fm_test_tmproot leaked a root after registration failed"
  done
  pass "failed fixture registration rolls back the new root"
}

test_orphan_sweep_respects_fixture_ownership() {
  local harness dirfile active_dir stale_dir fresh_dir pid tries
  harness=$(fm_test_tmproot fm-test-cleanup-orphan-harness)
  dirfile="$harness/active-dir"
  bash -c '
    # shellcheck source=tests/lib.sh
    . "'"$LIB"'"
    d=$(fm_test_tmproot fm-test-cleanup-active)
    printf "%s\n" "$d" > "'"$dirfile"'"
    while :; do sleep 0.1; done
  ' &
  pid=$!
  tries=0
  while [ "$tries" -lt 100 ]; do
    [ -s "$dirfile" ] && break
    sleep 0.05
    tries=$((tries + 1))
  done
  [ -s "$dirfile" ] || fail "the active child never published its fixture root before the wait timed out"
  active_dir=$(cat "$dirfile")
  touch -t 202001010000 "$active_dir/.fm-test-fixture"

  stale_dir=$(mktemp -d "$FM_TEST_TMPDIR/fm-test-cleanup-stale.XXXXXX")
  printf '%s\n%s\n' "$$" reused-process-identity > "$stale_dir/.fm-test-fixture"
  touch -t 202001010000 "$stale_dir/.fm-test-fixture"
  fresh_dir=$(mktemp -d "$FM_TEST_TMPDIR/fm-test-cleanup-fresh.XXXXXX")
  : > "$fresh_dir/.fm-test-fixture"

  bash -c '
    # shellcheck source=tests/lib.sh
    . "'"$LIB"'"
  '

  assert_absent "$stale_dir" \
    "a stale fixture root whose PID was reused by another process was not reaped"
  assert_present "$active_dir" \
    "the orphan reaper removed an old fixture root whose owning process was still alive"
  assert_present "$fresh_dir" \
    "the orphan reaper removed a fresh marked fixture root it does not own yet"
  kill -TERM "$pid"
  wait "$pid" 2>/dev/null
  assert_absent "$active_dir" \
    "the active fixture root survived its owning process's teardown"
  rm -rf "$fresh_dir"
  pass "the orphan sweep reaps only old fixtures without a live owner"
}

test_orphan_sweep_reaps_read_only_package_tree() {
  local stale_dir package_dir
  stale_dir=$(mktemp -d "$FM_TEST_TMPDIR/fm-test-cleanup-read-only.XXXXXX")
  package_dir="$stale_dir/packages/extension"
  mkdir -p "$package_dir"
  printf '%s\n%s\n' "$$" reused-process-identity > "$stale_dir/.fm-test-fixture"
  printf 'installed package\n' > "$package_dir/entrypoint.py"
  chmod -R a-w "$stale_dir/packages"
  touch -t 202001010000 "$stale_dir/.fm-test-fixture"

  bash -c '
    # shellcheck source=tests/lib.sh
    . "$1"
  ' _ "$LIB"

  assert_absent "$stale_dir" \
    "the orphan reaper left a stale fixture containing a read-only package tree"
  pass "the orphan sweep reaps read-only package fixtures"
}

test_registries_avoid_git_worktree_root() {
  # A TMPDIR pointed at a repository root used to place live `.fm-test-*`
  # registries beside tracked files. A concurrent git add during a suite then
  # committed them (observed on the claim-walk CI fix round). The helper must
  # keep registries and fixture roots outside that root for the whole run.
  local harness repo dirfile child_dir pid tries entry
  harness=$(fm_test_tmproot fm-test-cleanup-gitroot-harness)
  repo="$harness/repo"
  dirfile="$harness/child-dir"
  mkdir -p "$repo"
  git -C "$repo" init -q
  bash -c '
    export TMPDIR="$1"
    # shellcheck source=tests/lib.sh
    . "$2"
    d=$(fm_test_tmproot fm-test-cleanup-gitroot)
    printf "%s\n" "$d" > "$3"
    # Hold the suite open so a concurrent add would see any root-side leak.
    while :; do sleep 0.1; done
  ' _ "$repo" "$LIB" "$dirfile" &
  pid=$!
  tries=0
  while [ "$tries" -lt 100 ]; do
    [ -s "$dirfile" ] && break
    sleep 0.05
    tries=$((tries + 1))
  done
  [ -s "$dirfile" ] || fail "the git-root TMPDIR child never published its fixture root"
  child_dir=$(cat "$dirfile")
  assert_present "$child_dir" "the git-root TMPDIR child did not create a fixture root"
  case "$child_dir" in
    "$repo"|"$repo"/*)
      fail "fm_test_tmproot placed a fixture root inside the git worktree root: $child_dir"
      ;;
  esac
  for entry in "$repo"/.fm-test-cleanup.* "$repo"/.fm-test-procevent.* "$repo"/.fm-test-watcher.*; do
    [ ! -e "$entry" ] || fail "a live test registry landed in the git worktree root: $entry"
  done
  kill -TERM "$pid"
  wait "$pid" 2>/dev/null || true
  assert_absent "$child_dir" \
    "the git-root TMPDIR child's fixture root survived SIGTERM"
  pass "test registries and fixture roots stay out of a git worktree TMPDIR"
}

test_remote_worker_cleanup_with_spaced_root() (
  local harness root sibling candidate pid i expected actual group worker sibling_worker
  local -a supervisors=() workers=()
  # A serving worker also runs its own readiness-heartbeat child, which carries
  # the worker's command line. Expect the supervisor, the serving process, and
  # exactly those of its direct children that discovery reports for this root.
  expected_worker_tree() { # <supervisor> <serving-pid> <code-root>
    local child
    printf '%s\n' "$1" "$2"
    for child in $(fm_test_remote_job_worker_pids "$3"); do
      [ "$(ps -o ppid= -p "$child" 2>/dev/null | tr -d '[:space:]')" = "$2" ] && printf '%s\n' "$child"
    done
  }
  harness=$(fm_test_tmproot fm-test-cleanup-remote-worker)
  root="$harness/test runs [*]/remote-root"
  sibling="$root-neighbor"
  # shellcheck source=bin/fm-remote-job-lib.sh
  . "$ROOT/bin/fm-remote-job-lib.sh"
  trap 'for pid in "${supervisors[@]:-}"; do
    [ -n "$pid" ] || continue
    fm_remote_job_stop_worker_tree "$pid" || true
    wait "$pid" 2>/dev/null || true
  done' EXIT
  export FM_REMOTE_JOB_PLATFORM_OVERRIDE=Linux

  for candidate in "$root" "$sibling"; do
    mkdir -p "$candidate/bin" "$candidate/account"
    cp "$ROOT/bin/fm-remote-job-lib.sh" "$ROOT/bin/fm-remote-job-worker.sh" "$candidate/bin/"
    printf 'fixture\n' > "$candidate/AGENTS.md"
    git -C "$candidate" init -q -b main
    git -C "$candidate" config user.email test@example.com
    git -C "$candidate" config user.name Test
    git -C "$candidate" add AGENTS.md bin
    git -C "$candidate" commit -qm 'remote worker cleanup fixture'
    export FM_REMOTE_JOB_STATE_ROOT="$candidate/remote-jobs"
    fm_remote_job_start_linux_worker "$candidate" "$candidate/account" \
      || fail "could not start the remote worker cleanup fixture"
    supervisors+=("$!")
    for ((i=0; i<100; i++)); do
      [ -s "$candidate/remote-jobs/worker.pid" ] && break
      sleep 0.05
    done
    [ -s "$candidate/remote-jobs/worker.pid" ] \
      || fail "the remote worker cleanup fixture never published its serving pid"
    workers+=("$(cat "$candidate/remote-jobs/worker.pid")")
  done

  worker=${workers[0]}
  sibling_worker=${workers[1]}
  expected=$(expected_worker_tree "${supervisors[0]}" "$worker" "$root" | sort -n)
  actual=$(fm_test_remote_job_worker_pids "$root" | sort -n)
  [ "$actual" = "$expected" ] \
    || fail "worker discovery missed the spaced-root supervisor or serving child, or included a sibling"
  group=$(fm_test_remote_job_worker_groups "$root")
  [ "$group" = "${supervisors[0]}" ] \
    || fail "worker group discovery missed the spaced-root tree"
  fm_test_stop_remote_job_workers "$root" \
    || fail "cleanup failed to stop the spaced-root worker tree"
  wait "${supervisors[0]}" 2>/dev/null || true
  ! ps -p "${supervisors[0]},$worker" -o stat= 2>/dev/null | grep -qv '^[[:space:]]*Z' \
    || fail "cleanup left a spaced-root worker process running"
  [ -z "$(fm_test_remote_job_worker_pids "$root")" ] \
    || fail "worker discovery still found a worker after cleanup"
  if ! kill -0 "${supervisors[1]}" || ! kill -0 "$sibling_worker"; then
    fail "cleanup stopped another fixture's worker"
  fi
  expected=$(expected_worker_tree "${supervisors[1]}" "$sibling_worker" "$sibling" | sort -n)
  [ "$(fm_test_remote_job_worker_pids "$sibling" | sort -n)" = "$expected" ] \
    || fail "cleanup disturbed the sibling worker tree"
  supervisors[0]=''
  fm_test_stop_remote_job_workers "$sibling" \
    || fail "cleanup failed to stop the sibling worker tree"
  wait "${supervisors[1]}" 2>/dev/null || true
  supervisors[1]=''
  pass "remote worker discovery and cleanup preserve spaced paths and exact fixture scope"
)

test_fixture_root_gone_after_normal_exit
test_fixture_root_gone_after_sigterm
test_cleanup_registry_resists_precreation
test_fixture_registration_failure_rolls_back_root
test_orphan_sweep_respects_fixture_ownership
test_orphan_sweep_reaps_read_only_package_tree
test_registries_avoid_git_worktree_root
test_remote_worker_cleanup_with_spaced_root || exit 1
