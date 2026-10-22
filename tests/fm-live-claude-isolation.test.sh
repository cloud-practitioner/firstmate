#!/usr/bin/env bash
# Regression for the host-launcher incident: a live Claude scenario that
# sandboxed only XDG_DATA_HOME let Claude Code's native updater re-point the host
# ~/.local/bin/claude at the scenario's scratch versions directory, and the
# scenario's cleanup then deleted that directory.
#
# No real Claude runs here. The "real" claude is a stub that records its
# environment and then behaves like the native updater: it installs itself under
# $XDG_DATA_HOME/claude/versions and re-points $HOME/.local/bin/claude at it. A
# fake host HOME stands in for the machine's, so the assertions are about what
# the shim (bin/fm-live-claude.sh) lets that stub reach. The suite's own
# fm_live_gate and bin/fm-spawn.sh launch path are driven the way a live
# scenario drives them.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

OWNER="$ROOT/bin/fm-live-claude.sh"
TMP_ROOT=$(fm_test_tmproot fm-live-claude-isolation)
HOST="$TMP_ROOT/host"
LOG="$TMP_ROOT/stub.log"

# The fake host: a native install (versions/ plus the ~/.local/bin/claude
# launcher), a sibling tool, and a signed-in ~/.claude.
mkdir -p "$HOST/.local/share/claude/versions" "$HOST/.local/bin" "$HOST/.claude"
cat > "$HOST/.local/share/claude/versions/9.9.9" <<'SH'
#!/usr/bin/env bash
# Stub "real" claude: record the environment, then act like the native updater.
{
  printf 'argv0=%s\n' "$(basename "$0")"
  printf 'home=%s\n' "$HOME"
  printf 'path=%s\n' "$PATH"
  printf 'shim=%s\n' "${FM_LIVE_CLAUDE_SHIM:-unset}"
  printf 'autoupdater=%s\n' "${DISABLE_AUTOUPDATER:-unset}"
  printf 'updates=%s\n' "${DISABLE_UPDATES:-unset}"
  printf 'xdg_data=%s\n' "${XDG_DATA_HOME:-unset}"
  printf 'xdg_state=%s\n' "${XDG_STATE_HOME:-unset}"
  printf 'xdg_cache=%s\n' "${XDG_CACHE_HOME:-unset}"
  printf 'xdg_bin=%s\n' "${XDG_BIN_HOME:-unset}"
  printf 'args=%s\n' "$*"
  [ -f "$HOME/.claude/.credentials.json" ] && echo cred=visible || echo cred=missing
  [ -e "$HOME/.local/share/claude/versions/9.9.9" ] && echo host_install=visible || echo host_install=absent
  echo ---
} >> "$FM_STUB_LOG"
echo wrote > "$HOME/.claude/stub-session"
case "${FM_STUB_UPDATER:-}" in
  honor) [ "${DISABLE_AUTOUPDATER:-}" = 1 ] && exit 0 ;;
  rogue) ;;
  *) exit 0 ;;
esac
# The incident: install under the scratch XDG data dir, re-point the launcher
# under HOME, then (the scenario's cleanup) delete the scratch install.
mkdir -p "$XDG_DATA_HOME/claude/versions" "$HOME/.local/bin"
cp "$0" "$XDG_DATA_HOME/claude/versions/9.9.9" 2>/dev/null || true
ln -sfn "$XDG_DATA_HOME/claude/versions/9.9.9" "$HOME/.local/bin/claude"
if [ "${FM_STUB_CLEANUP:-}" = 1 ]; then rm -rf "$XDG_DATA_HOME/claude"; fi
if [ -n "${FM_STUB_NESTED:-}" ]; then FM_STUB_UPDATER= FM_STUB_NESTED= claude --nested; fi
if [ -n "${FM_STUB_SCRIPT:-}" ]; then exec env FM_STUB_SCRIPT= bash "$FM_STUB_SCRIPT"; fi
exit 0
SH
chmod +x "$HOST/.local/share/claude/versions/9.9.9"
ln -s "$HOST/.local/share/claude/versions/9.9.9" "$HOST/.local/bin/claude"
printf '#!/bin/sh\nexit 0\n' > "$HOST/.local/bin/othertool"; chmod +x "$HOST/.local/bin/othertool"
printf '{"token":"fake"}\n' > "$HOST/.claude/.credentials.json"
printf '{"projects":{}}\n' > "$HOST/.claude.json"
HOST_REAL=$(cd -P "$HOST" && pwd -P)

