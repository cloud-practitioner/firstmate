#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M47HX8Y8BQRSDDHWXNW190JH
# Relative XDG path is necessary because the worktree prefix leaves no space
# for a generated AF_UNIX socket name. Every call retains this cwd.
[ ! -e herdr ] || { echo 'refusing preexisting local Herdr config'; exit 1; }
mkdir -p herdr .live-validation/tripwire .live-validation/tmp .live-validation/os-home
ln -s /home/node/.config/herdr/herdr.sock herdr/herdr.sock
export XDG_CONFIG_HOME="$ROOT"
export FM_HERDR_LAB_STATE_DIR="$ROOT/.live-validation/tripwire"
export TMPDIR="$ROOT/.live-validation/tmp"
export HERDR_SESSION=fm-lab-x SHELL=/bin/bash
cleanup() {
  set +e
  bin/fm-herdr-lab.sh teardown fm-lab-x
  rm -rf herdr .live-validation
}
trap cleanup EXIT
# Provision performs prepare itself for a new session, and keeps its tripwire.
# Provision under a disposable OS home so its shell cannot load operator rc.
HOME="$ROOT/.live-validation/os-home" bin/fm-herdr-lab.sh provision fm-lab-x
bin/fm-herdr-lab.sh run fm-lab-x status --json
bin/fm-herdr-lab.sh run fm-lab-x workspace create --label firstmate --cwd "$ROOT/.live-validation"
bin/fm-herdr-lab.sh run fm-lab-x workspace list
bin/fm-herdr-lab.sh run fm-lab-x pane process-info --pane w1:p1
bin/fm-herdr-lab.sh teardown fm-lab-x
trap - EXIT
rm -rf herdr .live-validation
printf '\nLab removed, default-session tripwire verified.\n'
