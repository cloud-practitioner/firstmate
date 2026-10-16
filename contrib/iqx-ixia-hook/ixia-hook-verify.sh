#!/usr/bin/env bash
# ixia-hook-verify.sh - verify the Ixia commit-msg hook in named IQX
# Bitbucket clones of one firstmate home, without creating a commit in them.
#
# Fork-only material for IQX Bitbucket repositories; see README in this
# directory. Bash 3.2 compatible.
#
# Usage: ixia-hook-verify.sh <project>...
# Run from the firstmate home root whose projects/ holds the clones.
#   -h, --help    print this help
#
# For each project the script checks that projects/<project> is a clone whose
# origin is bitbucket.org/iqxbusiness, that no configuration redirects its
# hooks, that the real hooks directory holds commit-msg with mode 755 and the
# bundled (v2) hook's sha256, that every linked worktree of the clone resolves to
# the same hooks, and that the installed hook leaves exactly one Ixia line,
# last, in two probe messages (one with human trailers, one whose subject
# starts with #). The probe is a throwaway commit in a temporary
# repository (same origin URL, a copy of the installed hook); the real clone
# is only read.
#
# Output: "ok <project> (<n> worktrees share <hook>)" or "FAIL <project>:
# <reason>" per project. Exit: 0 every project ok; 1 any failure; 2 usage
# error or the bundled hook is unusable.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=contrib/iqx-ixia-hook/ixia-hook-lib.sh
. "$here/ixia-hook-lib.sh"

IXIA='Co-Authored-By: Ixia Engineering (Claude) <noreply@anthropic.com>'
JANE='Co-Authored-By: Jane Doe <jane@example.com>'

usage() {
  sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

projects=()
while [ $# -gt 0 ]; do
  case $1 in
  -h | --help) usage; exit 0 ;;
  --) shift; while [ $# -gt 0 ]; do projects+=("$1"); shift; done ;;
  -*) echo "ixia-hook-verify: unknown option $1" >&2; exit 2 ;;
  *) projects+=("$1"); shift ;;
  esac
done
if [ "${#projects[@]}" -eq 0 ]; then
  echo "ixia-hook-verify: name at least one project (see --help)" >&2
  exit 2
fi
home=$(pwd -P)
ixia_check_source || exit 2

work=$(mktemp -d "${TMPDIR:-/tmp}/ixia-hook-verify.XXXXXX")
trap 'rm -rf "$work"' EXIT

# Throwaway commit in a temporary repository: prints the resulting message.
# Usage: probe_commit <hook> <origin> file|hash
probe_commit() {
  local hook=$1 origin=$2 kind=$3 repo="$work/probe-repo"
  rm -rf "$repo"
  mkdir -p "$repo"
  ixia_clean_git_env git -C "$repo" init -q || return 1
  ixia_clean_git_env git -C "$repo" remote add origin "$origin" || return 1
  mkdir -p "$repo/.git/hooks"
  cp "$hook" "$repo/.git/hooks/commit-msg" && chmod 755 "$repo/.git/hooks/commit-msg" || return 1
  printf 'VERIFY-1: probe\n\n%s\n%s\n\nMiddle line.\n' "$JANE" "$IXIA" >"$work/probe-msg"
  if [ "$kind" = hash ]; then
    # A subject starting with # under git commit -m is message text, not a comment.
    ixia_clean_git_env git -C "$repo" \
      -c "core.hooksPath=$repo/.git/hooks" -c user.name=ixia-verify -c user.email=ixia-verify@example.invalid \
      -c commit.gpgsign=false commit -q --allow-empty --cleanup=whitespace -m '#VERIFY-2: hash subject' >/dev/null || return 1
  else
    ixia_clean_git_env git -C "$repo" \
      -c "core.hooksPath=$repo/.git/hooks" -c user.name=ixia-verify -c user.email=ixia-verify@example.invalid \
      -c commit.gpgsign=false commit -q --allow-empty --cleanup=whitespace -F "$work/probe-msg" >/dev/null || return 1
  fi
  ixia_clean_git_env git -C "$repo" log -1 --format=%B
}

rc=0
for p in "${projects[@]}"; do
  why=
  if ! ixia_resolve_clone "$home" "$p"; then
    why=$IXIA_WHY
  elif ! ixia_resolve_hooks_dir "$IXIA_CLONE"; then
    why=$IXIA_WHY
  fi
  clone=$IXIA_CLONE
  dest=${IXIA_HOOKS_DIR:+$IXIA_HOOKS_DIR/commit-msg}
  if [ -z "$why" ]; then
    if [ ! -f "$dest" ]; then
      why="hook missing: $dest"
    elif [ ! -x "$dest" ] || [ "$(ixia_mode "$dest")" != 755 ]; then
      why="hook mode is $(ixia_mode "$dest"), not 755 (a non-executable hook is skipped silently): $dest"
    elif [ "$(ixia_sha256 "$dest")" = "$IXIA_HOOK_V1_SHA256" ]; then
      why="hook is the superseded v1 hook; re-run ixia-hook-install.sh to upgrade it: $dest"
    elif [ "$(ixia_sha256 "$dest")" != "$IXIA_HOOK_EXPECTED_SHA256" ]; then
      why="hook differs from the bundled hook: $dest"
    fi
  fi
  # Every linked worktree (each treehouse pool slot) must share this hooks dir.
  nwt=0
  if [ -z "$why" ]; then
    wtlist=$(git -C "$clone" worktree list --porcelain | sed -n 's/^worktree //p')
    while IFS= read -r wt; do
      [ -n "$wt" ] || continue
      [ -d "$wt" ] || continue
      nwt=$((nwt + 1))
      if ! ixia_resolve_hooks_dir "$wt" || [ "$IXIA_HOOKS_DIR/commit-msg" != "$dest" ]; then
        why="worktree $wt resolves hooks ${IXIA_HOOKS_DIR:-?} ${IXIA_WHY:+($IXIA_WHY)}"
        break
      fi
    done <<EOT
$wtlist
EOT
  fi
  if [ -z "$why" ]; then
    if ! out=$(probe_commit "$dest" "$IXIA_ORIGIN" file); then
      why="probe commit failed"
    else
      kept=$(printf '%s\n' "$out" | sed '/^$/d')
      if [ "$(printf '%s\n' "$kept" | tail -n 1)" != "$IXIA" ] ||
        [ "$(printf '%s\n' "$kept" | grep -cxF "$IXIA")" != 1 ] ||
        ! printf '%s\n' "$kept" | grep -qxF "$JANE"; then
        why="probe result wrong: $(printf '%s' "$kept" | tr '\n' '|')"
      fi
    fi
  fi
  if [ -z "$why" ]; then
    if ! out=$(probe_commit "$dest" "$IXIA_ORIGIN" hash); then
      why="hash-subject probe commit failed"
    else
      kept=$(printf '%s\n' "$out" | sed '/^$/d')
      if [ "$(printf '%s\n' "$kept" | tail -n 1)" != "$IXIA" ] ||
        [ "$(printf '%s\n' "$kept" | grep -cxF "$IXIA")" != 1 ] ||
        [ "$(printf '%s\n' "$kept" | head -n 1)" != '#VERIFY-2: hash subject' ]; then
        why="hash-subject probe result wrong: $(printf '%s' "$kept" | tr '\n' '|')"
      fi
    fi
  fi
  if [ -z "$why" ]; then
    echo "ok $p ($nwt worktrees share $dest)"
  else
    echo "FAIL $p: $why"
    rc=1
  fi
done
exit "$rc"