host_state() {  # a comparable picture of everything under the fake host ~/.local
  (cd "$HOST/.local" && find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r p; do
    if [ -L "$p" ]; then printf '%s -> %s\n' "$p" "$(readlink "$p")"; else printf '%s\n' "$p"; fi
  done)
}
launcher() { readlink "$HOST/.local/bin/claude"; }
logval() {  # <key> [n]: the value of key in the n-th (default last) record
  awk -F= -v k="$1" -v n="${2:-0}" 'BEGIN{r=0} $0=="---"{r++; next} $1==k{v[r]=substr($0,length(k)+2)} END{if(n==0)n=r; print v[n-1]}' "$LOG"
}
runenv() {  # <env assignments...> -- <command...>: a minimal host-like environment
  env -i HOME="$HOST_REAL" PATH="$HOST_REAL/.local/bin:/usr/bin:/bin" TMPDIR="${TMPDIR:-/tmp}" \
    FM_STUB_LOG="$LOG" FM_TEST_SKIP_ORPHAN_REAP=1 "$@"
}

LAUNCHER_BEFORE=$(launcher)
STATE_BEFORE=$(host_state)

# --- counterfactual: the incident reproduces with only XDG sandboxed ---------
: > "$LOG"
runenv FM_STUB_UPDATER=rogue FM_STUB_CLEANUP=1 XDG_DATA_HOME="$TMP_ROOT/scratch-xdg" claude --probe >/dev/null 2>&1 \
  || fail "the stub claude must run"
[ "$(launcher)" != "$LAUNCHER_BEFORE" ] && [ ! -e "$HOST/.local/bin/claude" ] \
  || fail "the stub must reproduce the incident (host launcher re-pointed at a deleted scratch install) when only XDG is sandboxed"
pass "reproduced: sandboxing only XDG_DATA_HOME lets the updater re-point the host launcher and leave it dangling"
# restore the fake host for the cases below
ln -sfn "$LAUNCHER_BEFORE" "$HOST/.local/bin/claude"
[ "$(launcher)" = "$LAUNCHER_BEFORE" ] && [ "$(host_state)" = "$STATE_BEFORE" ] || fail "could not restore the fake host"

# --- the shim --------------------------------------------------------------
SHIM=$(runenv "$OWNER" shim "$TMP_ROOT/shim") || fail "shim must be created"
assert_equals "$TMP_ROOT/shim" "$SHIM" "shim prints its directory"

# A rogue updater that ignores DISABLE_AUTOUPDATER entirely (the worst case)
# still cannot reach the host: HOME and ~/.local are scratch.
: > "$LOG"
runenv PATH="$SHIM:$HOST_REAL/.local/bin:/usr/bin:/bin" FM_STUB_UPDATER=rogue FM_STUB_CLEANUP=1 \
  claude --probe >/dev/null 2>&1 || fail "the guarded claude must run"
