#!/usr/bin/env bash
# Behavior tests for the fork-only PR evidence gate (bin/fm-pr-evidence.sh and
# bin/fm-pr-evidence-lib.py). A local stub forge (tests/fixtures/pr-evidence)
# serves GitHub comments with rendered HTML, an image server, and Bitbucket
# comments with a Downloads redirect, so every case runs with no network.
# The stub copies the one forge behaviour the gate exists for: an image line
# right after a closing </details> line renders no <img> (fork PRs 35 and 38).
# The opt-in live guard at the end proves real upload, display, and fetch against
# a private sandbox repository when FM_PR_EVIDENCE_LIVE_PR names a PR in it.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

EV="$ROOT/bin/fm-pr-evidence.sh"
LIB="$ROOT/bin/fm-pr-evidence-lib.py"
PR_CHECK="$ROOT/bin/fm-pr-check.sh"
PR_MERGE="$ROOT/bin/fm-pr-merge.sh"
FIX="$ROOT/tests/fixtures/pr-evidence"
TMP_ROOT=$(fm_test_tmproot fm-pr-evidence)
fm_git_identity fmtest fmtest@example.invalid

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not found"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "skip: jq not found"; exit 0; }
command -v curl >/dev/null 2>&1 || { echo "skip: curl not found"; exit 0; }

LIVE_PR=${FM_PR_EVIDENCE_LIVE_PR:-}
LIVE_GH_TOKEN=${GH_TOKEN:-}
LIVE_GITHUB_TOKEN=${GITHUB_TOKEN:-}
LIVE_GH=${FM_PR_EVIDENCE_GH:-}
export -n LIVE_GH_TOKEN LIVE_GITHUB_TOKEN LIVE_GH

# Keep ambient identity and credentials out of every case.
unset FM_BACKEND FM_HOME FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_CONFIG_OVERRIDE HERDR_PANE_ID HERDR_SESSION \
  NO_MISTAKES_BITBUCKET_EMAIL NO_MISTAKES_BITBUCKET_API_TOKEN GH_TOKEN GITHUB_TOKEN FM_PR_EVIDENCE_GH \
  FM_PR_EVIDENCE_BITBUCKET_API FM_PR_EVIDENCE_LIVE_PR

PYTHONDONTWRITEBYTECODE=1 TMPDIR="$TMP_ROOT" python3 "$ROOT/tests/fm-pr-evidence-regressions.test.py" || fail "the Python evidence regressions failed"

mkdir -p "$TMP_ROOT/img"
STUB_PID=
(python3 "$FIX/stub-forge.py" "$TMP_ROOT/port" "$TMP_ROOT/img" >/dev/null 2>&1 & echo $! > "$TMP_ROOT/stub.pid")
for _ in $(seq 1 50); do
  [ -s "$TMP_ROOT/port" ] && break
  sleep 0.1
done
[ -s "$TMP_ROOT/port" ] || fail "the stub forge did not start"
STUB_PID=$(cat "$TMP_ROOT/stub.pid")
STUB="http://127.0.0.1:$(cat "$TMP_ROOT/port")"
stop_stub() { [ -z "$STUB_PID" ] || kill "$STUB_PID" 2>/dev/null || true; }
trap 'stop_stub; fm_test_cleanup' EXIT

HEAD1=0123456789abcdef0123456789abcdef01234567
HEAD2=fedcba9876543210fedcba9876543210fedcba98
PRN=100

# ---- helpers ---------------------------------------------------------------

stub_post() {  # <path> <json>
  curl -sS -X POST --data "$2" "$STUB$1" >/dev/null
}

# new_case <name> [config-line...]: sets C (case dir) and PRKEY, PRURL.
new_case() {
  local name=$1
  shift
  C="$TMP_ROOT/$name"
  mkdir -p "$C/home/state" "$C/home/config" "$C/home/data" "$C/proj" "$C/ev"
  fm_test_tasks_toml "$C/home/.tasks.toml"
  git -C "$C/proj" init -q
  git -C "$C/proj" commit -q --allow-empty -m "fixture $name"
  git -C "$C/proj" remote add origin https://github.com/o/r.git
  # A readable code-root history lets the publication gate tell this project is not firstmate itself.
  mkdir -p "$C/root"
  git -C "$C/root" init -q
  git -C "$C/root" commit -q --allow-empty -m "code root fixture $name"
  if [ "$#" -gt 0 ]; then printf '%s\n' "$@" > "$C/home/config/pr-evidence"; else echo '* enforce' > "$C/home/config/pr-evidence"; fi
  PRN=$((PRN + 1))
  PRKEY="o/r/$PRN"
  PRURL="https://github.com/o/r/pull/$PRN"
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"files\":[\"bin/tool.sh\"]}"
}

write_task() {  # <id> <evidence> [extra meta line...]
  local id=$1 evidence=$2
  shift 2
  fm_write_meta "$C/home/state/$id.meta" "window=fm-$id" "endpoint_task_id=$id" "project=$C/proj" "kind=ship" \
    "mode=no-mistakes" ${evidence:+"evidence=$evidence"} "$@"
}

ev() {  # <args...> - run the gate script in the case home
  FM_HOME="$C/home" FM_TEST_STUB="$STUB" FM_PR_EVIDENCE_GH="$FIX/gh" PATH="$FIX:$PATH" "$EV" "$@" 2>&1
}

png() {  # <out> <seed> <marks>
  python3 "$FIX/mkpng.py" "$1" "$2" "$3"
}

annotation_records() {
  python3 - "$1" <<'PY'
import hashlib, json, pathlib, sys
items_path = pathlib.Path(sys.argv[1])
for item in json.loads(items_path.read_text())["items"]:
    for phase in ("before", "after"):
        image = items_path.parent / item[phase]["image"]
        record = {"sha256": hashlib.sha256(image.read_bytes()).hexdigest(),
                  "purpose": item["purpose"], "labels": item["labels"]}
        pathlib.Path(str(image) + ".annotation.json").write_text(json.dumps(record))
PY
}

poll_valid() {
  (
    . "$ROOT/bin/fm-pr-lib.sh"
    fm_pr_poll_artifacts_valid "$C/home/state" t1 "$ROOT/bin/fm-pr-poll.sh"
  )
}

ui_items() {  # writes $C/ev/items.json with one ui item of marked images
  png "$C/ev/b.png" 1 400
  png "$C/ev/a.png" 2 400
  cat > "$C/ev/items.json" <<'EOF'
{"items":[{"id":"cli","kind":"ui","purpose":"The tool printed old text. Now it prints new text.","before":{"image":"b.png"},"after":{"image":"a.png"},"labels":["Text changed"]}]}
EOF
  annotation_records "$C/ev/items.json"
}

api_sidecars() {
  cat > "$C/ev/b.json" <<'EOF'
{"v":1,"request":{"method":"GET","url":"https://api.example/items","headers":[["Accept","application/json"],["Authorization","***masked (40 chars)***"]],"body":""},"response":{"status":500,"reason":"Internal Server Error","headers":[["Content-Type","application/json"]],"body":"{\"error\":\"boom\"}"}}
EOF
  sed 's/500/200/;s/Internal Server Error/OK/;s/boom/fine/' "$C/ev/b.json" > "$C/ev/a.json"
}

uiapi_items() {
  ui_items
  api_sidecars
  png "$C/ev/ba.png" 3 400
  png "$C/ev/aa.png" 4 400
  cat > "$C/ev/items.json" <<'EOF'
{"items":[{"id":"cli","kind":"ui","purpose":"The tool printed old text. Now it prints new text.","before":{"image":"b.png"},"after":{"image":"a.png"},"labels":["Text changed"]},
{"id":"api","kind":"api","purpose":"The API returned HTTP 500. Now it returns HTTP 200.","before":{"image":"ba.png","sidecar":"b.json"},"after":{"image":"aa.png","sidecar":"a.json"},"labels":["Status changed"]}]}
EOF
  annotation_records "$C/ev/items.json"
}

published() {  # publish the case's items and require a pass
  local out
  out=$(ev publish t1 "$PRURL" "$C/ev/items.json") || fail "publish failed in $C: $out"
  assert_contains "$out" "[PASS] evidence gate" "publish did not end with the gate passing"
}

comments_json() {
  curl -sS -X POST "$STUB/_admin/state" | jq -c ".comments[\"$PRKEY\"]"
}

# tamper <python-statement-on-m>: edit the newest comment's manifest in place.
tamper() {
  # Read the growing forge state over HTTP, not through a size-limited env value.
  PRKEY=$PRKEY STUB=$STUB python3 - "$1" <<'PY'
import json, os, re, sys, urllib.request
req = urllib.request.Request(os.environ["STUB"] + "/_admin/state", data=b"")
with urllib.request.urlopen(req) as response:
    state = json.load(response)
c = state["comments"][os.environ["PRKEY"]][-1]
m_re = re.compile(r"(```fm-pr-evidence-v1\n)(.*?)(\n```)", re.S)
mo = m_re.search(c["body"])
m = json.loads(mo.group(2))
exec(sys.argv[1])
body = c["body"][:mo.start(2)] + json.dumps(m, indent=2, sort_keys=True) + c["body"][mo.end(2):]
req = urllib.request.Request(os.environ["STUB"] + "/_admin/replace", data=json.dumps(
    {"key": os.environ["PRKEY"], "id": c["id"], "body": body, "html": c["html"]}).encode())
urllib.request.urlopen(req).read()
PY
}

# ---- tests -----------------------------------------------------------------

test_gate_is_off_without_config_and_config_is_strict() {
  local out rc
  new_case off
  rm -f "$C/home/config/pr-evidence"
  write_task t1 ui
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 0 "$rc" "check without config"
  [ -z "$out" ] || fail "an off gate printed output: $out"
  ev eligible proj no-mistakes none "$C/proj" >/dev/null && fail "an absent config must be ineligible"
  printf '%s\n' '* enforce' 'proj off' > "$C/home/config/pr-evidence"
  out=$(ev eligible proj no-mistakes none "$C/proj"); rc=$?
  expect_code 2 "$rc" "a project off line must be rejected"
  assert_contains "$out" "config/pr-evidence is not valid" "off must not bypass enforcement"
  printf '%s\n' '* enforce' > "$C/home/config/pr-evidence"
  ev eligible other no-mistakes none "$C/proj" >/dev/null || fail "'* enforce' must enable other projects"
  printf '%s\n' '* enforce' 'proj frobnicate x' > "$C/home/config/pr-evidence"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "invalid config line"
  assert_contains "$out" "config/pr-evidence is not valid" "an invalid config line must be named"
  pass "fm-pr-evidence: off without config; config lines are strict; project off is refused"
}

