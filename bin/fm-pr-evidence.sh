#!/usr/bin/env bash
# PR evidence gate: before-and-after evidence for eligible pull requests.
#
# fork-only (cloud-practitioner/firstmate); never offered upstream.
#
# docs/configuration.md "PR evidence gate" owns eligibility, evidence requirements,
# exceptions, waivers, and setup. This header owns command syntax and publish input.
# The gate follows the workos/case model: refusals print [FAIL] and FIX lines.
#
# Usage: fm-pr-evidence.sh <command> ...
#   eligible <project> <mode> <forge> <proj-dir>
#                                         exit 0 for an enforced lane, 1 for an excluded lane, 2 for an error
#   intake <brief> <project> <mode> <forge> <proj-dir>
#                                         print evidence= meta lines for an eligible spawn, or refuse
#   brief-block <task-id> <project> <mode> <forge> <proj-dir>
#                                         print the eligible worker's evidence contract
#   check <task-id> <pr-url> [<merge-head>]
#                                         gate registration, or verify the exact head for an immediate merge
#   publish <task-id> <pr-url> <items.json>
#                                         validate, upload, post the one comment, then check
#   capture-ui --out <txt> -- <command>   run a command and keep a masked terminal transcript
#   capture-api --out <json> [-X M] [--header 'N: V']... [--body-file F] <url>
#                                         run one HTTP call and keep a masked six-part exchange
#   annotate-ui (--image <image> --mark x,y,w,h[,label] ... |
#                --text <txt> (--against <txt> | --mark-line <zero-based line> ...))
#               --purpose <text> [--label <text>]... --out <png>
#   annotate-api --sidecar <json> --against <json> --purpose <text> [--label <text>] --out <png>
#   ste [--kind purpose|label|steps] (--text <t> | --file <f>)
#                                         the plain-English check on its own
#   waive <task-id> <pr-url> --words <captain's words>
#                                         record a waiver; refused in away mode
#   list-unevidenced                      list recorded open eligible PRs with no evidence declaration
#
# Items file for publish (paths are relative to the file or absolute):
#   {"items":[{"id":"save-button","kind":"ui","purpose":"...",
#              "before":{"image":"b.png"},"after":{"image":"a.png"},
#              "labels":["Button is now blue"]},
#             {"id":"create-order","kind":"api","purpose":"...",
#              "before":{"image":"b.png","sidecar":"b.json"},
#              "after":{"image":"a.png","sidecar":"a.json"},"labels":["..."]}],
#    "none_reason":null}
# For a none declaration, use {"items":[],"none_reason":"<plain-English reason>"}.
# Omitting none_reason reuses the task's intake reason.
# Annotation commands save <png>.annotation.json beside each image; keep it with
# the image so publish can validate and record the drawn purpose and labels.
#
# Config: docs/configuration.md "PR evidence gate" owns config/pr-evidence.
# The helper bin/fm-pr-evidence-lib.py holds the pure parts: the plain-English
# check, masking, mark counting, rendering, comment composition, and the verifier.
# Notices and refusals go to stderr. Exit 0 is a pass or a skip with a notice,
# 1 is a refusal, 2 is a usage error.
# Overrides: FM_PR_EVIDENCE_GH (an explicit gh binary) and
# FM_PR_EVIDENCE_BITBUCKET_API (the test API base).
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
CONFIG_DIR="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"
CONFIG_FILE="$CONFIG_DIR/pr-evidence"
LIB_PY="$SCRIPT_DIR/fm-pr-evidence-lib.py"

# shellcheck source=bin/fm-pr-lib.sh
. "$SCRIPT_DIR/fm-pr-lib.sh"
. "$SCRIPT_DIR/fm-wake-lib.sh"
. "$SCRIPT_DIR/fm-role-lib.sh"
[ -z "${FM_PR_EVIDENCE_BITBUCKET_API:-}" ] || FM_PR_BITBUCKET_API=$FM_PR_EVIDENCE_BITBUCKET_API

