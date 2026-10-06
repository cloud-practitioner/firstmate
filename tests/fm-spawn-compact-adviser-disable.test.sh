#!/usr/bin/env bash
# tests/fm-spawn-compact-adviser-disable.test.sh - every agent this fleet
# launches must start with COMPACT_ADVISER_DISABLE=1 in its environment.
#
# The assertions never read bin/fm-spawn.sh's source. They drive the real spawn
# against a fake pane and a real isolated git worktree, then EXECUTE the launch
# command the pane actually received, under a synthetic pane environment, with
# the harness binary replaced by a probe that prints the environment it was
# started with. What the probe prints is what a real agent would have received.
#
# The remote second-mate route never reaches this path; its coverage lives in
# tests/fm-spawn-compact-adviser-disable-remote.test.sh.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

CONTROL="$ROOT/bin/fm-control.sh"
TMP_ROOT=$(fm_test_tmproot fm-spawn-compact-adviser)

# A synthetic pane value the launch must override rather than inherit: the
# switch is a floor, so a pane that already carries the wrong value still has to
# start its agent with 1.
CONTRARY=0

# make_case <name> <harness> <id>...
# Echoes "<case-dir>|<home>|<project>|<worktree>|<fakebin>|<launch-log>|<pane-log>".
make_case() {
  local name=$1 harness=$2 case_dir home proj wt fakebin launchlog panelog id
  shift 2
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  launchlog="$case_dir/launch.log"
  panelog="$case_dir/pane.log"
  fakebin=$(fm_test_make_spawn_fakebin "$case_dir/fake")
  fm_test_spawn_home "$home" "$harness"
  fm_git_worktree "$proj" "$wt" "wt-$name"
  for id in "$@"; do
    fm_test_spawn_brief "$home" "$id"
  done
  printf '%s\n' "$case_dir|$home|$proj|$wt|$fakebin|$launchlog|$panelog"
}

read_case() {
  IFS='|' read -r CASE_DIR HOME_DIR PROJ_DIR WT_DIR FAKEBIN_DIR LAUNCH_LOG PANE_LOG <<EOF
$1
EOF
}

run_case_spawn() {
  : > "$LAUNCH_LOG"
  : > "$PANE_LOG"
  FM_FAKE_LAUNCH_LOG="$LAUNCH_LOG" FM_FAKE_PANE_LOG="$PANE_LOG" \
    fm_test_run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$@"
}

# Replace the harness binary with a probe that reports the single environment
# fact under test, so executing the emitted launch answers "what would the agent
# have seen" rather than "what does the command text look like".
install_env_probe() {  # <fakebin> <harness> [variable]
  cat > "$1/$2" <<SH
#!/bin/sh
printf '%s\n' "\${${3:-COMPACT_ADVISER_DISABLE}-unset}"
SH
  chmod +x "$1/$2"
}

# Run the emitted launch command in a synthetic pane shell. The pane carries the
# CONTRARY value, so a launch that merely forwarded the ambient environment
# would be caught here rather than reported as a pass.
#   emitted_launch_env <fakebin> <launch-log> <pane-log>
emitted_launch_env() {
  local fakebin=$1 launchlog=$2 panelog=$3 launch preamble
  launch=$(cat "$launchlog")
  # The pane exports run before the launch command in the real pane shell, so
  # replay them here in the same order: the filtered launch environment retains
  # what the pane holds, and dropping them would test a pane that never existed.
  preamble=$(grep '^export ' "$panelog")
  env -i HOME="$TMP_ROOT/pane-home" PATH="$fakebin:$PATH" TERM=xterm \
    TMUX=synthetic-pane COMPACT_ADVISER_DISABLE="$CONTRARY" \
    /bin/sh -c "$preamble
$launch"
}

pane_export_lines() { grep -c '^export COMPACT_ADVISER_DISABLE=1$' "$1" || true; }

