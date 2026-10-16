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
#     exactly one Ixia line as the last trailer,
#     so the line is never duplicated and lands before git's scissors section.
#   - Never changes any other line, so human trailers stay exactly as written.
#   - Fails the commit (exit 1) when the message git will commit does not end
#     with exactly one Ixia line, rather than letting a commit land without it.
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

parent_arguments() {
  case $(uname -s) in
  Linux) tr '\n\000' '\r\n' <"/proc/$PPID/cmdline" ;;
  Darwin)
    command -v python3 >/dev/null 2>&1 || {
      echo "ixia commit-msg: macOS argument retrieval requires python3 on PATH" >&2
      return 1
    }
    python3 - "$PPID" <<'PY'
import ctypes
import os
import struct
import sys

libc = ctypes.CDLL(None, use_errno=True)
libc.sysctl.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_uint,
                       ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t),
                       ctypes.c_void_p, ctypes.c_size_t]
libc.sysctl.restype = ctypes.c_int
mib = (ctypes.c_int * 3)(1, 49, int(sys.argv[1]))
buffer = ctypes.create_string_buffer(os.sysconf("SC_ARG_MAX"))
size = ctypes.c_size_t(len(buffer))
if libc.sysctl(mib, 3, buffer, ctypes.byref(size), None, 0) != 0:
    raise OSError(ctypes.get_errno(), "sysctl(KERN_PROCARGS2)")
data = buffer.raw[:size.value]
argc = struct.unpack_from("i", data)[0]
start = data.index(b"\0", 4) + 1
while start < len(data) and data[start] == 0:
    start += 1
arguments = data[start:].split(b"\0")[:argc]
if argc < 1 or len(arguments) != argc or not arguments[0]:
    raise ValueError("incomplete KERN_PROCARGS2 argument list")
for argument in arguments:
    sys.stdout.buffer.write(argument.replace(b"\n", b"\r") + b"\n")
PY
    ;;
  *) return 1 ;;
  esac
}

if ! parent_args=$(parent_arguments) || [ -z "$parent_args" ]; then
  echo "ixia commit-msg: cannot read parent arguments; refusing to guess cleanup options" >&2
  exit 1
fi

mode=$(git config --get commit.cleanup 2>/dev/null || printf default)
editor=1
[ "${GIT_EDITOR-}" != : ] || editor=0
verbose=$(git config --bool --get commit.verbose 2>/dev/null || printf false)
options=$(printf '%s\n' "$parent_args" | awk -v mode="$mode" -v editor="$editor" -v verbose="$verbose" '
  BEGIN { names["message"] = "m"; names["file"] = "F"; names["reuse-message"] = "C"; names["fixup"] = "fixup" }
  NR == 1 { n = $0; sub(/.*\//, "", n); if (n != "git" && n != "git.exe") exit; next }
  skip { skip = 0; next }
  !command {
    if ($0 == "-c" || $0 == "-C" || $0 ~ /^--(config-env|git-dir|work-tree|namespace)$/) { skip = 1; next }
    if ($0 == "commit") { command = 1; editor = 1 }
    else if ($0 == "merge") command = 2
    else if ($0 !~ /^-/) exit
    next
  }
  operand {
    if (operand == "cleanup") mode = $0
    if (operand == "fixup") fixup_edit = ($0 ~ /^(amend|reword):/)
    operand = ""; next
  }
  $0 == "--" { exit }
  $0 == "--cleanup" { operand = "cleanup"; next }
  /^--cleanup=/ { mode = substr($0, 11); next }
  $0 == "--no-cleanup" { mode = "default"; next }
  $0 == "--edit" { edit = 1; edited = 1; next }
  $0 == "--no-edit" { edit = 0; edited = 1; next }
  $0 == "--verbose" { verbose = "true"; next }
  $0 == "--no-verbose" { verbose = "false"; next }
  /^--(message|file|reuse-message)(=|$)/ {
    name = $0; sub(/^--/, "", name); sub(/=.*/, "", name)
    source[names[name]] = 1; if ($0 !~ /=/) operand = "skip"; next
  }
  /^--no-(message|file|reuse-message|fixup)$/ { name = substr($0, 6); source[names[name]] = 0; next }
  /^--reedit-message(=|$)/ { if ($0 !~ /=/) operand = "skip"; next }
  $0 == "--fixup" { source["fixup"] = 1; operand = "fixup"; next }
  /^--fixup=/ { source["fixup"] = 1; fixup_edit = ($0 ~ /^--fixup=(amend|reword):/); next }
  command == 1 && /^--(author|date|squash|template|trailer|pathspec-from-file)$/ { operand = "skip"; next }
  command == 2 && /^--(strategy|strategy-option|into-name)$/ { operand = "skip"; next }
  /^-[^-]/ {
    flags = substr($0, 2)
    while (length(flags)) {
      flag = substr(flags, 1, 1); flags = substr(flags, 2)
      if (flag == "e") { edit = 1; edited = 1 }
      if (flag == "v") verbose = "true"
      if (command == 2 && flag ~ /^[sX]$/) {
        if (!length(flags)) operand = "skip"
        break
      }
      if (flag ~ /^[mFcCt]$/) {
        if (flag ~ /^[mFC]$/) source[flag] = 1
        if (!length(flags)) operand = "skip"
        break
      }
      if (flag == "S") break
    }
  }
  END {
    if (command == 1) editor = !(source["m"] || source["F"] || source["C"] || (source["fixup"] && !fixup_edit))
    if (command == 2) {
      if (source["m"] || source["F"]) editor = 0
      verbose = "false"
    }
    if (edited) editor = edit
    print mode, editor, verbose, command + 0
  }
')
read -r mode editor verbose caller <<EOF
$options
EOF
case $mode in
strip | whitespace | verbatim) ;;
scissors) [ "$editor" = 1 ] || mode='whitespace' ;;
*) if [ "$editor" = 1 ]; then mode='strip'; else mode='whitespace'; fi ;;
esac
cut=0
if [ "$mode" = scissors ] || [ "$verbose" = true ]; then cut=1; fi
cc=$(git config --get-regexp '^core\.comment(char|string)$' 2>/dev/null | tail -n 1 | cut -d ' ' -f 2-)
case $(printf '%s' "$cc" | tr '[:upper:]' '[:lower:]') in
'') cc='#' ;;
auto)
  echo "ixia commit-msg: automatic comment delimiters are unsupported; set an explicit core.commentChar or core.commentString" >&2
  exit 1
  ;;
