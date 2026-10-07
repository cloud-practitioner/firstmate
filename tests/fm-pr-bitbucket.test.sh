#!/usr/bin/env bash
# Tests for Bitbucket Cloud pull request support across the PR scripts: URL
# parsing in bin/fm-pr-lib.sh, recording and arming in bin/fm-pr-check.sh, the
# static merge poll in bin/fm-pr-poll.sh, state reads in bin/fm-pr-lib.sh and
# bin/fm-pr-state.sh, the guarded merge in bin/fm-pr-merge.sh, and the direct-PR
# worker's open, verify, and ready commands in bin/fm-pr-open.sh. The
# Bitbucket API is the stub tests/lib.sh's fm_fake_bitbucket_curl drops, so no
# case reaches the network; landed-work proof after a squash merge is covered by
# tests/fm-teardown.test.sh, which owns the teardown fixture.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fm_git_identity fmtest fmtest@example.invalid

TMP_ROOT=$(fm_test_tmproot fm-pr-bitbucket-tests)
command -v jq >/dev/null 2>&1 \
  || fail "these tests run the scripts' own jq programs over API-shaped JSON with the real jq, which was not found"

BB_PATH=iqxbusiness/supplier_online_orchestration_api
BB_URL="https://bitbucket.org/$BB_PATH/pull-requests/7"
BB_HEAD=c2eac54c17a1ddc2633ad51b83e21e5fe888142e
BB_ABBREV=${BB_HEAD:0:12}
BB_OTHER_HEAD=4dc2291e6969de1bf204fbdb53c9e57a8353d4e2
# A synthetic credential whose token carries both characters curl's config
# syntax must escape, so the escaping itself is under test.
BB_EMAIL=captain@example.invalid
BB_TOKEN='synthetic"tok\en-0123'
BB_EXPECT_USER='captain@example.invalid:synthetic\"tok\\en-0123'

# A sandbox for one case: task metadata, a worktree, a backlog for the
# captain-hold read, and a fakebin holding the Bitbucket API stub plus inert
# GitHub CLIs so nothing reaches a real forge. Echoes the case directory.
make_case() {
  local name=$1 case_dir fakebin
  case_dir="$TMP_ROOT/$name"
  fakebin="$case_dir/fakebin"
  mkdir -p "$case_dir/state" "$case_dir/home/data" "$case_dir/home/config" "$fakebin"
  fm_git_init_commit "$case_dir/wt"
  git -C "$case_dir/wt" update-ref refs/remotes/origin/main "$(git -C "$case_dir/wt" rev-parse HEAD)"
  cp "$ROOT/.tasks.toml" "$case_dir/home/.tasks.toml"
  printf '%s\n' '## In flight' '' '## Queued' '' '## Done' > "$case_dir/home/data/backlog.md"
  fm_write_meta "$case_dir/state/task-x1.meta" \
    "window=fm-task-x1" \
    "worktree=$case_dir/wt" \
    "project=$case_dir/project" \
    "kind=ship" \
    "mode=no-mistakes"
  fm_fake_exit0 "$fakebin" gh gh-axi glab
  fm_fake_bitbucket_curl "$fakebin" "$case_dir/bb"
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" > "$case_dir/bb/pr.json"
  fm_bitbucket_pr_json 7 MERGED "$BB_ABBREV" > "$case_dir/bb/pr-post.json"
  printf '{"hash":"%s"}\n' "$BB_HEAD" > "$case_dir/bb/commit.json"
  printf '%s\n' '{"values":[{"key":"pipeline","name":"Pipeline #1","state":"SUCCESSFUL"}],"pagelen":100,"page":1}' \
    > "$case_dir/bb/statuses.json"
  printf '%s\n' '{"values":[],"pagelen":100,"page":1}' > "$case_dir/bb/restrictions.json"
  printf '%s\n' '{"type":"pullrequest","id":7,"state":"MERGED"}' > "$case_dir/bb/merge.json"
  printf '%s\n' "$case_dir"
}

bb_env() {
  local case_dir=$1
  shift
  FM_ROOT_OVERRIDE="$ROOT" \
  FM_HOME="$case_dir/home" \
  FM_STATE_OVERRIDE="$case_dir/state" \
  HOME="$case_dir/user-home" \
  NO_MISTAKES_BITBUCKET_EMAIL="${FM_TEST_BB_EMAIL-$BB_EMAIL}" \
  NO_MISTAKES_BITBUCKET_API_TOKEN="${FM_TEST_BB_TOKEN-$BB_TOKEN}" \
  FM_TEST_BB_EXPECT_USER="$BB_EXPECT_USER" \
  FM_PR_BITBUCKET_CONFIRM_ATTEMPTS="${FM_PR_BITBUCKET_CONFIRM_ATTEMPTS:-2}" \
  FM_PR_BITBUCKET_CONFIRM_INTERVAL=0 \
  PATH="$case_dir/fakebin:$PATH" \
    "$@"
}

run_merge() {
  local case_dir=$1
  shift
  bb_env "$case_dir" "$ROOT/bin/fm-pr-merge.sh" task-x1 "$@" \
    > "$case_dir/stdout" 2> "$case_dir/stderr"
}

run_check() {
  local case_dir=$1
  bb_env "$case_dir" "$ROOT/bin/fm-pr-check.sh" task-x1 "$BB_URL" \
    > "$case_dir/stdout" 2> "$case_dir/stderr"
}

assert_token_never_in_argv() {
  local case_dir=$1 label=$2
  [ -s "$case_dir/bb/curl-argv.log" ] || fail "$label: the Bitbucket API was never called"
  if grep -qF 'synthetic' "$case_dir/bb/curl-argv.log"; then
    fail "$label: the API token reached a curl argument"
  fi
}

