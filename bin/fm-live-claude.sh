#!/usr/bin/env bash
# fm-live-claude.sh - the single owner of running a REAL Claude Code inside a
# live or end-to-end scenario with updater-path isolation for the host's
# installed launcher.
#
# Usage:
#   fm-live-claude.sh shim <dir>
#   <dir>/claude [claude args...]
#
# shim creates <dir> and prints it. Put it first on PATH (or launch
# "<dir>/claude" by its absolute path, which is what a pane command should do),
# and every `claude` the scenario starts - directly, through bin/fm-spawn.sh, or
# from another Claude - runs the real binary this host has, resolved once when
# the shim was made, like this:
#   - DISABLE_AUTOUPDATER=1 and DISABLE_UPDATES=1, so the native updater never
#     runs.
#   - HOME is a scratch directory under <dir>/homes: a symlink mirror of the
#     caller's HOME (so the normal login, settings, trust, and transcripts under
#     ~/.claude and ~/.claude.json behave as they do today) with private
#     .local and .cache directories. XDG_DATA_HOME, XDG_STATE_HOME, and
#     XDG_CACHE_HOME point inside it and XDG_BIN_HOME is unset. The host ~/.local,
#     where Claude's native installer keeps its launcher (~/.local/bin/claude)
#     and its versions, is therefore not an updater destination even if something
#     ignores the updater switches.
#   - PATH starts with <dir>, and the caller's ~/.local/bin entry is replaced by
#     the scratch ~/.local/bin, a mirror of it whose claude is this shim.
#   - the real binary is exec'd under the name claude, so process names and
#     argv[0] stay what a real launch shows.
# Each guarded invocation exports FM_LIVE_CLAUDE_SHIM=<dir>, including an
# absolute-path launch without an inherited marker, so later fm-spawn.sh calls
# can restore the shim in daemon-created panes whose PATH did not inherit it.
# The shim refuses to run if the scratch HOME is, or resolves to, the caller's.
# This is updater-path isolation, not a filesystem sandbox: mirrored HOME
# entries still share the caller's files, including credentials and transcripts.
#
# Sandboxing only XDG_DATA_HOME or CLAUDE_CONFIG_DIR leaves the native updater
# able to re-point the host ~/.local/bin/claude at a disposable versions folder;
# cleanup can then leave the host launcher dangling. In a manual scenario, never
# create, re-point, or delete anything under the real ~/.local, and check that
# readlink ~/.local/bin/claude is unchanged before and after the scenario.
# tests/lib.sh's fm_live_gate and bin/fm-live-lab.sh install this shim for every
# live scenario they open, bin/fm-spawn.sh carries it into a spawned claude
# pane, and .no-mistakes.yaml's Test instructions name it for an agent that
# improvises a scenario. tests/fm-live-claude-isolation.test.sh is the
# regression.
#
# Override for tests: FM_LIVE_CLAUDE_REAL=<absolute path> at shim time pins the
# binary instead of searching PATH.
set -u

die() { echo "fm-live-claude: $*" >&2; exit 1; }

real_path() {  # <path> -> its fully resolved absolute path, nothing if it does not resolve
  perl -MCwd=realpath -e '$p = realpath($ARGV[0]); defined($p) or exit 1; print "$p\n"' "$1" 2>/dev/null
}

SELF=$(real_path "${BASH_SOURCE[0]}") || die "cannot resolve this script"

# find_real <shim-dir>: the first executable claude on PATH that is not a shim.
find_real() {
  local skip=$1 entry cand resolved entry_real
  local -a entries
  IFS=: read -r -a entries <<< "$PATH"
  for entry in "${entries[@]}"; do
    [ -n "$entry" ] || continue
    entry_real=$(real_path "$entry") || continue
    [ "$entry_real" != "$skip" ] || continue
    cand=$entry/claude
    [ -f "$cand" ] && [ -x "$cand" ] || continue
    resolved=$(real_path "$cand") || continue
    [ "$resolved" != "$SELF" ] || continue
    printf '%s\n' "$resolved"
    return 0
  done
  return 1
}

