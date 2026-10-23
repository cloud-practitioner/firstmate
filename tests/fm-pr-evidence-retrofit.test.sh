#!/usr/bin/env bash
set -u

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-pr-evidence-retrofit)
FIX="$ROOT/tests/fixtures/pr-evidence"
EV="$ROOT/bin/fm-pr-evidence.sh"
for tool in python3 jq curl; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is required for the retrofit test"
done
mkdir -p "$TMP_ROOT/images" "$TMP_ROOT/home/config" "$TMP_ROOT/home/state" "$TMP_ROOT/proj"
printf '* enforce\nbitbucket on\n' > "$TMP_ROOT/home/config/pr-evidence"
python3 "$FIX/stub-forge.py" "$TMP_ROOT/port" "$TMP_ROOT/images" > "$TMP_ROOT/server.log" 2>&1 &
STUB_PID=$!
cleanup() {
  kill "$STUB_PID" 2>/dev/null || true
  wait "$STUB_PID" 2>/dev/null || true
  fm_test_cleanup
}
trap cleanup EXIT
for _ in $(seq 1 50); do
  [ ! -s "$TMP_ROOT/port" ] || break
  sleep 0.1
done
[ -s "$TMP_ROOT/port" ] || fail 'the local forge did not start'
STUB="http://127.0.0.1:$(< "$TMP_ROOT/port")"

put_pr() {
  curl -fsS -X POST --data "$(jq -n --arg key "$1" --arg state "$2" \
    '{key:$key,state:$state,head:"0123456789abcdef0123456789abcdef01234567",files:[]}')" \
    "$STUB/_admin/pr" >/dev/null || fail 'could not seed the local PR state'
}
write_task() {
  fm_write_meta "$TMP_ROOT/home/state/$1.meta" "kind=ship" "mode=no-mistakes" \
    "project=$TMP_ROOT/proj" "pr=$2" "${3:-window=fm-$1}"
  chmod 0600 "$TMP_ROOT/home/state/$1.meta"
}
evidence() {
  FM_HOME="$TMP_ROOT/home" FM_STATE_OVERRIDE="$TMP_ROOT/home/state" \
    FM_CONFIG_OVERRIDE="$TMP_ROOT/home/config" FM_PR_EVIDENCE_GH="$FIX/gh" FM_TEST_STUB="$STUB" \
    FM_PR_EVIDENCE_BITBUCKET_API="$STUB/bb/2.0" \
    NO_MISTAKES_BITBUCKET_EMAIL=fixture@example.invalid NO_MISTAKES_BITBUCKET_API_TOKEN=fixture-token \
    "$EV" "$@" 2>&1
}

put_pr o/r/101 OPEN
put_pr o/r/102 CLOSED
put_pr ws/repo/201 OPEN
put_pr ws/repo/202 DECLINED
put_pr ws/repo/203 MERGED
write_task gh-open https://github.com/o/r/pull/101
write_task gh-closed https://github.com/o/r/pull/102
write_task bb-open https://bitbucket.org/ws/repo/pull-requests/201
write_task bb-declined https://bitbucket.org/ws/repo/pull-requests/202
write_task bb-merged https://bitbucket.org/ws/repo/pull-requests/203
write_task declared https://github.com/o/r/pull/101 evidence=ui
cp "$TMP_ROOT/home/state/gh-open.meta" "$TMP_ROOT/original.meta"

out=$(evidence list-unevidenced); rc=$?
expect_code 0 "$rc" "listing current open PRs (got: $out)"
assert_contains "$out" 'gh-open proj https://github.com/o/r/pull/101' 'an open GitHub PR must be listed'
assert_contains "$out" 'bb-open proj https://bitbucket.org/ws/repo/pull-requests/201' 'an open Bitbucket PR must be listed'
for excluded in gh-closed bb-declined bb-merged declared; do
  assert_not_contains "$out" "$excluded proj " 'closed PRs and declared tasks must not be retrofit candidates'
done

put_pr o/r/101 CLOSED
put_pr o/r/102 OPEN
put_pr ws/repo/201 MERGED
put_pr ws/repo/202 OPEN
out=$(evidence list-unevidenced); rc=$?
expect_code 0 "$rc" "listing must read fresh states (got: $out)"
assert_contains "$out" 'gh-closed proj https://github.com/o/r/pull/102' 'a reopened GitHub PR must now be listed'
assert_contains "$out" 'bb-declined proj https://bitbucket.org/ws/repo/pull-requests/202' 'a reopened Bitbucket PR must now be listed'
assert_not_contains "$out" 'gh-open proj ' 'a retained but now-closed GitHub PR must not be listed'
assert_not_contains "$out" 'bb-open proj ' 'a retained but now-merged Bitbucket PR must not be listed'
cmp -s "$TMP_ROOT/original.meta" "$TMP_ROOT/home/state/gh-open.meta" || fail 'listing must not rewrite task history'
out=$(evidence check gh-open https://github.com/o/r/pull/101); rc=$?
expect_code 0 "$rc" 'a task without evidence= must retain its accepted exception'
assert_contains "$out" 'predates it (no evidence=' 'the accepted missing-declaration notice must remain'

write_task zz-unreadable https://github.com/o/r/pull/999
out=$(evidence list-unevidenced); rc=$?
expect_code 1 "$rc" 'an unreadable PR state must make the list incomplete, not silently exclude it'
assert_contains "$out" 'current PR state cannot be read' 'a forge read failure must be reported'
rm "$TMP_ROOT/home/state/zz-unreadable.meta"
write_task zz-unreadable https://bitbucket.org/ws/repo/pull-requests/999
out=$(evidence list-unevidenced); rc=$?
expect_code 1 "$rc" 'a Bitbucket read failure must also refuse the list'
assert_contains "$out" 'current PR state cannot be read' 'a Bitbucket read failure must be reported'
pass 'fm-pr-evidence: retrofit listing reads current GitHub and Bitbucket states without changing the legacy exception'