test_intake_declares_the_kind() {
  local out rc brief
  new_case intake
  brief="$C/brief.md"
  fill() { printf '# Task\n## Captain'\''s intent\nx\n\n## Firstmate spec\ny\n\n## Evidence class\n%s\n\n# Definition of done\nz\n' "$1" > "$brief"; }
  fill '{EVIDENCE}'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj"); rc=$?
  expect_code 1 "$rc" "unfilled placeholder"
  assert_contains "$out" "is not filled" "the unfilled class must be refused"
  fill 'ui'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj")
  assert_equals "evidence=ui" "$out" "ui class"
  fill 'api+ui'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj"); rc=$?
  expect_code 1 "$rc" "api+ui is not a canonical declaration"
  fill 'ui+api'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj")
  assert_equals "evidence=ui+api" "$out" "ui+api is accepted"
  fill 'none: The change only fixes a typo in a comment.'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj")
  assert_contains "$out" "evidence=none" "none with a plain reason"
  assert_contains "$out" "evidence_reason=The change only fixes a typo in a comment." "the reason is recorded"
  fill 'none:'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj"); rc=$?
  expect_code 1 "$rc" "none without a reason"
  fill 'none: It does not matter; skip it.'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj"); rc=$?
  expect_code 1 "$rc" "none with a semicolon reason (plain-English refuse rule)"
  assert_contains "$out" "semicolon" "the plain-English refusal must say why"
  fill 'sideways'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj"); rc=$?
  expect_code 1 "$rc" "invalid class"
  printf '# Task\n## Captain'\''s intent\nx\n\n## Firstmate spec\ny\n' > "$brief"
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj"); rc=$?
  expect_code 1 "$rc" "missing subsection while the gate is on"
  assert_contains "$out" "has no '## Evidence class'" "a missing subsection must be named"
  # Call 5: a require line and the firstmate repository itself never allow none.
  printf '%s\n' '* enforce' 'proj require' > "$C/home/config/pr-evidence"
  fill 'none: Only a comment changed in the file.'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj"); rc=$?
  expect_code 1 "$rc" "none on a require project"
  assert_contains "$out" "always needs evidence" "the require refusal must say why"
  fill 'ui'
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj")
  assert_equals "evidence=ui" "$out" "ui stays allowed on a require project"
  echo '* enforce' > "$C/home/config/pr-evidence"
  fill 'none: Only a comment changed in the file.'
  out=$(FM_ROOT_OVERRIDE="$C/proj" ev intake "$brief" firstmate no-mistakes none "$C/proj"); rc=$?
  expect_code 1 "$rc" "none on the firstmate repository"
  assert_contains "$out" "always needs evidence" "the firstmate repository never allows none"
  # An off gate prints nothing and records nothing.
  rm -f "$C/home/config/pr-evidence"
  out=$(ev intake "$brief" proj no-mistakes none "$C/proj"); rc=$?
  expect_code 0 "$rc" "intake without config"
  [ -z "$out" ] || fail "intake without config printed output"
  pass "fm-pr-evidence: intake validates the declared kind, the none reason, and the require rule"
}

test_publish_posts_one_comment_that_passes_the_gate() {
  local out n
  new_case happy
  write_task t1 ui+api
  uiapi_items
  published
  out=$(comments_json)
  assert_equals 1 "$(printf '%s' "$out" | jq 'length')" "publish must post exactly one comment"
  assert_contains "$(printf '%s' "$out" | jq -r '.[0].body')" '```fm-pr-evidence-v1' "the comment must carry the manifest"
  assert_contains "$(printf '%s' "$out" | jq -r '.[0].body')" "fm-pr-evidence-sidecar api before" "the comment must carry the API exchange text"
  n=$(printf '%s' "$out" | jq -r '.[0].html' | grep -c '<img ')
  assert_equals 4 "$n" "all four images must show on the rendered page"
  # Publishing again keeps one comment (the older one is removed).
  published
  assert_equals 1 "$(comments_json | jq 'length')" "a second publish must leave one comment"
  stub_post /_admin/comment "$(comments_json | jq -c --arg k "$PRKEY" '.[0] | {key:$k,author:"captain",body:.body,html:.html}')"
  published
  assert_equals 2 "$(comments_json | jq 'length')" "cleanup must preserve another account's comment"
  assert_equals captain "$(comments_json | jq -r '.[0].user.login')" "cleanup may delete only PR-author comments"
  out=$(ev check t1 "$PRURL"); rc=$?
  assert_contains "$out" "[PASS]" "the gate must pass on a published PR"
  pass "fm-pr-evidence: publish posts one comment whose images show, and the gate passes it"
}

test_head_drift_author_and_missing_comment_refuse() {
  local out rc
  new_case drift
  write_task t1 ui
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "no comment"
  assert_contains "$out" "[FAIL] no evidence comment" "a PR with no evidence must refuse"
  assert_contains "$out" "FIX: run fm-pr-evidence.sh publish" "the refusal must carry a FIX line"
  ui_items
  published
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD2\",\"files\":[\"bin/tool.sh\"]}"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "head drift"
  assert_contains "$out" "the PR changed after the evidence" "a moved head must ask for a new publish"
  # A new head with new evidence passes again.
  published
  # A manifest comment from another account is ignored: author filter.
  new_case author
  write_task t1 ui
  ui_items
  published
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"author\":\"actual-worker\",\"files\":[]}"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "a fake manifest by another account"
  assert_contains "$out" "no evidence comment by actual-worker" "only the PR author may hold the evidence"
  pass "fm-pr-evidence: a missing comment, a moved head, and a stranger's comment all refuse with FIX lines"
}

test_images_that_do_not_display_refuse() {
  local out rc body html
  new_case details
  write_task t1 ui
  ui_items
  published
  # The fork PR 35 and 38 shape: the image lines follow a closing details line.
  body=$(comments_json | jq -r '.[0].body')
  body=$(printf '%s' "$body" | python3 -c '
import re, sys
b = sys.stdin.read()
b = re.sub(r"(\*\*Before\*\*\n\n)(!\[[^\n]*\n)", r"<details><summary>x</summary>\n\ntext\n\n</details>\n\2", b)
b = re.sub(r"(\*\*After\*\*\n\n)(!\[[^\n]*\n)", r"<details><summary>y</summary>\n\ntext\n\n</details>\n\2", b)
sys.stdout.write(b)')
  html=$(comments_json | jq -c '.[0].html')
  stub_post /_admin/replace "$(jq -n --arg k "$PRKEY" --arg id "$(comments_json | jq -r '.[0].id')" --arg b "$body" --arg h "" '{key:$k,id:$id,body:$b,html:$h}')"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "images the page does not show"
  assert_contains "$out" "only 0 show on the PR page" "uploaded but not displayed must refuse"
  assert_contains "$out" "closing </details> line" "the FIX line must name the </details> cause"
  : "$html"
  # The layout publish writes never puts an image after a details block: the real
  # publish path through the stub's renderer shows every image.
  new_case details-ok
  write_task t1 ui+api
  uiapi_items
  published
  pass "fm-pr-evidence: an image line after </details> refuses; publish writes a layout that shows"
}

test_broken_or_swapped_images_refuse() {
  local out rc id
  new_case swap
  write_task t1 ui
  ui_items
  published
  tamper 'm["items"][0]["after"]["sha256"] = "0" * 64'
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "a hash that does not match the shown image"
  assert_contains "$out" "does not match its hash" "a swapped image must refuse"
  new_case missing-image
  write_task t1 ui
  ui_items
  published
  id=$(comments_json | jq -r '.[0].id')
  stub_post /_admin/replace "$(jq -n --arg k "$PRKEY" --arg id "$id" --argjson c "$(comments_json | jq '.[0]')" \
    '{key:$k,id:$id,body:$c.body,html:($c.html | gsub("/img/[0-9a-f]+\\.png"; "/img/gone.png"))}')"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "a shown image that 404s"
  assert_contains "$out" "did not load as an image" "an image that does not fetch must refuse"
  new_case same
  write_task t1 ui
  ui_items
  published
  tamper 'm["items"][0]["after"]["sha256"] = m["items"][0]["before"]["sha256"]'
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "before equal to after"
  assert_contains "$out" "same file" "identical before and after must refuse"
  pass "fm-pr-evidence: a swapped, missing, or identical image refuses"
}

test_marks_must_be_drawn() {
  local out rc
  new_case nomarks
  write_task t1 ui
  ui_items
  png "$C/ev/a.png" 2 0
  out=$(FM_PR_EVIDENCE_MARK_MIN=0 ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
  expect_code 1 "$rc" "publish with an unmarked image even with a threshold environment override"
  assert_contains "$out" "has no drawn marks" "publish must refuse an unmarked image"
  assert_equals 0 "$(comments_json | jq 'length')" "a refused publish must post nothing"
  # The gate re-checks the shown bytes, so an unmarked image slipped into the comment refuses too.
  ui_items
  published
  out=$(python3 "$LIB" marks "$C/ev/a.png" --min 200); rc=$?
  expect_code 0 "$rc" "a marked image must count"
  png "$C/ev/plain.png" 9 0
  out=$(python3 "$LIB" marks "$C/ev/plain.png"); rc=$?
  expect_code 1 "$rc" "an unmarked image must fail the marks check"
  : "$out"
  pass "fm-pr-evidence: images without drawn marks are refused at publish and by the mark counter"
}

test_annotation_records_are_required_and_bound() {
  local out rc index phase image record defect expected original
  new_case annotation-records
  write_task t1 ui+api
  uiapi_items
  for index in 0 1; do
    for phase in before after; do
      image=$(jq -r --argjson i "$index" --arg p "$phase" '.items[$i][$p].image' "$C/ev/items.json")
      record="$C/ev/$image.annotation.json"
      cp "$record" "$C/record.json"
      for defect in missing stale empty invalid; do
        case "$defect" in
          missing) rm "$record"; expected="has no annotation record" ;;
          stale) jq '.sha256 = ("0" * 64)' "$C/record.json" > "$record"; expected="annotation does not match its image" ;;
          empty) jq '.purpose = ""' "$C/record.json" > "$record"; expected="text is empty" ;;
          invalid) printf 'not JSON\n' > "$record"; expected="has no annotation record" ;;
        esac
        out=$(ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
        expect_code 1 "$rc" "$image with $defect annotation must refuse composition"
        assert_contains "$out" "$expected" "composition must name the annotation defect"
        assert_equals 0 "$(comments_json | jq 'length')" "an annotation refusal must post nothing"
        cp "$C/record.json" "$record"
      done
    done
  done
  published
  original=$(comments_json | jq -c --arg k "$PRKEY" '.[0] | {key:$k,id:.id,body:.body,html:.html}')
  for index in 0 1; do
    for phase in before after; do
      for defect in missing stale empty invalid; do
        stub_post /_admin/replace "$original"
        case "$defect" in
          missing) tamper "del m['items'][$index]['$phase']['annotation']"; expected="has no annotation record" ;;
          stale) tamper "m['items'][$index]['$phase']['annotation']['sha256'] = '0' * 64"; expected="annotation does not match its image" ;;
          empty) tamper "m['items'][$index]['$phase']['annotation']['purpose'] = ''"; expected="text is empty" ;;
          invalid) tamper "m['items'][$index]['$phase']['annotation'] = []"; expected="has no annotation record" ;;
        esac
        out=$(ev check t1 "$PRURL"); rc=$?
        expect_code 1 "$rc" "item $index $phase with $defect annotation must refuse verification"
        assert_contains "$out" "$expected" "verification must name the annotation defect"
      done
    done
  done
  stub_post /_admin/replace "$original"
  out=$(ev check t1 "$PRURL") || fail "valid annotation records must pass verification: $out"
  pass "fm-pr-evidence: each UI and API phase requires a purpose record bound to its image"
}

