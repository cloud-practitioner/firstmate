#!/usr/bin/env bash
set -u
cd /home/node/.no-mistakes/worktrees/c98b859efde5/01M469KHGAXW3MXGQ83EVZD7E8
export HOME="$PWD/.v/home" TMPDIR="$PWD/.v/tmp" RUNNER_TEMP="$PWD/.v/tmp"
export XDG_CONFIG_HOME=.v/c XDG_DATA_HOME="$PWD/.v/home/data" XDG_CACHE_HOME="$PWD/.v/home/cache"
export HERDR_CONFIG_PATH="$PWD/.v/config.toml" FM_HERDR_LAB_STATE_DIR="$PWD/.v/lab-state"
export FM_HOME="$PWD/.v/fmhome"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_CONFIG_OVERRIDE FM_DATA_OVERRIDE FM_PROJECTS_OVERRIDE
export FM_REAL_HERDR="${FM_REAL_HERDR:-/home/node/.local/bin/herdr}"
export PATH="$PWD/.v/bin:$PATH"
exec "$@"