WORK=
cleanup() {
  [ -z "$WORK" ] || rm -rf -- "$WORK"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

say() { printf '%s\n' "$*" >&2; }
fail_line() {  # <what> <fix>
  printf '[FAIL] %s\nFIX: %s\n' "$1" "$2" >&2
}
need_tools() {
  local missing=''
  command -v python3 >/dev/null 2>&1 || missing="python3"
  command -v jq >/dev/null 2>&1 || missing="${missing:+$missing, }jq"
  command -v curl >/dev/null 2>&1 || missing="${missing:+$missing, }curl"
  [ -z "$missing" ] || {
    fail_line "the evidence gate needs $missing on PATH" "install $missing, then run the command again"
    return 1
  }
}

meta_get() {  # <meta-file> <key>
  grep "^$2=" "$1" 2>/dev/null | tail -1 | cut -d= -f2- || true
}

# Sets CFG_JSON, CFG_ENABLED, CFG_REQUIRE, CFG_BITBUCKET for a project.
CFG_JSON='{}'
CFG_ENABLED=0
CFG_REQUIRE=0
CFG_BITBUCKET=0
load_config() {  # <project>
  CFG_JSON='{}'
  CFG_ENABLED=0
  CFG_REQUIRE=0
  CFG_BITBUCKET=0
  [ -e "$CONFIG_FILE" ] || [ -L "$CONFIG_FILE" ] || return 0
  if [ ! -f "$CONFIG_FILE" ]; then
    fail_line "configuration cannot be read: config/pr-evidence is not a regular file" "replace $CONFIG_FILE with a readable configuration file"
    return 1
  fi
  need_tools || return 1
  CFG_JSON=$(python3 "$LIB_PY" config "$CONFIG_FILE" "$1") || return 1
  if [ "$(printf '%s' "$CFG_JSON" | jq -r '.errors | length')" != 0 ]; then
    fail_line "config/pr-evidence is not valid: $(printf '%s' "$CFG_JSON" | jq -r '.errors[0]')" \
      "fix the line in $CONFIG_FILE (docs/configuration.md \"PR evidence gate\")"
    return 1
  fi
  [ "$(printf '%s' "$CFG_JSON" | jq -r .enabled)" != true ] || CFG_ENABLED=1
  [ "$(printf '%s' "$CFG_JSON" | jq -r .require)" != true ] || CFG_REQUIRE=1
  [ "$(printf '%s' "$CFG_JSON" | jq -r .bitbucket)" != true ] || CFG_BITBUCKET=1
}

# A project that always needs evidence: a `require` line, or the firstmate repository.
project_requires_evidence() {  # <project-dir>
  [ "$CFG_REQUIRE" != 1 ] || return 0
  [ -n "${1:-}" ] && [ -d "$1" ] || return 1
  fm_role_self_repo "$1" "$FM_ROOT" >/dev/null 2>&1
}

# ---- gh resolution ---------------------------------------------------------

GH=
resolve_gh_read() {
  # Keep a gh that resolve_gh_attach already picked; publish reads and uploads with one gh.
  [ -z "$GH" ] || return 0
  if [ -n "${FM_PR_EVIDENCE_GH:-}" ]; then
    GH=$FM_PR_EVIDENCE_GH
    return 0
  fi
  GH=$(command -v gh 2>/dev/null) || {
    fail_line "gh is not on PATH" "install the GitHub CLI and log in, then run the command again"
    return 1
  }
}
# Uploads need gh 2.99 or newer, which has `pr comment --attach`. An older gh can
# shadow a newer one on PATH, so every candidate is tried and the first that
# accepts the flag wins.
resolve_gh_attach() {
  local c
  while IFS= read -r c; do
    [ -x "$c" ] || continue
    if "$c" pr comment --help 2>&1 | grep -q -- '--attach'; then
      GH=$c
      return 0
    fi
  done <<EOF
$(type -ap gh 2>/dev/null || true)
EOF
  c=${FM_PR_EVIDENCE_GH:-}
  if [ -n "$c" ] && [ -x "$c" ] && "$c" pr comment --help 2>&1 | grep -q -- '--attach'; then
    GH=$c
    return 0
  fi
  fail_line "no gh with 'pr comment --attach' was found (gh 2.99 or newer)" \
    "install a newer gh on PATH or set FM_PR_EVIDENCE_GH to an executable that accepts --attach"
  return 1
}

# ---- config-facing commands ------------------------------------------------

EVIDENCE_SKIP_REASON=
evidence_eligible() {
  local project=$1 mode=$2 forge=$3 dir=$4 provider=${5:-} target
  EVIDENCE_SKIP_REASON="this delivery mode does not publish PR evidence"
  case "$mode" in no-mistakes|direct-PR) ;; *) return 1 ;; esac
  EVIDENCE_SKIP_REASON="forge=$forge does not use the PR evidence gate"
  [ "$forge" = none ] || return 1
  if [ -z "$provider" ]; then
    EVIDENCE_SKIP_REASON="the project's publication target is unknown"
    [ -n "$dir" ] && [ -d "$dir" ] || return 1
    target=$(fm_role_publication_target "$dir")
    case "$target" in
      github.com/*) provider=github ;;
      bitbucket.org/*) provider=bitbucket ;;
      *) provider=unsupported ;;
    esac
  fi
  EVIDENCE_SKIP_REASON="$provider pull requests are not supported by the evidence gate"
  case "$provider" in github|bitbucket) ;; *) return 1 ;; esac
  load_config "$project" || return 2
  EVIDENCE_SKIP_REASON=
  [ "$CFG_ENABLED" = 1 ] || return 1
  EVIDENCE_SKIP_REASON="the Bitbucket arm is off"
  if [ "$provider" = bitbucket ] && [ "$CFG_BITBUCKET" != 1 ]; then return 1; fi
  EVIDENCE_SKIP_REASON=
  return 0
}

cmd_eligible() {
  [ "$#" -eq 4 ] || { say "usage: fm-pr-evidence.sh eligible <project> <mode> <forge> <proj-dir>"; return 2; }
  evidence_eligible "$@"
}

cmd_intake() {
  [ "$#" -eq 5 ] || { say "usage: fm-pr-evidence.sh intake <brief> <project> <mode> <forge> <proj-dir>"; return 2; }
  local brief=$1 project=$2 mode=$3 forge=$4 dir=$5 body line value reason rc=0
  evidence_eligible "$project" "$mode" "$forge" "$dir" || rc=$?
  case "$rc" in 0) ;; 1) return 0 ;; *) return 1 ;; esac
  # shellcheck source=bin/fm-brief-heading-lib.sh
  . "$SCRIPT_DIR/fm-brief-heading-lib.sh"
  if ! fm_brief_task_heading_present "$brief" "## Evidence class"; then
    fail_line "the brief has no '## Evidence class' subsection, and the evidence gate is on for $project" \
      "scaffold the brief again with bin/fm-brief.sh and fill the subsection with ui, api, ui+api, or none: <reason>"
    return 1
  fi
  body=$(fm_brief_task_heading_body "$brief" "## Evidence class")
  line=$(printf '%s\n' "$body" | sed -n '/[^[:space:]]/{s/^[[:space:]]*//;s/[[:space:]]*$//;p;q;}')
  case "$line" in
    ''|'{EVIDENCE}')
      fail_line "the brief's '## Evidence class' is not filled" "write ui, api, ui+api, or none: <reason> under it"
      return 1
      ;;
    ui|api|ui+api)
      value=$line
      printf 'evidence=%s\n' "$value"
      ;;
    none:*)
      reason=${line#none:}
      reason=$(printf '%s' "$reason" | sed 's/^[[:space:]]*//')
      if [ -z "$reason" ]; then
        fail_line "the evidence class none has no reason" "write none: <reason in plain English>"
        return 1
      fi
      if project_requires_evidence "$dir"; then
        fail_line "the evidence class none is not allowed for $project (it always needs evidence)" \
          "declare ui (terminal screenshots of the changed behaviour) or api in the brief"
        return 1
      fi
      need_tools || return 1
      python3 "$LIB_PY" ste --kind purpose --text "$reason" >&2 || return 1
      printf 'evidence=none\nevidence_reason=%s\n' "$(printf '%s' "$reason" | tr '\n' ' ')"
      ;;
    *)
      fail_line "the evidence class '$line' is not valid" "write ui, api, ui+api, or none: <reason>"
      return 1
      ;;
  esac
}

