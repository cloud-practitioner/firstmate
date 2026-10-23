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
git -C "$TMP_ROOT/proj" init -q
git -C "$TMP_ROOT/proj" remote add origin https://github.com/o/r.git
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
  PATH="$FIX:$PATH" FM_HOME="$TMP_ROOT/home" FM_STATE_OVERRIDE="$TMP_ROOT/home/state" \
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
rm "$TMP_ROOT/home/state/zz-unreadable.meta"

printf 'proj ui components/*.jsx\n' >> "$TMP_ROOT/home/config/pr-evidence"
write_task capped https://github.com/o/r/pull/301 evidence=none
printf 'evidence_reason=Only a comment changed in the file.\n' >> "$TMP_ROOT/home/state/capped.meta"
printf '{"items":[]}\n' > "$TMP_ROOT/items.json"
jq -n '{key:"o/r/301",head:"0123456789abcdef0123456789abcdef01234567",files:([range(3000) | "docs/" + tostring + ".md"] + ["components/Button.jsx"])}' \
  | curl -fsS -X POST --data-binary @- "$STUB/_admin/pr" >/dev/null || fail 'could not seed the truncated collection'
for command in check publish; do
  if [ "$command" = check ]; then
    out=$(evidence check capped https://github.com/o/r/pull/301); rc=$?
  else
    out=$(evidence publish capped https://github.com/o/r/pull/301 "$TMP_ROOT/items.json"); rc=$?
  fi
  expect_code 1 "$rc" "$command must refuse GitHub's successful 3000-file truncation (got: $out)"
  assert_contains "$out" incomplete 'the missing file collection must be named'
done
assert_equals 0 "$(curl -fsS -X POST "$STUB/_admin/state" | jq '.comments["o/r/301"] | length')" 'an incomplete collection must not publish any comment'
jq -n '{key:"o/r/301",head:"0123456789abcdef0123456789abcdef01234567",files:[range(3000) | "docs/" + tostring + ".md"]}' \
  | curl -fsS -X POST --data-binary @- "$STUB/_admin/pr" >/dev/null || fail 'could not seed the complete collection'
out=$(evidence publish capped https://github.com/o/r/pull/301 "$TMP_ROOT/items.json"); rc=$?
expect_code 0 "$rc" "a complete collection at the cap must pass (got: $out)"
assert_contains "$out" '[PASS] evidence gate' 'the exact cap must not itself be a refusal'
curl -fsS -X POST --data '{"key":"o/r/301","head":"0123456789abcdef0123456789abcdef01234567","files":[{"filename":"docs/new.md","previous_filename":"components/old.jsx"}]}' "$STUB/_admin/pr" >/dev/null
out=$(evidence check capped https://github.com/o/r/pull/301); rc=$?
expect_code 1 "$rc" 'a rename must count as one file object and still enforce both paths'
assert_contains "$out" 'components/old.jsx' 'the rename source must remain part of pattern enforcement'
assert_not_contains "$out" incomplete 'rename expansion must happen after the file-object count check'
pass 'fm-pr-evidence: file count completeness is enforced before rename expansion and publication'

printf '# Task\n## Evidence class\nnone: The system will abandon the task.\n' > "$TMP_ROOT/brief.md"
out=$(evidence intake "$TMP_ROOT/brief.md" proj no-mistakes none "$TMP_ROOT/proj"); rc=$?
expect_code 0 "$rc" "intake must keep vocabulary warnings non-blocking (got: $out)"
assert_contains "$out" "word 'abandon' is not approved" 'production intake must always run shipped vocabulary warnings'
assert_contains "$out" 'evidence=none' 'warning-only intake must still emit the declaration'
printf '* enforce\nbanned abandon\n' > "$TMP_ROOT/home/config/pr-evidence"
out=$(evidence eligible proj no-mistakes none "$TMP_ROOT/proj"); rc=$?
expect_code 2 "$rc" 'the removed banned directive must be rejected'
assert_contains "$out" 'config/pr-evidence is not valid' 'custom word policy must not be accepted'
pass 'fm-pr-evidence: shipped vocabulary warnings always run and custom banned policy is refused'

out=$(evidence capture-ui --out "$TMP_ROOT/capture.txt" -- printf '%s\n' 'Authorization: Token opaque-secret' https://api.example/old); rc=$?
expect_code 0 "$rc" "capture must preserve command argument boundaries (got: $out)"
assert_contains "$(head -n 1 "$TMP_ROOT/capture.txt")" 'https://api.example/old' 'the masked command must retain its public operation'
assert_not_contains "$(< "$TMP_ROOT/capture.txt")" opaque-secret 'neither the command nor its output may expose credentials'
pass 'fm-pr-evidence: captured header arguments retain the public URL after redaction'
