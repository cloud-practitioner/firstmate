#!/usr/bin/env bash
# fm-mcp-posture-lib.sh - the worker MCP-server posture, sourced by
# bin/fm-spawn.sh and bin/fm-control.sh.
#
# docs/configuration.md "Worker MCP servers" owns the config/crew-mcp contract,
# the --mcp override, and the runtime-support table; bin/fm-spawn.sh's header
# owns the launch-flag mechanics. This file only parses, resolves, and checks.
# Unlike config/crew-exclude-tools, which only hides tools, the posture decides
# whether the worker's MCP servers are started at all: `off` makes a Pi worker
# launch without MCP support, so none of its helper processes exist.

# fm_mcp_posture_file <config-dir>: print the posture the home file declares
# (`on` or `off`), or nothing when the file is absent. Non-zero with the
# reason on stderr when the file is unreadable or holds anything else.
fm_mcp_posture_file() {
  local config=$1 file present value
  file=$config/crew-mcp
  present=$(perl -MErrno=ENOENT -e '
    if (lstat $ARGV[0]) { print 1 }
    elsif ($! == ENOENT) { print 0 }
    else { die "error: cannot inspect config/crew-mcp: $!\n" }
  ' -- "$file") || return 1
  [ "$present" = 1 ] || return 0
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "error: config/crew-mcp must be a readable regular file holding one of: on, off" >&2
    return 1
  fi
  value=$(tr -d '[:space:]' <"$file") || {
    echo "error: cannot read config/crew-mcp" >&2
    return 1
  }
  case "$value" in
  on | off) printf '%s' "$value" ;;
  *)
    echo "error: config/crew-mcp holds '$value'; accepted values are: on (the default when the file is absent), off (Pi workers start no MCP servers)" >&2
    return 1
    ;;
  esac
}

# fm_mcp_posture_select <config-dir> <kind> <override> <relaunch 0|1> <recorded>
# prints "<on|off> <explicit 0|1>": the effective posture and whether any
# input chose it (an explicit value is recorded in the task record, so an
# unconfigured home keeps byte-identical records). Precedence: the per-task
# override, then the value a relaunch finds in the task's own record, then the
# home file, then `on`. A relaunch whose record has no value keeps `on`, the
# posture that task was launched with. A secondmate agent is never covered, so
# an override on one is refused and the home file is not read for it.
fm_mcp_posture_select() {
  local config=$1 kind=$2 override=$3 relaunch=$4 recorded=$5 file value explicit=0
  case "$override" in
  '' | on | off) ;;
  *)
    echo "error: --mcp must be on or off (got '$override')" >&2
    return 1
    ;;
  esac
  if [ "$kind" = secondmate ]; then
    if [ -n "$override" ]; then
      echo "error: --mcp applies only to ship and scout workers; a secondmate's own agent is never covered by config/crew-mcp" >&2
      return 1
    fi
    printf 'on 0'
    return 0
  fi
  file=$(fm_mcp_posture_file "$config") || return 1
  value=on
  if [ -n "$override" ]; then
    value=$override
    explicit=1
  elif [ "$relaunch" = 1 ]; then
    case "$recorded" in
    on | off)
      value=$recorded
      explicit=1
      ;;
    '') ;;
    *)
      echo "error: the task record holds mcp=$recorded; accepted values are: on, off" >&2
      return 1
      ;;
    esac
  elif [ -n "$file" ]; then
    value=$file
    explicit=1
  fi
  printf '%s %s' "$value" "$explicit"
}

# fm_mcp_posture_check <harness> <raw-launch 0|1> <posture>: succeed when this
# launch can honor the posture (`on` always can); otherwise refuse naming the
# setting and the per-task way out. A raw launch command cannot be given the
# flag, and only Pi-family runtimes have a verified way to start without MCP.
fm_mcp_posture_check() {
  local harness=$1 raw=$2 posture=$3
  [ "$posture" = off ] || return 0
  if [ "$raw" = 1 ]; then
    echo "error: MCP servers are set off (config/crew-mcp or --mcp off), but a raw launch command cannot start without MCP servers; pass --mcp on for this task or launch a runtime that supports it (pi, pi-signed)" >&2
    return 1
  fi
  case "$harness" in
  pi | pi-signed) ;;
  *)
    echo "error: MCP servers are set off (config/crew-mcp or --mcp off), but the $harness runtime cannot start without MCP servers, so this launch is refused rather than running with them; pass --mcp on for this task or launch a runtime that supports it (pi, pi-signed)" >&2
    return 1
    ;;
  esac
}