cmd_brief_block() {
  [ "$#" -eq 5 ] || { say "usage: fm-pr-evidence.sh brief-block <task-id> <project> <mode> <forge> <proj-dir>"; return 2; }
  fm_pr_task_id_valid "$1" || return 2
  local rc=0 ev=$SCRIPT_DIR/fm-pr-evidence.sh
  evidence_eligible "$2" "$3" "$4" "$5" || rc=$?
  case "$rc" in 0) ;; 1) return 0 ;; *) return 1 ;; esac
  cat <<EOF

# Evidence for review (hard rule)
This project's PRs need before and after evidence. The gate refuses a PR without it.
Your evidence class is in the \`## Evidence class\` subsection above and in \`evidence=\` of your task record. You may add a kind. You may not remove one.
Use \`$ev\`. Its header has the exact commands.
1. Take the before evidence before you change anything. Keep all evidence files under your task temp root.
2. UI evidence: capture the screen (a screenshot, or \`capture-ui\` for terminal output) before and after. Mark the differences with \`annotate-ui\`.
3. API evidence: capture the HTTP exchange with \`capture-api\` before and after. It shows the request headers, request body, response headers, response body, status code, and status message. It masks secrets. Draw the image with \`annotate-api\`.
4. Write the purpose of each item in ASD-STE100 Simplified Technical English: short plain sentences, about 20 words or fewer, one idea each, active voice, no idioms, no semicolons, no contractions, no abbreviations. \`$ev ste\` checks your text.
5. Write an items file and run \`$ev publish $1 <pr-url> <items.json>\` after the PR exists (with no-mistakes: after CI is green). It posts the one evidence comment and then runs the gate.
6. The gate checks that every image shows on the PR page, matches its hash, and has marks drawn in the colour #FF2D95. If the PR head moves later, publish again.
7. Report the final PR-ready \`done\` only after \`publish\` prints \`[PASS]\`. The first \`done\` that hands off to no-mistakes needs no evidence. Never put real secrets, tokens, or personal data in an image.
EOF
}

# ---- forge reads -----------------------------------------------------------

PR_HEAD=
PR_AUTHORS_JSON='[]'
PR_FILES_JSON='[]'
PR_COMMENTS_JSON='[]'

read_github() {  # <owner/repo> <number>
  local path=$1 number=$2 pr files comments
  resolve_gh_read || return 1
  pr=$("$GH" api "repos/$path/pulls/$number" 2>/dev/null) || {
    fail_line "the PR cannot be read from GitHub" "check that gh is logged in and the PR exists"
    return 1
  }
  PR_HEAD=$(printf '%s' "$pr" | jq -r '.head.sha // empty')
  PR_AUTHORS_JSON=$(printf '%s' "$pr" | jq -c '[.user.login] | map(select(. != null and . != ""))')
  if ! files=$("$GH" api --paginate --slurp "repos/$path/pulls/$number/files?per_page=100" 2>/dev/null); then
    fail_line "the changed files of the PR cannot be read" "check that gh is logged in"
    return 1
  fi
  if ! printf '%s' "$files" | jq -e --argjson pr "$pr" '
    $pr.changed_files as $expected
    | if ($expected | type) != "number" or $expected < 0 or ($expected | floor) != $expected then false
      else [.[] | if type == "array" then .[] else error("invalid file page") end
                | if type == "object" then . else error("invalid file entry") end]
           | length == $expected
      end' >/dev/null 2>&1; then
    fail_line "the GitHub changed-file collection is incomplete or does not match changed_files" \
      "read the complete file collection or split the PR, then run the command again"
    return 1
  fi
  PR_FILES_JSON=$(printf '%s' "$files" | jq -c '[.[][] | .filename, .previous_filename | select(. != null)] | unique') || return 1
  if ! comments=$("$GH" api --paginate --slurp -H 'Accept: application/vnd.github.full+json' \
    "repos/$path/issues/$number/comments?per_page=100" 2>/dev/null) \
    || ! PR_COMMENTS_JSON=$(printf '%s' "$comments" | jq -c '[.[][] | {id: (.id | tostring), author: .user.login, body: .body, html: .body_html, updated: .updated_at}]'); then
    fail_line "the PR comments cannot be read" "check that gh is logged in"
    return 1
  fi
}

read_bitbucket() {  # <workspace/repo> <number>
  local path=$1 number=$2 head
  fm_pr_bitbucket_request GET "repositories/$path/pullrequests/$number" || {
    fail_line "the PR cannot be read from Bitbucket" "check NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN"
    return 1
  }
  head=$(printf '%s' "$FM_PR_BITBUCKET_BODY" | jq -r '.source.commit.hash // empty')
  PR_AUTHORS_JSON=$(printf '%s' "$FM_PR_BITBUCKET_BODY" | jq -c '[.author.account_id] | map(select(. != null))')
  PR_HEAD=$(fm_pr_bitbucket_resolve_commit "$path" "$head" 2>/dev/null || true)
  fm_pr_bitbucket_get_all "repositories/$path/pullrequests/$number/diffstat?pagelen=100" || {
    fail_line "the changed files of the PR cannot be read" "check the Bitbucket credential"
    return 1
  }
  PR_FILES_JSON=$(printf '%s' "$FM_PR_BITBUCKET_VALUES" | jq -c '[.[] | .new.path, .old.path | select(. != null)] | unique')
  fm_pr_bitbucket_get_all "repositories/$path/pullrequests/$number/comments?pagelen=100" || {
    fail_line "the PR comments cannot be read" "check the Bitbucket credential"
    return 1
  }
  PR_COMMENTS_JSON=$(printf '%s' "$FM_PR_BITBUCKET_VALUES" \
    | jq -c '[.[] | {id: (.id | tostring), author: .user.account_id, body: .content.raw, html: .content.html, updated: .updated_on}]')
}

# ---- the gate --------------------------------------------------------------

cmd_check() {
  [ "$#" -ge 2 ] && [ "$#" -le 3 ] || { say "usage: fm-pr-evidence.sh check <task-id> <pr-url> [<merge-head>]"; return 2; }
  local id=$1 raw=$2 expected=${3:-} meta project_dir project evidence reason require rc waiver forge
  if ! { fm_pr_task_id_valid "$id" && fm_pr_url_parse "$raw"; }; then
    say "error: invalid PR evidence check request"
    return 2
  fi
  meta="$STATE/$id.meta"
  [ -f "$meta" ] || { fail_line "task metadata for $id is unavailable" "run the check for a task of this home"; return 1; }
  [ "$(meta_get "$meta" kind)" = ship ] || return 0
  project_dir=$(meta_get "$meta" project)
  project=$(basename "$project_dir")
  forge=$(meta_get "$meta" forge)
  rc=0
  evidence_eligible "$project" "$(meta_get "$meta" mode)" "${forge:-none}" "$project_dir" "$FM_PR_PROVIDER" || rc=$?
  case "$rc" in
    0) ;;
    1) [ -z "$EVIDENCE_SKIP_REASON" ] || say "notice: evidence gate not applied: $EVIDENCE_SKIP_REASON"; return 0 ;;
    *) return 1 ;;
  esac
  evidence=$(meta_get "$meta" evidence)
  if [ -z "$evidence" ]; then
    say "notice: evidence gate not applied: task $id predates it (no evidence= in its task record); the captain may ask for a retrofit (fm-pr-evidence.sh list-unevidenced)"
    return 0
  fi
  waiver="$STATE/$id.evidence-waiver"
  if [ -f "$waiver" ] && [ "$(meta_get "$waiver" url)" = "$FM_PR_URL" ] \
    && [ "$(meta_get "$waiver" at | tr -cd '0-9')" = "$(meta_get "$waiver" at)" ] \
    && [ -n "$(meta_get "$waiver" at)" ] \
    && [ "$(meta_get "$waiver" words | wc -w | tr -d ' ')" -ge 4 ]; then
    say "notice: evidence gate waived for $id by the captain's words recorded in state/$id.evidence-waiver"
    return 0
  fi
  need_tools || return 1
  if [ "$FM_PR_PROVIDER" = github ]; then
    read_github "$FM_PR_PATH" "$FM_PR_NUMBER" || return 1
  else
    read_bitbucket "$FM_PR_PATH" "$FM_PR_NUMBER" || return 1
  fi
  if [ -z "$PR_HEAD" ]; then
    fail_line "the PR head cannot be read" "check the forge credential, then run the check again"
    return 1
  fi
  if [ -n "$expected" ]; then
    if [ "$FM_PR_PROVIDER" = bitbucket ]; then
      fail_line "Bitbucket cannot bind evidence to an exact merge head" "keep this PR open until an expected-head merge interface is available"
      return 1
    fi
    if [ "$PR_HEAD" != "$expected" ]; then
      fail_line "the evidence check head differs from the merge head" "check and publish evidence for the current PR head, then retry"
      return 1
    fi
  fi
  require=false
  if project_requires_evidence "$project_dir"; then require=true; fi
  reason=$(meta_get "$meta" evidence_reason)
  WORK=$(mktemp -d "$STATE/.pr-evidence.XXXXXX") || return 1
  jq -n --arg head "$PR_HEAD" --arg provider "$FM_PR_PROVIDER" --arg repo "$FM_PR_PATH" --arg url "$FM_PR_URL" \
    --argjson authors "$PR_AUTHORS_JSON" --argjson files "$PR_FILES_JSON" \
    '{head: $head, provider: $provider, repo: $repo, url: $url, authors: $authors, files: $files}' > "$WORK/pr.json"
  printf '%s\n' "$PR_COMMENTS_JSON" > "$WORK/comments.json"
  evidence=$(python3 "$LIB_PY" effective --declared "$evidence" --comments "$WORK/comments.json" --authors "$PR_AUTHORS_JSON") || return 1
  jq -n --arg declared "$evidence" --arg reason "$reason" --argjson require "$require" \
    --argjson globs "$(printf '%s' "$CFG_JSON" | jq -c .globs)" \
    '{declared: $declared, none_reason: $reason, require: $require, globs: $globs}' \
    > "$WORK/rules.json"
  rc=0
  python3 "$LIB_PY" verify --work "$WORK" >&2 || rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$expected" ]; then printf '%s\n' "$PR_HEAD"; fi
  return "$rc"
}

# ---- publish ---------------------------------------------------------------

bb_upload() {  # <workspace/repo> <file> <name>
  local path=$1 file=$2 name=$3 credential out code
  credential="$NO_MISTAKES_BITBUCKET_EMAIL:$NO_MISTAKES_BITBUCKET_API_TOKEN"
  credential=${credential//\\/\\\\}
  credential=${credential//\"/\\\"}
  out=$(printf 'user = "%s"\n' "$credential" \
    | curl -q -sS -K - -X POST --connect-timeout 10 --max-time 120 -w '\n%{http_code}' \
      -F "files=@$file;filename=$name" "$FM_PR_BITBUCKET_API/repositories/$path/downloads" 2>/dev/null) || return 1
  code=${out##*$'\n'}
  case "$code" in 2??) return 0 ;; esac
  return 1
}

cmd_publish() {
  [ "$#" -eq 3 ] || { say "usage: fm-pr-evidence.sh publish <task-id> <pr-url> <items.json>"; return 2; }
  local id=$1 raw=$2 items=$3 meta project evidence reason out new_id line path alt name body lock updated publisher forge rc=0
  local -a attach=() compose_extra=()
  if ! { fm_pr_task_id_valid "$id" && fm_pr_url_parse "$raw"; }; then
    say "error: invalid PR evidence publish request"
    return 2
  fi
  [ -f "$items" ] || { fail_line "the items file $items does not exist" "write the items file (see the header of fm-pr-evidence.sh)"; return 1; }
  meta="$STATE/$id.meta"
  [ -f "$meta" ] || { fail_line "task metadata for $id is unavailable" "run publish for a task of this home"; return 1; }
  project=$(basename "$(meta_get "$meta" project)")
  forge=$(meta_get "$meta" forge)
  evidence_eligible "$project" "$(meta_get "$meta" mode)" "${forge:-none}" "$(meta_get "$meta" project)" "$FM_PR_PROVIDER" || rc=$?
  case "$rc" in
    0) ;;
    1) fail_line "PR evidence is not enabled for this delivery lane${EVIDENCE_SKIP_REASON:+: $EVIDENCE_SKIP_REASON}" "complete this task's delivery contract without PR evidence"; return 1 ;;
    *) return 1 ;;
  esac
  evidence=$(meta_get "$meta" evidence)
  if [ -z "$evidence" ]; then
    fail_line "task $id has no evidence= declaration" "firstmate must declare the evidence class for the task first"
    return 1
  fi
  reason=$(meta_get "$meta" evidence_reason)
  [ -z "$reason" ] || compose_extra=(--default-none-reason "$reason")
  need_tools || return 1
  case "$FM_PR_PROVIDER" in
    github)
      resolve_gh_attach || return 1
      read_github "$FM_PR_PATH" "$FM_PR_NUMBER" || return 1
      publisher=$("$GH" api user --jq .login 2>/dev/null) || publisher=
      ;;
    bitbucket)
      read_bitbucket "$FM_PR_PATH" "$FM_PR_NUMBER" || return 1
      publisher=
      if fm_pr_bitbucket_request GET user; then
        publisher=$(printf '%s' "$FM_PR_BITBUCKET_BODY" | jq -r '.account_id // empty') || publisher=
      fi
      ;;
  esac
  if [ -z "$publisher" ] || ! printf '%s' "$PR_AUTHORS_JSON" | jq -e --arg publisher "$publisher" 'length == 1 and .[0] == $publisher' >/dev/null; then
    fail_line "only the PR author may publish evidence" "log in as the PR author and run publish again"
    return 1
  fi
  [ -n "$PR_HEAD" ] || { fail_line "the PR head cannot be read" "check the forge credential"; return 1; }
  WORK=$(mktemp -d "$STATE/.pr-evidence.XXXXXX") || return 1
  printf '%s\n' "$PR_COMMENTS_JSON" > "$WORK/comments.json"
  evidence=$(python3 "$LIB_PY" effective --declared "$evidence" --comments "$WORK/comments.json" --authors "$PR_AUTHORS_JSON") || return 1
  python3 "$LIB_PY" compose --items "$items" --head "$PR_HEAD" --declared "$evidence" \
    --provider "$FM_PR_PROVIDER" --repo "$FM_PR_PATH" --number "$FM_PR_NUMBER" \
    --out "$WORK" "${compose_extra[@]+"${compose_extra[@]}"}" >&2 || return 1
  if [ "$FM_PR_PROVIDER" = github ]; then
    while IFS=$'\t' read -r path alt name; do
      [ -z "$path" ] || attach+=(--attach "$path#$alt")
    done < "$WORK/attach.tsv"
    out=$("$GH" pr comment "$FM_PR_URL" --body-file "$WORK/comment.md" "${attach[@]+"${attach[@]}"}") || {
      fail_line "gh could not post the evidence comment" "check that gh is logged in with write access and is version 2.99 or newer"
      return 1
    }
    new_id=${out##*issuecomment-}
  else
    while IFS=$'\t' read -r path alt name; do
      [ -n "$path" ] || continue
      bb_upload "$FM_PR_PATH" "$path" "$name" || {
        fail_line "the image $name could not be uploaded to the repository Downloads area" "check the Bitbucket credential scope write:repository:bitbucket"
        return 1
      }
    done < "$WORK/attach.tsv"
    body=$(jq -Rs '{content: {raw: .}}' < "$WORK/comment.md")
    fm_pr_bitbucket_request POST "repositories/$FM_PR_PATH/pullrequests/$FM_PR_NUMBER/comments" "$body" || {
      fail_line "the evidence comment could not be posted to Bitbucket" "check the Bitbucket credential"
      return 1
    }
    new_id=$(printf '%s' "$FM_PR_BITBUCKET_BODY" | jq -r '.id | tostring')
  fi
  say "posted: evidence comment $new_id on $FM_PR_URL"
  lock=$(fm_meta_lock_path "$meta") || return 1
  fm_lock_acquire_wait "$lock" || return 1
  jq -n --arg body "$(< "$WORK/comment.md")" --argjson authors "$PR_AUTHORS_JSON" \
    '[{author: $authors[0], body: $body}]' > "$WORK/published.json"
  if ! updated=$(python3 "$LIB_PY" effective --declared "$(meta_get "$meta" evidence)" --comments "$WORK/published.json" --authors "$PR_AUTHORS_JSON") \
    || ! awk -v evidence="$updated" '/^evidence=/ { print "evidence=" evidence; next } { print }' "$meta" > "$WORK/meta" \
    || { grep -q '^pr=' "$WORK/meta" && ! (fm_pr_metadata_identity_parse "$WORK/meta"); } \
    || ! chmod 0600 "$WORK/meta" \
    || ! mv -f -- "$WORK/meta" "$meta"; then
    fm_lock_release "$lock"
    fail_line "the replacement task metadata is not valid or could not be saved" "repair the task metadata, then run publish again"
    return 1
  fi
  fm_lock_release "$lock"
  while IFS= read -r line; do
    { [ -n "$line" ] && [ "$line" != "$new_id" ]; } || continue
    if [ "$FM_PR_PROVIDER" = github ]; then
      "$GH" api -X DELETE "repos/$FM_PR_PATH/issues/comments/$line" >/dev/null 2>&1
    else
      fm_pr_bitbucket_request DELETE "repositories/$FM_PR_PATH/pullrequests/$FM_PR_NUMBER/comments/$line" >/dev/null 2>&1
    fi || {
      fail_line "the older evidence comment $line could not be removed" "remove that PR-author evidence comment and run publish again"
      return 1
    }
  done <<EOF
$(printf '%s' "$PR_COMMENTS_JSON" | jq -r --argjson a "$PR_AUTHORS_JSON" '.[] | select(.author as $x | $a | index($x)) | select((.body // "") | contains("```fm-pr-evidence-v1")) | .id')
EOF
  rm -rf -- "$WORK"
  WORK=
  cmd_check "$id" "$FM_PR_URL"
}