assert_pane_export_precedes_launch() {  # <pane-log> <label>
  local panelog=$1 label=$2
  [ "$(pane_export_lines "$panelog")" = 1 ] \
    || fail "$label: the pane shell should receive exactly one compact-adviser export, got $(pane_export_lines "$panelog")"
  # Ordering: the export must ride the same pre-launch site as GOTMPDIR, which
  # is what makes it set before the agent process starts.
  local gotmp switch
  gotmp=$(grep -n '^export GOTMPDIR=' "$panelog" | tail -1 | cut -d: -f1)
  switch=$(grep -n '^export COMPACT_ADVISER_DISABLE=1$' "$panelog" | tail -1 | cut -d: -f1)
  [ -n "$gotmp" ] && [ -n "$switch" ] \
    || fail "$label: the pane log is missing the pre-launch exports"
  [ "$switch" -gt "$gotmp" ] \
    || fail "$label: the compact-adviser export must ride the GOTMPDIR pre-launch site (gotmp=$gotmp switch=$switch)"
}

test_ship_allowlist_absent() {
  local rec out status seen
  rec=$(make_case ship-open codex ship-open-a1)
  read_case "$rec"
  out=$(run_case_spawn ship-open-a1 "$PROJ_DIR" --mode no-mistakes --yolo off)
  status=$?
  expect_code 0 "$status" "ship spawn without an allowlist should succeed: $out"
  assert_pane_export_precedes_launch "$PANE_LOG" "ship, allowlist absent"
  install_env_probe "$FAKEBIN_DIR" codex
  seen=$(emitted_launch_env "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "ship, allowlist absent: the emitted launch failed to run"
  assert_equals 1 "$seen" \
    "a ship worker launched with the ambient environment must start with the compact adviser disabled"
  pass "ship launch with no allowlist starts its agent with the compact-adviser switch on"
}

test_ship_allowlist_enabled() {
  local rec out status seen launch
  rec=$(make_case ship-filtered codex ship-filtered-a1)
  read_case "$rec"
  # An empty file is the strictest opt-in: the launch keeps Firstmate's own
  # operational floor and nothing else, so it is where a floor either holds or
  # is lost.
  : > "$HOME_DIR/config/launch-env-allowlist"
  out=$(run_case_spawn ship-filtered-a1 "$PROJ_DIR" --mode no-mistakes --yolo off)
  status=$?
  expect_code 0 "$status" "ship spawn under an allowlist should succeed: $out"
  assert_pane_export_precedes_launch "$PANE_LOG" "ship, allowlist enabled"
  launch=$(cat "$LAUNCH_LOG")
  assert_contains "$launch" '/usr/bin/env -i' \
    "an enabled allowlist should launch under a cleared environment"
  install_env_probe "$FAKEBIN_DIR" codex
  seen=$(emitted_launch_env "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
    || fail "ship, allowlist enabled: the emitted launch failed to run"
  assert_equals 1 "$seen" \
    "a ship worker launched under the cleared allowlisted environment must still start with the compact adviser disabled"
  pass "ship launch under an enabled allowlist keeps the compact-adviser switch through the cleared environment"
}

# The floor must not depend on the pane export having landed: a pane whose
# export was lost still has to launch its agent with the switch on. Replaying
# the launch alone, with a contrary ambient value, is that case.
test_launch_command_carries_the_switch_without_the_pane_export() {
  local setting rec out status seen launch
  for setting in absent enabled; do
    rec=$(make_case "ship-nopane-$setting" codex "ship-nopane-$setting-a1")
    read_case "$rec"
    [ "$setting" = absent ] || : > "$HOME_DIR/config/launch-env-allowlist"
    out=$(run_case_spawn "ship-nopane-$setting-a1" "$PROJ_DIR" --mode no-mistakes --yolo off)
    status=$?
    expect_code 0 "$status" "allowlist=$setting spawn should succeed: $out"
    install_env_probe "$FAKEBIN_DIR" codex
    launch=$(cat "$LAUNCH_LOG")
    seen=$(env -i HOME="$TMP_ROOT/pane-home" PATH="$FAKEBIN_DIR:$PATH" TERM=xterm \
      TMUX=synthetic-pane COMPACT_ADVISER_DISABLE="$CONTRARY" \
      /bin/sh -c "$launch") \
      || fail "allowlist=$setting: the emitted launch failed to run without the pane exports"
    assert_equals 1 "$seen" \
      "allowlist=$setting: the launch command alone must set the compact-adviser switch, overriding a contrary pane value"
  done
  pass "the launch command sets the switch on its own, whichever allowlist posture is in force"
}

test_secondmate_launch() {
  local setting rec sm out status seen
  for setting in absent enabled; do
    rec=$(make_case "secondmate-$setting" codex "sm-$setting")
    read_case "$rec"
    [ "$setting" = absent ] || : > "$HOME_DIR/config/launch-env-allowlist"
    sm="$CASE_DIR/secondmate-home"
    mkdir -p "$sm/bin" "$sm/data"
    printf '# Firstmate\n' > "$sm/AGENTS.md"
    printf '%s\n' "sm-$setting" > "$sm/.fm-secondmate-home"
    printf 'charter for sm-%s\n' "$setting" > "$sm/data/charter.md"
    printf '%s\n' 'projects/' 'state/' 'data/' 'config/' '.no-mistakes/' > "$sm/.gitignore"
    git -C "$sm" init -q -b main
    out=$(run_case_spawn "sm-$setting" "$sm" --secondmate)
    status=$?
    expect_code 0 "$status" "secondmate spawn with allowlist=$setting should succeed: $out"
    assert_pane_export_precedes_launch "$PANE_LOG" "secondmate, allowlist $setting"
    install_env_probe "$FAKEBIN_DIR" codex
    seen=$(emitted_launch_env "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
      || fail "secondmate, allowlist $setting: the emitted launch failed to run"
    assert_equals 1 "$seen" \
      "a secondmate launched with allowlist=$setting must start with the compact adviser disabled"
  done
  pass "a secondmate launch carries the compact-adviser switch in both allowlist postures"
}

# The steering doorbell names "$FM_TASK_INBOX" rather than a path, so every
# launch must hand its agent the absolute path of the task's own inbox. For a
# secondmate that inbox lives in the launching home's state, not its own. The
# cleared allowlist environment is where an ambient forward would be lost.
test_launch_exports_task_inbox() {
  local kind rec id sm out status seen want
  for kind in ship secondmate; do
    id="inbox-$kind-a1"
    rec=$(make_case "inbox-$kind" codex "$id")
    read_case "$rec"
    : > "$HOME_DIR/config/launch-env-allowlist"
    if [ "$kind" = ship ]; then
      out=$(run_case_spawn "$id" "$PROJ_DIR" --mode no-mistakes --yolo off)
    else
      sm="$CASE_DIR/secondmate-home"
      mkdir -p "$sm/bin" "$sm/data"
      printf '# Firstmate\n' > "$sm/AGENTS.md"
      printf '%s\n' "$id" > "$sm/.fm-secondmate-home"
      printf 'charter for %s\n' "$id" > "$sm/data/charter.md"
      printf '%s\n' 'projects/' 'state/' 'data/' 'config/' '.no-mistakes/' > "$sm/.gitignore"
      git -C "$sm" init -q -b main
      out=$(run_case_spawn "$id" "$sm" --secondmate)
    fi
    status=$?
    expect_code 0 "$status" "$kind spawn should succeed: $out"
    install_env_probe "$FAKEBIN_DIR" codex FM_TASK_INBOX
    seen=$(emitted_launch_env "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
      || fail "$kind: the emitted launch failed to run"
    want="$(cd "$HOME_DIR/state" && pwd -P)/$id.inbox"
    assert_equals "$want" "$seen" \
      "a $kind agent must start with FM_TASK_INBOX set to its absolute steering inbox"
  done
  pass "ship and secondmate launches export their absolute steering inbox as FM_TASK_INBOX"
}

# --- relaunch ---------------------------------------------------------------
#
# bin/fm-control.sh relaunch stops the agent and rebuilds the launch through
# bin/fm-spawn.sh --relaunch, so this drives the operator-facing verb rather
# than the rebuild alone. The stub below models just enough pane lifecycle for
# that transaction: the harness exit command leaves a bare shell behind, and the
# launch literal starts the harness again.
make_relaunch_stub() {  # <case-dir>
  local fb="$1/fakebin"
  mkdir -p "$fb"
  cat > "$fb/tmux" <<'SH'
#!/usr/bin/env bash
set -u
D=$FM_FAKE_DIR
case "${1:-}" in
  send-keys)
    shift
    literal=0
    while [ $# -gt 0 ]; do
      case "$1" in
        -t) shift 2 ;;
        -l) literal=1; shift ;;
        *) break ;;
      esac
    done
    payload=${1:-}
    if [ "$literal" = 1 ]; then
      case "$payload" in
        ". '"*"'")
          staged=${payload#". '"}
          staged=${staged%"'"}
          [ ! -f "$staged" ] || payload=$(cat "$staged")
          ;;
      esac
      printf '%s\n' "$payload" >> "$D/literal"
      case "$payload" in
        /exit|/quit) printf 'zsh' > "$D/command" ;;
        *'encode launch-brief'*) printf 'codex' > "$D/command" ;;
      esac
    else
      printf '%s\n' "$payload" >> "$D/keys"
    fi
    exit 0 ;;
  display-message)
    for a in "$@"; do
      case "$a" in
        *cursor_y*) printf '1\n'; exit 0 ;;
        *pane_current_command*) cat "$D/command"; printf '\n'; exit 0 ;;
        *pane_current_path*) cat "$D/cwd"; printf '\n'; exit 0 ;;
      esac
    done
    printf 'fakepane\n'; exit 0 ;;
  capture-pane) printf '╭────╮\n│    │\n╰────╯\n'; exit 0 ;;
  list-windows) [ -f "$D/windows" ] && cat "$D/windows"; exit 0 ;;
