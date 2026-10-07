#!/usr/bin/env bash
# fm-exclude-tools-lib.sh - the single owner of the opt-in per-home worker tool
# exclusion list, config/crew-exclude-tools.
#
# docs/configuration.md "Worker tool exclusions" owns the operator-facing
# contract. Sourced by bin/fm-spawn.sh and bin/fm-control.sh.
#
# The list names tools a home's ship and scout workers must not be able to use,
# for example MCP write tools. It is runtime-neutral: every runtime either
# hides the listed tools or the launch refuses, so a non-empty list is never
# silently ignored. Runtimes that can hide tools, and how:
#   pi, pi-signed   --exclude-tools '<comma-joined names>'
# Every other runtime, and a raw launch command, refuses a non-empty list.
# Secondmate agents are not covered and neither read nor refuse on the file.
#
# One tool name per line; blank lines and lines beginning with # are ignored
# and surrounding whitespace is trimmed. A name may use only letters, digits,
# _ . and -. Shape is checked here; the Pi worker extension checks its own
# loaded-tool registry and reports unmatched entries as unverified in task
# status. Firstmate never connects to servers to validate the list.
# An absent file is an empty list; an unreadable or nonregular file, or any
# malformed entry, is an error rather than a partial list.

# fm_exclude_tools_names <config-dir>: print the comma-joined names, empty when
# the file is absent or lists nothing. Non-zero with the reason on stderr when
# the file or an entry is invalid.
fm_exclude_tools_names() {
  local config=$1 file line names= present
  file=$config/crew-exclude-tools
  present=$(perl -MErrno=ENOENT -e '
    if (lstat $ARGV[0]) { print 1 }
    elsif ($! == ENOENT) { print 0 }
    else { die "error: cannot inspect config/crew-exclude-tools: $!\n" }
  ' -- "$file") || return 1
  [ "$present" = 1 ] || return 0
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "error: config/crew-exclude-tools must be a readable regular file" >&2
    return 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    case "$line" in
    '' | '#'*) continue ;;
    esac
    if [ -n "${line//[A-Za-z0-9_.-]/}" ]; then
      echo "error: config/crew-exclude-tools has a malformed entry '$line'; expected one tool name per line using only letters, digits, _ . and - (blank lines and # comment lines are allowed)" >&2
      return 1
    fi
    names="${names:+$names,}$line"
  done <"$file"
  printf '%s' "$names"
}

# fm_exclude_tools_check <harness> <raw-launch 0|1> <config-dir>: succeed when
# this launch can honor the home's list (empty list, or a runtime that hides
# tools); otherwise refuse naming the file. Prints the names on stdout.
fm_exclude_tools_check() {
  local harness=$1 raw=$2 config=$3 names
  names=$(fm_exclude_tools_names "$config") || return 1
  if [ -n "$names" ]; then
    if [ "$raw" = 1 ]; then
      echo "error: config/crew-exclude-tools lists tools to hide, but a raw launch command cannot hide tools; remove the entries or launch a runtime that supports them (pi, pi-signed)" >&2
      return 1
    fi
    case "$harness" in
    pi | pi-signed) ;;
    *)
      echo "error: config/crew-exclude-tools lists tools to hide, but the $harness runtime cannot hide tools, so this launch is refused rather than running with them available; empty the file or launch a runtime that supports exclusion (pi, pi-signed)" >&2
      return 1
      ;;
    esac
  fi
  printf '%s' "$names"
}