# ---- capture helpers -------------------------------------------------------

cmd_capture_ui() {
  local out='' rc=0 raw
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --out) out=${2:?}; shift 2 ;;
      --) shift; break ;;
      *) say "usage: fm-pr-evidence.sh capture-ui --out <txt> -- <command> [args...]"; return 2 ;;
    esac
  done
  [ -n "$out" ] && [ "$#" -gt 0 ] || { say "usage: fm-pr-evidence.sh capture-ui --out <txt> -- <command> [args...]"; return 2; }
  need_tools || return 1
  WORK=$(mktemp -d) || return 1
  raw="$WORK/raw"
  "$@" > "$raw" 2>&1 || rc=$?
  python3 "$LIB_PY" capture-text --raw "$raw" --rc "$rc" --out "$out" --command "$@"
}

cmd_capture_api() {
  local out='' method=GET body='' url='' cfg line
  local -a headers=() args=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --out) out=${2:?}; shift 2 ;;
      -X) method=${2:?}; shift 2 ;;
      --header) headers+=("${2:?}"); shift 2 ;;
      --body-file) body=${2:?}; shift 2 ;;
      -*) say "usage: fm-pr-evidence.sh capture-api --out <json> [-X M] [--header 'N: V']... [--body-file F] <url>"; return 2 ;;
      *) url=$1; shift ;;
    esac
  done
  [ -n "$out" ] && [ -n "$url" ] || { say "usage: fm-pr-evidence.sh capture-api --out <json> [-X M] [--header 'N: V']... [--body-file F] <url>"; return 2; }
  need_tools || return 1
  WORK=$(mktemp -d) || return 1
  cfg="$WORK/curl.cfg"
  : > "$cfg"
  chmod 0600 "$cfg"
  for line in "${headers[@]+"${headers[@]}"}"; do
    line=${line//\\/\\\\}
    printf 'header = "%s"\n' "${line//\"/\\\"}" >> "$cfg"
  done
  args=(-q -sS -v -K "$cfg" -X "$method" -D "$WORK/resp.hdr" -o "$WORK/resp.body" --max-time 30)
  [ -z "$body" ] || args+=(--data-binary "@$body")
  curl "${args[@]}" "$url" 2> "$WORK/verbose" || {
    fail_line "the HTTP call failed: $(tail -n 1 "$WORK/verbose" | sed 's/[Aa]uthorization.*//')" "check the URL and the network, then capture again"
    return 1
  }
  python3 "$LIB_PY" sidecar-build --verbose "$WORK/verbose" --resp-headers "$WORK/resp.hdr" --resp-body "$WORK/resp.body" \
    --method "$method" --url "$url" --out "$out" ${body:+--req-body "$body"}
  python3 "$LIB_PY" scan-sidecar "$out" >&2
}

