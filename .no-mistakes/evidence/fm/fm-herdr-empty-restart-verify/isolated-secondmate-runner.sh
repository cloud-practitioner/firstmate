#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/node/.no-mistakes/worktrees/450411b3e67c/01M55ZEBSTEQDE51HBJ3XNZ6TR
D="$ROOT/.test-herdr-runtime"
export PROOT_NO_SECCOMP=1 PROOT_TMP_DIR="$D/tmp"
export XDG_CONFIG_HOME=/fm-config HOME="$D/home" TMPDIR="$D/tmp" SHELL=/bin/sh ENV= HISTFILE=/dev/null
export FM_HERDR_LAB_STATE_DIR="$D/tripwires"
unset HERDR_CONFIG_PATH HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
exec "$D/tools/legacy-syscalls" "$D/tools/proot" -b "$D/config:/fm-config" -b /home/node/.config/herdr/herdr.sock:/fm-config/herdr/herdr.sock -b "$D/virtual-main:/fm-main" -b "$D/virtual-alpha:/fm-alpha" -b "$D/virtual-beta:/fm-beta" -w "$ROOT" "$@"
