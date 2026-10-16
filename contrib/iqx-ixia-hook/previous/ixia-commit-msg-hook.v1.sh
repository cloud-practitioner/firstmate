#!/bin/sh
# ixia-commit-msg-hook v1
# Ixia attribution commit-msg hook for iqxbusiness Bitbucket repositories.
#
# The Ixia architecture contract requires every commit message on an IQX
# Bitbucket repository to end with exactly the line in IXIA_LINE below.
# Firstmate's fleet commit-msg hook strips AI co-author trailers (this line
# included, because it names noreply@anthropic.com) and then runs this
# repository's own commit-msg hook with the same message file, so this hook
# puts the line back after the strip.
#
# What it does:
#   - Acts only when remote.origin.url names bitbucket.org/iqxbusiness, in the
#     same URL shapes the machine's identity includeIf rules recognise;
#     anywhere else it exits 0 without touching the message.
#   - Leaves an empty message alone, so git still aborts an empty commit.
#   - Removes every existing Ixia line from the message part (any letter case,
#     trailing blanks ignored; lines after git's scissors line are left alone)
#     and any blank lines at the very end of the file, then appends exactly one
#     Ixia line as the last trailer with git interpret-trailers, so the line is
#     never duplicated and lands before git's comment and scissors sections.
#   - Never changes any other line, so human trailers stay exactly as written.
#   - Fails the commit (exit 1) when the result does not end with exactly one
#     Ixia line, rather than letting a commit land without it.
#
# Install: copy to <clone>/.git/hooks/commit-msg with mode 755. Linked
# worktrees, including every treehouse pool slot, resolve hooks from the
# clone's common git directory, so one copy per clone covers every current and
# future slot. git commit --no-verify skips this hook (and firstmate's strip).
set -u

IXIA_LINE='Co-Authored-By: Ixia Engineering (Claude) <noreply@anthropic.com>'
SCISSORS=' ------------------------ >8 ------------------------'

msg=${1:-}
if [ -z "$msg" ] || [ ! -f "$msg" ]; then
  echo "ixia commit-msg: no commit message file given" >&2
  exit 1
fi

origin=$(git config --get remote.origin.url 2>/dev/null | tr '[:upper:]' '[:lower:]')
case $origin in
git@bitbucket.org:iqxbusiness/* | git@bitbucket.org-*:iqxbusiness/* | \
  ssh://git@bitbucket.org/iqxbusiness/* | ssh://git@bitbucket.org-*/iqxbusiness/* | \
  ssh://git@bitbucket.org:*/iqxbusiness/* | \
  https://bitbucket.org/iqxbusiness/* | https://*@bitbucket.org/iqxbusiness/*) ;;
*) exit 0 ;;
esac

# The message git will keep: everything before the scissors line, without
# comment lines or surrounding blank lines.
message_part() {
  awk -v s="$SCISSORS" 'length($0) >= length(s) && substr($0, length($0) - length(s) + 1) == s { exit } { print }' "$msg" |
    git stripspace --strip-comments
}

if [ -z "$(message_part)" ]; then
  exit 0
fi

want=$(printf '%s' "$IXIA_LINE" | tr '[:upper:]' '[:lower:]')
tmp=$(mktemp "$msg.ixia.XXXXXX") || exit 1
trap 'rm -f "$tmp"' EXIT
if ! awk -v want="$want" -v s="$SCISSORS" '
  length($0) >= length(s) && substr($0, length($0) - length(s) + 1) == s { cut = 1 }
  !cut { line = tolower($0); sub(/[ \t\r]+$/, "", line); if (line == want) next }
  !cut && $0 ~ /^[ \t\r]*$/ { blank = blank $0 "\n"; next }
  { printf "%s", blank; blank = ""; print }
' "$msg" >"$tmp" || ! cat "$tmp" >"$msg"; then
  echo "ixia commit-msg: could not rewrite $msg" >&2
  exit 1
fi

if ! git interpret-trailers --in-place --no-divider --where end \
  --if-exists add --if-missing add --trailer "$IXIA_LINE" "$msg"; then
  echo "ixia commit-msg: git interpret-trailers failed" >&2
  exit 1
fi

kept=$(message_part)
count=$(printf '%s\n' "$kept" | grep -cxF "$IXIA_LINE")
last=$(printf '%s\n' "$kept" | tail -n 1)
if [ "$count" != 1 ] || [ "$last" != "$IXIA_LINE" ]; then
  echo "ixia commit-msg: the message does not end with exactly one '$IXIA_LINE' line" >&2
  exit 1
fi
exit 0
