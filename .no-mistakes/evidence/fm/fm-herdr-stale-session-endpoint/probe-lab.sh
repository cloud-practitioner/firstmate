#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
export HOME=.live-validation/user XDG_CONFIG_HOME=.live-validation/user/.config
export HERDR_CONFIG_PATH="$ROOT/.live-validation/config.toml"
export FM_HERDR_LAB_STATE_DIR="$ROOT/.live-validation/tripwires"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION HERDR_CLIENT_SOCKET_PATH
mkdir -p "$HOME/.config/herdr"
ln -s /home/node/.config/herdr/herdr.sock "$HOME/.config/herdr/herdr.sock"
cat > "$HERDR_CONFIG_PATH" <<'EOF'
onboarding = false
[terminal]
default_shell = "/bin/bash"
shell_mode = "non_login"
[update]
version_check = false
manifest_check = false
EOF
SESSION=$(bin/fm-herdr-lab.sh name stale)
cleanup() { bin/fm-herdr-lab.sh teardown "$SESSION"; }
trap cleanup EXIT
# Provision invokes prepare internally for an absent session.
bin/fm-herdr-lab.sh provision "$SESSION"
bin/fm-herdr-lab.sh run "$SESSION" status --json
bin/fm-herdr-lab.sh run "$SESSION" workspace create --cwd "$ROOT" --label isolate --no-focus
bin/fm-herdr-lab.sh run "$SESSION" pane process-info --pane w1:p1
bin/fm-herdr-lab.sh run "$SESSION" session list --json