# ---- waiver and retrofit list ----------------------------------------------

cmd_waive() {
  local id raw words='' meta project now body forge rc=0
  [ "$#" -ge 2 ] || { say "usage: fm-pr-evidence.sh waive <task-id> <pr-url> --words <captain's words>"; return 2; }
  id=$1
  raw=$2
  shift 2
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --words) words=${2:?}; shift 2 ;;
      *) say "usage: fm-pr-evidence.sh waive <task-id> <pr-url> --words <captain's words>"; return 2 ;;
    esac
  done
  if ! { fm_pr_task_id_valid "$id" && fm_pr_url_parse "$raw"; }; then
    say "error: invalid waiver request"
    return 2
  fi
  if [ -e "$STATE/.afk" ] && [ "$(fm_afk_mode "$STATE")" = away ]; then
    fail_line "a waiver is refused in away mode" "wait for the captain to return and say the waiver in their own words"
    return 1
  fi
  if [ "$(printf '%s' "$words" | wc -w | tr -d ' ')" -lt 4 ]; then
    fail_line "a waiver needs the captain's own words (at least 4 words)" "pass the captain's words exactly as written in the chat"
    return 1
  fi
  meta="$STATE/$id.meta"
  [ -f "$meta" ] || { fail_line "task metadata for $id is unavailable" "run the waiver for a task of this home"; return 1; }
  project=$(basename "$(meta_get "$meta" project)")
  forge=$(meta_get "$meta" forge)
  evidence_eligible "$project" "$(meta_get "$meta" mode)" "${forge:-none}" "$(meta_get "$meta" project)" "$FM_PR_PROVIDER" || rc=$?
  case "$rc" in
    0) ;;
    1) fail_line "PR evidence is not enabled for this delivery lane${EVIDENCE_SKIP_REASON:+: $EVIDENCE_SKIP_REASON}" "no evidence waiver is needed for this delivery lane"; return 1 ;;
    *) return 1 ;;
  esac
  need_tools || return 1
  now=$(date +%s)
  body="Evidence gate waived for this PR by the captain. The captain's words: ${words}"
  case "$FM_PR_PROVIDER" in
    github)
      resolve_gh_read || return 1
      "$GH" pr comment "$FM_PR_URL" --body "$body" >/dev/null || { fail_line "the waiver could not be posted on the PR" "check that gh is logged in"; return 1; }
      ;;
    bitbucket)
      fm_pr_bitbucket_request POST "repositories/$FM_PR_PATH/pullrequests/$FM_PR_NUMBER/comments" \
        "$(jq -n --arg raw "$body" '{content: {raw: $raw}}')" \
        || { fail_line "the waiver could not be posted on the PR" "check the Bitbucket credential"; return 1; }
      ;;
  esac
  umask 077
  printf 'at=%s\nurl=%s\nwords=%s\n' "$now" "$FM_PR_URL" "$(printf '%s' "$words" | tr '\n' ' ')" > "$STATE/$id.evidence-waiver"
  say "waived: $id (recorded in state/$id.evidence-waiver and posted on the PR)"
}