esac
exit 0
SH
  chmod +x "$fb/tmux"
  cat > "$fb/sleep" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$fb/sleep"
}

test_relaunch_rebuilds_the_switch() {
  local setting dir home proj wt id out status seen launch preamble
  for setting in absent enabled; do
    id="relaunch-$setting-a1"
    dir="$TMP_ROOT/relaunch-$setting"
    home="$dir/home"
    proj="$dir/proj"
    wt="$dir/wt"
    mkdir -p "$home/state" "$home/data" "$home/config" "$home/projects" "$dir/fake"
    touch "$home/state/.last-watcher-beat"
    [ "$setting" = absent ] || : > "$home/config/launch-env-allowlist"
    make_relaunch_stub "$dir"
    fm_git_worktree "$proj" "$wt" "wt-relaunch-$setting"
    fm_test_spawn_brief "$home" "$id"
    : > "$dir/fake/literal"
    : > "$dir/fake/keys"
    printf 'codex' > "$dir/fake/command"
    printf '%s\n' "fm-$id" > "$dir/fake/windows"
    printf '%s' "$wt" > "$dir/fake/cwd"
    {
      echo "window=fmses:fm-$id"
      echo "endpoint_task_id=$id"
      echo "worktree=$wt"
      echo "project=$proj"
      echo "harness=codex"
      echo "kind=ship"
      echo "mode=no-mistakes"
      echo "yolo=off"
      echo "tasktmp=$dir/tasktmp"
      echo "model=default"
      echo "effort=default"
    } > "$home/state/$id.meta"

    mkdir -p "$dir/user-home"
    out=$(env PATH="$dir/fakebin:$PATH" FM_HOME="$home" FM_FAKE_DIR="$dir/fake" \
      HOME="$dir/user-home" CLAUDE_CONFIG_DIR='' FM_SPAWN_NO_GUARD=1 \
      FM_CONTROL_POLL=0.01 FM_CONTROL_EXIT_WAIT=0.05 FM_CONTROL_LAUNCH_WAIT=0.05 \
      "$CONTROL" "$id" relaunch --note 'replacement continues the same task' 2>&1)
    status=$?
    expect_code 0 "$status" "relaunch with allowlist=$setting should succeed: $out"

    grep -qx 'export COMPACT_ADVISER_DISABLE=1' "$dir/fake/keys" \
      || fail "relaunch with allowlist=$setting did not re-export the compact-adviser switch into the pane"
    launch=$(grep 'encode launch-brief' "$dir/fake/literal" | tail -1)
    [ -n "$launch" ] || fail "relaunch with allowlist=$setting sent no replacement launch command"
    install_env_probe "$dir/fakebin" codex
    preamble=$(grep '^export ' "$dir/fake/keys")
    seen=$(env -i HOME="$dir/user-home" PATH="$dir/fakebin:$PATH" TERM=xterm \
      TMUX=synthetic-pane COMPACT_ADVISER_DISABLE="$CONTRARY" \
      /bin/sh -c "$preamble
$launch") \
      || fail "relaunch with allowlist=$setting: the replacement launch failed to run"
    assert_equals 1 "$seen" \
      "a relaunched agent with allowlist=$setting must start with the compact adviser disabled, exactly as a fresh spawn does"
  done
  pass "relaunch rebuilds the compact-adviser switch for the replacement agent in both allowlist postures"
}

# A command-prefix assignment only covers the first simple command. A raw
# compound launch such as `cd <dir> && <probe>` must still start the probe with
# the switch on, so this drives that escape hatch and executes the pane's
# launch under a contrary ambient value.
test_raw_compound_launch_command_carries_the_switch() {
  local rec out status seen launch probe_dir
  rec=$(make_case raw-compound claude raw-compound-a1)
  read_case "$rec"
  printf '%s\n' '{"rules":[{"when":"current events","use":{"harness":"grok","model":"grok-4","effort":"high"}}],"default":{"harness":"codex","model":"gpt-5","effort":"medium"}}' \
    > "$HOME_DIR/config/crew-dispatch.json"

  probe_dir="$CASE_DIR/agent-cwd"
  mkdir -p "$probe_dir"
  cat > "$probe_dir/probe" <<'SH'
#!/bin/sh
printf '%s\n' "${COMPACT_ADVISER_DISABLE-unset}"
SH
  chmod +x "$probe_dir/probe"

  out=$(run_case_spawn raw-compound-a1 "$PROJ_DIR" --mode no-mistakes --yolo off \
    "cd $probe_dir && ./probe")
  status=$?
  expect_code 0 "$status" "raw compound launch spawn should succeed: $out"
  launch=$(cat "$LAUNCH_LOG")
  [ -n "$launch" ] || fail "raw compound launch spawn sent no launch command"
  seen=$(env -i HOME="$TMP_ROOT/pane-home" PATH="$FAKEBIN_DIR:$PATH" TERM=xterm \
    TMUX=synthetic-pane COMPACT_ADVISER_DISABLE="$CONTRARY" \
    /bin/sh -c "$launch") \
    || fail "raw compound launch: the emitted launch failed to run"
  assert_equals 1 "$seen" \
    "a raw compound launch must start its agent with the compact adviser disabled, even after cd"
  pass "a compound raw launch-command still starts its agent with the compact-adviser switch on"
}

# --- snapshot-scoped variables ---------------------------------------------
#
# fm-fleet-snapshot scopes FM_CREW_STATE_*_OVERRIDE to one crew-state read, but
# a herdr call during that read once started a server that kept them, so every
# pane after it carried a stale override into its agent and watcher. A launch
# must clear them whether they arrive in the spawn's own environment or in the
# pane's. The probe prints every scoped value the agent started with.
LEAK_NAMES='FM_SNAPSHOT_SCOPED_ENV FM_CREW_STATE_META_OVERRIDE FM_CREW_STATE_STATUS_OVERRIDE FM_HOME_SUMMARY_IF_IDLE FM_HOME_SUMMARY_WORKER_BEST_EFFORT'
SNAPSHOT_PATH_NAMES='FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_PROJECTS_OVERRIDE FM_CONFIG_OVERRIDE'

install_leak_probe() {  # <fakebin> <harness>
  local name body=
  for name in $LEAK_NAMES; do body="$body\${$name-unset}|"; done
  # Secondmate launches deliberately set these to empty rather than unsetting.
  for name in $SNAPSHOT_PATH_NAMES; do body="$body\${$name:-unset}|"; done
  # shellcheck disable=SC2016
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$(printf '%s' "$body" | sed 's/\\//g')" > "$1/$2"
  chmod +x "$1/$2"
}

# The pane shell of a server that inherited the leak: every scoped name is set.
leaky_pane_launch() {  # <fakebin> <launch> [<preamble>] [<scope-marker>]
  env -i HOME="$TMP_ROOT/pane-home" PATH="$1:$PATH" TERM=xterm TMUX=synthetic-pane \
    FM_SNAPSHOT_SCOPED_ENV="${4-1}" FM_CREW_STATE_META_OVERRIDE=/tmp/leak.meta \
    FM_CREW_STATE_STATUS_OVERRIDE=/tmp/leak.status FM_HOME_SUMMARY_IF_IDLE=0 \
    FM_HOME_SUMMARY_WORKER_BEST_EFFORT=1 \
    FM_ROOT_OVERRIDE=/snapshot/root FM_STATE_OVERRIDE=/snapshot/state \
    FM_DATA_OVERRIDE=/snapshot/data FM_PROJECTS_OVERRIDE=/snapshot/projects \
    FM_CONFIG_OVERRIDE=/snapshot/config \
    /bin/sh -c "${3:-}
$2"
}

test_snapshot_scoped_variables_are_cleared_from_the_launch() {
  local setting rec sm id out status seen kind want='unset|unset|unset|unset|unset|unset|unset|unset|unset|unset|'
  for kind in ship secondmate; do
    for setting in absent enabled paths-only; do
      id="leak-$kind-$setting-a1"
      rec=$(make_case "leak-$kind-$setting" codex "$id")
      read_case "$rec"
      case "$setting" in
        enabled) printf '%s\n' "$LEAK_NAMES $SNAPSHOT_PATH_NAMES" | tr ' ' '\n' > "$HOME_DIR/config/launch-env-allowlist" ;;
        paths-only) printf '%s\n' "$SNAPSHOT_PATH_NAMES" | tr ' ' '\n' > "$HOME_DIR/config/launch-env-allowlist" ;;
      esac
      if [ "$kind" = ship ]; then
        out=$(run_case_spawn "$id" "$PROJ_DIR" --mode no-mistakes --yolo off)
      else
        sm="$CASE_DIR/secondmate-home"
        mkdir -p "$sm/bin" "$sm/data"
        printf '# Firstmate\n' > "$sm/AGENTS.md"
        printf '%s\n' "$id" > "$sm/.fm-secondmate-home"
        printf 'charter for %s\n' "$id" > "$sm/data/charter.md"
        printf '%s\n' 'projects/' 'state/' 'data/' 'config/' '.no-mistakes/' > "$sm/.gitignore"
        git -C "$sm" init -q -b main
        out=$(run_case_spawn "$id" "$sm" --secondmate)
      fi
      status=$?
      expect_code 0 "$status" "$kind spawn with allowlist=$setting should succeed: $out"
      install_leak_probe "$FAKEBIN_DIR" codex
      seen=$(leaky_pane_launch "$FAKEBIN_DIR" "$(cat "$LAUNCH_LOG")" "$(grep '^export ' "$PANE_LOG")") \
        || fail "$kind, allowlist $setting: the emitted launch failed to run"
      assert_equals "$want" "$seen" \
        "a $kind agent launched into a pane carrying snapshot-scoped variables (allowlist=$setting) must start without them"
    done
  done
  pass "ship and secondmate launches start their agent without snapshot-scoped variables a pane carries"
}

