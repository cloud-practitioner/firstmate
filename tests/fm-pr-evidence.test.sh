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

# Keep ambient identity and credentials out of every case.
unset FM_BACKEND FM_HOME FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_CONFIG_OVERRIDE HERDR_PANE_ID HERDR_SESSION \
  NO_MISTAKES_BITBUCKET_EMAIL NO_MISTAKES_BITBUCKET_API_TOKEN GH_TOKEN GITHUB_TOKEN FM_PR_EVIDENCE_GH \
  FM_PR_EVIDENCE_BITBUCKET_API FM_PR_EVIDENCE_GH_FALLBACKS

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
  mkdir -p "$C/home/state" "$C/home/config" "$C/proj" "$C/ev"
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
  FM_HOME="$C/home" FM_TEST_STUB="$STUB" FM_PR_EVIDENCE_GH="$FIX/gh" FM_PR_EVIDENCE_GH_FALLBACKS='' "$EV" "$@" 2>&1
}

png() {  # <out> <seed> <marks>
  python3 "$FIX/mkpng.py" "$1" "$2" "$3"
}

ui_items() {  # writes $C/ev/items.json with one ui item of marked images
  png "$C/ev/b.png" 1 400
  png "$C/ev/a.png" 2 400
  cat > "$C/ev/items.json" <<'EOF'
{"items":[{"id":"cli","kind":"ui","purpose":"The tool printed old text. Now it prints new text.","before":{"image":"b.png"},"after":{"image":"a.png"},"labels":["Text changed"]}]}
EOF
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
  local state
  state=$(curl -sS -X POST "$STUB/_admin/state")
  STATE_JSON=$state PRKEY=$PRKEY STUB=$STUB python3 - "$1" <<'PY'
import json, os, re, sys, urllib.request
state = json.loads(os.environ["STATE_JSON"])
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
  ev enabled proj >/dev/null && fail "enabled must fail without config"
  printf '%s\n' '* enforce' 'proj off' > "$C/home/config/pr-evidence"
  ev enabled proj >/dev/null && fail "a project 'off' line must beat '* enforce'"
  ev enabled other >/dev/null || fail "'* enforce' must enable other projects"
  printf '%s\n' '* enforce' 'proj frobnicate x' > "$C/home/config/pr-evidence"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "invalid config line"
  assert_contains "$out" "config/pr-evidence is not valid" "an invalid config line must be named"
  pass "fm-pr-evidence: off without config; config lines are strict; a project off line wins"
}

