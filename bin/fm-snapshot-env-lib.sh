#!/usr/bin/env bash
# bin/fm-snapshot-env-lib.sh - the single owner of which environment variables
# are scoped to one short read and must never reach a long-lived process.
#
# bin/fm-fleet-snapshot.sh hands bin/fm-crew-state.sh a captured copy of one
# task's records through FM_CREW_STATE_META_OVERRIDE and
# FM_CREW_STATE_STATUS_OVERRIDE, and the home-summary refresh passes its worker
# flags down the same chain. That read can reach the herdr CLI, and `herdr`
# auto-starts a server when none is listening; every pane that server later
# starts inherits its environment. A leaked override made every unmodified
# fm-crew-state read the same stale copy and report "no metadata" for each task.
#
# Two guards use this list:
#   - the herdr client boundary (bin/backends/herdr.sh fm_backend_herdr_exec)
#     strips the variables from the child it runs, so the leak path is closed
#     at the one place a server can be started;
#   - worker, second-mate, and relaunch spawns (bin/fm-spawn.sh) and watcher arm
#     (bin/fm-watch-arm.sh) clear them defensively, so a value already present
#     in an inherited environment does not reach an agent or a watcher.
#
# FM_SNAPSHOT_ONLY_ENV_NAMES are never legitimate in a launched agent's
# environment. FM_SNAPSHOT_PATH_ENV_NAMES (FM_STATE_OVERRIDE and friends) are
# test seams elsewhere, so they are scoped only when FM_SNAPSHOT_SCOPED_ENV=1
# marks the environment as a snapshot read.
#
# Sourced, not executed. Bash 3.2 compatible.

# shellcheck disable=SC2034  # consumed by the sourcing scripts
FM_SNAPSHOT_ONLY_ENV_NAMES=(
  FM_SNAPSHOT_SCOPED_ENV
  FM_CREW_STATE_META_OVERRIDE FM_CREW_STATE_STATUS_OVERRIDE
  FM_HOME_SUMMARY_IF_IDLE FM_HOME_SUMMARY_WORKER_BEST_EFFORT
  FM_HOME_SUMMARY_PARENT_ERROR FM_HOME_SUMMARY_PARENT_STAMP
)
# shellcheck disable=SC2034
FM_SNAPSHOT_PATH_ENV_NAMES=(
  FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE
  FM_PROJECTS_OVERRIDE FM_CONFIG_OVERRIDE
)

# fm_snapshot_env_strip_array: set FM_SNAPSHOT_ENV_STRIP_ARGS to one `-u NAME`
# pair for every scoped variable currently set, as arguments for `env`.
fm_snapshot_env_strip_array() {  # sets FM_SNAPSHOT_ENV_STRIP_ARGS
  local var
  FM_SNAPSHOT_ENV_STRIP_ARGS=()
  for var in "${FM_SNAPSHOT_ONLY_ENV_NAMES[@]}"; do
    [ -z "${!var+x}" ] || FM_SNAPSHOT_ENV_STRIP_ARGS+=(-u "$var")
  done
  if [ "${FM_SNAPSHOT_SCOPED_ENV:-}" = 1 ]; then
    for var in "${FM_SNAPSHOT_PATH_ENV_NAMES[@]}"; do
      [ -z "${!var+x}" ] || FM_SNAPSHOT_ENV_STRIP_ARGS+=(-u "$var")
    done
  fi
}

# fm_snapshot_env_clear: unset every scoped variable in the current shell,
# including the exported copy. The path overrides go only under the marker.
fm_snapshot_env_clear() {
  local var
  if [ "${FM_SNAPSHOT_SCOPED_ENV:-}" = 1 ]; then
    for var in "${FM_SNAPSHOT_PATH_ENV_NAMES[@]}"; do unset "$var"; done
  fi
  for var in "${FM_SNAPSHOT_ONLY_ENV_NAMES[@]}"; do unset "$var"; done
}

# fm_snapshot_env_unset_command: a shell command that unsets the always-scoped
# names, for a pane or launch command that starts an agent.
fm_snapshot_env_unset_command() {
  printf 'unset %s' "${FM_SNAPSHOT_ONLY_ENV_NAMES[*]}"
}