test_url_parse_accepts_canonical_bitbucket_urls() {
  local out
  out=$(bash -c '. "$1"; fm_pr_url_parse "$2" || exit 1
    printf "%s|%s|%s|%s|%s|%s\n" "$FM_PR_PROVIDER" "$FM_PR_HOST" "$FM_PR_PATH" "$FM_PR_NUMBER" "$FM_PR_OWNER" "$FM_PR_URL"' \
    _ "$ROOT/bin/fm-pr-lib.sh" "$BB_URL") || fail "the canonical Bitbucket URL did not parse"
  assert_equals "bitbucket|bitbucket.org|$BB_PATH|7||$BB_URL" "$out" \
    "a Bitbucket URL must parse into the provider-tagged identity with no GitHub owner"
  bash -c '. "$1"; fm_pr_url_parse "$2"' _ "$ROOT/bin/fm-pr-lib.sh" \
    'https://bitbucket.org/my-team_2/repo.name-x/pull-requests/12345' \
    || fail "a workspace and slug using every allowed character must parse"
  pass "canonical Bitbucket Cloud pull request URLs parse"
}

test_url_parse_refuses_malformed_bitbucket_urls() {
  local url
  for url in \
    "https://bitbucket.org/$BB_PATH/pull-requests/7/" \
    "https://bitbucket.org/$BB_PATH/pull-requests/7/overview" \
    "https://bitbucket.org/$BB_PATH/pull-requests/07" \
    "https://bitbucket.org/$BB_PATH/pull-requests/0" \
    "https://bitbucket.org/$BB_PATH/pull-requests/7?at=main" \
    "http://bitbucket.org/$BB_PATH/pull-requests/7" \
    "https://www.bitbucket.org/$BB_PATH/pull-requests/7" \
    'https://bitbucket.org/IQXBusiness/repo/pull-requests/7' \
    'https://bitbucket.org/ws/-repo/pull-requests/7' \
    'https://bitbucket.org/-ws/repo/pull-requests/7' \
    'https://bitbucket.org/ws/../pull-requests/7' \
    'https://bitbucket.org/ws/repo/extra/pull-requests/7' \
    'https://bitbucket.org/ws/pull-requests/7' \
    'https://bitbucket.org/ws/repo/pull/7' \
    'https://bitbucket.org/ws/repo/-/merge_requests/7' \
    'https://bitbucket.org/c/project/+/7' \
    'https://bitbucket.example/projects/P/repos/r/pull-requests/7'; do
    if bash -c '. "$1"; fm_pr_url_parse "$2"' _ "$ROOT/bin/fm-pr-lib.sh" "$url"; then
      fail "a malformed or non-Cloud Bitbucket URL parsed: $url"
    fi
  done
  pass "malformed Bitbucket URLs, other forges' shapes on bitbucket.org, and Data Center URLs are refused"
}

test_record_read_reports_state_and_merged() {
  local case_dir out
  case_dir=$(make_case record-read)
  # shellcheck disable=SC2016 # bash -c expands its own positional arguments.
  out=$(bb_env "$case_dir" bash -c '. "$1"; fm_pr_bitbucket_read_record "$2" 7 || exit 1
    printf "%s %s\n" "$FM_PR_RECORD_STATE" "$FM_PR_RECORD_MERGED"' _ "$ROOT/bin/fm-pr-lib.sh" "$BB_PATH") \
    || fail "record-read: an open pull request could not be read"
  assert_equals "OPEN false" "$out" "record-read: an open pull request must read as open and unmerged"
  cp "$case_dir/bb/pr-post.json" "$case_dir/bb/pr.json"
  # shellcheck disable=SC2016 # bash -c expands its own positional arguments.
  out=$(bb_env "$case_dir" bash -c '. "$1"; fm_pr_bitbucket_read_record "$2" 7 || exit 1
    printf "%s %s\n" "$FM_PR_RECORD_STATE" "$FM_PR_RECORD_MERGED"' _ "$ROOT/bin/fm-pr-lib.sh" "$BB_PATH") \
    || fail "record-read: a merged pull request could not be read"
  assert_equals "MERGED true" "$out" "record-read: a merged pull request must read as merged"
  fm_bitbucket_pr_json 8 MERGED "$BB_ABBREV" > "$case_dir/bb/pr.json"
  # shellcheck disable=SC2016 # bash -c expands its own positional arguments.
  if bb_env "$case_dir" bash -c '. "$1"; fm_pr_bitbucket_read_record "$2" 7' _ "$ROOT/bin/fm-pr-lib.sh" "$BB_PATH"; then
    fail "record-read: a record for another pull request was accepted"
  fi
  printf '401\n' > "$case_dir/bb/pr.code"
  # shellcheck disable=SC2016 # bash -c expands its own positional arguments.
  if bb_env "$case_dir" bash -c '. "$1"; fm_pr_bitbucket_read_record "$2" 7' _ "$ROOT/bin/fm-pr-lib.sh" "$BB_PATH"; then
    fail "record-read: an unauthorized answer was read as a state"
  fi
  assert_token_never_in_argv "$case_dir" record-read
  assert_grep "user = \"$BB_EXPECT_USER\"" "$case_dir/bb/curl-config.log" \
    "record-read: the credential was not handed to curl on stdin, escaped"
  pass "the Bitbucket record read reports state and merged, refuses another record, and keeps the token out of argv"
}

test_statuses_read_follows_pagination_only_under_the_api_base() {
  local case_dir out
  case_dir=$(make_case statuses-pages)
  printf '%s\n' "{\"values\":[{\"key\":\"a\",\"state\":\"SUCCESSFUL\"}],\"next\":\"https://api.bitbucket.org/2.0/repositories/$BB_PATH/commit/$BB_HEAD/statuses?pagelen=100&page=2\"}" \
    > "$case_dir/bb/statuses.json"
  printf '%s\n' '{"values":[{"key":"b","name":"B","state":"FAILED"}]}' > "$case_dir/bb/statuses-2.json"
  # shellcheck disable=SC2016 # bash -c expands its own positional arguments.
  out=$(bb_env "$case_dir" bash -c '. "$1"; fm_pr_bitbucket_read_statuses "$2" "$3" || exit 1
    printf "%s" "$FM_PR_BITBUCKET_VALUES" | jq -c "map(.key + \"=\" + .state)"' \
    _ "$ROOT/bin/fm-pr-lib.sh" "$BB_PATH" "$BB_HEAD") || fail "statuses-pages: a two-page status list could not be read"
  assert_equals '["a=SUCCESSFUL","b=FAILED"]' "$out" "statuses-pages: both pages must be read"
  printf '%s\n' '{"values":[],"next":"https://evil.example/2.0/steal?page=2"}' > "$case_dir/bb/statuses.json"
  # shellcheck disable=SC2016 # bash -c expands its own positional arguments.
  if bb_env "$case_dir" bash -c '. "$1"; fm_pr_bitbucket_read_statuses "$2" "$3"' \
    _ "$ROOT/bin/fm-pr-lib.sh" "$BB_PATH" "$BB_HEAD"; then
    fail "statuses-pages: a next link to another host was followed or ignored instead of refused"
  fi
  if grep -q 'evil.example' "$case_dir/bb/curl-argv.log"; then
    fail "statuses-pages: the credential was sent to the host a next link named"
  fi
  pass "the status read follows pagination and refuses a next link that leaves the API base"
}

test_check_records_full_head_and_arms_the_poll() {
  local case_dir rc=0
  case_dir=$(make_case check-arms)
  run_check "$case_dir" || rc=$?
  expect_code 0 "$rc" "check-arms: a ready Bitbucket pull request should arm"$'\n'"$(cat "$case_dir/stderr")"
  assert_grep "pr=$BB_URL" "$case_dir/state/task-x1.meta" "check-arms: pr= was not recorded"
  assert_grep "pr_head=$BB_HEAD" "$case_dir/state/task-x1.meta" \
    "check-arms: the abbreviated head was not recorded as the full resolved hash"
  assert_equals bitbucket "$(head -1 "$case_dir/state/task-x1.pr-poll")" \
    "check-arms: the poll sidecar is not tagged as a Bitbucket pull request"
  assert_present "$case_dir/state/task-x1.check.sh" "check-arms: no poll was armed"
  assert_token_never_in_argv "$case_dir" check-arms
  pass "fm-pr-check records a Bitbucket pull request with its full head and arms the poll"
}

test_check_refuses_a_draft() {
  local case_dir rc=0
  case_dir=$(make_case check-draft)
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" true > "$case_dir/bb/pr.json"
  run_check "$case_dir" || rc=$?
  expect_code 1 "$rc" "check-draft: a draft Bitbucket pull request must not arm"
  assert_grep 'is a draft pull request' "$case_dir/stderr" "check-draft: the refusal did not name the draft"
  assert_no_grep 'pr=' "$case_dir/state/task-x1.meta" "check-draft: a draft was recorded"
  assert_absent "$case_dir/state/task-x1.check.sh" "check-draft: a draft armed a poll"
  pass "fm-pr-check refuses a draft Bitbucket pull request"
}

test_check_refuses_without_the_credential() {
  local case_dir rc=0
  case_dir=$(make_case check-no-credential)
  FM_TEST_BB_TOKEN='' run_check "$case_dir" || rc=$?
  expect_code 1 "$rc" "check-no-credential: arming without the token must refuse"
  assert_grep 'requires the NO_MISTAKES_BITBUCKET_API_TOKEN environment variable' "$case_dir/stderr" \
    "check-no-credential: the refusal did not name the missing variable"
  assert_no_grep 'pr=' "$case_dir/state/task-x1.meta" "check-no-credential: the URL was recorded anyway"
  assert_absent "$case_dir/state/task-x1.check.sh" "check-no-credential: a poll was armed anyway"
  assert_absent "$case_dir/bb/curl-argv.log" "check-no-credential: the API was called without a credential"
  pass "fm-pr-check refuses a Bitbucket watch without the credential and names it"
}

test_poll_wakes_only_on_an_exact_merged_record() {
  local case_dir out
  case_dir=$(make_case poll)
  poll() {
    bb_env "$case_dir" "$ROOT/bin/fm-pr-poll.sh" --validated bitbucket "$1" bitbucket.org "$BB_PATH" 7
  }
  out=$(poll "$BB_URL")
  assert_equals '' "$out" "poll: an open pull request woke the poll"
  cp "$case_dir/bb/pr-post.json" "$case_dir/bb/pr.json"
  out=$(poll "$BB_URL")
  assert_equals merged "$out" "poll: a merged pull request did not wake the poll"
  out=$(poll "https://bitbucket.org/other/repo/pull-requests/7")
  assert_equals '' "$out" "poll: a URL that does not rebuild from the identity was polled"
  printf '500\n' > "$case_dir/bb/pr.code"
  out=$(poll "$BB_URL")
  assert_equals '' "$out" "poll: an error status woke the poll"
  rm -f "$case_dir/bb/pr.code"
  out=$(FM_TEST_BB_TOKEN='' poll "$BB_URL")
  assert_equals '' "$out" "poll: a poll without the credential woke"
  assert_token_never_in_argv "$case_dir" poll
  pass "the Bitbucket merge poll wakes only on the exact merged record and stays silent otherwise"
}

test_pr_state_reports_bitbucket_blockers() {
  local case_dir out participants
  case_dir=$(make_case pr-state)
  out=$(bb_env "$case_dir" "$ROOT/bin/fm-pr-state.sh" "$BB_URL") || fail "pr-state: a clean pull request errored"
  assert_equals '' "$out" "pr-state: a clean open pull request must print nothing"
  participants='[{"user":{"nickname":"reviewer1"},"role":"REVIEWER","approved":false,"state":"changes_requested"},{"user":{"nickname":"reviewer2"},"approved":true,"state":"approved"}]'
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" true main "$participants" > "$case_dir/bb/pr.json"
  printf '%s\n' '{"values":[{"key":"pipeline","state":"FAILED"},{"key":"lint","state":"SUCCESSFUL"},{"key":"deploy","state":"INPROGRESS"}]}' \
    > "$case_dir/bb/statuses.json"
  out=$(bb_env "$case_dir" "$ROOT/bin/fm-pr-state.sh" "$BB_URL") || fail "pr-state: a blocked pull request errored"
  assert_equals "DRAFT: pull request is not ready for review
CHECK: pipeline (FAILED)
CHECK: deploy (INPROGRESS)
REVIEW: reviewer1 CHANGES_REQUESTED" "$out" "pr-state: the Bitbucket blockers were not reported"
  printf '%s\n' '{"values":[]}' > "$case_dir/bb/statuses.json"
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" > "$case_dir/bb/pr.json"
  out=$(bb_env "$case_dir" "$ROOT/bin/fm-pr-state.sh" "$BB_URL") || fail "pr-state: an unbuilt pull request errored"
  assert_equals 'CHECKS: none reported yet' "$out" "pr-state: an unbuilt head was read as ready"
  cp "$case_dir/bb/pr-post.json" "$case_dir/bb/pr.json"
  out=$(bb_env "$case_dir" "$ROOT/bin/fm-pr-state.sh" "$BB_URL") || fail "pr-state: a merged pull request errored"
  assert_equals 'STATE: merged' "$out" "pr-state: a merged pull request must report only that"
  pass "fm-pr-state reports a Bitbucket pull request's state, draft, builds, and requested changes"
}

test_merge_succeeds_with_read_back_and_keeps_the_branch() {
  local case_dir rc=0
  case_dir=$(make_case merge-ok)
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 0 "$rc" "merge-ok: a green open pull request should merge"$'\n'"$(cat "$case_dir/stderr")"
  assert_equals '{"type":"pullrequest","close_source_branch":false}' "$(cat "$case_dir/bb/merge-body.json")" \
    "merge-ok: the merge request must keep the source branch and use the branch's own strategy"
  assert_grep "verified: $BB_URL is merged at the verified head $BB_HEAD" "$case_dir/stdout" \
    "merge-ok: the landed merge was not proven by reading it back"
  assert_grep "pr=$BB_URL" "$case_dir/state/task-x1.meta" "merge-ok: pr= was not recorded before merging"
  assert_present "$case_dir/state/task-x1.pr-poll-merge-notified" "merge-ok: the landed outcome was not recorded"
  assert_token_never_in_argv "$case_dir" merge-ok
  pass "fm-pr-merge merges a green Bitbucket pull request, keeps its branch, and proves the merge by reading it back"
}

test_merge_passes_a_requested_strategy() {
  local case_dir rc=0
  case_dir=$(make_case merge-squash)
  run_merge "$case_dir" "$BB_URL" -- --squash || rc=$?
  expect_code 0 "$rc" "merge-squash: a squash merge should merge"$'\n'"$(cat "$case_dir/stderr")"
  assert_equals '{"type":"pullrequest","close_source_branch":false,"merge_strategy":"squash"}' \
    "$(cat "$case_dir/bb/merge-body.json")" "merge-squash: the requested strategy was not sent"
  case_dir=$(make_case merge-rebase)
  rc=0
  run_merge "$case_dir" "$BB_URL" -- --rebase || rc=$?
  expect_code 0 "$rc" "merge-rebase: the shared --rebase spelling should merge"$'\n'"$(cat "$case_dir/stderr")"
  assert_equals '{"type":"pullrequest","close_source_branch":false,"merge_strategy":"rebase_fast_forward"}' \
    "$(cat "$case_dir/bb/merge-body.json")" "merge-rebase: --rebase was not sent as rebase_fast_forward"
  case_dir=$(make_case merge-delete-branch)
  rc=0
  run_merge "$case_dir" "$BB_URL" -- --delete-branch || rc=$?
  expect_code 1 "$rc" "merge-delete-branch: branch deletion without an attended override must refuse"
  assert_absent "$case_dir/bb/merge-called" "merge-delete-branch: a merge was requested anyway"
  rc=0
  run_merge "$case_dir" "$BB_URL" --attended-override -- --delete-branch || rc=$?
  expect_code 0 "$rc" "merge-delete-branch: an attended branch deletion should merge"$'\n'"$(cat "$case_dir/stderr")"
  assert_equals '{"type":"pullrequest","close_source_branch":true}' "$(cat "$case_dir/bb/merge-body.json")" \
    "merge-delete-branch: the attended deletion was not sent"
  case_dir=$(make_case merge-bad-arg)
  local arg
  for arg in --subject --fast-forward; do
    rc=0
    run_merge "$case_dir" "$BB_URL" -- "$arg" || rc=$?
    expect_code 1 "$rc" "merge-bad-arg: $arg has no Bitbucket meaning and must refuse"
    assert_grep "extra merge argument '$arg' does not apply to a Bitbucket pull request" "$case_dir/stderr" \
      "merge-bad-arg: the $arg refusal did not explain"
  done
  assert_absent "$case_dir/bb/merge-called" "merge-bad-arg: a merge was requested anyway"
  pass "fm-pr-merge sends a requested Bitbucket strategy and refuses arguments it cannot translate"
}

test_merge_refuses_red_and_unreported_required_builds() {
  local case_dir rc=0
  case_dir=$(make_case merge-red)
  printf '%s\n' '{"values":[{"key":"pipeline","state":"FAILED"},{"key":"deploy","state":"INPROGRESS"}]}' \
    > "$case_dir/bb/statuses.json"
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-red: a red pull request must not merge"
  assert_grep "build 'pipeline' is FAILED, not SUCCESSFUL" "$case_dir/stderr" "merge-red: the failed build was not named"
  assert_grep "build 'deploy' is INPROGRESS, not SUCCESSFUL" "$case_dir/stderr" "merge-red: the running build was not named"
  assert_absent "$case_dir/bb/merge-called" "merge-red: a merge was requested anyway"

  case_dir=$(make_case merge-required)
  printf '%s\n' '{"values":[{"kind":"require_passing_builds_to_merge","branch_match_kind":"glob","pattern":"ma*","value":2},{"kind":"require_passing_builds_to_merge","branch_match_kind":"glob","pattern":"release/*","value":5}]}' \
    > "$case_dir/bb/restrictions.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-required: a head short of the required builds must not merge"
  assert_grep "base branch main requires 2 successful builds, and 1 reported at head $BB_HEAD" "$case_dir/stderr" \
    "merge-required: the unmet required build count was not named"
  assert_absent "$case_dir/bb/merge-called" "merge-required: a merge was requested anyway"

  case_dir=$(make_case merge-required-model)
  printf '%s\n' '{"values":[{"kind":"require_passing_builds_to_merge","branch_match_kind":"branching_model","branch_type":"development","value":3}]}' \
    > "$case_dir/bb/restrictions.json"
  printf '%s\n' '{"development":{"name":"main","use_mainbranch":true,"branch":{"name":"main"}},"branch_types":[]}' \
    > "$case_dir/bb/model.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-required-model: a branching-model requirement must apply to its development branch"
  assert_grep "base branch main requires 3 successful builds" "$case_dir/stderr" \
    "merge-required-model: the branching-model requirement was not applied"

  # A named branch type matches by the branching model's own prefix for that
  # type: it applies to a destination under the prefix and to no other.
  local feature_model='{"development":{"name":"main","use_mainbranch":true,"branch":{"name":"main"}},"branch_types":[{"kind":"release","prefix":"release/"},{"kind":"feature","prefix":"feature/"}]}'
  case_dir=$(make_case merge-type-unmet)
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" false feature/login > "$case_dir/bb/pr.json"
  printf '%s\n' '{"values":[{"kind":"require_passing_builds_to_merge","branch_match_kind":"branching_model","branch_type":"feature","value":2}]}' \
    > "$case_dir/bb/restrictions.json"
  printf '%s\n' "$feature_model" > "$case_dir/bb/model.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-type-unmet: a named branch type requirement must apply under its prefix"
  assert_grep "base branch feature/login requires 2 successful builds, and 1 reported at head $BB_HEAD" "$case_dir/stderr" \
    "merge-type-unmet: the named branch type requirement was not applied"
  assert_absent "$case_dir/bb/merge-called" "merge-type-unmet: a merge was requested anyway"

  case_dir=$(make_case merge-type-met)
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" false feature/login > "$case_dir/bb/pr.json"
  printf '%s\n' '{"values":[{"kind":"require_passing_builds_to_merge","branch_match_kind":"branching_model","branch_type":"feature","value":1}]}' \
    > "$case_dir/bb/restrictions.json"
  printf '%s\n' "$feature_model" > "$case_dir/bb/model.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 0 "$rc" "merge-type-met: a met named branch type requirement must not refuse"$'\n'"$(cat "$case_dir/stderr")"
  assert_present "$case_dir/bb/merge-called" "merge-type-met: the eligible merge was not requested"

  case_dir=$(make_case merge-type-other-branch)
  printf '%s\n' '{"values":[{"kind":"require_passing_builds_to_merge","branch_match_kind":"branching_model","branch_type":"feature","value":3}]}' \
    > "$case_dir/bb/restrictions.json"
  printf '%s\n' "$feature_model" > "$case_dir/bb/model.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 0 "$rc" "merge-type-other-branch: a named branch type requirement must not apply outside its prefix"$'\n'"$(cat "$case_dir/stderr")"
  assert_present "$case_dir/bb/merge-called" "merge-type-other-branch: the eligible merge was not requested"

  case_dir=$(make_case merge-restrictions-unreadable)
  printf '%s\n' '{"type":"error","error":{"message":"Access denied"}}' > "$case_dir/bb/restrictions.json"
  printf '403\n' > "$case_dir/bb/restrictions.code"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-restrictions-unreadable: an unreadable restriction set must refuse"
  assert_grep "branch restrictions for base branch main could not be read (HTTP 403; reading them needs repository admin access), so an unmet merge check cannot be ruled out" \
    "$case_dir/stderr" "merge-restrictions-unreadable: the refusal did not name the missing read"
  assert_absent "$case_dir/bb/merge-called" "merge-restrictions-unreadable: a merge was requested anyway"
  pass "fm-pr-merge refuses red builds, an unmet required build count, and an unreadable restriction set"
}

test_merge_refuses_draft_closed_and_missing_credentials() {
  local case_dir rc=0
  case_dir=$(make_case merge-draft)
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" true > "$case_dir/bb/pr.json"
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-draft: a draft must not merge"
  assert_grep 'the pull request is a draft' "$case_dir/stderr" "merge-draft: the draft was not named"
  assert_absent "$case_dir/bb/merge-called" "merge-draft: a merge was requested anyway"

  case_dir=$(make_case merge-declined)
  fm_bitbucket_pr_json 7 DECLINED "$BB_ABBREV" > "$case_dir/bb/pr.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-declined: a declined pull request must not merge"
  assert_grep 'state is "DECLINED", not OPEN' "$case_dir/stderr" "merge-declined: the state was not named"

  case_dir=$(make_case merge-no-credential)
  rc=0
  FM_TEST_BB_EMAIL='' run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-no-credential: a merge without the credential must refuse"
  assert_grep 'requires the NO_MISTAKES_BITBUCKET_EMAIL environment variable' "$case_dir/stderr" \
    "merge-no-credential: the refusal did not name the missing variable"
  assert_no_grep 'pr=' "$case_dir/state/task-x1.meta" "merge-no-credential: state was recorded before the refusal"
  pass "fm-pr-merge refuses a draft, a closed pull request, and a missing credential"
}

test_merge_waivers_follow_the_attended_rules() {
  local case_dir rc=0
  case_dir=$(make_case merge-allow-red)
  printf '%s\n' '{"values":[{"key":"flaky","state":"FAILED"},{"key":"pipeline","state":"SUCCESSFUL"}]}' \
    > "$case_dir/bb/statuses.json"
  run_merge "$case_dir" "$BB_URL" --allow-red flaky || rc=$?
  expect_code 0 "$rc" "merge-allow-red: an attended waiver of the exact failed key should merge"$'\n'"$(cat "$case_dir/stderr")"
  assert_present "$case_dir/bb/merge-called" "merge-allow-red: the waived merge was not requested"

  case_dir=$(make_case merge-allow-red-other)
  printf '%s\n' '{"values":[{"key":"flaky","state":"FAILED"}]}' > "$case_dir/bb/statuses.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" --allow-red other || rc=$?
  expect_code 1 "$rc" "merge-allow-red-other: a waiver naming another key must not merge"
  assert_absent "$case_dir/bb/merge-called" "merge-allow-red-other: a merge was requested anyway"

  case_dir=$(make_case merge-allow-missing)
  rc=0
  run_merge "$case_dir" "$BB_URL" --allow-missing pipeline || rc=$?
  expect_code 2 "$rc" "merge-allow-missing: --allow-missing must be refused on Bitbucket"
  assert_grep 'does not apply to Bitbucket' "$case_dir/stderr" "merge-allow-missing: the refusal did not explain"

  case_dir=$(make_case merge-allow-red-away)
  printf '%s\n' '{"values":[{"key":"flaky","state":"FAILED"}]}' > "$case_dir/bb/statuses.json"
  FM_HOME="$case_dir/home" FM_STATE_OVERRIDE="$case_dir/state" \
    "$ROOT/bin/fm-afk-contract.sh" enter --words 'merge task-x1 when green' >/dev/null \
    || fail "merge-allow-red-away: could not write the away record"
  rc=0
  run_merge "$case_dir" "$BB_URL" --allow-red flaky || rc=$?
  expect_code 2 "$rc" "merge-allow-red-away: --allow-red must be refused while away"
  assert_grep '--allow-red is attended-only' "$case_dir/stderr" "merge-allow-red-away: the refusal did not explain"
  assert_absent "$case_dir/bb/merge-called" "merge-allow-red-away: a merge was requested anyway"
  pass "Bitbucket build waivers match the exact key, stay attended-only, and --allow-missing is refused"
}

test_merge_under_away_authority_is_synchronous_and_gated() {
  local case_dir rc=0
  case_dir=$(make_case merge-away)
  FM_HOME="$case_dir/home" FM_STATE_OVERRIDE="$case_dir/state" \
    "$ROOT/bin/fm-afk-contract.sh" enter --words 'merge task-x1 when green' >/dev/null \
    || fail "merge-away: could not write the away record"
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 0 "$rc" "merge-away: a green pull request should merge under away authority"$'\n'"$(cat "$case_dir/stderr")"
  assert_grep 'away' "$case_dir/state/task-x1.merge-authority" \
    "merge-away: the merge was not recorded under away authority"

  case_dir=$(make_case merge-away-red)
  FM_HOME="$case_dir/home" FM_STATE_OVERRIDE="$case_dir/state" \
    "$ROOT/bin/fm-afk-contract.sh" enter --words 'merge task-x1 when green' >/dev/null \
    || fail "merge-away-red: could not write the away record"
  printf '%s\n' '{"values":[{"key":"pipeline","state":"FAILED"}]}' > "$case_dir/bb/statuses.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-away-red: away authority must not merge a red pull request"
  assert_absent "$case_dir/bb/merge-called" "merge-away-red: a merge was requested anyway"
  pass "a Bitbucket merge under away authority stays synchronous, records that authority, and keeps the green gate"
}

test_merge_refuses_a_head_that_moved_before_the_request() {
  local case_dir rc=0
  case_dir=$(make_case merge-moved)
  fm_bitbucket_pr_json 7 OPEN "${BB_OTHER_HEAD:0:12}" > "$case_dir/bb/pr-moved.json"
  printf '{"hash":"%s"}\n' "$BB_OTHER_HEAD" > "$case_dir/bb/commit-${BB_OTHER_HEAD:0:12}.json"
  # Reads one and two are the recording and the verification; the third is the
  # final read inside the away-record lock, which is where the head has moved.
  printf '3\n' > "$case_dir/bb/pr-moved.at"
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-moved: a head that moved after verification must not merge"
  assert_grep 'changed after verification' "$case_dir/stderr" "merge-moved: the moved head was not reported"
  assert_grep 'nothing was merged' "$case_dir/stderr" "merge-moved: the refusal did not say nothing merged"
  assert_absent "$case_dir/bb/merge-called" "merge-moved: a merge was requested anyway"
  pass "fm-pr-merge re-reads the Bitbucket head immediately before merging and refuses a moved head"
}

test_merge_reports_forge_refusal_unconfirmed_and_wrong_head() {
  local case_dir rc=0
  case_dir=$(make_case merge-forge-refuses)
  printf '%s\n' '{"type":"error","error":{"message":"You can'"'"'t merge until you resolve all merge conflicts."}}' \
    > "$case_dir/bb/merge.json"
  printf '400\n' > "$case_dir/bb/merge.code"
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-forge-refuses: a refused merge request must fail"
  assert_grep 'Bitbucket refused the merge request' "$case_dir/stderr" "merge-forge-refuses: the refusal was not reported"
  assert_grep 'resolve all merge conflicts' "$case_dir/stderr" "merge-forge-refuses: Bitbucket's own reason was not quoted"
  assert_absent "$case_dir/state/task-x1.pr-poll-merge-notified" "merge-forge-refuses: a landed outcome was recorded"

  case_dir=$(make_case merge-unconfirmed)
  printf '202\n' > "$case_dir/bb/merge.code"
  rm -f "$case_dir/bb/pr-post.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 0 "$rc" "merge-unconfirmed: an accepted merge that has not landed yet must not fail the run"
  assert_grep 'landed state could not be confirmed; the merge poll remains armed' "$case_dir/stderr" \
    "merge-unconfirmed: the unconfirmed landing was not reported"
  assert_absent "$case_dir/state/task-x1.pr-poll-merge-notified" "merge-unconfirmed: an unproven merge was recorded as landed"
  assert_present "$case_dir/state/task-x1.check.sh" "merge-unconfirmed: the merge poll was not left armed"

  case_dir=$(make_case merge-wrong-head)
  fm_bitbucket_pr_json 7 MERGED "${BB_OTHER_HEAD:0:12}" > "$case_dir/bb/pr-post.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-wrong-head: a merge that landed another head must exit non-zero"
  assert_grep "reads back at head ${BB_OTHER_HEAD:0:12}, not the verified head $BB_HEAD" "$case_dir/stderr" \
    "merge-wrong-head: the unverified landed head was not reported"
  assert_present "$case_dir/state/task-x1.pr-poll-merge-notified" \
    "merge-wrong-head: the landed outcome must still be recorded"
  pass "fm-pr-merge quotes Bitbucket's refusal, leaves an unconfirmed merge armed, and flags a landed head it did not verify"
}

test_merge_refuses_unmet_review_merge_checks() {
  local case_dir rc=0 approved changes
  approved='[{"user":{"uuid":"{alice}","nickname":"alice"},"role":"REVIEWER","approved":true,"state":"approved"}]'
  changes='[{"user":{"uuid":"{bob}","nickname":"bob"},"role":"REVIEWER","approved":false,"state":"changes_requested"}]'

  case_dir=$(make_case merge-approvals)
  printf '%s\n' '{"values":[{"kind":"require_approvals_to_merge","branch_match_kind":"glob","pattern":"main","value":1},{"kind":"require_approvals_to_merge","branch_match_kind":"glob","pattern":"release/*","value":4},{"kind":"push","branch_match_kind":"glob","pattern":"main","users":[]}]}' \
    > "$case_dir/bb/restrictions.json"
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-approvals: a pull request short of the required approvals must not merge"
  assert_grep "base branch main requires 1 approvals, and the pull request has 0" "$case_dir/stderr" \
    "merge-approvals: the unmet approval count was not named"
  assert_absent "$case_dir/bb/merge-called" "merge-approvals: a merge was requested anyway"
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" false main "$approved" > "$case_dir/bb/pr.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 0 "$rc" "merge-approvals: an approved pull request should merge"$'\n'"$(cat "$case_dir/stderr")"

  case_dir=$(make_case merge-default-reviewers)
  printf '%s\n' '{"values":[{"kind":"require_default_reviewer_approvals_to_merge","branch_match_kind":"glob","pattern":"*","value":1}]}' \
    > "$case_dir/bb/restrictions.json"
  printf '%s\n' '{"values":[{"type":"default_reviewer","reviewer_type":"repository","user":{"uuid":"{carol}"}}]}' \
    > "$case_dir/bb/default-reviewers.json"
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" false main "$approved" > "$case_dir/bb/pr.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-default-reviewers: an approval from someone other than a default reviewer must not count"
  assert_grep "base branch main requires 1 approvals from default reviewers, and the pull request has 0" "$case_dir/stderr" \
    "merge-default-reviewers: the unmet default-reviewer approval count was not named"
  assert_absent "$case_dir/bb/merge-called" "merge-default-reviewers: a merge was requested anyway"
  printf '%s\n' '{"values":[{"type":"default_reviewer","reviewer_type":"repository","user":{"uuid":"{alice}"}}]}' \
    > "$case_dir/bb/default-reviewers.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 0 "$rc" "merge-default-reviewers: a default reviewer's approval should merge"$'\n'"$(cat "$case_dir/stderr")"

  case_dir=$(make_case merge-default-reviewers-unreadable)
  printf '%s\n' '{"values":[{"kind":"require_default_reviewer_approvals_to_merge","branch_match_kind":"glob","pattern":"main","value":1}]}' \
    > "$case_dir/bb/restrictions.json"
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" false main "$approved" > "$case_dir/bb/pr.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-default-reviewers-unreadable: unreadable default reviewers must refuse"
  assert_grep "the default reviewers for base branch main could not be read (HTTP 404)" "$case_dir/stderr" \
    "merge-default-reviewers-unreadable: the missing read was not named"

  case_dir=$(make_case merge-changes-requested)
  printf '%s\n' '{"values":[{"kind":"require_no_changes_requested","branch_match_kind":"branching_model","branch_type":"development","value":null}]}' \
    > "$case_dir/bb/restrictions.json"
  printf '%s\n' '{"development":{"name":"main","use_mainbranch":true,"branch":{"name":"main"}},"branch_types":[]}' \
    > "$case_dir/bb/model.json"
  fm_bitbucket_pr_json 7 OPEN "$BB_ABBREV" false main "$changes" > "$case_dir/bb/pr.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" --allow-red pipeline || rc=$?
  expect_code 1 "$rc" "merge-changes-requested: requested changes must not merge, and --allow-red must not waive them"
  assert_grep "base branch main requires no requested changes, and changes are requested by bob" "$case_dir/stderr" \
    "merge-changes-requested: the reviewer requesting changes was not named"
  assert_absent "$case_dir/bb/merge-called" "merge-changes-requested: a merge was requested anyway"

  case_dir=$(make_case merge-tasks)
  printf '%s\n' '{"values":[{"kind":"require_tasks_to_be_completed","branch_match_kind":"glob","pattern":"main"}]}' \
    > "$case_dir/bb/restrictions.json"
  printf '%s\n' '{"values":[{"id":1,"state":"RESOLVED"},{"id":2,"state":"UNRESOLVED"}]}' > "$case_dir/bb/tasks.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-tasks: an unresolved task must not merge"
  assert_grep "base branch main requires every task resolved, and 1 are unresolved" "$case_dir/stderr" \
    "merge-tasks: the unresolved task was not named"
  assert_absent "$case_dir/bb/merge-called" "merge-tasks: a merge was requested anyway"
  printf '%s\n' '{"values":[{"id":1,"state":"RESOLVED"}]}' > "$case_dir/bb/tasks.json"
  rc=0
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 0 "$rc" "merge-tasks: every task resolved should merge"$'\n'"$(cat "$case_dir/stderr")"
  pass "fm-pr-merge refuses a Bitbucket pull request that misses an approval, default-reviewer, changes-requested, or task merge check"
}

test_merge_reads_back_after_a_transport_failure() {
  local case_dir rc=0
  case_dir=$(make_case merge-transport)
  : > "$case_dir/bb/merge.transport-failure"
  run_merge "$case_dir" "$BB_URL" || rc=$?
  expect_code 1 "$rc" "merge-transport: a merge request with no HTTP response must fail"
  assert_grep "the merge request for $BB_URL got no HTTP response, and the pull request reads back as MERGED at head $BB_ABBREV; the merge poll remains armed" \
    "$case_dir/stderr" "merge-transport: the observed state was not read back and reported"
  assert_no_grep 'Bitbucket refused the merge request' "$case_dir/stderr" \
    "merge-transport: a transport failure was reported as a refusal"
  assert_absent "$case_dir/state/task-x1.pr-poll-merge-notified" "merge-transport: an unconfirmed merge was recorded as landed"
  assert_present "$case_dir/state/task-x1.check.sh" "merge-transport: the merge poll was not left armed"
  pass "fm-pr-merge reads a Bitbucket pull request back after its merge request got no response"
}

# A direct-PR worker's copy: a branch named like the stub's pull request source,
# with a Bitbucket origin that is only a name, so nothing is ever fetched or
# pushed. Its pull request fixture reports the copy's real HEAD.
make_open_case() {
  local name=$1 case_dir head
  case_dir=$(make_case "$name")
  git -C "$case_dir/wt" checkout -q -b fm/task-x1
  git -C "$case_dir/wt" remote add origin "git@bitbucket.org:$BB_PATH.git"
  head=$(git -C "$case_dir/wt" rev-parse HEAD)
  printf '%s\n' "$head" > "$case_dir/head"
  fm_bitbucket_pr_json 7 OPEN "$head" > "$case_dir/bb/pr.json"
  cp "$case_dir/bb/pr.json" "$case_dir/bb/create.json"
  printf '%s\n' '{"values":[],"pagelen":50,"page":1}' > "$case_dir/bb/prlist.json"
  printf '%s\n' "$case_dir"
}

run_open() {
  local case_dir=$1
  shift
  (cd "$case_dir/wt" && bb_env "$case_dir" "$ROOT/bin/fm-pr-open.sh" "$@") \
    > "$case_dir/stdout" 2> "$case_dir/stderr"
}

assert_token_never_in_output() {
  local case_dir=$1 label=$2
  assert_no_grep 'synthetic' "$case_dir/stdout" "$label: the token reached stdout"
  assert_no_grep 'synthetic' "$case_dir/stderr" "$label: the token reached stderr"
  assert_no_grep 'Authorization' "$case_dir/stdout" "$label: an auth header reached stdout"
  assert_no_grep 'authorization' "$case_dir/stdout" "$label: an auth header reached stdout"
  assert_no_grep 'Authorization' "$case_dir/stderr" "$label: an auth header reached stderr"
  assert_no_grep 'authorization' "$case_dir/stderr" "$label: an auth header reached stderr"
}

test_remote_path_names_only_bitbucket_cloud_repositories() {
  local url got
  for url in \
    "https://bitbucket.org/$BB_PATH.git" \
    "https://user:secret@bitbucket.org/$BB_PATH" \
    "https://captain@bitbucket.org/$BB_PATH.git/" \
    "ssh://git@bitbucket.org/$BB_PATH.git" \
    "ssh://git@bitbucket.org:22/$BB_PATH.git" \
    "ssh://git@bitbucket.org:7999/$BB_PATH.git" \
    "ssh://git@altssh.bitbucket.org:443/$BB_PATH.git" \
    "git@bitbucket.org:$BB_PATH.git" \
    "bitbucket.org:$BB_PATH" \
    'https://BitBucket.org/IQXBusiness/Supplier_Online_Orchestration_API.git'; do
    got=$(bash -c '. "$1"; fm_pr_bitbucket_remote_path "$2"' _ "$ROOT/bin/fm-pr-lib.sh" "$url") \
      || fail "a Bitbucket Cloud remote did not parse: ${url%%@*}"
    assert_equals "$BB_PATH" "$got" "a Bitbucket Cloud remote must name its workspace/repository"
    assert_not_contains "$got" secret "the remote's userinfo must never be printed"
  done
  for url in \
    'https://github.com/o/r.git' \
    'git@github.com:o/r.git' \
    'https://bitbucket.org.evil.example/ws/repo.git' \
    'https://evil.example/bitbucket.org/ws/repo.git' \
    'https://bitbucket.example/scm/p/r.git' \
    'ssh://git@bitbucket.org:invalid/ws/repo.git' \
    'ssh://git@bitbucket.org:/ws/repo.git' \
    'ssh://git@altssh.bitbucket.org:22/ws/repo.git' \
    'ssh://git@altssh.bitbucket.org:443.evil.example/ws/repo.git' \
    'http://bitbucket.org/ws/repo.git' \
    'https://bitbucket.org/ws' \
    'https://bitbucket.org/ws/repo/extra.git' \
    'https://bitbucket.org/ws/-repo.git' \
    '/srv/git/bitbucket.org/ws/repo.git' \
    ''; do
    if bash -c '. "$1"; fm_pr_bitbucket_remote_path "$2" >/dev/null' _ "$ROOT/bin/fm-pr-lib.sh" "$url"; then
      fail "a remote that is not a Bitbucket Cloud repository parsed: $url"
    fi
  done
  pass "a remote URL names a Bitbucket Cloud repository only when it is one, and never prints userinfo"
}

test_project_pr_host_follows_the_origin_remote() {
  local case_dir clone url
  case_dir=$(make_open_case pr-host)
  clone="$case_dir/wt"
  for url in \
    "https://bitbucket.org/$BB_PATH.git" \
    "git@bitbucket.org:$BB_PATH.git" \
    "ssh://git@bitbucket.org/$BB_PATH.git" \
    "ssh://git@bitbucket.org:22/$BB_PATH.git" \
    "ssh://git@altssh.bitbucket.org:443/$BB_PATH.git"; do
    git -C "$clone" remote set-url origin "$url"
    assert_equals bitbucket "$(bash -c '. "$1"; fm_pr_project_pr_host "$2"' _ "$ROOT/bin/fm-pr-lib.sh" "$clone")" \
      "a Bitbucket origin must select the Bitbucket contract: $url"
  done
  git -C "$clone" remote set-url origin https://github.com/o/r.git
  assert_equals github "$(bash -c '. "$1"; fm_pr_project_pr_host "$2"' _ "$ROOT/bin/fm-pr-lib.sh" "$clone")" \
    "a GitHub origin must keep the GitHub contract"
  git -C "$clone" remote remove origin
  assert_equals github "$(bash -c '. "$1"; fm_pr_project_pr_host "$2"' _ "$ROOT/bin/fm-pr-lib.sh" "$clone")" \
    "a clone with no origin must keep the GitHub contract"
  assert_equals github "$(bash -c '. "$1"; fm_pr_project_pr_host "$2"' _ "$ROOT/bin/fm-pr-lib.sh" "$case_dir/absent")" \
    "a missing clone must keep the GitHub contract"
  pass "the pull request forge follows the clone's origin remote and defaults to GitHub"
}

test_open_creates_a_non_draft_pull_request() {
  local case_dir rc=0 title description head
  case_dir=$(make_open_case open-create)
  title='Add the "thing"'
  description=$'Body with an apostrophe: it\'s ready.\nSecond line.'
  git -C "$case_dir/wt" commit -q --allow-empty -m "$title" -m "$description"
  head=$(git -C "$case_dir/wt" rev-parse HEAD)
  fm_bitbucket_pr_json 7 OPEN "$head" > "$case_dir/bb/pr.json"
  cp "$case_dir/bb/pr.json" "$case_dir/bb/create.json"
  run_open "$case_dir" open || rc=$?
  expect_code 0 "$rc" "open-create: opening a pull request should succeed"$'\n'"$(cat "$case_dir/stderr")"
  assert_equals "$BB_URL" "$(cat "$case_dir/stdout")" "open-create: stdout must be the pull request URL alone"
  assert_present "$case_dir/bb/create-called" "open-create: no pull request was created"
  assert_equals false "$(jq -r .draft "$case_dir/bb/create-body.json")" "open-create: the request must ask for a non-draft pull request"
  assert_equals fm/task-x1 "$(jq -r .source.branch.name "$case_dir/bb/create-body.json")" "open-create: the source branch was not the current branch"
  assert_equals "$title" "$(jq -r .title "$case_dir/bb/create-body.json")" "open-create: the title must be the commit subject"
  assert_equals "$description" "$(jq -r .description "$case_dir/bb/create-body.json")" "open-create: the description must be the commit body"
  assert_equals null "$(jq -r '.destination // null' "$case_dir/bb/create-body.json")" "open-create: Bitbucket must choose the default destination"
  assert_grep 'draft: no' "$case_dir/stderr" "open-create: the read-back was not reported"
  assert_token_never_in_argv "$case_dir" open-create
  assert_token_never_in_output "$case_dir" open-create
  pass "fm-pr-open open creates a non-draft pull request, reads it back, and prints its URL"
}

test_open_reuses_an_existing_pull_request() {
  local case_dir rc=0
  case_dir=$(make_open_case open-reuse)
  printf '{"values":[%s],"pagelen":50,"page":1}\n' "$(cat "$case_dir/bb/pr.json")" > "$case_dir/bb/prlist.json"
  run_open "$case_dir" open || rc=$?
  expect_code 0 "$rc" "open-reuse: an already-open pull request should be reused"$'\n'"$(cat "$case_dir/stderr")"
  assert_equals "$BB_URL" "$(cat "$case_dir/stdout")" "open-reuse: the existing pull request's URL was not printed"
  assert_absent "$case_dir/bb/create-called" "open-reuse: a duplicate pull request was created"

  pass "fm-pr-open open reuses an open pull request for the source branch instead of duplicating it"
}

test_draft_is_refused_by_open_and_repaired_by_ready() {
  local case_dir rc=0 head
  case_dir=$(make_open_case draft)
  head=$(cat "$case_dir/head")
  fm_bitbucket_pr_json 7 OPEN "$head" true > "$case_dir/bb/pr.json"
  printf '{"values":[%s],"pagelen":50,"page":1}\n' "$(cat "$case_dir/bb/pr.json")" > "$case_dir/bb/prlist.json"
  fm_bitbucket_pr_json 7 OPEN "$head" false > "$case_dir/bb/pr-ready.json"
  cp "$case_dir/bb/pr-ready.json" "$case_dir/bb/ready.json"

  run_open "$case_dir" open || rc=$?
  expect_code 1 "$rc" "draft: open must not report success for a draft"
  assert_grep 'is a draft' "$case_dir/stderr" "draft: the draft was not named"
  assert_grep "fm-pr-open.sh ready $BB_URL" "$case_dir/stderr" "draft: the repair command was not named"
  assert_absent "$case_dir/bb/ready-called" "draft: open changed a pull request it did not create"
  assert_absent "$case_dir/bb/create-called" "draft: open created a duplicate"

  rc=0
  run_open "$case_dir" verify "$BB_URL" || rc=$?
  expect_code 1 "$rc" "draft: verify must refuse a draft"
  assert_grep 'draft: yes' "$case_dir/stdout" "draft: verify did not report the draft"
  assert_absent "$case_dir/bb/ready-called" "draft: verify changed the pull request"

  rc=0
  run_open "$case_dir" ready "$BB_URL" || rc=$?
  expect_code 0 "$rc" "draft: ready should take the pull request out of draft"$'\n'"$(cat "$case_dir/stderr")"
  assert_equals '{"draft":false}' "$(cat "$case_dir/bb/ready-body.json")" "draft: ready sent more than the draft flag"
  assert_grep 'draft: no' "$case_dir/stdout" "draft: ready did not read back a non-draft pull request"

  # An API that creates a draft despite the request is caught by the read-back.
  case_dir=$(make_open_case draft-created)
  fm_bitbucket_pr_json 7 OPEN "$(cat "$case_dir/head")" true > "$case_dir/bb/pr.json"
  rc=0
  run_open "$case_dir" open || rc=$?
  expect_code 1 "$rc" "draft-created: a pull request created as a draft must fail the read-back"
  assert_grep 'is a draft' "$case_dir/stderr" "draft-created: the read-back did not name the draft"
  pass "fm-pr-open refuses a draft, never flips one implicitly, and ready repairs it with a read-back"
}

test_verify_checks_state_branch_and_head() {
  local case_dir rc=0 head
  case_dir=$(make_open_case verify)
  head=$(cat "$case_dir/head")
  printf '{"values":[%s],"pagelen":50,"page":1}\n' "$(cat "$case_dir/bb/pr.json")" > "$case_dir/bb/prlist.json"

  run_open "$case_dir" verify "$BB_URL" || rc=$?
  expect_code 0 "$rc" "verify: an open, ready pull request at HEAD should verify"$'\n'"$(cat "$case_dir/stderr")"
  assert_grep 'state: open' "$case_dir/stdout" "verify: the state was not printed"
  assert_grep 'draft: no' "$case_dir/stdout" "verify: draft: no was not printed"
  assert_grep "head: $head" "$case_dir/stdout" "verify: the head was not printed"
  assert_grep "url: $BB_URL" "$case_dir/stdout" "verify: the URL was not printed"

  fm_bitbucket_pr_json 7 OPEN "$BB_OTHER_HEAD" > "$case_dir/bb/pr.json"
  rc=0
  run_open "$case_dir" verify "$BB_URL" || rc=$?
  expect_code 1 "$rc" "verify: a pull request not at this HEAD must refuse"
  assert_grep "so push your latest commit" "$case_dir/stderr" "verify: the unpushed commit was not named"

  fm_bitbucket_pr_json 7 MERGED "$head" > "$case_dir/bb/pr.json"
  rc=0
  run_open "$case_dir" verify "$BB_URL" || rc=$?
  expect_code 1 "$rc" "verify: a merged pull request must refuse"
  assert_grep 'is MERGED, not open' "$case_dir/stderr" "verify: the state was not named"

  fm_bitbucket_pr_json 7 OPEN "$head" | jq '.source.branch.name = "other-branch"' > "$case_dir/bb/pr.json"
  rc=0
  run_open "$case_dir" verify "$BB_URL" || rc=$?
  expect_code 1 "$rc" "verify: a wrong source branch must refuse"
  assert_grep 'has source branch other-branch, not fm/task-x1' "$case_dir/stderr" "verify: the source branch was not named"

  pass "fm-pr-open verify exits zero only for an open, ready pull request from the branch at HEAD"
}

test_open_never_leaks_credentials() {
  local case_dir rc=0
  case_dir=$(make_open_case cred-missing)
  FM_TEST_BB_EMAIL='' run_open "$case_dir" open || rc=$?
  expect_code 1 "$rc" "cred-missing: a missing email must refuse"
  assert_grep 'requires the NO_MISTAKES_BITBUCKET_EMAIL environment variable' "$case_dir/stderr" \
    "cred-missing: the missing variable was not named"
  assert_no_grep 'NO_MISTAKES_BITBUCKET_API_TOKEN' "$case_dir/stderr" "cred-missing: a present variable was named as missing"
  assert_token_never_in_output "$case_dir" cred-missing
  assert_no_grep "$BB_EMAIL" "$case_dir/stderr" "cred-missing: the email value was printed"
  assert_absent "$case_dir/bb/curl-argv.log" "cred-missing: the API was called without a credential"

  rc=0
  FM_TEST_BB_EMAIL='' FM_TEST_BB_TOKEN='' run_open "$case_dir" open || rc=$?
  expect_code 1 "$rc" "cred-missing: both missing must refuse"
  assert_grep 'NO_MISTAKES_BITBUCKET_EMAIL environment variable, the NO_MISTAKES_BITBUCKET_API_TOKEN environment variable' \
    "$case_dir/stderr" "cred-missing: both variable names were not reported"

  case_dir=$(make_open_case cred-rejected)
  rc=0
  FM_TEST_BB_TOKEN='synthetic-wrong-token' run_open "$case_dir" open || rc=$?
  expect_code 1 "$rc" "cred-rejected: a refused credential must fail"
  assert_grep 'Bitbucket answered HTTP 401 (Unauthorized)' "$case_dir/stderr" "cred-rejected: the refusal was not reported"
  assert_no_grep 'synthetic-wrong-token' "$case_dir/stderr" "cred-rejected: the rejected token was printed"
  assert_no_grep 'synthetic-wrong-token' "$case_dir/stdout" "cred-rejected: the rejected token was printed"
  assert_no_grep 'synthetic-wrong-token' "$case_dir/bb/curl-argv.log" "cred-rejected: the token reached a curl argument"
  assert_absent "$case_dir/bb/create-called" "cred-rejected: a pull request was created without a valid credential"
  pass "fm-pr-open names missing credentials by variable only and never prints the token or an auth header"
}

test_open_accepts_supported_bitbucket_origins() {
  local case_dir url rc i=0
  for url in \
    "https://bitbucket.org/$BB_PATH.git" \
    "git@bitbucket.org:$BB_PATH.git" \
    "ssh://git@bitbucket.org/$BB_PATH.git" \
    "ssh://git@bitbucket.org:22/$BB_PATH.git" \
    "ssh://git@altssh.bitbucket.org:443/$BB_PATH.git"; do
    i=$((i + 1))
    case_dir=$(make_open_case "origin-supported-$i")
    git -C "$case_dir/wt" remote set-url origin "$url"
    rc=0
    run_open "$case_dir" open || rc=$?
    expect_code 0 "$rc" "origin-supported: open must accept $url"$'\n'"$(cat "$case_dir/stderr")"
    assert_equals "$BB_URL" "$(cat "$case_dir/stdout")" "origin-supported: the URL was not printed"
  done
  pass "fm-pr-open accepts every supported Bitbucket Cloud origin form"
}

test_commands_require_current_bitbucket_context() {
  local case_dir cmd context rc
  for cmd in open verify ready; do
    for context in non-bitbucket no-origin detached other-repository; do
      [ "$cmd:$context" != open:other-repository ] || continue
      case_dir=$(make_open_case "context-$cmd-$context")
      case "$context" in
        non-bitbucket) git -C "$case_dir/wt" remote set-url origin https://user:synthetic-secret@github.com/o/r.git ;;
        no-origin) git -C "$case_dir/wt" remote remove origin ;;
        detached) git -C "$case_dir/wt" checkout -q --detach HEAD ;;
        other-repository) git -C "$case_dir/wt" remote set-url origin git@bitbucket.org:other/repository.git ;;
      esac
      rc=0
      if [ "$cmd" = open ]; then
        run_open "$case_dir" "$cmd" || rc=$?
      else
        run_open "$case_dir" "$cmd" "$BB_URL" || rc=$?
      fi
      expect_code 1 "$rc" "context-$cmd-$context: an invalid current context must refuse"
      case "$context" in
        non-bitbucket) assert_grep 'origin remote is not a Bitbucket Cloud repository' "$case_dir/stderr" "context: the origin refusal was not explained" ;;
        no-origin) assert_grep 'has no origin remote' "$case_dir/stderr" "context: the absent origin was not named" ;;
        detached) assert_grep 'detached HEAD' "$case_dir/stderr" "context: detached HEAD was not named" ;;
        other-repository) assert_grep 'does not name this work tree' "$case_dir/stderr" "context: URL repository mismatch was not named" ;;
      esac
      assert_absent "$case_dir/bb/curl-argv.log" "context: invalid local context reached the API"
      assert_token_never_in_output "$case_dir" context
    done
  done
  pass "all fm-pr-open commands require the current branch and Bitbucket origin, and URLs must match it"
}