test_intake_declares_the_kind() {
  local out rc brief
  new_case intake
  brief="$C/brief.md"
  fill() { printf '# Task\n## Captain'\''s intent\nx\n\n## Firstmate spec\ny\n\n## Evidence class\n%s\n\n# Definition of done\nz\n' "$1" > "$brief"; }
  fill '{EVIDENCE}'
  out=$(ev intake "$brief" proj "$C/proj"); rc=$?
  expect_code 1 "$rc" "unfilled placeholder"
  assert_contains "$out" "is not filled" "the unfilled class must be refused"
  fill 'ui'
  out=$(ev intake "$brief" proj "$C/proj")
  assert_equals "evidence=ui" "$out" "ui class"
  fill 'api+ui'
  out=$(ev intake "$brief" proj "$C/proj")
  assert_equals "evidence=ui+api" "$out" "api+ui is normalized"
  fill 'none: The change only fixes a typo in a comment.'
  out=$(ev intake "$brief" proj "$C/proj")
  assert_contains "$out" "evidence=none" "none with a plain reason"
  assert_contains "$out" "evidence_reason=The change only fixes a typo in a comment." "the reason is recorded"
  fill 'none:'
  out=$(ev intake "$brief" proj "$C/proj"); rc=$?
  expect_code 1 "$rc" "none without a reason"
  fill 'none: It does not matter; skip it.'
  out=$(ev intake "$brief" proj "$C/proj"); rc=$?
  expect_code 1 "$rc" "none with a semicolon reason (plain-English refuse rule)"
  assert_contains "$out" "semicolon" "the plain-English refusal must say why"
  fill 'sideways'
  out=$(ev intake "$brief" proj "$C/proj"); rc=$?
  expect_code 1 "$rc" "invalid class"
  printf '# Task\n## Captain'\''s intent\nx\n\n## Firstmate spec\ny\n' > "$brief"
  out=$(ev intake "$brief" proj "$C/proj"); rc=$?
  expect_code 1 "$rc" "missing subsection while the gate is on"
  assert_contains "$out" "has no '## Evidence class'" "a missing subsection must be named"
  # Call 5: a require line and the firstmate repository itself never allow none.
  printf '%s\n' '* enforce' 'proj require' > "$C/home/config/pr-evidence"
  fill 'none: Only a comment changed in the file.'
  out=$(ev intake "$brief" proj "$C/proj"); rc=$?
  expect_code 1 "$rc" "none on a require project"
  assert_contains "$out" "always needs evidence" "the require refusal must say why"
  fill 'ui'
  out=$(ev intake "$brief" proj "$C/proj")
  assert_equals "evidence=ui" "$out" "ui stays allowed on a require project"
  echo '* enforce' > "$C/home/config/pr-evidence"
  fill 'none: Only a comment changed in the file.'
  out=$(ev intake "$brief" firstmate "$ROOT"); rc=$?
  expect_code 1 "$rc" "none on the firstmate repository"
  assert_contains "$out" "always needs evidence" "the firstmate repository never allows none"
  # An off gate prints nothing and records nothing.
  rm -f "$C/home/config/pr-evidence"
  out=$(ev intake "$brief" proj "$C/proj"); rc=$?
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
  stub_post /_admin/replace "{\"key\":\"$PRKEY\",\"id\":\"$(comments_json | jq -r '.[0].id')\",\"body\":$(comments_json | jq '.[0].body'),\"html\":$(comments_json | jq '.[0].html')}"
  curl -sS -X POST --data "{\"key\":\"$PRKEY\",\"author\":\"stranger\",\"body\":$(comments_json | jq '.[0].body'),\"html\":$(comments_json | jq '.[0].html')}" "$STUB/_admin/comment" >/dev/null
  # Remove the worker's own comment so only the stranger's copy remains.
  curl -sS -X DELETE "$STUB/gh/repos/o/r/issues/comments/$(comments_json | jq -r '.[0].id')" >/dev/null
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "a fake manifest by another account"
  assert_contains "$out" "no evidence comment by worker" "only the PR author or the acting account may hold the evidence"
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
  out=$(ev publish t1 "$PRURL" "$C/ev/items.json"); rc=$?
  expect_code 1 "$rc" "publish with an unmarked image"
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
  out=$(python3 "$LIB" ste --no-vocab --text "The Save button stays grey after you type a name. You cannot save the form."); rc=$?
  expect_code 0 "$rc" "plain text passes"
  out=$(python3 "$LIB" ste --no-vocab --text "The tool wasn't shown; it's seamless, e.g. robust — and long."); rc=$?
  expect_code 1 "$rc" "refuse rules"
  assert_contains "$out" "semicolon" "semicolon refused"
  assert_contains "$out" "contraction 'wasn't'" "contraction refused"
  assert_contains "$out" "abbreviation 'e.g.'" "abbreviation refused"
  assert_contains "$out" "long dash" "em dash refused"
  assert_contains "$out" "banned word 'seamless'" "banned word refused"
  out=$(python3 "$LIB" ste --no-vocab --text ""); rc=$?
  expect_code 1 "$rc" "empty text"
  out=$(python3 "$LIB" ste --no-vocab --text "$(printf 'word %.0s' $(seq 1 30)).");  rc=$?
  expect_code 1 "$rc" "a sentence over 25 words"
  assert_contains "$out" "maximum 25" "sentence length refused"
  out=$(python3 "$LIB" ste --no-vocab --text "One. Two. Three. Four."); rc=$?
  assert_contains "$out" "sentences (maximum 3)" "too many sentences refused"
  out=$(python3 "$LIB" ste --no-vocab --banned "frobnicate" --text "We frobnicate the file."); rc=$?
  expect_code 1 "$rc" "a configured banned word"
  out=$(python3 "$LIB" ste --no-vocab --text "The error was caused by a bad value. The job is running and it has finished."); rc=$?
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
  # The merge records through the same script and refuses when the head moved.
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD2\",\"files\":[\"bin/tool.sh\"]}"
  out=$(run_pr "$PR_MERGE" t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "merging after the head moved"
  assert_contains "$out" "the PR changed after the evidence" "merge must refuse a moved head"
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
  rm -f "$C/home/state/.afk"
  out=$(ev waive t1 "$PRURL" --words "Waive the evidence for this PR please") || fail "an attended waiver must work: $out"
  assert_present "$C/home/state/t1.evidence-waiver" "a waiver must be recorded"
  assert_contains "$(comments_json | jq -r '.[-1].body')" "The captain's words: Waive the evidence for this PR please" "the waiver must be posted on the PR"
  out=$(ev check t1 "$PRURL"); rc=$?
  expect_code 0 "$rc" "a waived PR"
  assert_contains "$out" "waived for t1" "a waived PR passes with a notice"
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
    FM_HOME="$C/home" FM_TEST_STUB="$STUB" FM_PR_EVIDENCE_GH_FALLBACKS="${1:-}" \
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
  out=$(stale_run ""); rc=$?
  expect_code 0 "$rc" "the later gh with --attach must be used (got: $out)"
  assert_contains "$out" "[PASS]" "publish through the second gh must pass"
  rm -rf "$good"
  out=$(stale_run ""); rc=$?
  expect_code 1 "$rc" "only a stale gh"
  assert_contains "$out" "no gh with 'pr comment --attach' was found" "a stale-only PATH must refuse"
  assert_contains "$out" "FIX: install a newer gh" "the refusal must carry a FIX line"
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
    FM_HOME="$C/home" FM_TEST_STUB="$STUB" FM_PR_EVIDENCE_GH="$FIX/gh" FM_PR_EVIDENCE_BITBUCKET_API="$STUB/bb/2.0" \
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
  [ "$(curl -sS -X POST "$STUB/_admin/state" | jq -r .bb_auth)" -gt 0 ] || fail "the Bitbucket credential was never sent"
  stub_post /_admin/pr "{\"key\":\"$PRKEY\",\"head\":\"$HEAD2\",\"author\":\"acct-worker\",\"files\":[\"bin/tool.sh\"]}"
  out=$(bbenv check t1 "$PRURL"); rc=$?
  expect_code 1 "$rc" "Bitbucket head drift"
  assert_contains "$out" "the PR changed after the evidence" "a moved Bitbucket head must refuse"
  pass "fm-pr-evidence: the Bitbucket arm is off by default; when on it uploads to Downloads and gates the same way"
}

test_annotation_tools_draw_marks() {
  local out rc
  if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
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
  assert_contains "$(cat "$C/ev/cap.txt")" '$ echo hello world' "capture-ui must keep the command"
  assert_contains "$(cat "$C/ev/cap.txt")" "(exit status 0)" "capture-ui must keep the exit status"
  pass "fm-pr-evidence: the annotate helpers draw marks that the gate's counter finds"
}

test_brief_block_and_list_commands_print() {
  local out
  new_case blocks
  out=$(ev brief-block task-x)
  assert_contains "$out" "# Evidence for review (hard rule)" "the worker contract heading"
  assert_contains "$out" "publish task-x <pr-url>" "the worker contract names publish with the task id"
  assert_contains "$out" "ASD-STE100" "the worker contract names the plain-English rule"
  out=$(ev help)
  assert_contains "$out" "fork-only (cloud-practitioner/firstmate); never offered upstream" "the header marks the script fork-only"
  pass "fm-pr-evidence: the worker contract and help print"
}

test_live_guard_against_the_sandbox() {
  local pr out rc dir
  pr=${FM_PR_EVIDENCE_LIVE_PR:-}
  if [ -z "$pr" ]; then
    echo "note: live guard skipped (set FM_PR_EVIDENCE_LIVE_PR to a PR URL in the private sandbox repository)"
    return 0
  fi
  dir="$TMP_ROOT/live"
  mkdir -p "$dir/home/state" "$dir/home/config" "$dir/proj" "$dir/ev"
  echo '* enforce' > "$dir/home/config/pr-evidence"
  fm_write_meta "$dir/home/state/t1.meta" "window=fm-t1" "endpoint_task_id=t1" "project=$dir/proj" "kind=ship" "mode=no-mistakes" "evidence=ui"
  python3 "$FIX/mkpng.py" "$dir/ev/b.png" 1 400
  python3 "$FIX/mkpng.py" "$dir/ev/a.png" 2 400
  cat > "$dir/ev/items.json" <<'EOF'
{"items":[{"id":"live","kind":"ui","purpose":"This is a synthetic test image. The gate must find it on the PR page.","before":{"image":"b.png"},"after":{"image":"a.png"},"labels":["Synthetic mark"]}]}
EOF
  out=$(FM_HOME="$dir/home" "$EV" publish t1 "$pr" "$dir/ev/items.json" 2>&1); rc=$?
  expect_code 0 "$rc" "live publish against the sandbox (got: $out)"
  assert_contains "$out" "[PASS] evidence gate" "the real upload must display and fetch"
  pass "fm-pr-evidence: live guard - real upload, display, and fetch on the sandbox PR"
}

test_gate_is_off_without_config_and_config_is_strict
test_intake_declares_the_kind
test_publish_posts_one_comment_that_passes_the_gate
test_head_drift_author_and_missing_comment_refuse
test_images_that_do_not_display_refuse
test_broken_or_swapped_images_refuse
test_marks_must_be_drawn
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
