#!/usr/bin/env bash
# Open, verify, and ready a Bitbucket Cloud pull request for a direct-PR worker.
#
# gh-axi is GitHub-only, so a direct-PR task on a Bitbucket Cloud project opens
# its pull request here instead; bin/fm-dod-lib.sh's direct-PR Definition of done
# names these commands for a project whose origin is Bitbucket Cloud and keeps
# gh-axi for every other one. The pull request is created, found, and read back
# through bin/fm-pr-lib.sh's Bitbucket REST helpers, under the same
# NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN credential that
# bin/fm-pr-merge.sh, bin/fm-pr-state.sh, and the no-mistakes pipeline use
# (docs/configuration.md "Bitbucket Cloud pull requests" owns it). There is no
# second HTTP client. A missing credential is reported by variable name only, and
# neither the token nor the authorization header is ever printed.
#
# Usage:
#   fm-pr-open.sh open
#   fm-pr-open.sh verify <pr-url>
#   fm-pr-open.sh ready  <pr-url>
#
# All commands operate on the current git work tree, its Bitbucket Cloud origin
# repository, and its current branch; a missing or non-Bitbucket origin and a
# detached HEAD are refused. A PR URL must name that origin repository.
# open creates a non-draft pull request from the current branch, which must
# already be pushed, to the repository's default destination. The title is the
# HEAD commit's subject and the description is its body. An open pull request
# for the same source repository and branch is reused rather than duplicated.
# An existing draft is refused, because opening never changes a pull request it
# did not create; "ready" is the explicit step that takes a draft out of draft. open
# always finishes with the same read-back verify performs, prints the pull
# request's https URL as its last line, and exits nonzero when the read-back
# fails.
#
# verify reads the pull request back and exits 0 only when it is open, not a
# draft, from the origin repository's current branch, and carries this work
# tree's HEAD, so a commit that was never pushed is refused. The <pr-url> is
# required. It prints "state:", "draft:", "source:", "head:",
# and "url:" lines, with "draft: no" on success mirroring `gh-axi pr view`.
#
# ready takes a pull request out of draft, then verifies it.
#
# Exit status: 0 success, 1 a refusal or failed read-back, 2 a usage error.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=bin/fm-pr-lib.sh
. "$SCRIPT_DIR/fm-pr-lib.sh"

usage() {
  sed -n '2,/^set -eu$/s/^# \{0,1\}//p' "$0" | sed '$d'
}

die() {
  printf 'fm-pr-open: %s\n' "$*" >&2
  exit 1
}

usage_error() {
  printf 'fm-pr-open: %s\n' "$*" >&2
  printf 'usage: fm-pr-open.sh open | verify <pr-url> | ready <pr-url> (see --help)\n' >&2
  exit 2
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  open|verify|ready) CMD=$1; shift ;;
  '') usage_error "a command is required" ;;
  *) usage_error "unknown command '$1'" ;;
esac

PR_ARG=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    -*) usage_error "unknown option '$1'" ;;
    *)
      [ -z "$PR_ARG" ] || usage_error "only one pull request URL is accepted"
      PR_ARG=$1
      shift ;;
  esac
done

case "$CMD" in
  open)
    [ -z "$PR_ARG" ] || usage_error "open takes no pull request URL; it finds or creates one"
    ;;
  verify|ready)
    [ -n "$PR_ARG" ] || usage_error "$CMD requires the pull request URL"
    ;;
esac

[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] \
  || die "the current directory is not a git work tree"

ORIGIN_URL=$(git remote get-url origin 2>/dev/null) \
  || die "this work tree has no origin remote"
REPO_PATH=$(fm_pr_bitbucket_remote_path "$ORIGIN_URL") \
  || die "the origin remote is not a Bitbucket Cloud repository"
if [ -n "$PR_ARG" ]; then
  fm_pr_url_parse "$PR_ARG" && [ "$FM_PR_PROVIDER" = bitbucket ] \
    || die "expected a Bitbucket Cloud pull request URL (https://bitbucket.org/<workspace>/<repository>/pull-requests/<number>)"
  [ "$REPO_PATH" = "$FM_PR_PATH" ] \
    || die "the pull request URL does not name this work tree's origin repository"
fi

SOURCE=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
  || die "this work tree is on a detached HEAD; check out the branch"
LOCAL_HEAD=$(git rev-parse --verify --quiet "HEAD^{commit}") \
  || die "this work tree has no commit to open a pull request for"

MISSING=$(fm_pr_bitbucket_missing_requirements)
[ -z "$MISSING" ] || die "talking to Bitbucket requires $MISSING"

# Say why a Bitbucket request failed without ever quoting the credential: only
# the HTTP status and Bitbucket's own error message are used.
api_failure() {  # <what>
  local what=$1 detail=''
  if [ -n "${FM_PR_BITBUCKET_STATUS:-}" ]; then
    detail=$(printf '%s' "$FM_PR_BITBUCKET_BODY" \
      | jq -r 'if type == "object" and (.error.message | type) == "string" then .error.message else "" end' 2>/dev/null \
      | head -c 300 || true)
    die "$what failed: Bitbucket answered HTTP $FM_PR_BITBUCKET_STATUS${detail:+ ($detail)}"
  fi
  die "$what failed: no usable response from Bitbucket"
}

pr_url() {  # <number>
  printf 'https://bitbucket.org/%s/pull-requests/%s' "$REPO_PATH" "$1"
}

