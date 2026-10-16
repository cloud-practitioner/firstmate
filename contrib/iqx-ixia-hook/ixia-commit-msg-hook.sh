#!/bin/sh
# ixia-commit-msg-hook v2
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
#   - Works out the cleanup git will apply to the message after this hook
#     (strip, whitespace, scissors or verbatim) and judges the message as git
#     will commit it: the --cleanup flag when git's own command line shows it,
#     else commit.cleanup, else strip when an editor is used and whitespace
#     when it is not (git runs commit-msg with GIT_EDITOR=: then). So a
#     subject starting with # counts as text under git commit -m, and as a
#     comment under an editor.
#   - Leaves a message that git will treat as empty alone, so git still
#     aborts an empty commit.
#   - Removes every existing Ixia line from the message part (any letter case,
#     trailing blanks ignored; lines after git's scissors line are left alone)
#     and any blank lines at the very end of the message part, then appends
#     exactly one Ixia line as the last trailer with git interpret-trailers,
#     so the line is never duplicated and lands before git's scissors section.
#   - Never changes any other line, so human trailers stay exactly as written.
#   - Fails the commit (exit 1) when the message git will commit does not end
#     with exactly one Ixia line, rather than letting a commit land without it.
#
# Limits: a hook cannot see the --cleanup flag when git is started through a
# wrapper that hides its command line; and when GIT_EDITOR=: is exported to
# an editor session, the editor template in the message file is what tells
# the session apart from a no-editor commit.
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

# The --cleanup value on the command line of the git process that runs this
# hook (this hook is exec'd by git or by firstmate's chain, so it is our
# parent); prints nothing when it cannot be seen.
cleanup_flag() {
  if [ -r "/proc/$PPID/cmdline" ]; then
    parent_args=$(tr '\0' '\n' <"/proc/$PPID/cmdline" 2>/dev/null)
  else
    parent_args=$(ps -o args= -p "$PPID" 2>/dev/null | tr ' ' '\n')
  fi
  printf '%s\n' "$parent_args" | awk '
    NR == 1 { n = $0; sub(/.*\//, "", n); if (n != "git" && n != "git.exe") exit; next }
    want { print; exit }
    /^--clea(n(up?)?)?$/ { want = 1; next }
    /^--clea(n(up?)?)?=/ { sub(/^[^=]*=/, ""); print; exit }'
}

mode=$(cleanup_flag)
if [ -z "$mode" ]; then
  mode=$(git config --get commit.cleanup 2>/dev/null)
fi
case $mode in
strip | whitespace | verbatim | scissors) ;;
*)
  mode='strip'
  if [ "${GIT_EDITOR-}" = : ]; then
    mode=whitespace
    # GIT_EDITOR=: is also what an exported no-op editor looks like. An editor
    # session leaves git's template in the file, which always has a line that
    # is just the comment character, so treat that as an editor session.
    cc=$(git config --get core.commentChar 2>/dev/null)
    case $cc in '' | auto | ????*) cc='#' ;; esac
    if awk -v c="$cc" '$0 == c { f = 1 } END { exit !f }' "$msg"; then
      mode='strip'
    fi
  fi
  ;;
esac

# The part of the file git keeps as message: everything before the scissors
# line, then cleaned the way git cleans it for the chosen mode.
head_part() {
  awk -v s="$SCISSORS" 'length($0) >= length(s) && substr($0, length($0) - length(s) + 1) == s { exit } { print }' "$1"
}
kept_message() {
  case $mode in
  strip) head_part "$1" | git stripspace --strip-comments ;;
  verbatim) head_part "$1" ;;
  *) head_part "$1" | git stripspace ;;
  esac
}

if [ -z "$(kept_message "$msg" | tr -d ' \t\r\n')" ]; then
  exit 0
fi

work=$(mktemp -d "$msg.ixia.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT
want=$(printf '%s' "$IXIA_LINE" | tr '[:upper:]' '[:lower:]')
head_file="$work/head"
tail_file="$work/tail"

# Split at the scissors line; drop existing Ixia lines and trailing blank
# lines from the head.
if ! awk -v want="$want" -v s="$SCISSORS" -v headf="$head_file" -v tailf="$tail_file" '
  BEGIN { printf "" >headf; printf "" >tailf }
  !cut && length($0) >= length(s) && substr($0, length($0) - length(s) + 1) == s { cut = 1 }
  cut { print >tailf; next }
  { line = tolower($0); sub(/[ \t\r]+$/, "", line); if (line == want) next }
  $0 ~ /^[ \t\r]*$/ { blank = blank $0 "\n"; next }
  { printf "%s", blank >headf; blank = ""; print >headf }
' "$msg"; then
  echo "ixia commit-msg: could not split $msg" >&2
  exit 1
fi

# Where git keeps # lines as text (every mode but strip), tell
# interpret-trailers to use a comment character that no line starts with, so
# the new line lands after them instead of before.
comment_cfg=
if [ "$mode" != strip ]; then
  for c in ';' '@' '%' '~' '^' '&' '!' '|'; do
    if ! awk -v c="$c" 'substr($0, 1, 1) == c { f = 1 } END { exit !f }' "$head_file"; then
      comment_cfg=$c
      break
    fi
  done
  if [ -z "$comment_cfg" ]; then
    echo "ixia commit-msg: no free comment character for $msg" >&2
    exit 1
  fi
fi

if [ -n "$comment_cfg" ]; then
  git -c "core.commentChar=$comment_cfg" interpret-trailers --in-place --no-divider --where end \
    --if-exists add --if-missing add --trailer "$IXIA_LINE" "$head_file" || {
    echo "ixia commit-msg: git interpret-trailers failed" >&2
    exit 1
  }
else
  git interpret-trailers --in-place --no-divider --where end \
    --if-exists add --if-missing add --trailer "$IXIA_LINE" "$head_file" || {
    echo "ixia commit-msg: git interpret-trailers failed" >&2
    exit 1
  }
fi

if ! cat "$head_file" "$tail_file" >"$msg"; then
  echo "ixia commit-msg: could not rewrite $msg" >&2
  exit 1
fi

kept=$(kept_message "$msg" | sed '/^[ \t\r]*$/d')
count=$(printf '%s\n' "$kept" | grep -cxF "$IXIA_LINE")
last=$(printf '%s\n' "$kept" | tail -n 1)
if [ "$count" != 1 ] || [ "$last" != "$IXIA_LINE" ]; then
  echo "ixia commit-msg: the message does not end with exactly one '$IXIA_LINE' line" >&2
  exit 1
fi
exit 0
