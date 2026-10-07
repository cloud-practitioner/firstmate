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
#   fm-pr-open.sh open   [--title <t>] [--description <d>] [--dest <branch>] [common]
#   fm-pr-open.sh verify [<pr-url>] [--dest <branch>] [common]
#   fm-pr-open.sh ready  <pr-url> [common]
# Common options:
#   --worktree <dir>   the git work tree the branch lives in (default: here)
#   --source <branch>  the source branch (default: the work tree's current branch)
#   --repo <w>/<r>     the Bitbucket repository (default: parsed from origin)
#
# open creates a non-draft pull request from the source branch, which must
# already be pushed, to --dest (default: the repository's main branch). The title
# defaults to the HEAD commit's subject and the description to its body. An open
# pull request for the same source branch is reused rather than duplicated, and
# an existing one that targets another branch than an explicit --dest, or that
# is a draft, is refused, because opening never changes a pull request it did not
# create; "ready" is the explicit step that takes a draft out of draft. open
# always finishes with the same read-back verify performs, prints the pull
# request's https URL as its last line, and exits nonzero when the read-back
# fails.
#
# verify reads the pull request back and exits 0 only when it is open, not a
# draft, from the source branch, and carries this work tree's HEAD, so a commit
# that was never pushed is refused. It finds the pull request by <pr-url> or, with
# none, by the source branch. It prints "state:", "draft:", "source:", "head:",
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
  printf 'usage: fm-pr-open.sh open|verify|ready [options] (see --help)\n' >&2
  exit 2
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  open|verify|ready) CMD=$1; shift ;;
  '') usage_error "a command is required" ;;
  *) usage_error "unknown command '$1'" ;;
esac

WORKTREE=.
SOURCE=
REPO_PATH=
DEST=
TITLE=
DESCRIPTION=
DESCRIPTION_SET=0
PR_ARG=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --worktree|--source|--repo|--dest|--title|--description)
      [ "$#" -ge 2 ] || usage_error "$1 requires a value"
      case "$1" in
        --worktree) WORKTREE=$2 ;;
        --source) SOURCE=$2 ;;
        --repo) REPO_PATH=$2 ;;
        --dest) DEST=$2 ;;
        --title) TITLE=$2 ;;
        --description) DESCRIPTION=$2; DESCRIPTION_SET=1 ;;
      esac
      shift 2 ;;
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
  verify)
    [ -z "$TITLE" ] && [ "$DESCRIPTION_SET" -eq 0 ] || usage_error "--title and --description apply only to open"
    ;;
  ready)
    [ -n "$PR_ARG" ] || usage_error "ready requires the pull request URL"
    [ -z "$TITLE" ] && [ "$DESCRIPTION_SET" -eq 0 ] && [ -z "$DEST" ] \
      || usage_error "ready takes only a pull request URL and the common options"
    ;;
esac

git -C "$WORKTREE" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "$WORKTREE is not a git work tree"

MISSING=$(fm_pr_bitbucket_missing_requirements)
[ -z "$MISSING" ] || die "talking to Bitbucket requires $MISSING"

# The pull request, when named, fixes the repository; otherwise --repo or the
# origin remote does. The remote's URL is never printed, because it can carry
# userinfo.
if [ -n "$PR_ARG" ]; then
  fm_pr_url_parse "$PR_ARG" && [ "$FM_PR_PROVIDER" = bitbucket ] \
    || die "expected a Bitbucket Cloud pull request URL (https://bitbucket.org/<workspace>/<repository>/pull-requests/<number>)"
  if [ -n "$REPO_PATH" ] && [ "$REPO_PATH" != "$FM_PR_PATH" ]; then
    die "--repo disagrees with the repository in the pull request URL"
  fi
  REPO_PATH=$FM_PR_PATH
elif [ -z "$REPO_PATH" ]; then
  ORIGIN_URL=$(git -C "$WORKTREE" remote get-url origin 2>/dev/null) \
    || die "this work tree has no origin remote; pass --repo <workspace>/<repository>"
  REPO_PATH=$(fm_pr_bitbucket_remote_path "$ORIGIN_URL") \
    || die "the origin remote is not a Bitbucket Cloud repository; pass --repo <workspace>/<repository> to name one"
fi
fm_pr_bitbucket_path_valid "$REPO_PATH" \
  || die "the repository must be <workspace>/<repository> in Bitbucket's lowercase spelling"

if [ -z "$SOURCE" ]; then
  SOURCE=$(git -C "$WORKTREE" symbolic-ref --quiet --short HEAD 2>/dev/null) \
    || die "this work tree is on a detached HEAD; check out the branch or pass --source"