make_shim() {
  local dir=${1:-} real
  [ -n "$dir" ] || die "usage: fm-live-claude.sh shim <dir>"
  mkdir -p "$dir/homes" "$dir/real" || die "cannot create $dir"
  dir=$(cd -P -- "$dir" && pwd -P) || die "cannot resolve $dir"
  if [ -n "${FM_LIVE_CLAUDE_REAL:-}" ]; then
    case "$FM_LIVE_CLAUDE_REAL" in /*) ;; *) die "FM_LIVE_CLAUDE_REAL must be an absolute path" ;; esac
    real=$(real_path "$FM_LIVE_CLAUDE_REAL") || die "FM_LIVE_CLAUDE_REAL does not resolve: $FM_LIVE_CLAUDE_REAL"
    [ -x "$real" ] || die "FM_LIVE_CLAUDE_REAL is not executable: $real"
  else
    real=$(find_real "$dir") || die "no executable claude on PATH to guard"
  fi
  printf '%s\n' "$real" > "$dir/.real.$$" || die "cannot record the real claude"
  mv -f "$dir/.real.$$" "$dir/.real" || die "cannot record the real claude"
  ln -sfn "$real" "$dir/real/claude" || die "cannot link the real claude"
  ln -sfn "$SELF" "$dir/claude" || die "cannot create the shim"
  printf '%s\n' "$dir"
}

# mirror_link <source-dir> <name> <sandbox-dir>: make <sandbox-dir>/<name> a
# symlink to <source-dir>/<name> unless it already is one.
mirror_link() {
  [ -L "$3/$2" ] || ln -sfn "$1/$2" "$3/$2"
}

run_shim() {
  local shimdir real src sb key entry name newpath=''
  local -a entries
  shimdir=$(cd -P -- "$(dirname -- "$0")" && pwd -P) || die "cannot resolve the shim directory"
  [ -f "$shimdir/.real" ] || die "$shimdir carries no recorded claude; make it with fm-live-claude.sh shim"
  real=$(cat "$shimdir/.real")
  [ -x "$shimdir/real/claude" ] || die "the real claude ($real) is no longer executable"
  [ -n "${HOME:-}" ] || die "HOME is not set"

  case "$HOME" in
    "$shimdir"/homes/*) src=$(cat "$HOME/.fm-live-claude-src" 2>/dev/null) || die "unreadable scratch HOME record in $HOME" ;;
    *) src=$(real_path "$HOME") || die "HOME does not resolve: $HOME" ;;
  esac
  key=$(printf '%s' "$src" | cksum | awk '{print $1}')
  sb=$shimdir/homes/$key
  [ "$sb" != "$src" ] && [ "$(real_path "$sb" || echo "$sb")" != "$src" ] \
    || die "refusing: the scratch HOME would be the caller's HOME ($src)"

  mkdir -p "$sb/.local/bin" "$sb/.local/share" "$sb/.local/state" "$sb/.cache" \
    || die "cannot create the scratch HOME $sb"
  [ ! -L "$sb/.local" ] && [ ! -L "$sb/.local/bin" ] || die "refusing: $sb/.local is a symlink"
  printf '%s\n' "$src" > "$sb/.fm-live-claude-src"

  shopt -s nullglob dotglob
  for entry in "$src"/*; do
    name=${entry##*/}
    case "$name" in .local | .cache | .fm-live-claude-src) continue ;; esac
    mirror_link "$src" "$name" "$sb"
  done
  for entry in "$src/.local/bin"/*; do
    name=${entry##*/}
    [ "$name" != claude ] || continue
    mirror_link "$src/.local/bin" "$name" "$sb/.local/bin"
  done
  shopt -u nullglob dotglob
  ln -sfn "$shimdir/claude" "$sb/.local/bin/claude"

  IFS=: read -r -a entries <<< "$PATH"
  for entry in "${entries[@]}"; do
    [ -n "$entry" ] || continue
    [ "$entry" != "$shimdir" ] || continue
    case "$entry" in
      "$src/.local/bin" | "$HOME/.local/bin") entry=$sb/.local/bin ;;
    esac
    newpath=${newpath:+$newpath:}$entry
  done

  export HOME="$sb" XDG_DATA_HOME="$sb/.local/share" XDG_STATE_HOME="$sb/.local/state" XDG_CACHE_HOME="$sb/.cache"
  unset XDG_BIN_HOME
  export DISABLE_AUTOUPDATER=1 DISABLE_UPDATES=1
  export FM_LIVE_CLAUDE_SHIM="$shimdir" PATH="$shimdir${newpath:+:$newpath}"
  exec -a claude "$shimdir/real/claude" "$@"
}

case "$(basename -- "$0")" in
  claude) run_shim "$@" ;;
esac
case "${1:-}" in
  shim) shift; make_shim "$@" ;;
  *) echo "usage: fm-live-claude.sh shim <dir>" >&2; exit 2 ;;
esac