test_publish_refuses_invalid_replacement_metadata() {
  local out rc
  new_case invalid-publish-meta
  write_task t1 ui "pr=$PRURL" "pr_head=$HEAD1" 'unexpected=tail'
  ui_items
  cp "$C/home/state/t1.meta" "$C/original.meta"
  out=$(ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
  expect_code 1 "$rc" "publication must validate replacement PR metadata"
  assert_contains "$out" "replacement task metadata is not valid" "invalid metadata must refuse"
  cmp -s "$C/original.meta" "$C/home/state/t1.meta" || fail "invalid replacement must leave task metadata unchanged"
  assert_absent "$C/home/state/.meta-t1.lock" "a refused replacement must release the metadata lock"
  pass "fm-pr-evidence: invalid replacement metadata is not saved"
}

test_api_exchange_needs_all_parts_and_masked_secrets() {
  local out rc
  new_case api
  write_task t1 api
  uiapi_items
  # Drop the UI item: this case declares api only.
  jq 'del(.items[0])' "$C/ev/items.json" > "$C/ev/api-items.json"
  jq 'del(.response.reason)' "$C/ev/b.json" > "$C/ev/b2.json"
  jq '.items[0].before.sidecar = "b2.json"' "$C/ev/api-items.json" > "$C/ev/bad.json"
  out=$(ev publish t1 "$PRURL" "$C/ev/bad.json"); rc=$?
  expect_code 1 "$rc" "an exchange with no status message"
  assert_contains "$out" "response status message is missing" "a missing HTTP part must be named"
  jq '.request.headers[1][1] = "Bearer abcdefghijklmnop1234"' "$C/ev/b.json" > "$C/ev/b3.json"
  jq '.items[0].before.sidecar = "b3.json"' "$C/ev/api-items.json" > "$C/ev/bad.json"
  out=$(ev publish t1 "$PRURL" "$C/ev/bad.json"); rc=$?
  expect_code 1 "$rc" "an exchange with an unmasked Authorization"
  assert_contains "$out" "header Authorization holds a secret value" "an unmasked secret header must refuse"
  jq '.response.body = "{\"token\":\"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abcdefghijklmnop\"}"' "$C/ev/b.json" > "$C/ev/b4.json"
  jq '.items[0].before.sidecar = "b4.json"' "$C/ev/api-items.json" > "$C/ev/bad.json"
  out=$(ev publish t1 "$PRURL" "$C/ev/bad.json"); rc=$?
  expect_code 1 "$rc" "an exchange with a JWT in the body"
  assert_contains "$out" "secret-shaped value is visible" "a secret in the body must refuse"
  out=$(ev publish t1 "$PRURL" "$C/ev/api-items.json") || fail "a complete masked exchange must publish: $out"
  # Tamper with the sidecar text in the posted comment: its hash no longer matches.
  tamper 'm["items"][0]["before"]["sidecar_sha256"] = "1" * 64'
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "a sidecar that does not match its hash"
  assert_contains "$out" "HTTP exchange text does not match its hash" "the exchange text is bound by hash"
  pass "fm-pr-evidence: API evidence needs all six parts, masked secrets, and a bound exchange text"
}

test_capture_api_masks_and_keeps_six_parts() {
  local out rc
  new_case capture
  out=$(ev capture-api --out "$C/ev/cap.json" --header 'Authorization: Bearer ghp_abcdefghijklmnopqrstuvwxyz0123456789' \
    --header 'Cookie: session=abcdef' --header 'Accept: application/json' "$STUB/gh/user"); rc=$?
  expect_code 0 "$rc" "capture-api (got: $out)"
  assert_equals 200 "$(jq -r .response.status "$C/ev/cap.json")" "status code kept"
  assert_equals OK "$(jq -r .response.reason "$C/ev/cap.json")" "status message kept"
  assert_contains "$(jq -r '.request.headers[] | join(": ")' "$C/ev/cap.json")" "Accept: application/json" "an allowed header stays visible"
  assert_contains "$(jq -r '.request.headers[] | join(": ")' "$C/ev/cap.json")" "Authorization: ***masked (" "Authorization is masked, name kept"
  assert_contains "$(jq -r '.request.headers[] | join(": ")' "$C/ev/cap.json")" "Cookie: ***masked (" "Cookie is masked"
  assert_no_grep "ghp_abcdefghijkl" "$C/ev/cap.json" "the token must not reach the sidecar"
  assert_contains "$(jq -r '.response.body' "$C/ev/cap.json")" '"login"' "response body kept"
  [ -n "$(jq -r '.response.headers[0][0]' "$C/ev/cap.json")" ] || fail "response headers kept"
  jq -e '.request | has("body")' "$C/ev/cap.json" >/dev/null || fail "request body part kept"
  out=$(python3 "$LIB" scan-sidecar "$C/ev/cap.json") || fail "a captured exchange must pass its own scan: $out"
  out=$(printf 'token=ghp_abcdefghijklmnopqrstuvwxyz0123456789 x\nplain text\n' | python3 "$LIB" mask --stdin)
  assert_contains "$out" "token=***masked (" "the text masker hides a token"
  assert_contains "$out" "plain text" "the text masker keeps plain text"
  out=$(printf 'https://github.com/example-org/some-long-repository-name/pull/2 aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5bC7dE9fG1hJ3k\n' | python3 "$LIB" mask --stdin)
  assert_contains "$out" "https://github.com/example-org/some-long-repository-name/pull/2" "a long path of plain words is not a token"
  assert_contains "$out" "***masked (" "a long random run is still masked"
  pass "fm-pr-evidence: capture-api keeps the six HTTP parts and masks secrets"
}

test_declared_kind_and_changed_files_must_agree() {
  local out rc
  new_case globs '* enforce' 'proj ui bin/*.sh' 'proj api srv/*.cds'
  write_task t1 api
  ui_items
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"files\":[\"bin/tool.sh\",\"srv/a.cds\"]}"
  jq '.items[0].kind = "api" | .items[0].before.sidecar = "b.json" | .items[0].after.sidecar = "a.json"' "$C/ev/items.json" > "$C/ev/api.json"
  api_sidecars
  out=$(ev publish t1 "$PRURL" "$C/ev/api.json"); rc=$?
  expect_code 1 "$rc" "ui files with an api-only declaration (publish ends with the gate)"
  assert_contains "$out" "match the ui patterns but the declared kind is api: bin/tool.sh" "the disagreeing file must be named"
  # none with a matching glob refuses too (declared none cannot hide changed UI files).
  write_task t1 'none' 'evidence_reason=Only a comment changed in the file.'
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "none with matching files"
  assert_contains "$out" "bin/tool.sh" "none must not hide matching files"
  # Adding a kind is allowed: declared ui+api with both items passes.
  new_case globs-ok '* enforce' 'proj ui bin/*.sh'
  write_task t1 ui+api
  uiapi_items
  published
  pass "fm-pr-evidence: file patterns add kinds, and a disagreement refuses naming the files"
}

test_none_still_posts_a_visible_reason() {
  local out rc
  new_case none
  write_task t1 none 'evidence_reason=Only a comment changed in the file.'
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "none with no comment"
  printf '{"items":[]}\n' > "$C/ev/items.json"
  published
  assert_contains "$(comments_json | jq -r '.[0].body')" "No UI or API surface changed. Reason: Only a comment changed in the file." \
    "none must show its reason on the PR"
  pass "fm-pr-evidence: none still posts a visible reason that the gate requires"
}

test_plain_english_refuse_and_warn() {
  local out rc
  new_case ste
  out=$(python3 "$LIB" ste --text "The Save button stays grey after you type a name. You cannot save the form."); rc=$?
  expect_code 0 "$rc" "plain text passes"
  out=$(python3 "$LIB" ste --text "The tool wasn't shown; it's seamless, e.g. robust — and long."); rc=$?
  expect_code 1 "$rc" "refuse rules"
  assert_contains "$out" "semicolon" "semicolon refused"
  assert_contains "$out" "contraction 'wasn't'" "contraction refused"
  assert_contains "$out" "abbreviation 'e.g.'" "abbreviation refused"
  assert_contains "$out" "long dash" "em dash refused"
  assert_contains "$out" "banned word 'seamless'" "banned word refused"
  out=$(python3 "$LIB" ste --text ""); rc=$?
  expect_code 1 "$rc" "empty text"
  out=$(python3 "$LIB" ste --text "$(printf 'word %.0s' $(seq 1 30)).");  rc=$?
  expect_code 1 "$rc" "a sentence over 25 words"
  assert_contains "$out" "maximum 25" "sentence length refused"
  out=$(python3 "$LIB" ste --text "One. Two. Three. Four."); rc=$?
  assert_contains "$out" "sentences (maximum 3)" "too many sentences refused"
  out=$(python3 "$LIB" ste --banned "frobnicate" --text "We frobnicate the file." 2>&1); rc=$?
  expect_code 2 "$rc" "the removed banned-word override must be refused"
  out=$(python3 "$LIB" ste --text "The error was caused by a bad value. The job is running and it has finished."); rc=$?
  expect_code 0 "$rc" "warnings do not refuse"
  assert_contains "$out" "[WARN] plain-English note (purpose): passive voice" "passive voice warns"
  assert_contains "$out" "progressive tense" "progressive tense warns"
  assert_contains "$out" "perfect tense" "perfect tense warns"
  out=$(python3 "$LIB" ste --text "The system will abandon the task."); rc=$?
  expect_code 0 "$rc" "vocabulary only warns"
  assert_contains "$out" "word 'abandon' is not approved; try stop" "the OpenSTE word list warns with a replacement"
  # The refuse rules apply to a purpose at publish; warnings go on the PR.
  new_case ste-publish
  write_task t1 ui
  ui_items
  jq '.items[0].purpose = "The tool prints new text; it works."' "$C/ev/items.json" > "$C/ev/bad.json"
  out=$(ev publish t1 "$PRURL" "$C/ev/bad.json"); rc=$?
  expect_code 1 "$rc" "a purpose with a semicolon"
  assert_contains "$out" "item cli purpose: semicolon" "the refusal must name the item"
  jq '.items[0].purpose = "The error was caused by a bad value. Now the tool prints new text."' "$C/ev/items.json" > "$C/ev/warn.json"
  out=$(ev publish t1 "$PRURL" "$C/ev/warn.json") || fail "a warning-only purpose must publish: $out"
  assert_contains "$(comments_json | jq -r '.[0].body')" "Plain-English notes (warnings)" "warnings must show on the PR"
  assert_contains "$(comments_json | jq -r '.[0].body')" "passive voice" "the passive warning must show on the PR"
  pass "fm-pr-evidence: the plain-English check refuses the strict rules and only warns on the heuristics"
}

test_arming_and_merge_go_through_the_gate() {
  local out rc fakebin
  new_case arm
  fakebin="$C/fakebin"
  mkdir -p "$fakebin" "$C/root/bin" "$C/wt"
  cp "$FIX/gh" "$fakebin/gh"
  printf '#!/bin/sh\nexit 0\n' > "$C/root/bin/fm-guard.sh"
  chmod +x "$C/root/bin/fm-guard.sh"
  git -C "$C/wt" init -q
  git -C "$C/wt" commit -q --allow-empty -m init
  write_task t1 ui "worktree=$C/wt"
  fm_write_meta "$C/home/state/t1.meta" "window=fm-t1" "endpoint_task_id=t1" "worktree=$C/wt" "project=$C/proj" "kind=ship" "mode=no-mistakes" "evidence=ui"
  run_pr() {  # <script> <args...>
    local script=$1
    shift
    FM_ROOT_OVERRIDE="$C/root" FM_HOME="$C/home" FM_TEST_STUB="$STUB" PATH="$fakebin:$(fm_test_base_path_sans "${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}" gh):$(dirname "$(command -v jq)")" \
      "$script" "$@" 2>&1
  }
  mv "$C/home/config/pr-evidence" "$C/home/config/pr-evidence.saved"
  ln -s missing-config "$C/home/config/pr-evidence"
  out=$(run_pr "$PR_CHECK" t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "arming must refuse a dangling evidence configuration"
  assert_contains "$out" 'configuration cannot be read' "arming must use the shared config validation"
  assert_absent "$C/home/state/t1.check.sh" "a dangling config must not arm a poll"
  rm "$C/home/config/pr-evidence"
  mv "$C/home/config/pr-evidence.saved" "$C/home/config/pr-evidence"
  out=$(run_pr "$PR_CHECK" t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "arming a PR with no evidence"
  assert_contains "$out" "[FAIL] no evidence comment" "arming must show the gate's FAIL line"
  assert_contains "$out" "the PR evidence gate refused" "arming must say the gate refused"
  assert_not_contains "$out" "armed:" "a refused PR must not be armed"
  assert_absent "$C/home/state/t1.check.sh" "a refused PR must not arm a poll"
  ui_items
  published
  out=$(run_pr "$PR_CHECK" t1 "$PRURL"); rc=$?
  expect_code 0 "$rc" "arming a PR with evidence (got: $out)"
  assert_contains "$out" "armed: state/t1.check.sh" "a PR with evidence must arm"
  poll_valid || fail "arming must register a valid poll"
  published
  poll_valid || fail "same-head republication must preserve the registered poll"
  # The merge records through the same script and refuses when the head moved.
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD2\",\"files\":[\"bin/tool.sh\"]}"
  out=$(run_pr "$PR_MERGE" t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "merging after the head moved"
  assert_contains "$out" "the PR changed after the evidence" "merge must refuse a moved head"
  published
  poll_valid || fail "new-head republication must preserve the registered poll"
  out=$(FM_TEST_GH_VIEW_HEAD="$HEAD1" FM_TEST_GH_LOG="$C/gh.log" run_pr "$PR_MERGE" t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "merge-time head must match evidence even after intake passed"
  assert_contains "$out" "evidence check head differs from the merge head" "a split head snapshot must refuse"
  assert_no_grep 'pr merge ' "$C/gh.log" "a mismatched head must never reach the merge interface"
  out=$(run_pr "$PR_MERGE" t1 "$PRURL" --attended-override -- --auto --squash); rc=$?
  expect_code 1 "$rc" "evidence cannot authorize asynchronous merging"
  assert_contains "$out" "not --auto" "auto-merge must refuse while evidence is enforced"
  out=$(FM_TEST_GH_RULES='[{"type":"merge_queue","parameters":{"merge_method":"SQUASH"}}]' run_pr "$PR_MERGE" t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "evidence cannot authorize a merge queue"
  assert_contains "$out" "no merge queue" "merge queues must refuse while evidence is enforced"
  out=$(FM_TEST_GH_LOG="$C/success.log" run_pr "$PR_MERGE" t1 "$PRURL"); rc=$?
  expect_code 0 "$rc" "an immediate merge of the evidence head must succeed (got: $out)"
  assert_grep "--match-head-commit $HEAD2" "$C/success.log" "the merge interface must receive the evidence head"
  # A task from before the gate passes with a notice, both ways.
  fm_write_meta "$C/home/state/t2.meta" "window=fm-t2" "endpoint_task_id=t2" "worktree=$C/wt" "project=$C/proj" "kind=ship" "mode=no-mistakes"
  out=$(run_pr "$PR_CHECK" t2 "$PRURL"); rc=$?
  expect_code 0 "$rc" "a task from before the gate (got: $out)"
  assert_contains "$out" "notice: evidence gate not applied: task t2 predates it" "a legacy task must pass with a notice"
  assert_contains "$out" "armed: state/t2.check.sh" "a legacy task must still arm"
  pass "fm-pr-evidence: arming and merging go through the gate; a legacy task passes with a notice"
}

test_waiver_needs_words_and_is_refused_away() {
  local out rc
  new_case waiver
  write_task t1 ui
  out=$(ev waive t1 "$PRURL" --words "skip it"); rc=$?
  expect_code 1 "$rc" "a waiver with too few words"
  assert_contains "$out" "needs the captain's own words" "short words refused"
  : > "$C/home/state/.afk"
  out=$(ev waive t1 "$PRURL" --words "Waive the evidence for this PR please"); rc=$?
  expect_code 1 "$rc" "a waiver in away mode"
  assert_contains "$out" "refused in away mode" "away mode must refuse"
  assert_absent "$C/home/state/t1.evidence-waiver" "a refused waiver records nothing"
  printf 'quiet\n' > "$C/home/state/.afk"
  out=$(ev waive t1 "$PRURL" --words "Waive the evidence for this PR please") || fail "an attended waiver must work: $out"
  assert_present "$C/home/state/t1.evidence-waiver" "a waiver must be recorded"
  assert_contains "$(comments_json | jq -r '.[-1].body')" "The captain's words: Waive the evidence for this PR please" "the waiver must be posted on the PR"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 0 "$rc" "a waived PR"
  assert_contains "$out" "waived for t1" "a waived PR passes with a notice"
  stub_post /_admin/pr "{\"key\":\"o/r/999\",\"head\":\"$HEAD1\",\"files\":[]}"
  out=$(ev check t1 https://github.com/o/r/pull/999); rc=$?
  expect_code 1 "$rc" "a waiver must not authorize the next PR for the same task"
  assert_contains "$out" "no evidence comment" "the next PR needs its own evidence"
  printf 'url=%s\n' "$PRURL" > "$C/home/state/t1.evidence-waiver"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "an incomplete waiver must not authorize a PR"
  pass "fm-pr-evidence: a waiver needs the captain's words, is refused away, and is posted on the PR"
}

test_list_unevidenced_names_prs_from_before_the_gate() {
  local out
  new_case list
  write_task t1 ui "pr=$PRURL"
  write_task old1 "" "pr=$PRURL"
  out=$(ev list-unevidenced)
  assert_contains "$out" "old1 proj $PRURL" "the list must name the older PR"
  assert_not_contains "$out" "t1 proj" "a task with evidence is not listed"
  pass "fm-pr-evidence: list-unevidenced names the open PRs from before the gate"
}

test_gh_with_attach_is_picked_over_a_stale_one() {
  local out rc stale good nogh
  new_case gh
  nogh=$(fm_test_base_path_sans "/usr/bin:/bin:$(dirname "$(command -v jq)")" gh)
  write_task t1 ui
  ui_items
  stale="$C/stale"
  good="$C/good"
  mkdir -p "$stale" "$good"
  cp "$FIX/gh" "$stale/gh"
  cp "$FIX/gh" "$good/gh"
  # The stale gh hides --attach in its help; the good one is later on PATH.
  stale_run() {
    FM_HOME="$C/home" FM_TEST_STUB="$STUB" FM_PR_EVIDENCE_GH="$stale/gh" \
      PATH="$stale:$good:$nogh" "$EV" publish t1 "$PRURL" "$C/ev/items.json" 2>&1
  }
  # A wrapper makes the stale copy report no --attach support.
  cat > "$stale/gh" <<EOF
#!/usr/bin/env bash
FM_TEST_GH_STALE=1 exec "$FIX/gh" "\$@"
EOF
  chmod +x "$stale/gh"
  cat > "$good/gh" <<EOF
#!/usr/bin/env bash
exec "$FIX/gh" "\$@"
EOF
  chmod +x "$good/gh"
  out=$(stale_run); rc=$?
  expect_code 0 "$rc" "the later gh with --attach must be used (got: $out)"
  assert_contains "$out" "[PASS]" "publish through the second gh must pass"
  rm -rf "$good"
  out=$(stale_run); rc=$?
  expect_code 1 "$rc" "only a stale gh"
  assert_contains "$out" "no gh with 'pr comment --attach' was found" "a stale-only PATH must refuse"
  assert_contains "$out" "FIX: install a newer gh" "the refusal must carry a FIX line"
  out=$(FM_HOME="$C/home" FM_TEST_STUB="$STUB" FM_PR_EVIDENCE_GH="$FIX/gh" PATH="$stale:$nogh" "$EV" publish t1 "$PRURL" "$C/ev/items.json" 2>&1); rc=$?
  expect_code 0 "$rc" "the explicit capable override must work when PATH has no capable gh (got: $out)"
  pass "fm-pr-evidence: the gh that accepts --attach is picked over a stale one on PATH"
}

test_bitbucket_arm_is_off_by_default_and_works_when_on() {
  local out rc
  new_case bb
  PRN=$((PRN + 1))
  PRURL="https://bitbucket.org/ws/repo/pull-requests/$PRN"
  PRKEY="ws/repo/$PRN"
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"author\":\"acct-worker\",\"files\":[\"bin/tool.sh\"]}"
  write_task t1 ui
  bbenv() {
    FM_HOME="$C/home" FM_TEST_STUB="$STUB" FM_PR_EVIDENCE_GH="$FIX/gh" PATH="$FIX:$PATH" FM_PR_EVIDENCE_BITBUCKET_API="$STUB/bb/2.0" \
      NO_MISTAKES_BITBUCKET_EMAIL=bot@example.invalid NO_MISTAKES_BITBUCKET_API_TOKEN=synthetic-token "$EV" "$@" 2>&1
  }
  out=$(bbenv check t1 "$PRURL"); rc=$?
  expect_code 0 "$rc" "the Bitbucket arm is off by default"
  assert_contains "$out" "the Bitbucket arm is off" "an off arm must say so"
  ui_items
  out=$(bbenv publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
  expect_code 1 "$rc" "publish with the arm off"
  assert_contains "$out" "the Bitbucket arm is off" "publish must refuse while the arm is off"
  printf '%s\n' '* enforce' 'bitbucket on' > "$C/home/config/pr-evidence"
  out=$(bbenv check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "an enabled arm with no evidence"
  assert_contains "$out" "[FAIL] no evidence comment" "the Bitbucket gate must refuse a PR with no evidence"
  out=$(bbenv publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
  expect_code 0 "$rc" "Bitbucket publish (got: $out)"
  assert_contains "$out" "[PASS] evidence gate" "the Bitbucket gate must pass after publish"
  assert_contains "$(comments_json | jq -r '.[0].body')" "https://bitbucket.org/ws/repo/downloads/fm-evidence-$PRN-" "images must point at the repository Downloads area"
  (
    . "$ROOT/bin/fm-pr-lib.sh"
    fm_pr_url_parse "$PRURL" &&
      fm_pr_poll_prepare "$C/home/state" t1 "$FM_PR_PROVIDER" "$FM_PR_URL" "$FM_PR_HOST" "$FM_PR_PATH" "$FM_PR_NUMBER" "$ROOT/bin/fm-pr-poll.sh" &&
      printf 'pr=%s\npr_head=%s\n' "$PRURL" "$HEAD1" >> "$C/home/state/t1.meta" &&
      fm_pr_poll_publish_prepared
  ) || fail "Bitbucket poll registration failed"
  poll_valid || fail "Bitbucket poll must be valid before republication"
  out=$(bbenv publish t1 "$PRURL" "$C/ev/items.json") || fail "Bitbucket republication failed: $out"
  poll_valid || fail "Bitbucket republication must preserve the registered poll"
  tamper "del m['items'][0]['after']['annotation']"
  out=$(bbenv check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "Bitbucket verification must require annotation records"
  assert_contains "$out" "cli after has no annotation record" "Bitbucket must name the missing phase record"
  out=$(bbenv publish t1 "$PRURL" "$C/ev/items.json") || fail "Bitbucket publication must restore the record: $out"
  out=$(bbenv check t1 "$PRURL" "$HEAD1"); rc=$?
  expect_code 1 "$rc" "Bitbucket must refuse a merge without an atomic expected-head interface"
  assert_contains "$out" "cannot bind evidence" "Bitbucket must explain why merge enforcement refuses"
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"author\":\"actual-worker\",\"files\":[]}"
  out=$(bbenv check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "the acting Bitbucket account must not authorize another PR author's evidence"
  assert_contains "$out" 'no evidence comment by actual-worker' "Bitbucket must filter to its PR author"
  [ "$(curl -sS -X POST "$STUB/_admin/state" | jq -r .bb_auth)" -gt 0 ] || fail "the Bitbucket credential was never sent"
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD2\",\"author\":\"acct-worker\",\"files\":[\"bin/tool.sh\"]}"
  out=$(bbenv check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "Bitbucket head drift"
  assert_contains "$out" "the PR changed after the evidence" "a moved Bitbucket head must refuse"
  printf '%s\n' '* enforce' 'bitbucket on' 'proj ui components/*.jsx' > "$C/home/config/pr-evidence"
  write_task t1 none 'evidence_reason=Only a comment changed in the file.'
  PRN=$((PRN + 1)); PRKEY="ws/repo/$PRN"; PRURL="https://bitbucket.org/ws/repo/pull-requests/$PRN"
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"author\":\"acct-worker\",\"files\":[{\"old\":{\"path\":\"components/Old.jsx\"},\"new\":{\"path\":\"other/New.txt\"}}]}"
  out=$(bbenv check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "Bitbucket rename matching must include the source path"
  assert_contains "$out" 'components/Old.jsx' "Bitbucket must name the matched source path"
  pass "fm-pr-evidence: the Bitbucket arm is off by default; when on it uploads to Downloads and gates the same way"
}

test_annotation_tools_draw_marks() {
  local out rc
  if ! command -v magick >/dev/null 2>&1; then
    echo "note: ImageMagick not found; skipping the render cases"
    return 0
  fi
  new_case render
  printf '$ tool\nold text\n' > "$C/ev/before.txt"
  printf '$ tool\nnew text\n' > "$C/ev/after.txt"
  ev annotate-ui --text "$C/ev/after.txt" --against "$C/ev/before.txt" --purpose "The tool now prints new text." \
    --label "Text changed" --out "$C/ev/after.png" >/dev/null || fail "annotate-ui of a terminal text failed"
  out=$(python3 "$LIB" marks "$C/ev/after.png" --min 200); rc=$?
  expect_code 0 "$rc" "an annotated terminal image must carry marks (got: $out)"
  ev annotate-ui --text "$C/ev/after.txt" --against "$C/ev/after.txt" --purpose "Same text." --out "$C/ev/same.png" >/dev/null && fail "annotate-ui must refuse when nothing differs"
  png "$C/ev/shot.png" 5 0
  ev annotate-ui --image "$C/ev/shot.png" --mark "5,5,40,20,Changed" --purpose "The page now shows the button." \
    --out "$C/ev/shot-marked.png" >/dev/null || fail "annotate-ui of a screenshot failed"
  out=$(python3 "$LIB" marks "$C/ev/shot-marked.png" --min 200); rc=$?
  expect_code 0 "$rc" "a marked screenshot must carry marks"
  api_sidecars
  ev annotate-api --sidecar "$C/ev/a.json" --against "$C/ev/b.json" --purpose "The API now returns success." \
    --out "$C/ev/api.png" >/dev/null || fail "annotate-api failed"
  python3 "$LIB" marks "$C/ev/api.png" --min 200 >/dev/null || fail "an annotated API image must carry marks"
  ev capture-ui --out "$C/ev/cap.txt" -- echo "hello world" >/dev/null || fail "capture-ui failed"
  python3 - "$C/ev/cap.txt" <<'PY' || fail "capture-ui must preserve the command arguments"
import pathlib, shlex, sys
command = pathlib.Path(sys.argv[1]).read_text().splitlines()[0]
assert command.startswith("$ "), command
assert shlex.split(command[2:]) == ["echo", "hello world"], command
PY
  assert_contains "$(cat "$C/ev/cap.txt")" "(exit status 0)" "capture-ui must keep the exit status"
  pass "fm-pr-evidence: the annotate helpers draw marks that the gate's counter finds"
}

test_brief_block_and_list_commands_print() {
  local out
  new_case blocks
  out=$(ev brief-block task-x proj no-mistakes none "$C/proj")
  assert_contains "$out" "# Evidence for review (hard rule)" "the worker contract heading"
  assert_contains "$out" "publish task-x <pr-url>" "the worker contract names publish with the task id"
  assert_contains "$out" "ASD-STE100" "the worker contract names the plain-English rule"
  out=$(ev help)
  assert_contains "$out" "fork-only (cloud-practitioner/firstmate); never offered upstream" "the header marks the script fork-only"
  pass "fm-pr-evidence: the worker contract and help print"
}

test_live_guard_against_the_sandbox() {
  local pr out rc dir phase
  pr=$LIVE_PR
  if [ -z "$pr" ]; then
    echo "note: live guard skipped (set FM_PR_EVIDENCE_LIVE_PR to a PR URL in the private sandbox repository)"
    return 0
  fi
  dir="$TMP_ROOT/live"
  mkdir -p "$dir/home/state" "$dir/home/config" "$dir/proj" "$dir/ev"
  echo '* enforce' > "$dir/home/config/pr-evidence"
  fm_write_meta "$dir/home/state/t1.meta" "window=fm-t1" "endpoint_task_id=t1" "project=$dir/proj" "kind=ship" "mode=no-mistakes" "evidence=ui"
  python3 "$FIX/mkpng.py" "$dir/ev/b-raw.png" 1 400
  python3 "$FIX/mkpng.py" "$dir/ev/a-raw.png" 2 400
  for phase in b a; do
    "$EV" annotate-ui --image "$dir/ev/$phase-raw.png" --mark '5,5,40,20,Synthetic mark' \
      --purpose 'This is a synthetic test image. The gate must find it on the PR page.' \
      --out "$dir/ev/$phase.png" >/dev/null || fail "live fixture annotation failed"
  done
  cat > "$dir/ev/items.json" <<'EOF'
{"items":[{"id":"live","kind":"ui","purpose":"This is a synthetic test image. The gate must find it on the PR page.","before":{"image":"b.png"},"after":{"image":"a.png"},"labels":["Synthetic mark"]}]}
EOF
  out=$(FM_HOME="$dir/home" GH_TOKEN="$LIVE_GH_TOKEN" GITHUB_TOKEN="$LIVE_GITHUB_TOKEN" \
    FM_PR_EVIDENCE_GH="$LIVE_GH" "$EV" publish t1 "$pr" "$dir/ev/items.json" 2>&1); rc=$?
  expect_code 0 "$rc" "live publish against the sandbox (got: $out)"
  assert_contains "$out" "[PASS] evidence gate" "the real upload must display and fetch"
  pass "fm-pr-evidence: live guard - real upload, display, and fetch on the sandbox PR"
}

test_promote_requires_evidence_intake() {
  local out rc value
  new_case promote
  mkdir -p "$C/root/bin" "$C/home/data/t1"
  printf '#!/bin/sh\nexit 0\n' > "$C/root/bin/fm-guard.sh"
  printf '#!/bin/sh\nprintf "none\\n"\n' > "$C/root/bin/fm-project-mode.sh"
  chmod +x "$C/root/bin/"*.sh
  write_task t1 '' 'kind=scout'
  printf '# Task\n## Captain'\''s intent\nFix the output.\n## Firstmate spec\nInspect the output.\n## Evidence class\nui\n' > "$C/home/data/t1/brief.md"
  mv "$C/home/config/pr-evidence" "$C/home/config/pr-evidence.saved"
  ln -s missing-config "$C/home/config/pr-evidence"
  out=$(FM_HOME="$C/home" FM_ROOT_OVERRIDE="$C/root" "$ROOT/bin/fm-promote.sh" t1 --mode direct-PR --yolo off 2>&1); rc=$?
  expect_code 1 "$rc" "promotion must refuse a dangling evidence configuration"
  assert_contains "$out" 'configuration cannot be read' "promotion must use shared config validation"
  assert_grep 'kind=scout' "$C/home/state/t1.meta" "a dangling config must retain the scout state"
  assert_absent "$C/home/data/t1/ship-instructions.md" "a dangling config must publish no ship instructions"
  out=$(FM_HOME="$C/home" "$ROOT/bin/fm-brief.sh" dangling-brief proj --mode direct-PR --project "$C/proj" 2>&1); rc=$?
  expect_code 1 "$rc" "brief generation must refuse a dangling evidence configuration"
  assert_contains "$out" 'configuration cannot be read' "a config error must not become an inactive brief gate"
  assert_absent "$C/home/data/dangling-brief/brief.md" "a dangling config must not emit a ship brief"
  rm "$C/home/config/pr-evidence"
  mv "$C/home/config/pr-evidence.saved" "$C/home/config/pr-evidence"
  for value in '{EVIDENCE}' 'api+ui' 'sideways'; do
    printf '# Task\n## Captain'\''s intent\nFix the output.\n## Firstmate spec\nInspect the output.\n## Evidence class\n%s\n' "$value" > "$C/home/data/t1/brief.md"
    out=$(FM_HOME="$C/home" FM_ROOT_OVERRIDE="$C/root" "$ROOT/bin/fm-promote.sh" t1 --mode direct-PR --yolo off 2>&1); rc=$?
    expect_code 1 "$rc" "promotion must reject $value (got: $out)"
    assert_grep 'kind=scout' "$C/home/state/t1.meta" "refusal must retain the scout state"
    assert_absent "$C/home/data/t1/ship-instructions.md" "refusal must publish no ship instructions"
  done
  printf '# Task\n## Captain'\''s intent\nFix the output.\n## Firstmate spec\nInspect the output.\n## Evidence class\nnone: Only a comment changed in the file.\n' > "$C/home/data/t1/brief.md"
  out=$(FM_HOME="$C/home" FM_ROOT_OVERRIDE="$C/root" "$ROOT/bin/fm-promote.sh" t1 --mode direct-PR --yolo off 2>&1); rc=$?
  expect_code 0 "$rc" "promotion with a valid declaration (got: $out)"
  assert_grep 'kind=ship' "$C/home/state/t1.meta" "promotion must switch to ship"
  assert_grep 'evidence=none' "$C/home/state/t1.meta" "promotion must record evidence"
  assert_grep 'evidence_reason=Only a comment changed in the file.' "$C/home/state/t1.meta" "promotion must record the reason"
  assert_contains "$(cat "$C/home/data/t1/ship-instructions.md")" '## Evidence class' "the emitted worker interface must include the declaration"
  assert_contains "$(cat "$C/home/data/t1/ship-instructions.md")" '# Evidence for review (hard rule)' "the emitted worker interface must include the evidence contract"
  pass "fm-pr-evidence: promotion validates and records the same intake as spawn"
}

test_worker_added_kinds_are_durable() {
  local out rc
  new_case durable '* enforce' 'proj ui bin/*.sh'
  write_task t1 api
  uiapi_items
  published
  assert_grep 'evidence=ui+api' "$C/home/state/t1.meta" "worker additions must persist in the task record"
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD2\",\"files\":[\"bin/tool.sh\"]}"
  ui_items
  out=$(ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
  expect_code 1 "$rc" "a republish must not drop a previously published API kind"
  assert_contains "$out" "required kinds: api" "the lost worker kind must be named"
  tamper 'm["items"] = [m["items"][0]]; m["head"] = "fedcba9876543210fedcba9876543210fedcba98"'
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "verification must retain the durable API requirement"
  assert_contains "$out" "no evidence item of kind api" "verification must name the lost kind"
  pass "fm-pr-evidence: worker kinds are durable in composition, pattern checks, and verification"
}

test_labelled_image_swaps_refuse() {
  local out rc
  new_case swapped-labels
  write_task t1 ui+api
  uiapi_items
  published
  STATE_JSON=$(comments_json) STUB=$STUB PRKEY=$PRKEY python3 - <<'PY'
import json, os, re, urllib.request
c = json.loads(os.environ['STATE_JSON'])[0]
urls = re.findall(r'<img src="([^"]+)"', c['html'])
c['html'] = c['html'].replace(urls[0], 'SWAP').replace(urls[1], urls[0]).replace('SWAP', urls[1])
req = urllib.request.Request(os.environ['STUB'] + '/_admin/replace', data=json.dumps(
    dict(key=os.environ['PRKEY'], id=c['id'], body=c['body'], html=c['html'])).encode())
urllib.request.urlopen(req).read()
PY
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "swapping Before and After must refuse even when both hashes remain on the page"
  assert_contains "$out" "does not match its hash" "the phase-to-image binding must be checked"
  pass "fm-pr-evidence: rendered images are bound to their item and phase labels"
}

test_rename_source_paths_require_evidence() {
  local out rc
  new_case renamed '* enforce' 'proj ui components/*.jsx'
  write_task t1 none 'evidence_reason=Only a comment changed in the file.'
  printf '{"items":[]}\n' > "$C/ev/items.json"
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"files\":[{\"filename\":\"other/New.txt\",\"previous_filename\":\"components/Old.jsx\"}]}"
  out=$(ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
  expect_code 1 "$rc" "rename out of a matched directory must not drop the kind"
  assert_contains "$out" 'components/Old.jsx' "the source path must be named"
  pass "fm-pr-evidence: rename sources retain their pattern requirements"
}

test_partial_github_reads_refuse() {
  local out rc collection
  for collection in files comments; do
    new_case "partial-$collection" '* enforce' 'proj ui components/*.jsx'
    write_task t1 none 'evidence_reason=Only a comment changed in the file.'
    printf '{"items":[]}\n' > "$C/ev/items.json"
    if [ "$collection" = files ]; then
      stub_post /_admin/pr "$(jq -n --arg key "$PRKEY" --arg head "$HEAD1" '{key:$key,head:$head,files:([range(100) | "docs/" + tostring + ".md"] + ["components/Button.jsx"])}')"
    fi
    out=$(FM_TEST_GH_PARTIAL="$collection" ev check t1 "$PRURL"); rc=$?
    expect_code 1 "$rc" "a partial $collection read must refuse the check"
    assert_contains "$out" 'cannot be read' "a partial read must be reported"
    out=$(FM_TEST_GH_PARTIAL="$collection" ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
    expect_code 1 "$rc" "a partial $collection read must refuse publication"
    assert_equals 0 "$(comments_json | jq 'length')" "a partial read must not post evidence"
  done
  pass "fm-pr-evidence: valid partial GitHub collections with failed pagination refuse"
}

test_existing_unreadable_config_refuses() {
  local out rc command expected mode
  new_case unreadable
  write_task t1 ui "pr=$PRURL"
  ui_items
  printf '# Task\n## Evidence class\nui\n' > "$C/brief.md"
  for mode in directory dangling permissions; do
    rm -rf "$C/home/config/pr-evidence"
    if [ "$mode" = directory ]; then
      mkdir "$C/home/config/pr-evidence"
    elif [ "$mode" = dangling ]; then
      ln -s missing-config "$C/home/config/pr-evidence"
    else
      printf '* enforce\n' > "$C/home/config/pr-evidence"
      chmod 000 "$C/home/config/pr-evidence"
      if [ -r "$C/home/config/pr-evidence" ]; then
        echo 'note: unreadable-file case skipped for a user who can read mode 000 files'
        continue
      fi
    fi
    for command in eligible intake check publish list-unevidenced; do
      expected=1
      case "$command" in
        eligible) out=$(ev eligible proj no-mistakes none "$C/proj"); rc=$?; expected=2 ;;
        intake) out=$(ev intake "$C/brief.md" proj no-mistakes none "$C/proj"); rc=$? ;;
        check) out=$(ev check t1 "$PRURL"); rc=$? ;;
        publish) out=$(ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$? ;;
        list-unevidenced) out=$(ev list-unevidenced); rc=$? ;;
      esac
      expect_code "$expected" "$rc" "$command must refuse an existing $mode configuration (got: $out)"
      assert_contains "$out" 'configuration cannot be read' "the config read failure must be named"
    done
  done
  pass "fm-pr-evidence: existing unreadable configuration refuses every consumer"
}

test_strict_english_in_quotes_refuses() {
  local out rc
  new_case strict-quotes
  write_task t1 ui
  ui_items
  jq '.items[0].purpose = "The tool is \"seamless\"."' "$C/ev/items.json" > "$C/ev/quoted.json"
  out=$(ev publish t1 "$PRURL" "$C/ev/quoted.json"); rc=$?
  expect_code 1 "$rc" "a quoted banned purpose must refuse publication"
  assert_contains "$out" "banned word 'seamless'" "the quoted banned word must be named"
  printf "# Task\n## Evidence class\nnone: The text says \`it is seamless\`.\n" > "$C/brief.md"
  out=$(ev intake "$C/brief.md" proj no-mistakes none "$C/proj"); rc=$?
  expect_code 1 "$rc" "a backticked banned none reason must refuse intake"
  assert_contains "$out" "banned word 'seamless'" "the backticked banned word must be named"
  printf 'new text\n' > "$C/ev/after.txt"
  out=$(ev annotate-ui --text "$C/ev/after.txt" --mark-line 0 --purpose 'The tool prints new text.' --label "Use \`e.g.\` now" --out "$C/ev/out.png"); rc=$?
  expect_code 1 "$rc" "a backticked abbreviation must refuse before drawing"
  assert_contains "$out" 'abbreviation' "the drawn abbreviation must be named"
  pass "fm-pr-evidence: quoted purposes, drawn labels, and none reasons face strict English checks"
}

test_comment_cleanup_and_image_freshness() {
  local out rc provider phase hash image comments writes
  for provider in github bitbucket; do
    new_case "fresh-$provider" '* enforce' 'bitbucket on'
    if [ "$provider" = bitbucket ]; then
      PRN=$((PRN + 1)); PRKEY="ws/repo/$PRN"; PRURL="https://bitbucket.org/ws/repo/pull-requests/$PRN"
      stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"author\":\"acct-worker\",\"files\":[]}"
    fi
    current_ev() {
      FM_PR_EVIDENCE_BITBUCKET_API="$STUB/bb/2.0" NO_MISTAKES_BITBUCKET_EMAIL=bot@example.invalid \
        NO_MISTAKES_BITBUCKET_API_TOKEN=synthetic-token ev "$@"
    }
    write_task t1 ui
    ui_items
    out=$(current_ev publish t1 "$PRURL" "$C/ev/items.json") || fail "initial $provider publish failed: $out"
    comments=$(comments_json)
    writes=$(curl -sS -X POST "$STUB/_admin/state" | jq -c .writes)
    cp "$C/home/state/t1.meta" "$C/original.meta"
    stub_post /_admin/actor '{"github":"captain","bitbucket":"acct-captain"}'
    out=$(current_ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
    stub_post /_admin/actor '{}'
    expect_code 1 "$rc" "$provider must refuse publication by another account"
    assert_contains "$out" 'only the PR author may publish' "publisher identity must be checked before mutation"
    assert_equals "$comments" "$(comments_json)" "an ineligible publisher must preserve the worker's evidence"
    assert_equals "$writes" "$(curl -sS -X POST "$STUB/_admin/state" | jq -c .writes)" "an ineligible publisher must not upload, post, or delete"
    cmp -s "$C/original.meta" "$C/home/state/t1.meta" || fail "an ineligible publisher changed task metadata"
    stub_post /_admin/delete-failure '{"enabled":true}'
    out=$(current_ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
    stub_post /_admin/delete-failure '{"enabled":false}'
    expect_code 1 "$rc" "$provider publication must refuse failed cleanup"
    assert_contains "$out" 'could not be removed' "the cleanup failure must be named"
    assert_equals 2 "$(comments_json | jq 'length')" "the fixture must retain both competing comments"
    out=$(current_ev check t1 "$PRURL"); rc=$?
    expect_code 1 "$rc" "$provider verification must refuse duplicate eligible comments"
    assert_contains "$out" '2 evidence comments' "duplicate comments must be reported"
    out=$(current_ev publish t1 "$PRURL" "$C/ev/items.json") || fail "cleanup recovery failed: $out"
    assert_equals 1 "$(comments_json | jq 'length')" "successful cleanup must leave one comment"
    for phase in before after; do
      if [ "$phase" = before ]; then image="$C/ev/b.png"; else image="$C/ev/a.png"; fi
      if [ "$provider" = bitbucket ]; then
        hash="fm-evidence-$PRN-${HEAD1:0:12}-cli-$phase.png"
      else
        hash="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$image").png"
      fi
      rm "$TMP_ROOT/img/$hash"
      out=$(current_ev check t1 "$PRURL"); rc=$?
      expect_code 1 "$rc" "$provider must re-fetch a previously verified $phase image"
      assert_contains "$out" 'did not load as an image' "the missing image must refuse without comment or head changes"
      cp "$image" "$TMP_ROOT/img/$hash"
      out=$(current_ev check t1 "$PRURL") || fail "a restored image must pass: $out"
    done
  done
  pass "fm-pr-evidence: both forges refuse duplicate comments and reload every image on every check"
}

test_spawn_refuses_dangling_evidence_config() {
  local fakebin out rc id=ev-dangling
  . "$ROOT/tests/fixtures.sh"
  new_case spawn-dangling
  fakebin=$(fm_test_make_spawn_fakebin "$C/fakes" codex)
  mkdir -p "$C/home/projects" "$C/home/data/$id"
  printf 'codex\n' > "$C/home/config/crew-harness"
  printf -- '- proj [direct-PR] - fixture (added 2026-01-01)\n' > "$C/home/data/projects.md"
  git -C "$C/proj" branch -M main
  git clone -q --bare "$C/proj" "$C/origin.git"
  git -C "$C/proj" remote set-url origin "file://$C/origin.git"
  git -C "$C/origin.git" config remote.origin.url https://github.com/o/r.git
  git -C "$C/proj" fetch -q origin
  git -C "$C/proj" worktree add -q --detach "$C/pool" HEAD
  printf '# Task\n## Captain'\''s intent\nFix the output.\n## Firstmate spec\nChange the output.\n## Evidence class\nui\n# Definition of done\nDelivery contract: mode=direct-PR\nShip branch: fm/%s\n' "$id" > "$C/home/data/$id/brief.md"
  rm "$C/home/config/pr-evidence"
  ln -s missing-config "$C/home/config/pr-evidence"
  out=$(FM_BACKEND=tmux fm_test_run_spawn "$C/home" "$C/pool" "$fakebin" "$id" "$C/proj" --backend tmux --mode direct-PR --yolo off); rc=$?
  expect_code 1 "$rc" "fresh ship spawn must refuse dangling evidence config (got: $out)"
  assert_contains "$out" 'configuration cannot be read' "spawn must use shared config validation"
  assert_absent "$C/home/state/$id.meta" "a dangling config must not create grandfathered task metadata"
  rm "$C/home/data/$id/brief.md"
  out=$(FM_HOME="$C/home" "$ROOT/bin/fm-brief.sh" "$id" proj --mode local-only --project "$C/proj" 2>&1); rc=$?
  expect_code 0 "$rc" "local-only scaffolding must ignore the PR gate (got: $out)"
  assert_not_contains "$(< "$C/home/data/$id/brief.md")" '## Evidence class' "local-only scaffolding must not request an evidence class"
  assert_not_contains "$(< "$C/home/data/$id/brief.md")" '# Evidence for review (hard rule)' "local-only scaffolding must not emit the PR-publication contract"
  python3 - "$C/home/data/$id/brief.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace('{TASK}', 'Fix the output.').replace('{FIRSTMATE_SPEC}', 'Change the output.'))
PY
  rm "$C/home/config/pr-evidence"
  printf '* enforce\n' > "$C/home/config/pr-evidence"
  out=$(FM_BACKEND=tmux fm_test_run_spawn "$C/home" "$C/pool" "$fakebin" "$id" "$C/proj" --backend tmux --mode local-only --yolo off); rc=$?
  expect_code 0 "$rc" "local-only spawning must not require PR evidence (got: $out)"
  assert_grep 'mode=local-only' "$C/home/state/$id.meta" "the local-only delivery mode must be retained"
  assert_no_grep 'evidence=' "$C/home/state/$id.meta" "local-only spawning must not record an evidence declaration"
  pass "fm-pr-evidence: PR intake refuses bad config while local-only scaffolding and spawning skip the gate"
}

test_typographic_contractions_refuse_at_public_interfaces() {
  local out rc apostrophe text
  new_case apostrophes
  write_task t1 ui
  ui_items
  printf 'new text\n' > "$C/ev/after.txt"
  for apostrophe in "‘" "’"; do
    text="The tool isn${apostrophe}t ready."
    printf '# Task\n## Evidence class\nnone: %s\n' "$text" > "$C/brief.md"
    out=$(ev intake "$C/brief.md" proj no-mistakes none "$C/proj"); rc=$?
    expect_code 1 "$rc" "intake must refuse typographic contractions"
    assert_contains "$out" contraction "the intake reason must receive strict validation"
    jq --arg purpose "$text" '.items[0].purpose = $purpose' "$C/ev/items.json" > "$C/ev/bad.json"
    out=$(ev publish t1 "$PRURL" "$C/ev/bad.json"); rc=$?
    expect_code 1 "$rc" "publication must refuse a typographic contraction in its purpose"
    assert_contains "$out" contraction "the purpose must receive strict validation"
    out=$(ev annotate-ui --text "$C/ev/after.txt" --mark-line 0 --purpose 'The tool prints new text.' --label "$text" --out "$C/ev/out.png"); rc=$?
    expect_code 1 "$rc" "drawn labels must refuse typographic contractions"
    assert_contains "$out" contraction "the label must be refused before rendering"
    out=$(ev annotate-api --sidecar "$C/unused.json" --purpose "$text" --out "$C/ev/api.png"); rc=$?
    expect_code 1 "$rc" "drawn API purposes must refuse typographic contractions"
    assert_contains "$out" contraction "the API purpose must be refused before reading or rendering"
  done
  pass "fm-pr-evidence: typographic contractions refuse intake, publication, and annotation"
}

test_live_inputs_are_restored_only_for_an_opted_in_invocation() {
  local out rc
  new_case live-inputs
  local EV="$C/mock-evidence" TMP_ROOT="$C/mock-live"
  local LIVE_PR='https://github.com/fixture/private/pull/1'
  local LIVE_GH_TOKEN=synthetic-gh-token LIVE_GITHUB_TOKEN=synthetic-github-token LIVE_GH="$C/mock-gh"
  python3 - <<'PY'
import os
for name in ('GH_TOKEN', 'GITHUB_TOKEN', 'FM_PR_EVIDENCE_GH', 'LIVE_GH_TOKEN', 'LIVE_GITHUB_TOKEN', 'LIVE_GH'):
    assert name not in os.environ, name + ' leaked into a portable case'
PY
  rc=$?
  expect_code 0 "$rc" "portable cases must not inherit saved live credentials"
  cat > "$EV" <<'PY'
#!/usr/bin/env python3
import hashlib, json, os, pathlib, sys
if sys.argv[1] == 'annotate-ui':
    image = pathlib.Path(sys.argv[sys.argv.index('--image') + 1])
    out = pathlib.Path(sys.argv[sys.argv.index('--out') + 1])
    out.write_bytes(image.read_bytes())
    pathlib.Path(str(out) + '.annotation.json').write_text(json.dumps({
        'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
        'purpose': sys.argv[sys.argv.index('--purpose') + 1], 'labels': ['Synthetic mark']}))
    sys.exit(0)
assert sys.argv[1:3] == ['publish', 't1']
assert os.environ['GH_TOKEN'] == 'synthetic-gh-token'
assert os.environ['GITHUB_TOKEN'] == 'synthetic-github-token'
assert os.environ['FM_PR_EVIDENCE_GH'].endswith('/mock-gh')
(pathlib.Path(os.environ['FM_HOME']) / 'called').touch()
print('[PASS] evidence gate')
PY
  chmod +x "$EV"
  out=$(test_live_guard_against_the_sandbox); rc=$?
  expect_code 0 "$rc" "an opted-in invocation must restore saved auth and executable inputs (got: $out)"
  assert_present "$TMP_ROOT/live/home/called" "the isolated stub must receive the opted-in invocation"
  pass "fm-pr-evidence: live auth inputs are restored only at the isolated invocation boundary"
}

test_local_only_promotion_and_evidence_commands() {
  local out rc
  new_case local-promote
  mkdir -p "$C/root/bin" "$C/home/data/t1"
  printf '#!/bin/sh\nexit 0\n' > "$C/root/bin/fm-guard.sh"
  printf '#!/bin/sh\nprintf "none\\n"\n' > "$C/root/bin/fm-project-mode.sh"
  chmod +x "$C/root/bin/"*.sh
  write_task t1 '' 'kind=scout'
  printf '# Task\n## Captain'\''s intent\nFix the output.\n## Firstmate spec\nInspect the output.\n' > "$C/home/data/t1/brief.md"
  rm "$C/home/config/pr-evidence"
  ln -s missing-config "$C/home/config/pr-evidence"
  out=$(FM_HOME="$C/home" FM_ROOT_OVERRIDE="$C/root" "$ROOT/bin/fm-promote.sh" t1 --mode local-only --yolo off 2>&1); rc=$?
  expect_code 0 "$rc" "local-only promotion must not perform PR evidence intake (got: $out)"
  assert_grep 'mode=local-only' "$C/home/state/t1.meta" "promotion must retain local-only delivery"
  assert_no_grep 'evidence=' "$C/home/state/t1.meta" "local-only promotion must not create an evidence declaration"
  assert_not_contains "$(< "$C/home/data/t1/ship-instructions.md")" '## Evidence class' "local-only promotion must not request an evidence class"
  assert_not_contains "$(< "$C/home/data/t1/ship-instructions.md")" '# Evidence for review (hard rule)' "the current worker must not receive the PR-evidence contract"
  assert_not_contains "$(< "$C/home/data/t1/brief.md")" '# Evidence for review (hard rule)' "a relaunched worker must not receive the PR-evidence contract"
  out=$(ev brief-block t1 proj local-only none "$C/proj"); rc=$?
  expect_code 0 "$rc" "local-only tasks have no PR-evidence brief block"
  assert_equals '' "$out" "no PR-publication instructions may be emitted for a local-only task"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 0 "$rc" "local-only checks must skip the PR gate"
  printf '{"items":[]}\n' > "$C/ev/items.json"
  out=$(ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
  expect_code 1 "$rc" "local-only tasks must not publish evidence"
  assert_contains "$out" 'does not publish PR evidence' "local-only delivery has no evidence publication path"
  out=$(ev waive t1 "$PRURL" --words 'Waive the evidence for this PR please'); rc=$?
  expect_code 1 "$rc" "local-only tasks must not publish a waiver"
  assert_equals 0 "$(comments_json | jq length)" "local-only evidence commands must never post PR comments"
  rm "$C/home/config/pr-evidence"
  printf '* enforce\n' > "$C/home/config/pr-evidence"
  printf 'pr=%s\n' "$PRURL" >> "$C/home/state/t1.meta"
  out=$(ev list-unevidenced); rc=$?
  expect_code 0 "$rc" "local-only tasks must not be evidence retrofit candidates"
  assert_not_contains "$out" 't1 proj ' "local-only tasks must be excluded from the retrofit list"
  pass "fm-pr-evidence: local-only promotion and task commands have no PR-evidence obligation"
}

test_authorization_code_capture_is_masked() {
  local out rc code=a1b2c3d4e5f6a1b2c3d4
  new_case authorization-code
  out=$(ev capture-api --out "$C/ev/cap.json" "$STUB/oauth?code=$code"); rc=$?
  expect_code 0 "$rc" "OAuth redirect capture must succeed without exposing its code (got: $out)"
  assert_equals 302 "$(jq -r .response.status "$C/ev/cap.json")" "the HTTP status code must remain visible"
  assert_not_contains "$(< "$C/ev/cap.json")" "$code" "authorization codes must be masked in URLs and Location headers"
  assert_contains "$(jq -r .request.url "$C/ev/cap.json")" 'code=***masked' "the authorization-code query parameter must be masked"
  assert_contains "$(jq -r '.response.headers[] | select(.[0] == "Location") | .[1]' "$C/ev/cap.json")" 'code=***masked' "the redirect Location must be masked"
  out=$(python3 "$LIB" scan-sidecar "$C/ev/cap.json"); rc=$?
  expect_code 0 "$rc" "the masked redirect must pass its sidecar scan (got: $out)"
  pass "fm-pr-evidence: captured authorization-code redirects retain status and hide credentials"
}

test_fenced_payload_images_are_literal() {
  local provider out rc body id
  for provider in github bitbucket; do
    new_case "literal-$provider" '* enforce' 'bitbucket on'
    if [ "$provider" = bitbucket ]; then
      PRN=$((PRN + 1)); PRKEY="ws/repo/$PRN"; PRURL="https://bitbucket.org/ws/repo/pull-requests/$PRN"
      stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"author\":\"acct-worker\",\"files\":[]}"
    fi
    literal_ev() {
      FM_PR_EVIDENCE_BITBUCKET_API="$STUB/bb/2.0" NO_MISTAKES_BITBUCKET_EMAIL=bot@example.invalid \
        NO_MISTAKES_BITBUCKET_API_TOKEN=synthetic-token ev "$@"
    }
    write_task t1 ui+api
    uiapi_items
    jq '.response.body = "{\"body\":\"![preview](https://example.test/image.png)\"}"' "$C/ev/b.json" > "$C/ev/literal.json"
    mv "$C/ev/literal.json" "$C/ev/b.json"
    out=$(literal_ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
    expect_code 0 "$rc" "$provider must preserve image-shaped payload text without treating it as a screenshot (got: $out)"
    body=$(comments_json | jq -r '.[0].body')
    assert_contains "$body" 'https://example.test/image.png' "the literal HTTP payload must not be deleted"
    id=$(comments_json | jq -r '.[0].id')
    stub_post /_admin/replace "$(jq -n --arg key "$PRKEY" --arg id "$id" --arg body "$body" --argjson c "$(comments_json | jq '.[0]')" '{key:$key,id:$id,body:($body + "\n![external](https://example.test/visible.png)\n"),html:$c.html}')"
    out=$(literal_ev check t1 "$PRURL"); rc=$?
    expect_code 1 "$rc" "$provider must still refuse an actual external screenshot reference"
    assert_contains "$out" 'not hosted' "visible images must still face the hosting rule"
  done
  pass "fm-pr-evidence: fenced HTTP payloads are literal while visible image hosting remains enforced"
}

test_evidence_eligibility_is_shared_across_delivery_lanes() {
  local lane mode forge remote expected out rc url args
  for lane in github github-nm bitbucket-off bitbucket-on bitbucket-nm external gitlab gerrit forgejo local-only unknown; do
    new_case "lane-$lane"
    mode=direct-PR; forge=none; remote=https://github.com/o/r.git; expected=1; url=$PRURL
    case "$lane" in
      github) expected=0 ;;
      github-nm) mode=no-mistakes; expected=0 ;;
      bitbucket-*)
        remote=https://bitbucket.org/ws/repo.git
        PRKEY="ws/repo/$PRN"; url="https://bitbucket.org/ws/repo/pull-requests/$PRN"
        stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD1\",\"author\":\"acct-worker\",\"files\":[]}"
        if [ "$lane" != bitbucket-off ]; then printf 'bitbucket on\n' >> "$C/home/config/pr-evidence"; expected=0; fi
        [ "$lane" != bitbucket-nm ] || mode=no-mistakes
        ;;
      external) forge=external; printf "Run \`review-tool upload --draft\`.\n" > "$C/home/config/external-review.md" ;;
      gitlab) remote=https://gitlab.com/o/r.git; url="https://gitlab.com/o/r/-/merge_requests/$PRN" ;;
      gerrit) forge=gerrit; url="https://review.example/c/o/r/+/$PRN" ;;
      forgejo) forge=forgejo; remote=https://code.example/o/r.git; url="https://code.example/o/r/pulls/$PRN" ;;
      local-only) mode=local-only ;;
      unknown) remote=https://unknown.example/o/r.git; url="https://unknown.example/o/r/pulls/$PRN" ;;
    esac
    git -C "$C/proj" remote set-url origin "$remote"
    matrix_ev() {
      FM_PR_EVIDENCE_BITBUCKET_API="$STUB/bb/2.0" NO_MISTAKES_BITBUCKET_EMAIL=bot@example.invalid \
        NO_MISTAKES_BITBUCKET_API_TOKEN=synthetic-token ev "$@"
    }
    out=$(ev eligible proj "$mode" "$forge" "$C/proj"); rc=$?
    expect_code "$expected" "$rc" "$lane eligibility (got: $out)"
    printf '# Task\n## Captain'\''s intent\nFix the output.\n## Firstmate spec\nInspect the output.\n' > "$C/intake.md"
    out=$(ev intake "$C/intake.md" proj "$mode" "$forge" "$C/proj"); rc=$?
    if [ "$expected" -eq 0 ]; then
      expect_code 1 "$rc" "$lane must require evidence intake"
      assert_contains "$out" 'Evidence class' "$lane must name the missing intake declaration"
    else
      expect_code 0 "$rc" "$lane must not require evidence intake"
      assert_equals '' "$out" "$lane must record no evidence declaration"
    fi
    out=$(ev brief-block matrix proj "$mode" "$forge" "$C/proj"); rc=$?
    expect_code 0 "$rc" "$lane completion contract rendering"
    if [ "$expected" -eq 0 ]; then
      assert_contains "$out" '# Evidence for review (hard rule)' "$lane must receive its enforceable contract"
    else
      assert_equals '' "$out" "$lane must receive no publication-before-done contract"
    fi
    args=()
    [ "$forge" = none ] || args=(--forge "$forge")
    out=$(FM_HOME="$C/home" "$ROOT/bin/fm-brief.sh" matrix proj --mode "$mode" --project "$C/proj" "${args[@]+"${args[@]}"}" 2>&1); rc=$?
    expect_code 0 "$rc" "$lane brief generation (got: $out)"
    if [ "$expected" -eq 0 ]; then
      assert_contains "$(< "$C/home/data/matrix/brief.md")" '## Evidence class' "$lane must scaffold evidence intake"
    else
      assert_not_contains "$(< "$C/home/data/matrix/brief.md")" '## Evidence class' "$lane must not scaffold evidence intake"
      assert_not_contains "$(< "$C/home/data/matrix/brief.md")" '# Evidence for review (hard rule)' "$lane must not scaffold the PR-evidence contract"
    fi
    write_task t1 ui "mode=$mode" "forge=$forge"
    out=$(matrix_ev check t1 "$url"); rc=$?
    if [ "$expected" -eq 0 ]; then
      expect_code 1 "$rc" "$lane must enforce its evidence gate"
      assert_contains "$out" 'no evidence comment' "$lane must require a worker-authored comment"
    else
      case "$url" in
        https://github.com/*|https://bitbucket.org/*)
          expect_code 0 "$rc" "$lane must not enforce evidence checks" ;;
        *)
          expect_code 1 "$rc" "$lane must refuse unsupported evidence hosts"
          assert_contains "$out" 'PR evidence is not supported' "$lane must name the unsupported PR"
          ;;
      esac
      if [ "$forge" != external ]; then
        mkdir -p "$C/root/bin" "$C/home/data/scout1"
        printf '#!/bin/sh\nexit 0\n' > "$C/root/bin/fm-guard.sh"
        printf '#!/bin/sh\nprintf "%s\\n"\n' "$forge" > "$C/root/bin/fm-project-mode.sh"
        chmod +x "$C/root/bin/"*.sh
        cp "$C/intake.md" "$C/home/data/scout1/brief.md"
        write_task scout1 '' 'kind=scout'
        out=$(FM_HOME="$C/home" FM_ROOT_OVERRIDE="$C/root" "$ROOT/bin/fm-promote.sh" scout1 --mode "$mode" --yolo off 2>&1); rc=$?
        expect_code 0 "$rc" "$lane promotion must not require evidence (got: $out)"
        assert_no_grep 'evidence=' "$C/home/state/scout1.meta" "$lane promotion must record no evidence declaration"
        assert_not_contains "$(< "$C/home/data/scout1/ship-instructions.md")" '# Evidence for review (hard rule)' "$lane promotion must emit no publication-before-done contract"
      fi
    fi
  done
  pass "fm-pr-evidence: eligibility, intake, briefs, promotion, contracts, and checks agree across all delivery lanes"
}

test_unsupported_hosts_refuse_evidence_commands() {
  local url command out rc before order args
  new_case unsupported-hosts
  printf 'enterprise.example\n' > "$C/home/config/github-hosts"
  write_task t1 ui
  ui_items
  published
  before=$(comments_json)
  cp "$C/home/state/t1.meta" "$C/original.meta"
  for url in "https://enterprise.example/o/r/pull/$PRN" \
    "https://gitlab.example/o/r/-/merge_requests/$PRN" \
    "https://review.example/c/o/r/+/$PRN" "https://code.example/o/r/pulls/$PRN"; do
    for command in check publish waive; do
      args=("$command" t1 "$url")
      case "$command" in
        publish) args+=("$C/ev/items.json") ;;
        waive) args+=(--words 'Waive the evidence for this PR please') ;;
      esac
      : > "$C/gh.log"
      out=$(unset GH_HOST; FM_TEST_GH_LOG="$C/gh.log" ev "${args[@]}"); rc=$?
      expect_code 1 "$rc" "$command must refuse $url (got: $out)"
      assert_contains "$out" 'PR evidence is not supported' "$command must explain the unsupported host"
      assert_contains "$out" "$url" "$command must name the refused PR"
      [ ! -s "$C/gh.log" ] || fail "$command must refuse before any GitHub invocation"
      assert_equals "$before" "$(comments_json)" "$command must not alter another PR's comments"
      cmp -s "$C/original.meta" "$C/home/state/t1.meta" || fail "$command changed task metadata"
      assert_absent "$C/home/state/t1.evidence-waiver" "$command created an unsupported-host waiver"
    done
  done
  rm "$C/home/state/t1.meta"
  for order in public-first enterprise-first; do
    rm -f "$C/home/state/a.meta" "$C/home/state/z.meta"
    if [ "$order" = public-first ]; then
      write_task a '' "pr=$PRURL"
      write_task z '' "pr=https://enterprise.example/o/r/pull/$PRN"
    else
      write_task a '' "pr=https://enterprise.example/o/r/pull/$PRN"
      write_task z '' "pr=$PRURL"
    fi
    : > "$C/gh.log"
    : > "$C/gh-hosts.log"
    out=$(GH_HOST=enterprise.example FM_TEST_GH_LOG="$C/gh.log" FM_TEST_GH_HOST_LOG="$C/gh-hosts.log" ev list-unevidenced); rc=$?
    expect_code 1 "$rc" "mixed-host listing must refuse the Enterprise PR (got: $out)"
    assert_contains "$out" 'PR evidence is not supported' 'listing must explain the unsupported host'
    if [ "$order" = public-first ]; then
      assert_equals "api repos/o/r/pulls/$PRN" "$(< "$C/gh.log")" 'listing must read only the public PR'
      assert_equals github.com "$(< "$C/gh-hosts.log")" 'listing must bind the public read to github.com'
    else
      [ ! -s "$C/gh.log" ] || fail 'listing must stop at the first unsupported PR without a forge call'
    fi
  done
  pass 'fm-pr-evidence: unsupported hosts refuse without forge operations or mutations'
}

test_github_evidence_overrides_an_ambient_enterprise_host() {
  local out rc
  new_case github-host-binding
  write_task t1 ui
  ui_items
  GH_HOST=enterprise.example FM_TEST_GH_HOST_LOG="$C/gh-hosts.log" published
  GH_HOST=enterprise.example FM_TEST_GH_HOST_LOG="$C/gh-hosts.log" FM_TEST_GH_LOG="$C/gh.log" published
  assert_grep 'api -X DELETE repos/o/r/issues/comments/' "$C/gh.log" 'replacement must exercise comment deletion'
  assert_equals 1 "$(comments_json | jq length)" 'replacement must retain just the new evidence comment'
  out=$(GH_HOST=enterprise.example FM_TEST_GH_HOST_LOG="$C/gh-hosts.log" ev check t1 "$PRURL"); rc=$?
  expect_code 0 "$rc" "public check must pass with an ambient Enterprise host (got: $out)"
  out=$(GH_HOST=enterprise.example FM_TEST_GH_HOST_LOG="$C/gh-hosts.log" ev waive t1 "$PRURL" --words 'Waive the evidence for this PR please'); rc=$?
  expect_code 0 "$rc" "public waiver must post with an ambient Enterprise host (got: $out)"
  write_task t2 '' "pr=$PRURL"
  out=$(GH_HOST=enterprise.example FM_TEST_GH_HOST_LOG="$C/gh-hosts.log" ev list-unevidenced); rc=$?
  expect_code 0 "$rc" "public listing must work with an ambient Enterprise host (got: $out)"
  assert_contains "$out" "t2 proj $PRURL" 'listing must include the public PR'
  [ -s "$C/gh-hosts.log" ] || fail 'host binding must exercise forge operations'
  while IFS= read -r out; do
    assert_equals github.com "$out" 'every evidence GitHub operation must address github.com'
  done < "$C/gh-hosts.log"
  pass 'fm-pr-evidence: public reads, identity, posts, and deletes ignore an ambient Enterprise host'
}

test_unsupported_hosts_refuse_evidence_commands
test_github_evidence_overrides_an_ambient_enterprise_host
test_evidence_eligibility_is_shared_across_delivery_lanes
test_local_only_promotion_and_evidence_commands
test_authorization_code_capture_is_masked
test_fenced_payload_images_are_literal
test_spawn_refuses_dangling_evidence_config
test_typographic_contractions_refuse_at_public_interfaces
test_live_inputs_are_restored_only_for_an_opted_in_invocation
test_partial_github_reads_refuse
test_existing_unreadable_config_refuses
test_strict_english_in_quotes_refuses
test_comment_cleanup_and_image_freshness
test_promote_requires_evidence_intake
test_worker_added_kinds_are_durable
test_labelled_image_swaps_refuse
test_rename_source_paths_require_evidence
test_gate_is_off_without_config_and_config_is_strict
test_intake_declares_the_kind
test_publish_posts_one_comment_that_passes_the_gate
test_head_drift_author_and_missing_comment_refuse
test_images_that_do_not_display_refuse
test_broken_or_swapped_images_refuse
test_marks_must_be_drawn
test_annotation_records_are_required_and_bound
test_publish_refuses_invalid_replacement_metadata
test_api_exchange_needs_all_parts_and_masked_secrets
test_capture_api_masks_and_keeps_six_parts
test_declared_kind_and_changed_files_must_agree
test_none_still_posts_a_visible_reason
test_plain_english_refuse_and_warn
test_arming_and_merge_go_through_the_gate
test_waiver_needs_words_and_is_refused_away
test_list_unevidenced_names_prs_from_before_the_gate
test_gh_with_attach_is_picked_over_a_stale_one
test_bitbucket_arm_is_off_by_default_and_works_when_on
test_annotation_tools_draw_marks
test_brief_block_and_list_commands_print
test_live_guard_against_the_sandbox