test_verify_and_ready_require_a_url() {
  local case_dir cmd rc
  case_dir=$(make_open_case url-required)
  for cmd in verify ready; do
    rc=0
    run_open "$case_dir" "$cmd" || rc=$?
    expect_code 2 "$rc" "$cmd: omitting the URL must be a usage error"
    assert_grep "$cmd requires the pull request URL" "$case_dir/stderr" "$cmd: the required URL was not named"
    assert_absent "$case_dir/bb/curl-argv.log" "$cmd: URL-less verification reached the API"
  done
  pass "verify and ready require an explicit pull request URL"
}

test_discovery_distinguishes_forks_from_the_origin() {
  local case_dir head rc own_url query draft
  case_dir=$(make_open_case discovery-fork)
  head=$(cat "$case_dir/head")
  own_url="https://bitbucket.org/$BB_PATH/pull-requests/8"
  fm_bitbucket_pr_json 8 OPEN "$head" > "$case_dir/bb/pr.json"
  for draft in false true; do
    fm_bitbucket_pr_json 7 OPEN "$head" "$draft" | jq '
      .source.repository.full_name = "fork/repository"' > "$case_dir/bb/pr-7.json"
    jq --slurpfile fork "$case_dir/bb/pr-7.json" '{values: [$fork[0], .]}' \
      "$case_dir/bb/pr.json" > "$case_dir/bb/prlist.json"
    rc=0
    run_open "$case_dir" open || rc=$?
    expect_code 0 "$rc" "discovery-fork: the origin PR must win over an older same-branch fork PR"$'\n'"$(cat "$case_dir/stderr")"
    assert_equals "$own_url" "$(cat "$case_dir/stdout")" "discovery-fork: the wrong PR was selected"
    assert_absent "$case_dir/bb/create-called" "discovery-fork: a duplicate PR was created"
    assert_absent "$case_dir/bb/ready-called" "discovery-fork: the fork PR was updated"
  done
  query=$(jq -rn --arg r "$BB_PATH" '"source.repository.full_name=" + ($r | tojson) | @uri')
  assert_grep "$query" "$case_dir/bb/curl-argv.log" "discovery-fork: the API query did not constrain the source repository"

  case_dir=$(make_open_case discovery-fork-only)
  fm_bitbucket_pr_json 7 OPEN "$(cat "$case_dir/head")" | jq '
    .source.repository.full_name = "fork/repository" | {values: [.]}' > "$case_dir/bb/prlist.json"
  rc=0
  run_open "$case_dir" open || rc=$?
  expect_code 0 "$rc" "discovery-fork-only: a fork PR must not block creating the origin PR"
  assert_present "$case_dir/bb/create-called" "discovery-fork-only: the origin PR was not created"
  assert_equals "$BB_URL" "$(cat "$case_dir/stdout")" "discovery-fork-only: the created PR URL was not printed"
  pass "open discovers only PRs from the origin repository and current branch"
}