cmd_list_unevidenced() {
  local f id project url forge rc pr state count=0
  if [ ! -e "$CONFIG_FILE" ] && [ ! -L "$CONFIG_FILE" ]; then
    say "notice: config/pr-evidence is absent, so the evidence gate is off in this home"
    return 0
  fi
  need_tools || return 1
  load_config '*' || return 1
  for f in "$STATE"/*.meta; do
    [ -f "$f" ] || continue
    [ "$(meta_get "$f" kind)" = ship ] || continue
    url=$(meta_get "$f" pr)
    [ -n "$url" ] || continue
    [ -z "$(meta_get "$f" evidence)" ] || continue
    id=$(basename "$f" .meta)
    project=$(basename "$(meta_get "$f" project)")
    fm_pr_url_parse "$url" || continue
    forge=$(meta_get "$f" forge)
    rc=0
    evidence_eligible "$project" "$(meta_get "$f" mode)" "${forge:-none}" "$(meta_get "$f" project)" "$FM_PR_PROVIDER" || rc=$?
    case "$rc" in 0) ;; 1) continue ;; *) return 1 ;; esac
    if [ "$FM_PR_PROVIDER" = github ]; then
      resolve_gh_read || return 1
      pr=$("$GH" api "repos/$FM_PR_PATH/pulls/$FM_PR_NUMBER" 2>/dev/null) || {
        fail_line "the current PR state cannot be read: $url" "check the forge credential and run list-unevidenced again"
        return 1
      }
    else
      fm_pr_bitbucket_request GET "repositories/$FM_PR_PATH/pullrequests/$FM_PR_NUMBER" || {
        fail_line "the current PR state cannot be read: $url" "check the forge credential and run list-unevidenced again"
        return 1
      }
      pr=$FM_PR_BITBUCKET_BODY
    fi
    state=$(printf '%s' "$pr" | jq -er '.state | strings | ascii_upcase') || {
      fail_line "the current PR state is unavailable: $url" "check the forge response and run list-unevidenced again"
      return 1
    }
    case "$state" in
      OPEN) ;;
      CLOSED|MERGED|DECLINED|SUPERSEDED) continue ;;
      *) fail_line "the current PR state is not recognized: $url" "check the forge response and run list-unevidenced again"; return 1 ;;
    esac
    if [ "$count" -eq 0 ]; then
      say "These open PRs were made before the evidence gate. They pass with a notice. Pick the ones to retrofit."
    fi
    count=$((count + 1))
    printf '%s %s %s\n' "$id" "$project" "$url"
  done
  [ "$count" -gt 0 ] || say "No open PRs lack an evidence declaration."
}

# ---- dispatch --------------------------------------------------------------

usage() {
  sed -n '2,/^set -eu$/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
}

cmd=${1:-}
[ "$#" -eq 0 ] || shift
case "$cmd" in
  eligible) cmd_eligible "$@" ;;
  intake) cmd_intake "$@" ;;
  brief-block) cmd_brief_block "$@" ;;
  check) cmd_check "$@" ;;
  publish) cmd_publish "$@" ;;
  capture-ui) cmd_capture_ui "$@" ;;
  capture-api) cmd_capture_api "$@" ;;
  annotate-ui) need_tools && python3 "$LIB_PY" annotate-ui "$@" ;;
  annotate-api) need_tools && python3 "$LIB_PY" annotate-api "$@" ;;
  ste) need_tools && python3 "$LIB_PY" ste "$@" ;;
  waive) cmd_waive "$@" ;;
  list-unevidenced) cmd_list_unevidenced "$@" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