test_launch_preserves_unmarked_path_overrides() {
  local setting rec out status seen marker preamble
  for setting in absent enabled; do
    rec=$(make_case "unmarked-$setting" codex "unmarked-$setting-a1")
    read_case "$rec"
    [ "$setting" = absent ] || printf '%s\n' "$SNAPSHOT_PATH_NAMES" | tr ' ' '\n' > "$HOME_DIR/config/launch-env-allowlist"
    out=$(run_case_spawn "unmarked-$setting-a1" "$PROJ_DIR" --mode no-mistakes --yolo off)
    status=$?
    expect_code 0 "$status" "unmarked spawn with allowlist=$setting should succeed: $out"
    install_leak_probe "$FAKEBIN_DIR" codex
    for marker in unset '' 0; do
      preamble=$(grep '^export ' "$PANE_LOG")
      [ "$marker" != unset ] || preamble="unset FM_SNAPSHOT_SCOPED_ENV; $preamble"
      seen=$(leaky_pane_launch "$FAKEBIN_DIR" "$(cat "$LAUNCH_LOG")" "$preamble" "$marker") \
        || fail "unmarked launch with allowlist=$setting failed to run"
      assert_equals 'unset|unset|unset|unset|unset|/snapshot/root|/snapshot/state|/snapshot/data|/snapshot/projects|/snapshot/config|' "$seen" \
        "a launch must preserve unmarked path overrides (allowlist=$setting, marker=$marker)"
    done
  done
  pass "launches preserve legitimate unmarked path overrides in both allowlist postures"
}