test_read_back_enforces_source_identity_before_accepting_or_updating() {
  local case_dir action mismatch transform rc draft
  for action in open-reuse open-create verify ready; do
    for mismatch in fork missing-repository other-branch; do
      case_dir=$(make_open_case "identity-$action-$mismatch")
      if [ "$action" = open-reuse ]; then
        jq '{values: [.]}' "$case_dir/bb/pr.json" > "$case_dir/bb/prlist.json"
      fi
      case "$mismatch" in
        fork) transform='.source.repository.full_name = "fork/repository"' ;;
        missing-repository) transform='del(.source.repository)' ;;
        other-branch) transform='.source.branch.name = "other-branch"' ;;
      esac
      draft=false
      [ "$action" != ready ] || draft=true
      fm_bitbucket_pr_json 7 OPEN "$(cat "$case_dir/head")" "$draft" | jq "$transform" > "$case_dir/bb/pr.json"
      rc=0
      case "$action" in
        open-*) run_open "$case_dir" open || rc=$? ;;
        *) run_open "$case_dir" "$action" "$BB_URL" || rc=$? ;;
      esac
      expect_code 1 "$rc" "identity-$action-$mismatch: accepting another source must refuse"
      if [ "$mismatch" = other-branch ]; then
        assert_grep 'has source branch other-branch' "$case_dir/stderr" "identity: the branch mismatch was not named"
      else
        assert_grep 'does not come from this work tree' "$case_dir/stderr" "identity: the repository mismatch was not named"
      fi
      assert_absent "$case_dir/bb/ready-called" "identity: another source was updated"
      assert_no_grep 'fm-pr-open.sh ready' "$case_dir/stderr" "identity: another source received a draft-repair suggestion"
      [ ! -s "$case_dir/stdout" ] || fail "identity: another source was reported as the worker PR"
    done
  done
  pass "reuse, creation read-back, verify, and ready reject foreign source identities before acceptance or update"
}