# The lowest-numbered open pull request from the source branch, or nothing.
find_open_pr() {
  local query encoded
  query=$(jq -rn --arg b "$SOURCE" --arg r "$REPO_PATH" '
    "source.branch.name=" + ($b | tojson) + " AND source.repository.full_name=" + ($r | tojson) + " AND state=\"OPEN\""')
  encoded=$(jq -rn --arg q "$query" '$q | @uri')
  fm_pr_bitbucket_get_all "repositories/$REPO_PATH/pullrequests?state=OPEN&pagelen=50&q=$encoded" \
    || api_failure "listing the open pull requests for $SOURCE"
  printf '%s' "$FM_PR_BITBUCKET_VALUES" | jq -r --arg b "$SOURCE" --arg r "$REPO_PATH" '
    [.[] | select(.state == "OPEN" and .source.branch.name == $b
       and .source.repository.full_name == $r and (.id | type) == "number") | .id]
    | sort | (.[0] // "")' 2>/dev/null \
    || die "Bitbucket returned an unreadable pull request list"
}

read_pr() {  # <number>
  if fm_pr_bitbucket_read_pull_request "$REPO_PATH" "$1"; then
    printf '%s' "$FM_PR_BITBUCKET_JSON" | jq -e --arg r "$REPO_PATH" \
      '.source.repository.full_name == $r' >/dev/null 2>&1 \
      || die "$(pr_url "$1") does not come from this work tree's origin repository"
    [ "$FM_PR_BITBUCKET_SOURCE_BRANCH" = "$SOURCE" ] \
      || die "$(pr_url "$1") has source branch $FM_PR_BITBUCKET_SOURCE_BRANCH, not $SOURCE"
    return 0
  fi
  case "${FM_PR_BITBUCKET_STATUS:-}" in
    ''|2??) die "could not read $(pr_url "$1") back from Bitbucket (an unreadable or incomplete record)" ;;
  esac
  api_failure "reading $(pr_url "$1")"
}

# Read a pull request back and exit nonzero unless it is open, not a draft, from
# the source branch, and at this work tree's HEAD.
verify_pr() {  # <number>
  local number=$1 url problems=''
  url=$(pr_url "$number")
  read_pr "$number"
  printf 'state: %s\n' "$(printf '%s' "$FM_PR_BITBUCKET_STATE" | tr '[:upper:]' '[:lower:]')"
  case "$FM_PR_BITBUCKET_DRAFT" in
    false) printf 'draft: no\n' ;;
    true) printf 'draft: yes\n' ;;
    *) printf 'draft: unknown\n' ;;
  esac
  printf 'source: %s\n' "$FM_PR_BITBUCKET_SOURCE_BRANCH"
  printf 'destination: %s\n' "$FM_PR_BITBUCKET_DEST_BRANCH"
  printf 'head: %s\n' "$FM_PR_BITBUCKET_HEAD"
  printf 'url: %s\n' "$url"
  [ "$FM_PR_BITBUCKET_STATE" = OPEN ] \
    || problems="${problems}the pull request is $FM_PR_BITBUCKET_STATE, not open; "
  case "$FM_PR_BITBUCKET_DRAFT" in
    false) ;;
    true) problems="${problems}the pull request is a draft, so it cannot be merged; run fm-pr-open.sh ready $url; " ;;
    *) problems="${problems}Bitbucket reported no draft state; " ;;
  esac
  [ "$FM_PR_BITBUCKET_HEAD" = "$LOCAL_HEAD" ] \
    || problems="${problems}its head is $FM_PR_BITBUCKET_HEAD but this work tree's HEAD is $LOCAL_HEAD, so push your latest commit; "
  [ -z "$problems" ] || die "read-back of $url failed: ${problems%; }"
}

case "$CMD" in
  verify)
    verify_pr "$FM_PR_NUMBER"
    ;;
  ready)
    read_pr "$FM_PR_NUMBER"
    if [ "$FM_PR_BITBUCKET_DRAFT" != false ]; then
      fm_pr_bitbucket_request PUT "repositories/$REPO_PATH/pullrequests/$FM_PR_NUMBER" '{"draft":false}' \
        || api_failure "marking $PR_ARG ready"
    fi
    verify_pr "$FM_PR_NUMBER"
    ;;
  open)
    NUMBER=$(find_open_pr)
    if [ -n "$NUMBER" ]; then
      read_pr "$NUMBER"
      [ "$FM_PR_BITBUCKET_DRAFT" != true ] \
        || die "$(pr_url "$NUMBER") is already open from $SOURCE but is a draft; opening never changes a pull request it did not create, so run fm-pr-open.sh ready $(pr_url "$NUMBER") to take it out of draft"
      printf 'reusing the open pull request from %s\n' "$SOURCE" >&2
    else
      TITLE=$(git log -1 --format=%s HEAD)
      DESCRIPTION=$(git log -1 --format=%b HEAD)
      BODY=$(jq -cn --arg title "$TITLE" --arg description "$DESCRIPTION" --arg source "$SOURCE" '
        {title: $title, description: $description, draft: false,
         source: {branch: {name: $source}}}')
      fm_pr_bitbucket_request POST "repositories/$REPO_PATH/pullrequests" "$BODY" \
        || api_failure "creating the pull request from $SOURCE"
      NUMBER=$(printf '%s' "$FM_PR_BITBUCKET_BODY" | jq -r '
        if type == "object" and (.id | type) == "number" and .id > 0 then (.id | floor | tostring) else "" end' 2>/dev/null) \
        || NUMBER=
      case "$NUMBER" in
        ''|0*|*[!0-9]*) die "Bitbucket accepted the pull request but returned no usable id; run fm-pr-open.sh open again to find it from $SOURCE" ;;
      esac
    fi
    verify_pr "$NUMBER" >&2
    pr_url "$NUMBER"
    printf '\n'
    ;;
esac
