#!/usr/bin/env bash
# Run one firstmate script from the gate worktree against the lab home only.
exec env -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u TMUX \
  FM_HOME='/tmp/fm-lab.fka9Bl' TMUX_TMPDIR='/tmp/fm-lab.fka9Bl/tmux' PATH='/tmp/fm-lab.fka9Bl/bin':"$PATH" \
  NO_MISTAKES_BITBUCKET_EMAIL="${BB_EMAIL-captain@example.invalid}" \
  NO_MISTAKES_BITBUCKET_API_TOKEN="${BB_TOKEN-syn\"tok\\en-42}" \
  "/home/node/.no-mistakes/worktrees/450411b3e67c/01M3PAJ0WABS3J3HKA55KCZKXE/bin/$1" "${@:2}"