test_open_recovers_a_missing_creation_id_by_reopening() {
  local case_dir rc=0
  case_dir=$(make_open_case create-id-missing)
  printf '%s\n' '{}' > "$case_dir/bb/create.json"
  run_open "$case_dir" open || rc=$?
  expect_code 1 "$rc" "create-id-missing: a missing creation ID must refuse"
  assert_grep 'run fm-pr-open.sh open again' "$case_dir/stderr" "create-id-missing: idempotent open recovery was not named"
  jq '{values: [.]}' "$case_dir/bb/pr.json" > "$case_dir/bb/prlist.json"
  rm "$case_dir/bb/create-called"
  rc=0
  run_open "$case_dir" open || rc=$?
  expect_code 0 "$rc" "create-id-missing: reopening must discover the existing PR"
  assert_equals "$BB_URL" "$(cat "$case_dir/stdout")" "create-id-missing: the recovered PR URL was not printed"
  assert_absent "$case_dir/bb/create-called" "create-id-missing: recovery created a duplicate"
  pass "open recovers an accepted creation with no usable ID by discovering the existing PR"
}

test_url_parse_accepts_canonical_bitbucket_urls
test_url_parse_refuses_malformed_bitbucket_urls
test_record_read_reports_state_and_merged
test_statuses_read_follows_pagination_only_under_the_api_base
test_check_records_full_head_and_arms_the_poll
test_check_refuses_a_draft
test_check_refuses_without_the_credential
test_poll_wakes_only_on_an_exact_merged_record
test_pr_state_reports_bitbucket_blockers
test_merge_succeeds_with_read_back_and_keeps_the_branch
test_merge_passes_a_requested_strategy
test_merge_refuses_red_and_unreported_required_builds
test_merge_refuses_draft_closed_and_missing_credentials
test_merge_waivers_follow_the_attended_rules
test_merge_under_away_authority_is_synchronous_and_gated
test_merge_refuses_a_head_that_moved_before_the_request
test_merge_reports_forge_refusal_unconfirmed_and_wrong_head
test_merge_refuses_unmet_review_merge_checks
test_merge_reads_back_after_a_transport_failure
test_remote_path_names_only_bitbucket_cloud_repositories
test_project_pr_host_follows_the_origin_remote
test_open_creates_a_non_draft_pull_request
test_open_reuses_an_existing_pull_request
test_draft_is_refused_by_open_and_repaired_by_ready
test_verify_checks_state_branch_and_head
test_open_never_leaks_credentials
test_open_accepts_supported_bitbucket_origins
test_commands_require_current_bitbucket_context
test_verify_and_ready_require_a_url
test_discovery_distinguishes_forks_from_the_origin
test_read_back_enforces_source_identity_before_accepting_or_updating
test_open_recovers_a_missing_creation_id_by_reopening
