#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M5GMXRP8TEGYK8ZJPXTCW65Z
export PATH="$ROOT/.test-live/bin:$PATH" TMPDIR="$ROOT/.test-live/tmp"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS NM_HOME TASKS_AXI_FILE TASKS_AXI_BACKEND
export FM_BACKEND=tmux
LAB=$(mktemp -d "$ROOT/.l.XXXXXX")
export FM_HOME="$LAB" TMUX_TMPDIR="$LAB/tmux" TREEHOUSE_ROOT="$LAB/pool"
cleanup() {
  tmux -L fm-lab capture-pane -p -t primary > "$EVIDENCE/r3-primary-final.txt" 2>/dev/null || true
  tmux -L fm-lab kill-server 2>/dev/null || true
  chmod -R u+w "$LAB" 2>/dev/null || true
  rm -rf "$LAB"
}
trap cleanup EXIT

bin/fm-lab-home.sh create "$LAB"
export HOME="$LAB/user-home" CLAUDE_CONFIG_DIR="$LAB/claude-config" XDG_CONFIG_HOME="$LAB/xdg-config" XDG_DATA_HOME="$LAB/xdg-data" XDG_STATE_HOME="$LAB/xdg-state" XDG_CACHE_HOME="$LAB/xdg-cache" DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
mkdir -p "$HOME" "$CLAUDE_CONFIG_DIR"

mkdir -p "$LAB/tmux" "$LAB/claude-config"
touch "$LAB/config/supervision-host"
export XDG_CONFIG_HOME="$LAB/xdg-config" XDG_DATA_HOME="$LAB/xdg-data" XDG_STATE_HOME="$LAB/xdg-state"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
proj="$LAB/projects/disposable"
mkdir -p "$proj"
git -C "$proj" init -q -b main
printf 'Disposable Firstmate validation project.\n' > "$proj/README.md"
git -C "$proj" -c user.name=Test -c user.email=test@example.invalid add README.md
git -C "$proj" -c user.name=Test -c user.email=test@example.invalid commit -qm 'Runtime fixture'
printf '\n=== Real primary CLI (120x40) ===\n'
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab new-session -d -x 120 -y 40 -s primary -c "$ROOT" -e FM_HOME="$LAB" claude
tmux -L fm-lab set-option -g default-shell /bin/bash
tmux -L fm-lab set-option -g default-command 'bash --noprofile --norc'
export TMUX="$(tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')"
sleep 8
tmux -L fm-lab capture-pane -p -t primary | tee "$EVIDENCE/r3-spawn-primary.txt"
printf '\n=== Scaffold real scout ===\n'
bin/fm-brief.sh runtime-probe disposable --scout
python3 - "$LAB/data/runtime-probe/brief.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
p.write_text(p.read_text().replace('{TASK}', 'Validate the isolated launch. Run pwd, then stop without changing any files or contacting any service. This is a disposable smoke test, not a coding task.').replace('{FIRSTMATE_SPEC}', 'Only run pwd and acknowledge the validation. Do not invoke any pipeline, git publishing command, or lifecycle helper.'))
PY
printf '\n=== Spawn real Claude scout with private Treehouse pool ===\n'
CLAUDE_CONFIG_DIR="$LAB/claude-config" bin/fm-spawn.sh runtime-probe "$proj" --scout --harness claude --model sonnet --backend tmux
printf '\nWorker uses a disposable Claude config: no normal-login or operator trust-store mutations. Authenticated model execution is not claimed.\n'
printf '\n=== Published task metadata ===\n'
cp "$LAB/state/runtime-probe.meta" "$EVIDENCE/r3-spawn-meta.txt"
while IFS= read -r line; do printf '%s\n' "$line"; done < "$LAB/state/runtime-probe.meta"
TASK_TMP=$(awk -F= '$1=="tasktmp" {print substr($0,9)}' "$LAB/state/runtime-probe.meta")
[ "$TASK_TMP" = "$LAB/state/runtime-probe.tasktmp" ]
[ "$(stat -c '%a' "$TASK_TMP")" = 700 ]
[ -d "$TASK_TMP/gotmp" ]
printf 'tasktmp_mode=%s gotmp_exists=yes\n' "$(stat -c '%a' "$TASK_TMP")"
sleep 8
if tmux -L fm-lab capture-pane -p -t 'primary:fm-runtime-probe' | grep -Fq 'Allow external CLAUDE.md file imports?'; then
  printf 'Dismissing external-import onboarding with its default No option.\n'
  tmux -L fm-lab send-keys -t 'primary:fm-runtime-probe' Enter
fi
sleep 8
printf '\n=== Real worker terminal ===\n'
tmux -L fm-lab capture-pane -p -S -120 -t 'primary:fm-runtime-probe' | tee "$EVIDENCE/r3-spawn-worker.txt"
printf '\n=== End-user peek and current-state read ===\n'
bin/fm-peek.sh runtime-probe | tee "$EVIDENCE/r3-spawn-peek.txt"
bin/fm-crew-state.sh runtime-probe | tee "$EVIDENCE/r3-spawn-state.txt"
printf '\n=== Teardown disposable scout ===\n'
printf 'Disposable test driver report: real CLI launched, private temp root verified; no project changes requested.\n' > "$LAB/data/runtime-probe/report.md"
bin/fm-captain-hold.sh complete runtime-probe --none
bin/fm-teardown.sh runtime-probe
[ ! -e "$TASK_TMP" ]
[ ! -e "$LAB/state/runtime-probe.meta" ]
printf 'recorded_tasktmp_removed=yes task_meta_removed=yes\n'