assert_equals "$LAUNCHER_BEFORE" "$(launcher)" "a rogue updater run through the shim must leave the host launcher untouched"
assert_equals "$STATE_BEFORE" "$(host_state)" "nothing under the host ~/.local may change"
SB_HOME=$(logval home)
case "$SB_HOME" in "$SHIM"/homes/*) ;; *) fail "claude must run with a scratch HOME under the shim, saw: $SB_HOME" ;; esac
[ "$SB_HOME" != "$HOST_REAL" ] || fail "HOME must not be the host HOME"
pass "a rogue updater run through the shim cannot touch the host launcher or ~/.local"

assert_equals 1 "$(logval autoupdater)" "the updater switch must be on"
assert_equals 1 "$(logval updates)" "the all-updates switch must be on"
assert_equals "$SB_HOME/.local/share" "$(logval xdg_data)" "XDG_DATA_HOME must be inside the scratch HOME"
assert_equals "$SB_HOME/.local/state" "$(logval xdg_state)" "XDG_STATE_HOME must be inside the scratch HOME"
assert_equals "$SB_HOME/.cache" "$(logval xdg_cache)" "XDG_CACHE_HOME must be inside the scratch HOME"
assert_equals unset "$(logval xdg_bin)" "XDG_BIN_HOME must not point at the host"
assert_equals absent "$(logval host_install)" "the host's installed versions must not be visible under the scratch HOME"
assert_equals claude "$(logval argv0)" "the real binary must be exec'd as claude so process names stay real"
assert_equals "--probe" "$(logval args)" "arguments must pass through unchanged"
path_seen=$(logval path)
case "$path_seen" in "$SHIM:"*) ;; *) fail "the shim directory must lead PATH, saw: $path_seen" ;; esac
case ":$path_seen:" in *":$HOST_REAL/.local/bin:"*) fail "the host ~/.local/bin must not stay on PATH, saw: $path_seen" ;; esac
case ":$path_seen:" in *":$SB_HOME/.local/bin:"*) ;; *) fail "the scratch ~/.local/bin must replace it, saw: $path_seen" ;; esac
pass "updater off, scratch HOME/XDG/PATH, real process name"

# The normal login and session files still work: they are the host's, shared.
assert_equals visible "$(logval cred)" "the signed-in ~/.claude must stay visible"
[ -f "$HOST/.claude/stub-session" ] || fail "writes under ~/.claude must land in the host's ~/.claude, as before"
[ -x "$SB_HOME/.local/bin/othertool" ] || fail "other tools in ~/.local/bin must stay reachable through the scratch bin"
# The rogue run re-pointed only the scratch launcher; the next run puts the shim back.
[ "$(readlink "$SB_HOME/.local/bin/claude")" != "$LAUNCHER_BEFORE" ] || fail "the rogue run should have damaged only the scratch launcher"
runenv PATH="$SHIM:$HOST_REAL/.local/bin:/usr/bin:/bin" claude --again >/dev/null 2>&1 || fail "second guarded run"
[ "$(readlink "$SB_HOME/.local/bin/claude")" = "$SHIM/claude" ] || fail "the scratch ~/.local/bin/claude must be the shim"
pass "login, session files, and sibling tools keep working through the mirror"

# A claude started by that claude is guarded too, without stacking sandboxes.
: > "$LOG"
runenv PATH="$SHIM:$HOST_REAL/.local/bin:/usr/bin:/bin" FM_STUB_UPDATER=rogue FM_STUB_NESTED=1 \
  claude --outer >/dev/null 2>&1 || fail "the nested claude must run"
assert_equals "$SB_HOME" "$(logval home 1)" "outer scratch HOME"
assert_equals "$SB_HOME" "$(logval home 2)" "a nested claude must reuse the same scratch HOME, not a nested mirror"
assert_equals "$LAUNCHER_BEFORE" "$(launcher)" "the nested run must leave the host launcher untouched"
pass "a nested claude stays in the same sandbox"

# An updater that honors the switch is a plain no-op through the shim.
: > "$LOG"
runenv PATH="$SHIM:$HOST_REAL/.local/bin:/usr/bin:/bin" FM_STUB_UPDATER=honor claude >/dev/null 2>&1 || fail "honoring run"
assert_equals "$STATE_BEFORE" "$(host_state)" "an honoring updater must not change the host"

# With a native binary behind it the process name stays claude, which busy and
# liveness detection key on.
SLEEP_BIN=$(command -v sleep)
NATIVE_SHIM=$(runenv FM_LIVE_CLAUDE_REAL="$SLEEP_BIN" "$OWNER" shim "$TMP_ROOT/shim-native") || fail "native shim"
env -i HOME="$HOST_REAL" PATH="$NATIVE_SHIM:/usr/bin:/bin" claude 30 &
native_pid=$!
comm=''
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  comm=$(ps -o comm= -p "$native_pid" 2>/dev/null | awk '{print $1}')
  [ "$comm" = claude ] && break
  sleep 0.1
done
kill "$native_pid" 2>/dev/null; wait "$native_pid" 2>/dev/null
assert_equals claude "$comm" "a native real binary must keep the process name claude behind the shim"

# The shim refuses to guard nothing.
out=$(runenv FM_LIVE_CLAUDE_REAL="$TMP_ROOT/missing" "$OWNER" shim "$TMP_ROOT/shim-bad" 2>&1) && fail "a missing real claude must refuse"
assert_contains "$out" "not executable" "a missing real claude is reported"
out=$(runenv PATH=/usr/bin:/bin "$OWNER" shim "$TMP_ROOT/shim-none" 2>&1) && fail "no claude on PATH must refuse"
assert_contains "$out" "no executable claude" "no claude on PATH is reported"
out=$(runenv "$OWNER" 2>&1) && fail "usage error must exit non-zero"
assert_contains "$out" "usage:" "no subcommand prints usage"
pass "the shim refuses when it has nothing to guard"

# --- fm_live_gate installs it for a live scenario ---------------------------
: > "$LOG"
GATE_SCRIPT="$TMP_ROOT/gate.test.sh"
{
  printf '#!/usr/bin/env bash\nset -u\n'
  printf '. "%s/tests/lib.sh"\n' "$ROOT"
  printf 'fm_live_gate default-on FM_FAKE_LIVE claude\n'
  # shellcheck disable=SC2016 # expanded by the written scenario at its own runtime
  printf 'printf "resolved=%%s\\nshim=%%s\\n" "$(command -v claude)" "${FM_LIVE_CLAUDE_SHIM:-unset}"\n'
  printf 'claude --gated\n'
} > "$GATE_SCRIPT"
out=$(runenv FM_STUB_UPDATER=rogue FM_STUB_CLEANUP=1 bash "$GATE_SCRIPT" 2>&1) || fail "the gated scenario must run: $out"
gate_shim=$(printf '%s\n' "$out" | sed -n 's/^shim=//p')
case "$gate_shim" in "$TMP_ROOT"/*/*) ;; unset | '') fail "fm_live_gate must export FM_LIVE_CLAUDE_SHIM, saw: $out" ;; esac
assert_equals "$gate_shim/claude" "$(printf '%s\n' "$out" | sed -n 's/^resolved=//p')" "after the gate, claude must resolve to the shim"
assert_equals "$LAUNCHER_BEFORE" "$(launcher)" "a live scenario opened with fm_live_gate must leave the host launcher untouched"
assert_equals "$STATE_BEFORE" "$(host_state)" "a live scenario opened with fm_live_gate must not change ~/.local"
assert_equals 1 "$(logval autoupdater)" "the gated scenario's claude must run with the updater off"
case "$(logval home)" in "$gate_shim"/homes/*) ;; *) fail "the gated scenario's claude must run in a scratch HOME" ;; esac
[ ! -e "$gate_shim" ] || fail "the gate's shim directory must be removed with the scenario's temp root"
pass "fm_live_gate guards every claude a live scenario starts and cleans up after itself"

# A gate on a host with no claude installed adds nothing and still proceeds.
out=$(runenv PATH=/usr/bin:/bin bash -c ". '$ROOT/tests/lib.sh'; fm_live_gate default-on FM_FAKE_LIVE; echo \"shim=\${FM_LIVE_CLAUDE_SHIM:-unset}\"" 2>&1) \
  || fail "the gate must proceed without claude: $out"
assert_contains "$out" "shim=unset" "no claude installed means no shim"

# --- the spawned pane carries the shim --------------------------------------
case_dir="$TMP_ROOT/spawn"
home="$case_dir/home"; proj="$case_dir/proj"; wt="$case_dir/wt"; launchlog="$case_dir/launch.log"
fakebin=$(make_spawn_fakebin "$case_dir/fake" gh gh-axi)
ln -s "$(command -v node)" "$fakebin/node"
fm_test_spawn_home "$home" claude
fm_git_worktree "$proj" "$wt" "wt-live-claude"
fm_test_spawn_brief "$home" LC-1
: > "$launchlog"
spawn_script="$case_dir/spawn.test.sh"
{
  printf '#!/usr/bin/env bash\nset -u\n'
  printf '. %q\n' "$ROOT/tests/fixtures.sh"
  printf 'fm_test_run_spawn'
  printf ' %q' "$home" "$wt" "$fakebin" LC-1 "$proj" --mode no-mistakes --yolo off
  printf '\n'
} > "$spawn_script"
: > "$LOG"
out=$(runenv FM_FAKE_LAUNCH_LOG="$launchlog" FM_STUB_SCRIPT="$spawn_script" FM_STUB_UPDATER=rogue FM_STUB_CLEANUP=1 \
  "$SHIM/claude" --primary 2>&1) \
  || fail "an absolute-shim primary without an inherited marker must stage its spawn: $out"
assert_equals "$SHIM" "$(logval shim 1)" "the absolute-shim primary must export its shim identity"
launch=$(cat "$launchlog")
[ -n "$launch" ] || fail "no claude launch command was captured"
: > "$LOG"
# A daemon-built pane: its own PATH has the host launcher and no shim.
runenv FM_STUB_UPDATER=rogue FM_STUB_CLEANUP=1 bash -c "$launch" >/dev/null 2>&1 \
  || fail "the staged claude launch must run in the synthetic pane"
assert_equals "$LAUNCHER_BEFORE" "$(launcher)" "a claude pane spawned from a live scenario must leave the host launcher untouched"
assert_equals "$STATE_BEFORE" "$(host_state)" "a spawned claude pane must not change ~/.local"
case "$(logval home)" in "$SHIM"/homes/*) ;; *) fail "the spawned claude must run in the shim's scratch HOME, saw: $(logval home)" ;; esac
assert_equals 1 "$(logval autoupdater)" "the spawned claude must run with the updater off"
pass "an absolute-shim primary restores the marker and guards a daemon-built claude pane"

# A spawn outside a live scenario is unchanged.
: > "$launchlog"
case_dir="$TMP_ROOT/spawn-ordinary"
home="$case_dir/home"; proj="$case_dir/proj"; wt="$case_dir/wt"
fakebin=$(make_spawn_fakebin "$case_dir/fake" gh gh-axi)
fm_test_spawn_home "$home" claude
fm_git_worktree "$proj" "$wt" "wt-live-claude-2"
fm_test_spawn_brief "$home" LC-2
(
  unset FM_LIVE_CLAUDE_SHIM
  FM_FAKE_LAUNCH_LOG="$launchlog" \
    fm_test_run_spawn "$home" "$wt" "$fakebin" LC-2 "$proj" --mode no-mistakes --yolo off >/dev/null 2>&1
) || fail "the ordinary claude spawn must stage its launch command"
[ -s "$launchlog" ] || fail "no ordinary launch command was captured"
case "$(cat "$launchlog")" in *"$SHIM"*) fail "an ordinary spawn must not mention the shim" ;; esac
pass "an ordinary spawn is unchanged"

lab_source="$TMP_ROOT/lab-source"
fm_git_init_commit "$lab_source"
lab_fakebin=$(fm_fakebin "$TMP_ROOT/lab-tools")
fm_fake_exit0 "$lab_fakebin" jq node python3 pi
cat > "$lab_fakebin/tmux" <<'SH'
#!/usr/bin/env bash
case "$*" in *new-session*) ;; *) exit 1 ;; esac
printf '%s\n' "${FM_LIVE_CLAUDE_SHIM:-unset}" > "$TREEHOUSE_ROOT/../lab-shim"
FM_STUB_LOG="$TREEHOUSE_ROOT/../claude.log" FM_STUB_UPDATER=rogue FM_STUB_CLEANUP=1 claude --lab-probe || exit 2
exit 1
SH
chmod +x "$lab_fakebin/tmux"
for lab_harness in claude pi; do
  for helper in worker mate; do
    lab="$TMP_ROOT/lab-$lab_harness-$helper"
    out=$(runenv PATH="$lab_fakebin:$HOST_REAL/.local/bin:/usr/bin:/bin" \
      "$ROOT/bin/fm-live-lab.sh" up --harness "$lab_harness" "--$helper" --source "$lab_source" "$lab" 2>&1)
    lab_rc=$?
    runenv PATH="$lab_fakebin:/usr/bin:/bin" "$ROOT/bin/fm-lab-home.sh" teardown "$lab/home" \
      || fail "the non-live lab must release its unused tmux directory"
    expect_code 1 "$lab_rc" "the lab fixture must stop before starting a real backend: $out"
    assert_contains "$out" "cannot start the lab tmux server" "the lab fixture reached the clean process environment"
    assert_equals "$lab/claude-shim" "$(cat "$lab/lab-shim")" "$lab_harness --$helper must propagate the lab shim identity"
    case "$(LOG="$lab/claude.log" logval home)" in
      "$lab/claude-shim"/homes/*) ;;
      *) fail "$lab_harness --$helper must guard Claude from the shared lab environment" ;;
    esac
    assert_equals 1 "$(LOG="$lab/claude.log" logval autoupdater)" "$lab_harness --$helper must disable the updater"
    assert_equals "$LAUNCHER_BEFORE" "$(launcher)" "$lab_harness --$helper must not change the host launcher"
    assert_equals "$STATE_BEFORE" "$(host_state)" "$lab_harness --$helper must not change the host ~/.local"
  done
done
pass "Claude and Pi labs guard their shared process environment with either helper enabled"

assert_equals "$LAUNCHER_BEFORE" "$(launcher)" "the fake host launcher is intact at the end"