# The spawn's own process is where a backend command can start a long-lived
# server, so a leaked value must be gone before the first backend call.
test_spawn_process_clears_snapshot_scoped_variables_before_backend_calls() {
  local rec out status envlog real
  rec=$(make_case leak-spawn-env codex leak-spawn-env-a1)
  read_case "$rec"
  envlog="$CASE_DIR/tmux-env.log"
  : > "$envlog"
  real="$FAKEBIN_DIR/tmux.real"
  mv "$FAKEBIN_DIR/tmux" "$real"
  cat > "$FAKEBIN_DIR/tmux" <<SH
#!/usr/bin/env bash
env >> "$envlog"
exec "$real" "\$@"
SH
  chmod +x "$FAKEBIN_DIR/tmux"
  out=$(FM_SNAPSHOT_SCOPED_ENV=leak-marker FM_CREW_STATE_META_OVERRIDE=/tmp/leak.meta \
    FM_CREW_STATE_STATUS_OVERRIDE=/tmp/leak.status FM_HOME_SUMMARY_IF_IDLE=leak-idle \
    FM_HOME_SUMMARY_WORKER_BEST_EFFORT=leak-best-effort \
    run_case_spawn leak-spawn-env-a1 "$PROJ_DIR" --mode no-mistakes --yolo off)
  status=$?
  expect_code 0 "$status" "spawn with leaked variables should succeed: $out"
  [ -s "$envlog" ] || fail "the spawn made no backend call, so the test proves nothing"
  # Spawn's own fleet reads may legitimately scope these names to one crew-state
  # read with their own values, so only the planted sentinel values count.
  ! grep -Eq '^FM_[A-Z_]+=(/tmp/leak\.|leak-)' "$envlog" \
    || fail "a backend call made by spawn received a leaked snapshot-scoped variable: $(grep -E '^FM_[A-Z_]+=(/tmp/leak\.|leak-)' "$envlog" | head -1)"
  grep -q '^FM_HOME=' "$envlog" || fail "the backend call must keep the legitimate FM_HOME"
  pass "spawn clears snapshot-scoped variables from its own environment before any backend call"
}

