#!/usr/bin/env bash
# ixia-hook-lib.sh - shared helpers for ixia-hook-install.sh and
# ixia-hook-verify.sh. Source it; it runs nothing by itself.
# Fork-only material: see README in this directory.
#
# shellcheck disable=SC2034 # IXIA_* result variables are read by the sourcing scripts.
#
# Bash 3.2 compatible (no mapfile, no associative arrays, no ${var,,}).

IXIA_HOOK_EXPECTED_SHA256='3fa6e564eda1ffa16cdc3623df15878c59ab7cd8f9eff74b53255e112fc06685'
# The previously approved v1 hook; the installer upgrades an exact copy of it.
IXIA_HOOK_V1_SHA256='39c0d3c156f1b8ba404dcd5797874947b22c07e82ed06ff15f5f6837a19e8472'
IXIA_HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
IXIA_HOOK_SRC="$IXIA_HOOK_DIR/ixia-commit-msg-hook.sh"

ixia_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Octal permission bits of a file (GNU stat, then BSD stat).
ixia_mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

# True when the bundled hook is present, matches the approved (v2) sha256 and parses.
ixia_check_source() {
  [ -f "$IXIA_HOOK_SRC" ] || { echo "STOP: bundled hook $IXIA_HOOK_SRC is missing" >&2; return 1; }
  [ "$(ixia_sha256 "$IXIA_HOOK_SRC")" = "$IXIA_HOOK_EXPECTED_SHA256" ] ||
    { echo "STOP: $IXIA_HOOK_SRC does not match the approved sha256 $IXIA_HOOK_EXPECTED_SHA256" >&2; return 1; }
  sh -n "$IXIA_HOOK_SRC" || { echo "STOP: $IXIA_HOOK_SRC does not parse" >&2; return 1; }
}

# True when the origin URL is one the hook acts on: the same shapes as the
# hook's own gate (case-insensitive bitbucket.org/iqxbusiness).
ixia_origin_is_iqx() {
  local lower
  lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case $lower in
  git@bitbucket.org:iqxbusiness/* | git@bitbucket.org-*:iqxbusiness/* | \
    ssh://git@bitbucket.org/iqxbusiness/* | ssh://git@bitbucket.org-*/iqxbusiness/* | \
    ssh://git@bitbucket.org:*/iqxbusiness/* | \
    https://bitbucket.org/iqxbusiness/* | https://*@bitbucket.org/iqxbusiness/*) return 0 ;;
  esac
  return 1
}

# Run a command with any inherited command-scope core.hooksPath override
# removed (firstmate panes carry one in GIT_CONFIG_COUNT/KEY_n/VALUE_n, and
# `git rev-parse --git-path hooks` would then name the pane's own strip
# directory instead of the repository's). Other GIT_CONFIG_* entries are kept.
# Usage: ixia_clean_git_env <command> [args...]
ixia_clean_git_env() {
  (
    count=${GIT_CONFIG_COUNT:-0}
    case $count in '' | *[!0-9]*) count=0 ;; esac
    keys=()
    vals=()
    i=0
    while [ "$i" -lt "$count" ]; do
      kvar="GIT_CONFIG_KEY_$i"
      vvar="GIT_CONFIG_VALUE_$i"
      key=${!kvar-}
      val=${!vvar-}
      lower=$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')
      if [ "$lower" != "core.hookspath" ]; then
        keys+=("$key")
        vals+=("$val")
      fi
      unset "$kvar" "$vvar"
      i=$((i + 1))
    done
    unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
    n=${#keys[@]}
    if [ "$n" -gt 0 ]; then
      j=0
      while [ "$j" -lt "$n" ]; do
        export "GIT_CONFIG_KEY_$j=${keys[$j]}" "GIT_CONFIG_VALUE_$j=${vals[$j]}"
        j=$((j + 1))
      done
      export GIT_CONFIG_COUNT="$n"
    fi
    "$@"
  )
}

# Resolve a project's clone. Sets IXIA_CLONE, IXIA_ORIGIN; returns nonzero
# with IXIA_WHY set when the project is not an IQX Bitbucket clone of the home.
ixia_resolve_clone() {
  local home=$1 project=$2 top
  IXIA_CLONE="$home/projects/$project"
  IXIA_ORIGIN=
  IXIA_WHY=
  case $project in '' | */* | . | ..) IXIA_WHY="not a plain project name"; return 1 ;; esac
  if [ ! -d "$IXIA_CLONE" ] || ! top=$(git -C "$IXIA_CLONE" rev-parse --show-toplevel 2>/dev/null); then
    IXIA_WHY="$IXIA_CLONE is not a git clone"
    return 1
  fi
  if [ "$(cd "$IXIA_CLONE" && pwd -P)" != "$(cd "$top" && pwd -P)" ]; then
    IXIA_WHY="$IXIA_CLONE is not the top level of a git clone"
    return 1
  fi
  IXIA_ORIGIN=$(ixia_clean_git_env git -C "$IXIA_CLONE" config --get remote.origin.url 2>/dev/null || true)
  if ! ixia_origin_is_iqx "$IXIA_ORIGIN"; then
    IXIA_WHY="origin is '${IXIA_ORIGIN:-none}', not bitbucket.org/iqxbusiness"
    return 1
  fi
  return 0
}

# Resolve the clone's real hooks directory. Sets IXIA_HOOKS_DIR; refuses when
# repository or user configuration redirects hooks with core.hooksPath.
ixia_resolve_hooks_dir() {
  local clone=$1 hp
  IXIA_HOOKS_DIR=
  IXIA_WHY=
  if hp=$(ixia_clean_git_env git -C "$clone" config --get core.hooksPath 2>/dev/null); then
    IXIA_WHY="configuration sets core.hooksPath=$hp; the hook belongs there instead"
    return 1
  fi
  if ! IXIA_HOOKS_DIR=$(ixia_clean_git_env git -C "$clone" rev-parse --path-format=absolute --git-path hooks 2>/dev/null) ||
    [ -z "$IXIA_HOOKS_DIR" ]; then
    IXIA_WHY="cannot resolve the hooks directory"
    return 1
  fi
  return 0
}
