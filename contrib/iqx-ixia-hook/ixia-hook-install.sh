#!/usr/bin/env bash
# ixia-hook-install.sh - install the Ixia commit-msg hook into named IQX
# Bitbucket clones of one firstmate home.
#
# Fork-only material for IQX Bitbucket repositories; see README in this
# directory. Bash 3.2 compatible.
#
# Usage: ixia-hook-install.sh <project>...
# Run from the firstmate home root whose projects/ holds the clones.
#   -h, --help    print this help
#
# For each project the script requires projects/<project> to be a git clone
# whose origin is bitbucket.org/iqxbusiness, resolves the clone's real hooks
# directory (an inherited command-scope core.hooksPath override, such as a
# firstmate pane's own strip directory, is ignored), and installs the bundled
# hook there as commit-msg, mode 755. It replaces an existing commit-msg only
# when it is byte-identical to the superseded v1 hook (sha256
# 39c0d3c1...e8472), treats an identical copy as already installed, refuses
# any other existing commit-msg and any clone whose configuration sets
# core.hooksPath, and is idempotent.
#
# Output: one line per project - "installed", "updated" (v1 upgraded to v2),
# "unchanged",
# "STOP <project>: <reason>" when refused without changes, or
# "FAIL <project>: <reason>" when a write failed.
# Exit: 0 every project is installed or unchanged; 1 any project refused or
# failed; 2 usage error or the bundled hook is unusable.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=contrib/iqx-ixia-hook/ixia-hook-lib.sh
. "$here/ixia-hook-lib.sh"

usage() {
  sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

projects=()
while [ $# -gt 0 ]; do
  case $1 in
  -h | --help) usage; exit 0 ;;
  --) shift; while [ $# -gt 0 ]; do projects+=("$1"); shift; done ;;
  -*) echo "ixia-hook-install: unknown option $1" >&2; exit 2 ;;
  *) projects+=("$1"); shift ;;
  esac
done
if [ "${#projects[@]}" -eq 0 ]; then
  echo "ixia-hook-install: name at least one project (see --help)" >&2
  exit 2
fi
home=$(pwd -P)
ixia_check_source || exit 2

rc=0
for p in "${projects[@]}"; do
  if ! ixia_resolve_clone "$home" "$p"; then
    echo "STOP $p: $IXIA_WHY"
    rc=1
    continue
  fi
  clone=$IXIA_CLONE
  if ! ixia_resolve_hooks_dir "$clone"; then
    echo "STOP $p: $IXIA_WHY"
    rc=1
    continue
  fi
  dest="$IXIA_HOOKS_DIR/commit-msg"
  action=installed
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ] || [ ! -f "$dest" ]; then
      echo "STOP $p: $dest exists and is not a regular file; not overwriting"
      rc=1
      continue
    elif cmp -s "$IXIA_HOOK_SRC" "$dest"; then
      if [ "$(ixia_mode "$dest")" != 755 ] && ! chmod 755 "$dest"; then
        echo "FAIL $p: could not set mode 755 on $dest"
        rc=1
        continue
      fi
      echo "unchanged $p -> $dest"
      continue
    elif [ "$(ixia_sha256 "$dest")" = "$IXIA_HOOK_V1_SHA256" ]; then
      action=updated
    else
      echo "STOP $p: $dest already exists and is neither this hook nor the v1 hook; not overwriting"
      rc=1
      continue
    fi
  fi
  if ! mkdir -p "$IXIA_HOOKS_DIR" || ! tmp=$(mktemp "$IXIA_HOOKS_DIR/.commit-msg.ixia.XXXXXX"); then
    echo "FAIL $p: cannot write under $IXIA_HOOKS_DIR"
    rc=1
    continue
  fi
  if cp "$IXIA_HOOK_SRC" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$dest"; then
    echo "$action $p -> $dest"
  else
    rm -f "$tmp"
    echo "FAIL $p: could not write $dest"
    rc=1
  fi
done
exit "$rc"
