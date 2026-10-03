#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
PRODUCT="$ROOT/.test-phase-tmp/pi-product"
EV=/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C
export TMPDIR="$ROOT/.test-phase-tmp"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION TMUX TMUX_PANE
export FM_BACKEND=tmux
export PATH="$ROOT/.test-phase-tmp/tmux-tool/usr/bin:$PATH" LD_LIBRARY_PATH="$ROOT/.test-phase-tmp/tmux-tool/usr/lib/x86_64-linux-gnu"
LAB=$(mktemp -d "$ROOT/.pXXX")
SM=$(mktemp -d "$ROOT/.qXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
mkdir -p "$LAB/tmux" "$LAB/agent" "$LAB/user"
export TMUX_TMPDIR="$LAB/tmux" FM_HOME="$LAB" SHELL=/bin/bash
cleanup() {
  tmux -L fm-lab kill-server >/dev/null 2>&1 || true
  # The product's staging path is a disposable toolchain side effect, exactly bound to this known home and id.
  HASH=$(printf '%s' "$LAB" | sha256sum | awk '{print $1}')
  rm -rf "/tmp/fm-lab-pi+$HASH"
  chmod -R u+w "$LAB" "$SM" 2>/dev/null || true
  rm -rf "$LAB" "$SM"
}
trap cleanup EXIT
# Materialize the submitted tracked product into the disposable seed; no fake extensions.
git archive HEAD | tar -x -C "$SM"
git -C "$SM" init -q -b main
export FM_SECONDMATE_CHARTER='This is an isolated startup check. No model is configured. Do not run commands, mutate files, or start a pipeline. Stop after presenting the charter.' FM_SECONDMATE_SCOPE='Disposable Pi startup validation'
export HOME="$LAB/user" PI_CODING_AGENT_DIR="$LAB/agent" PI_OFFLINE=1
printf '{}\n' > "$PI_CODING_AGENT_DIR/trust.json"
printf 'pi\n' > "$LAB/config/secondmate-harness"
{
  printf 'Real fm-home-seed and fm-spawn, submitted product copy, real Pi, private 120x40 tmux; offline disposable agent store.\n'
  cmp bin/fm-spawn.sh "$PRODUCT/bin/fm-spawn.sh"
  "$PRODUCT/bin/fm-home-seed.sh" lab-pi "$SM" --no-projects
  # Reproduce the trust stall on the actually seeded home without the spawn approval.
  tmux -L fm-lab new-session -d -s baseline -x 120 -y 40 -c "$SM" 'pi --no-session --no-skills --no-prompt-templates'
  for i in $(seq 1 80); do
    tmux -L fm-lab capture-pane -p -t baseline > "$LAB/baseline.txt"
    grep -q 'Trust project folder' "$LAB/baseline.txt" && break
    sleep .2
  done
  grep -q 'Trust project folder' "$LAB/baseline.txt"
  tmux -L fm-lab capture-pane -ep -t baseline > "$EV/pi-seeded-stall.ansi"
  printf 'Baseline actually seeded home: Trust project folder dialog observed.\n'
  # Keep the private server up before closing its baseline endpoint.
  tmux -L fm-lab new-session -d -s firstmate -x 120 -y 40 -c "$ROOT" 'sleep 300'
  tmux -L fm-lab kill-session -t baseline
  export TMUX="$(tmux -L fm-lab display-message -p -t firstmate '#{socket_path},#{pid},0')"
  "$PRODUCT/bin/fm-spawn.sh" lab-pi "$SM" --secondmate --harness pi
  TARGET=firstmate:fm-lab-pi
  for i in $(seq 1 100); do
    tmux -L fm-lab capture-pane -p -t "$TARGET" > "$LAB/approved.txt"
    grep -qE 'No models available|No model selected|No API key|escape interrupt|No available models' "$LAB/approved.txt" && break
    sleep .2
  done
  tmux -L fm-lab capture-pane -ep -t "$TARGET" > "$EV/pi-seeded-approved.ansi"
  if grep -q 'Trust project folder' "$LAB/approved.txt"; then echo 'ERROR spawned Pi stalled on trust'; exit 1; fi
  grep -qE 'No models available|No model selected|No API key|escape interrupt|No available models' "$LAB/approved.txt"
  test "$(head -1 "$PI_CODING_AGENT_DIR/trust.json")" = '{}'
  printf 'Product-spawned Pi passed trust and reached the TUI; trust.json remained {}.\n'
  printf 'Persisted task endpoint:\n'; grep -E '^(harness|kind|home|window|worktree)=' "$LAB/state/lab-pi.meta"
  printf 'Visible Pi output:\n'; head -45 "$LAB/approved.txt"
} > "$EV/pi-live-spawn.log" 2>&1