esac
scissors="$cc$SCISSORS"

head_part() {
  if [ "$cut" = 1 ]; then
    awk -v s="$scissors" '$0 == s { exit } { print }' "$1"
  else
    cat "$1"
  fi
}
kept_message() {
  case $mode in
  strip) head_part "$1" | git stripspace --strip-comments ;;
  verbatim) head_part "$1" ;;
  *) head_part "$1" | git stripspace ;;
  esac
}

if [ "$caller" = 1 ] && [ "$mode" != verbatim ]; then
  message_bytes=$(kept_message "$msg" | LC_ALL=C sed '/^Signed-off-by: /d' | LC_ALL=C tr -d '[:space:]' | wc -c)
else
  message_bytes=$(kept_message "$msg" | wc -c)
fi
if [ "$message_bytes" -eq 0 ]; then
  exit 0
fi

work=$(mktemp -d "$msg.ixia.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT
want=$(printf '%s' "$IXIA_LINE" | tr '[:upper:]' '[:lower:]')
head_file="$work/head"
tail_file="$work/tail"

if ! LC_ALL=C awk -v want="$want" -v s="$scissors" -v truncate="$cut" -v strip="$mode" -v comment="$cc" \
  -v bytes="$(wc -c <"$msg")" -v headf="$head_file" -v tailf="$tail_file" '
  BEGIN { printf "" >headf; printf "" >tailf }
  {
    raw = $0 (offset + length($0) < bytes ? "\n" : "")
    offset += length(raw)
  }
  truncate && !cut && $0 == s {
    if (comments) printf "%s", pending >tailf
    pending = ""; comments = 0; cut = 1
  }
  cut { printf "%s", raw >tailf; next }
  { line = tolower($0); sub(/[ \t\r]+$/, "", line); if (line == want) next }
  strip == "strip" && substr($0, 1, length(comment)) == comment {
    pending = pending raw; comments = 1; next
  }
  $0 ~ /^[ \t\r]*$/ { pending = pending raw; next }
  { printf "%s%s", pending, raw >headf; pending = ""; comments = 0 }
  END { if (comments) printf "%s", pending >tailf }
' "$msg"; then
  echo "ixia commit-msg: could not split $msg" >&2
  exit 1
fi

set --
if [ "$mode" != strip ]; then
  comment_cfg=
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
  set -- -c "core.commentChar=$comment_cfg" -c "core.commentString=$comment_cfg"
fi

trailers=$(git "$@" interpret-trailers --parse --no-divider "$head_file") || {
  echo "ixia commit-msg: git interpret-trailers failed" >&2
  exit 1
}
if [ -s "$head_file" ]; then
  if [ "$(tail -c 1 "$head_file" | wc -l)" -eq 0 ]; then
    printf '\n' >>"$head_file" || exit 1
  fi
  if [ -z "$trailers" ]; then
    printf '\n' >>"$head_file" || exit 1
  fi
fi

if ! printf '%s\n' "$IXIA_LINE" >>"$head_file" || ! cat "$head_file" "$tail_file" >"$msg"; then
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