test_relaunch_clears_snapshot_scoped_variables() {
  local dir home proj wt id out status seen launch preamble
  id="relaunch-leak-a1"
  dir="$TMP_ROOT/relaunch-leak"
  home="$dir/home"; proj="$dir/proj"; wt="$dir/wt"
  mkdir -p "$home/state" "$home/data" "$home/config" "$home/projects" "$dir/fake" "$dir/user-home"
  # Retain paths but not their marker: cleanup must precede the env filter.
  printf '%s\n' "$SNAPSHOT_PATH_NAMES" | tr ' ' '\n' > "$home/config/launch-env-allowlist"
  touch "$home/state/.last-watcher-beat"
  make_relaunch_stub "$dir"
  fm_git_worktree "$proj" "$wt" "wt-relaunch-leak"
  fm_test_spawn_brief "$home" "$id"
  : > "$dir/fake/literal"; : > "$dir/fake/keys"
  printf 'codex' > "$dir/fake/command"
  printf '%s\n' "fm-$id" > "$dir/fake/windows"
  printf '%s' "$wt" > "$dir/fake/cwd"
  {
    echo "window=fmses:fm-$id"; echo "endpoint_task_id=$id"; echo "worktree=$wt"
    echo "project=$proj"; echo "harness=codex"; echo "kind=ship"
    echo "mode=no-mistakes"; echo "yolo=off"; echo "tasktmp=$dir/tasktmp"
    echo "model=default"; echo "effort=default"
  } > "$home/state/$id.meta"
  out=$(env PATH="$dir/fakebin:$PATH" FM_HOME="$home" FM_FAKE_DIR="$dir/fake" \
    HOME="$dir/user-home" CLAUDE_CONFIG_DIR='' FM_SPAWN_NO_GUARD=1 \
    FM_CONTROL_POLL=0.01 FM_CONTROL_EXIT_WAIT=0.05 FM_CONTROL_LAUNCH_WAIT=0.05 \
    "$CONTROL" "$id" relaunch --note 'replacement continues the same task' 2>&1)
  status=$?
  expect_code 0 "$status" "relaunch should succeed: $out"
  launch=$(grep 'encode launch-brief' "$dir/fake/literal" | tail -1)
  [ -n "$launch" ] || fail "relaunch sent no replacement launch command"
  install_leak_probe "$dir/fakebin" codex
  preamble=$(grep '^export ' "$dir/fake/keys")
  seen=$(leaky_pane_launch "$dir/fakebin" "$launch" "$preamble") \
    || fail "the replacement launch failed to run"
  assert_equals 'unset|unset|unset|unset|unset|unset|unset|unset|unset|unset|' "$seen" \
    "a relaunched agent in a pane carrying snapshot-scoped variables must start without them"
  pass "relaunch starts the replacement agent without snapshot-scoped variables a pane carries"
}

test_ship_allowlist_absent
test_ship_allowlist_enabled
test_launch_command_carries_the_switch_without_the_pane_export
test_secondmate_launch
test_launch_exports_task_inbox
test_relaunch_rebuilds_the_switch
test_raw_compound_launch_command_carries_the_switch
test_snapshot_scoped_variables_are_cleared_from_the_launch
test_launch_preserves_unmarked_path_overrides
test_spawn_process_clears_snapshot_scoped_variables_before_backend_calls
test_relaunch_clears_snapshot_scoped_variables