fi
git check-ref-format --branch "$SOURCE" >/dev/null 2>&1 || die "'$SOURCE' is not a valid branch name"
if [ -n "$DEST" ]; then
  git check-ref-format --branch "$DEST" >/dev/null 2>&1 || die "'$DEST' is not a valid branch name"
fi
LOCAL_HEAD=$(git -C "$WORKTREE" rev-parse --verify --quiet "HEAD^{commit}") \
  || die "this work tree has no commit to open a pull request for"

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
  query="source.branch.name=\"$SOURCE\" AND state=\"OPEN\""
  encoded=$(jq -rn --arg q "$query" '$q | @uri')
  fm_pr_bitbucket_get_all "repositories/$REPO_PATH/pullrequests?state=OPEN&pagelen=50&q=$encoded" \
    || api_failure "listing the open pull requests for $SOURCE"
  printf '%s' "$FM_PR_BITBUCKET_VALUES" | jq -r --arg b "$SOURCE" '
    [.[] | select(.state == "OPEN" and .source.branch.name == $b and (.id | type) == "number") | .id]
    | sort | (.[0] // "")' 2>/dev/null \
    || die "Bitbucket returned an unreadable pull request list"
}

read_pr() {  # <number>
  fm_pr_bitbucket_read_pull_request "$REPO_PATH" "$1" && return 0
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
  [ "$FM_PR_BITBUCKET_SOURCE_BRANCH" = "$SOURCE" ] \
    || problems="${problems}its source branch is $FM_PR_BITBUCKET_SOURCE_BRANCH, not $SOURCE; "
  [ "$FM_PR_BITBUCKET_HEAD" = "$LOCAL_HEAD" ] \
    || problems="${problems}its head is $FM_PR_BITBUCKET_HEAD but this work tree's HEAD is $LOCAL_HEAD, so push your latest commit; "
  if [ -n "$DEST" ] && [ "$FM_PR_BITBUCKET_DEST_BRANCH" != "$DEST" ]; then
    problems="${problems}it targets $FM_PR_BITBUCKET_DEST_BRANCH, not $DEST; "
  fi
  [ -z "$problems" ] || die "read-back of $url failed: ${problems%; }"
}

number_for_command() {
  if [ -n "$PR_ARG" ]; then
    printf '%s' "$FM_PR_NUMBER"
  else
    find_open_pr
  fi
}

case "$CMD" in
  verify)
    NUMBER=$(number_for_command)
    [ -n "$NUMBER" ] || die "no open pull request from $SOURCE in $REPO_PATH; run fm-pr-open.sh open"
    verify_pr "$NUMBER"
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
      if [ -n "$DEST" ] && [ "$FM_PR_BITBUCKET_DEST_BRANCH" != "$DEST" ]; then
        die "$(pr_url "$NUMBER") is already open from $SOURCE but targets $FM_PR_BITBUCKET_DEST_BRANCH, not $DEST; opening never retargets a pull request"
      fi
      [ "$FM_PR_BITBUCKET_DRAFT" != true ] \
        || die "$(pr_url "$NUMBER") is already open from $SOURCE but is a draft; opening never changes a pull request it did not create, so run fm-pr-open.sh ready $(pr_url "$NUMBER") to take it out of draft"
      printf 'reusing the open pull request from %s\n' "$SOURCE" >&2
    else
      [ -n "$TITLE" ] || TITLE=$(git -C "$WORKTREE" log -1 --format=%s HEAD)
      [ "$DESCRIPTION_SET" -eq 1 ] || DESCRIPTION=$(git -C "$WORKTREE" log -1 --format=%b HEAD)
      BODY=$(jq -cn --arg title "$TITLE" --arg description "$DESCRIPTION" --arg source "$SOURCE" --arg dest "$DEST" '
        {title: $title, description: $description, draft: false,
         source: {branch: {name: $source}}}
        + (if $dest == "" then {} else {destination: {branch: {name: $dest}}} end)')
      fm_pr_bitbucket_request POST "repositories/$REPO_PATH/pullrequests" "$BODY" \
        || api_failure "creating the pull request from $SOURCE"
      NUMBER=$(printf '%s' "$FM_PR_BITBUCKET_BODY" | jq -r '
        if type == "object" and (.id | type) == "number" and .id > 0 then (.id | floor | tostring) else "" end' 2>/dev/null) \
        || NUMBER=
      case "$NUMBER" in
        ''|0*|*[!0-9]*) die "Bitbucket accepted the pull request but returned no usable id; look for it from $SOURCE with fm-pr-open.sh verify" ;;
      esac
    fi
    verify_pr "$NUMBER" >&2
    pr_url "$NUMBER"
    printf '\n'
    ;;
esac
