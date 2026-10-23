#!/usr/bin/env bash
# tests/fm-secondmate-dormant.test.sh - the durable stood-down (dormant) state of
# a persistent local secondmate, owned by bin/fm-secondmate-dormant.sh and its
# record library bin/fm-secondmate-dormant-lib.sh.
#
# The gap under test: `bin/fm-control.sh <id> exit` stops a secondmate's agent but
# the liveness sweep reads the stopped mate as dead and relaunches it within about
# a minute, so a mate with no work for now could not be spun down. The guarantees:
#   - stand-down stops the agent through fm-control, records dormancy in the parent
#     home, and keeps the mate's home, route, backlog and records untouched.
#   - it refuses, changing nothing and naming each blocker, for in-flight work, a
#     pending reply, an unread steer, an undelivered handoff wake, a remote mate,
#     an already dormant mate, and an unknown mate; a failed stop records nothing.
#   - the liveness sweep never relaunches a dormant mate and never reports it dead,
#     while the same stopped mate that is NOT dormant is relaunched (the "before").
#   - fm-spawn and fm-control relaunch refuse a dormant mate except through resume.
#   - resume relaunches through the guarded launch and clears dormancy only after
#     that launch succeeds; a failed launch leaves the mate dormant.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BASE_PATH=${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}
fm_git_identity fmtest fmtest@example.com
DORMANT="$ROOT/bin/fm-secondmate-dormant.sh"
TMP_ROOT=$(fm_test_tmproot fm-secondmate-dormant)

# --- the record library ------------------------------------------------------

test_record_library_roundtrip() {
  local st="$TMP_ROOT/lib/state" out
  mkdir -p "$st"
  # shellcheck source=bin/fm-secondmate-dormant-lib.sh
  . "$ROOT/bin/fm-secondmate-dormant-lib.sh"

  fm_sm_dormant_is "$st" sm1 && fail "an id with no record must not read dormant"
  fm_sm_dormant_write "$st" sm1 $'no work\nfor now' || fail "write failed"
  fm_sm_dormant_is "$st" sm1 || fail "a written record must read dormant"
  assert_equals sm1 "$(fm_sm_dormant_get "$st" sm1 id)" "record id"
  assert_equals "no work for now" "$(fm_sm_dormant_get "$st" sm1 reason)" "a multi-line reason must flatten to one line"
  assert_grep 'schema=fm-secondmate-dormant.v1' "$st/sm1.dormant" "record schema"
  out=$(fm_sm_dormant_describe "$st" sm1)
  assert_contains "$out" "stood down since " "describe names the since-time"
  assert_contains "$out" "(no work for now)" "describe names the reason"

  fm_sm_dormant_write "$st" sm2 || fail "write without reason failed"
  assert_equals "sm1 sm2 " "$(fm_sm_dormant_ids "$st" | tr '\n' ' ')" "ids list both, sorted"

  # An unparseable record still reads dormant: the safe error leaves a mate stopped.
  printf 'garbage\n' > "$st/sm3.dormant"
  fm_sm_dormant_is "$st" sm3 || fail "an unparseable record must still read dormant"
  assert_contains "$(fm_sm_dormant_describe "$st" sm3)" "at an unrecorded time" "describe tolerates a garbage record"

  # A symlink or invalid id is never a record.
  ln -s "$st/sm1.dormant" "$st/sm4.dormant"
  fm_sm_dormant_is "$st" sm4 && fail "a symlinked path must not be a record"
  fm_sm_dormant_is "$st" 'a/b' && fail "an invalid id must not be a record"
  fm_sm_dormant_write "$st" 'a b' && fail "an invalid id must not be writable"

  fm_sm_dormant_clear "$st" sm1 || fail "clear failed"
  fm_sm_dormant_clear "$st" sm1 || fail "clearing an absent record must succeed"
  fm_sm_dormant_is "$st" sm1 && fail "a cleared record must not read dormant"
  pass "record library: write, read, describe, list, clear, and unsafe paths"
}

# --- fixture: a primary home with one local secondmate and a stateful tmux ----

make_toolchain() {  # <dir>
  local dir=$1 fakebin
  fakebin=$(fm_fakebin "$dir")
  fm_fake_exit0 "$fakebin" node chrome-devtools-axi pi-signed
  fm_fake_version_tool "$fakebin" lavish-axi FM_FAKE_LAVISH_AXI_VERSION 0.1.80
  cat > "$fakebin/gh-axi" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = --version ] && { echo 0.1.29; exit 0; }
exit 0
SH
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/gh"
  cat > "$fakebin/treehouse" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = get ] && [ "${2:-}" = --help ] && echo "Usage: treehouse get [--lease]"
exit 0
SH
  cat > "$fakebin/no-mistakes" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = --version ] && { echo "no-mistakes version v1.46.0 (fake)"; exit 0; }
exit 0
SH
  cat > "$fakebin/tasks-axi" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "--version ") printf '%s\n' '0.2.6' ;;
  "update --help") printf '%s\n' 'usage: tasks-axi update <id> [flags]' '  --archive-body' ;;
  "mv --help") printf '%s\n' 'usage: tasks-axi mv <id> [<id>...] --to <path-or-dir>' ;;
esac
exit 0
SH
  cat > "$fakebin/quota-axi" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = --version ] && { echo 0.1.51; exit 0; }
exit 0
SH
  chmod +x "$fakebin"/gh-axi "$fakebin"/gh "$fakebin"/treehouse "$fakebin"/no-mistakes "$fakebin"/tasks-axi "$fakebin"/quota-axi
  printf '%s\n' "$fakebin"
}

# A stateful tmux: the pane's foreground command lives in $FM_FAKE_DIR/command.
# Typing the exit command stops the agent (command -> zsh); a window launch brings
# one up (command -> claude) unless FM_TEST_FAIL_NEW_WINDOW=1; every window
# mutation is logged to $FM_FAKE_DIR/calls.
make_tmux() {  # <dir>
  local dir=$1 fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
set -u
D=${FM_FAKE_DIR:?}
target=
prev=
for arg in "$@"; do
  if [ "$prev" = -t ]; then
    target=${arg#=}
    target=${target#firstmate:}
    target=${target#=}
    target=${target#fm-}
  fi
  [ "$prev" != -n ] || target=${arg#fm-}
  prev=$arg
done
if [ -n "$target" ] && [ -d "$D/$target" ]; then D="$D/$target"; fi
case "${1:-}" in
  send-keys)
    literal=0
    for arg in "$@"; do
      if [ "$literal" = 1 ]; then
        printf '%s\n' "$arg" >> "$D/literal"
        if [ -z "${FM_FAKE_NEVER_DIES:-}" ] && { [ "$arg" = /exit ] || [ "$arg" = /quit ]; }; then
          printf 'zsh' > "$D/command"
          if [ -n "${FM_FAKE_STOP_GATE:-}" ]; then
            : > "$FM_FAKE_STOP_GATE.entered"
            for ((i=0; i<300; i++)); do
              [ ! -e "$FM_FAKE_STOP_GATE.release" ] || break
              sleep 0.1
            done
          fi
        fi
      fi
      [ "$arg" = -l ] && literal=1 || literal=0
    done
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
  list-windows)
    printf '%s\n' main
    [ -e "$D/killed" ] || printf '%s\n' fm-sm1
    if [ -s "$D/windows" ]; then
      while IFS= read -r name; do
        [ ! -e "$D/${name#fm-}/killed" ] || continue
        printf '%s\n' "$name"
      done < "$D/windows"
    fi
    exit 0 ;;
  new-window|kill-window)
    printf '%s\n' "$*" >> "$D/calls"
    if [ "${1:-}" = kill-window ]; then : > "$D/killed"; exit 0; fi
    [ "${FM_TEST_FAIL_NEW_WINDOW:-0}" = 1 ] && exit 1
    rm -f "$D/killed"
    printf 'claude' > "$D/command"
    exit 0 ;;
  has-session) exit 0 ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux"
  printf '%s\n' "$fakebin"
}

# new_world <name>: a primary home with a registered, running local secondmate sm1.
new_world() {
  local w="$TMP_ROOT/$1" home id=${2:-sm1}
  mkdir -p "$w/home/state" "$w/home/data" "$w/home/config" "$w/fake"
  touch "$w/home/state/.last-watcher-beat"
  printf 'codex\n' > "$w/home/config/crew-harness"
  home="$w/$id"
  mkdir -p "$home/bin" "$home/data" "$home/state" "$home/config" "$home/projects"
  printf '%s\n' "$id" > "$home/.fm-secondmate-home"
  printf '# Firstmate\n' > "$home/AGENTS.md"
  printf 'charter\n' > "$home/data/charter.md"
  printf '# Backlog\n\n## In flight\n\n## Queued\n\n## Done\n' > "$home/data/backlog.md"
  printf '%s\n' 'projects/' 'state/' 'data/' 'config/' '.no-mistakes/' > "$home/.gitignore"
  git -C "$home" init -q -b main
  fm_write_secondmate_meta "$w/home/state/$id.meta" "$home" "firstmate:fm-$id" none claude
  printf -- '- %s - a test mate (home: %s; scope: testing; projects: none; added 2026-01-01)\n' "$id" "$home" \
    > "$w/home/data/secondmates.md"
  : > "$w/fake/literal"; : > "$w/fake/calls"
  printf 'claude' > "$w/fake/command"
  printf '%s' "$home" > "$w/fake/cwd"
  make_toolchain "$w" >/dev/null
  make_tmux "$w" >/dev/null
  printf '%s\n' "$w"
}

# dormant_cmd <world> <args...>: the command under test, with the stateful tmux.
dormant_cmd() {
  local w=$1; shift
  env -u PI_CODING_AGENT -u FM_SUPERVISION_ACTOR PATH="$w/fakebin:$BASE_PATH" TMUX='' FM_BACKEND=tmux FM_HOME="$w/home" FM_FAKE_DIR="$w/fake" \
    FM_FAKE_NEVER_DIES="${FM_FAKE_NEVER_DIES:-}" FM_TEST_FAIL_NEW_WINDOW="${FM_TEST_FAIL_NEW_WINDOW:-0}" \
    FM_CONTROL_POLL=0.01 FM_CONTROL_SETTLE_WAIT=0.05 FM_CONTROL_EXIT_WAIT=0.05 FM_CONTROL_LAUNCH_WAIT=0.05 \
    "$DORMANT" "$@" 2>&1
}

# sweep <world>: the session-start liveness sweep (bootstrap), verbose facts on.
sweep() {
  local w=$1; shift
  env PATH="$w/fakebin:$BASE_PATH" TMUX='' FM_BACKEND=tmux FM_HOME="$w/home" FM_FAKE_DIR="$w/fake" \
    FM_TEST_FAIL_NEW_WINDOW="${FM_TEST_FAIL_NEW_WINDOW:-0}" "$@" "$ROOT/bin/fm-bootstrap.sh" 2>&1
}

stop_agent_with_control() {  # <world>
  env PATH="$1/fakebin:$BASE_PATH" TMUX='' FM_BACKEND=tmux FM_HOME="$1/home" FM_FAKE_DIR="$1/fake" \
    FM_CONTROL_POLL=0.01 FM_CONTROL_SETTLE_WAIT=0.05 FM_CONTROL_EXIT_WAIT=0.05 \
    "$ROOT/bin/fm-control.sh" sm1 exit 2>&1
}

# --- the "before": exit alone is undone by the sweep ---------------------------

test_before_exit_alone_is_relaunched_by_the_sweep() {
  local w out
  w=$(new_world before)
  out=$(stop_agent_with_control "$w") || fail "fm-control exit failed: $out"
  assert_equals zsh "$(cat "$w/fake/command")" "exit should have stopped the agent"
  sweep "$w" >/dev/null
  assert_contains "$(cat "$w/fake/calls")" "new-window" \
    "without dormancy the sweep relaunches a mate that was only exited"
  pass "before: fm-control exit alone is undone by the liveness sweep"
}

# --- stand-down ----------------------------------------------------------------

test_stand_down_stops_records_and_keeps_everything() {
  local w out before_reg before_backlog
  w=$(new_world stand)
  before_reg=$(cat "$w/home/data/secondmates.md")
  before_backlog=$(cat "$w/sm1/data/backlog.md")
  out=$(dormant_cmd "$w" stand-down sm1 --reason "no work for now") || fail "stand-down failed: $out"
  assert_contains "$out" "stood down sm1" "success line"
  assert_contains "$out" "resume sm1" "success line names the way back"
  assert_equals zsh "$(cat "$w/fake/command")" "the agent must be stopped"
  assert_grep 'reason=no work for now' "$w/home/state/sm1.dormant" "reason recorded in the parent home"
  assert_equals "$before_reg" "$(cat "$w/home/data/secondmates.md")" "the registry route is kept"
  assert_equals "$before_backlog" "$(cat "$w/sm1/data/backlog.md")" "the mate's backlog is kept"
  assert_present "$w/sm1/.fm-secondmate-home" "the mate's home is kept"
  assert_present "$w/home/state/sm1.meta" "the mate's durable record is kept"
  assert_not_contains "$(cat "$w/fake/calls")" "kill-window" "stand-down stops the agent, it does not kill the endpoint"
  out=$(dormant_cmd "$w" list)
  assert_contains "$out" "sm1" "list names the dormant mate"
  assert_contains "$out" "no work for now" "list shows the reason"
  pass "stand-down: stops the agent, records dormancy in the parent home, keeps the mate's records"
}

assert_refused_unchanged() {  # <world> <expected-text> <label>
  local w=$1 out rc=0
  out=$(dormant_cmd "$w" stand-down sm1) || rc=$?
  expect_code 1 "$rc" "$3 must refuse"
  assert_contains "$out" "$2" "$3 must name the blocker"
  assert_absent "$w/home/state/sm1.dormant" "$3 must record nothing"
  assert_equals claude "$(cat "$w/fake/command")" "$3 must leave the agent running"
}

test_stand_down_refuses_in_flight_work() {
  local w
  w=$(new_world busy-task)
  : > "$w/sm1/state/child.meta"
  assert_refused_unchanged "$w" "in-flight work: its home has task child" "a task record in the mate's home"
  w=$(new_world busy-backlog)
  printf '# Backlog\n\n## In flight\n\n- [ ] item-1 - doing a thing\n\n## Done\n' > "$w/sm1/data/backlog.md"
  assert_refused_unchanged "$w" "its backlog lists 1 item(s) under In flight" "an In flight backlog item"
  pass "stand-down: refuses while the mate's own home has in-flight work"
}

test_stand_down_refuses_pending_reply_unread_steer_and_handoff_wake() {
  local w
  w=$(new_world pending)
  # shellcheck disable=SC2016 # positional params expand in the child shell.
  env FM_HOME="$w/home" bash -c '. "$0/bin/fm-pending-reply-lib.sh"; fm_pending_reply_create "$1" "$2" sm1 "please report"' \
    "$ROOT" "$w/home" "$w/home/state" >/dev/null
  assert_refused_unchanged "$w" "pending reply" "an unresolved pending reply"
  w=$(new_world steer)
  mkdir -p "$w/home/state/sm1.inbox"; : > "$w/home/state/sm1.inbox/1.msg"
  assert_refused_unchanged "$w" "unread steer" "an unacknowledged steer"
  w=$(new_world wake)
  printf 'pending\n' > "$w/home/state/.backlog-handoff-sm1.wake-pending"
  assert_refused_unchanged "$w" "undelivered handoff wake" "an undelivered handoff wake"
  w=$(new_world wake-confirmed)
  printf 'confirmed\n' > "$w/home/state/.backlog-handoff-sm1.wake-pending"
  dormant_cmd "$w" stand-down sm1 >/dev/null || fail "a confirmed handoff wake must not block"
  pass "stand-down: names a pending reply, an unread steer, and an undelivered handoff wake"
}

test_stand_down_lists_every_blocker() {
  local w out
  w=$(new_world multi)
  : > "$w/sm1/state/child.meta"
  mkdir -p "$w/home/state/sm1.inbox"; : > "$w/home/state/sm1.inbox/1.msg"
  out=$(dormant_cmd "$w" stand-down sm1) || true
  assert_contains "$out" "in-flight work" "first blocker"
  assert_contains "$out" "unread steer" "second blocker"
  pass "stand-down: lists every blocker at once"
}

test_stand_down_refuses_remote_dormant_and_unknown() {
  local w out rc=0
  w=$(new_world remote)
  printf 'remote_host=lab\n' >> "$w/home/state/sm1.meta"
  out=$(dormant_cmd "$w" stand-down sm1) || rc=$?
  expect_code 1 "$rc" "remote mate must refuse"
  assert_contains "$out" "is remote" "remote refusal names why"
  assert_absent "$w/home/state/sm1.dormant" "remote mate: nothing recorded"

  w=$(new_world remote-route)
  printf -- '- sm1 - a test mate (host: lab; root: /r; home: /r/sm1; scope: testing; projects: none; added 2026-01-01)\n' \
    > "$w/home/data/secondmates.md"
  rc=0; out=$(dormant_cmd "$w" stand-down sm1) || rc=$?
  expect_code 1 "$rc" "a remote registry route must refuse"
  assert_contains "$out" "remote" "remote route refusal"

  w=$(new_world twice)
  dormant_cmd "$w" stand-down sm1 >/dev/null || fail "first stand-down failed"
  rc=0; out=$(dormant_cmd "$w" stand-down sm1) || rc=$?
  expect_code 1 "$rc" "second stand-down must refuse"
  assert_contains "$out" "already dormant" "already-dormant refusal"

  rc=0; out=$(dormant_cmd "$w" stand-down ghost) || rc=$?
  expect_code 1 "$rc" "unknown id must refuse"
  assert_contains "$out" "no durable record" "unknown refusal"
  rc=0; out=$(dormant_cmd "$w" stand-down) || rc=$?
  expect_code 2 "$rc" "missing id is a usage error"
  rc=0; out=$(env FM_HOME= "$DORMANT" list 2>&1) || rc=$?
  expect_code 1 "$rc" "an unset FM_HOME must refuse"
  pass "stand-down: refuses remote, already dormant, unknown, and malformed requests"
}

test_failed_stop_records_nothing() {
  local w out rc=0
  w=$(new_world stubborn)
  out=$(FM_FAKE_NEVER_DIES=1 dormant_cmd "$w" stand-down sm1) || rc=$?
  expect_code 1 "$rc" "an agent that does not stop must fail the stand-down"
  assert_contains "$out" "dormancy was not recorded" "failure says nothing was recorded"
  assert_absent "$w/home/state/sm1.dormant" "no record after a failed stop"
  pass "stand-down: a stop that cannot be confirmed records no dormancy"
}

# --- relaunch paths skip a dormant mate -----------------------------------------

test_sweep_skips_a_dormant_mate_and_lists_it() {
  local w out
  w=$(new_world sweep)
  dormant_cmd "$w" stand-down sm1 >/dev/null || fail "stand-down failed"
  : > "$w/fake/calls"
  out=$(sweep "$w")
  assert_not_contains "$out" "SECONDMATE_LIVENESS" "a dormant mate is never reported by the sweep"
  [ ! -s "$w/fake/calls" ] || fail "the sweep must not touch a dormant mate: $(cat "$w/fake/calls")"
  assert_equals zsh "$(cat "$w/fake/command")" "the mate stays stopped through the sweep"
  out=$(sweep "$w" FM_BOOTSTRAP_VERBOSE_FACTS=1)
  assert_contains "$out" "BOOTSTRAP_INFO: secondmate sm1 dormant" "verbose facts list it as dormant, not dead"
  [ ! -s "$w/fake/calls" ] || fail "verbose sweep must not touch a dormant mate"
  pass "sweep: a dormant mate stays stopped, is not reported dead, and shows as dormant"
}

test_spawn_and_control_relaunch_refuse_a_dormant_mate() {
  local w out rc=0
  w=$(new_world refuse-launch)
  dormant_cmd "$w" stand-down sm1 >/dev/null || fail "stand-down failed"
  : > "$w/fake/calls"
  out=$(env PATH="$w/fakebin:$BASE_PATH" TMUX='' FM_BACKEND=tmux FM_HOME="$w/home" FM_FAKE_DIR="$w/fake" \
    "$ROOT/bin/fm-spawn.sh" sm1 --secondmate 2>&1) || rc=$?
  expect_code 1 "$rc" "fm-spawn --secondmate must refuse a dormant mate"
  assert_contains "$out" "is dormant" "spawn refusal names dormancy"
  assert_contains "$out" "resume sm1" "spawn refusal names the way back"
  rc=0
  out=$(env PATH="$w/fakebin:$BASE_PATH" TMUX='' FM_BACKEND=tmux FM_HOME="$w/home" FM_FAKE_DIR="$w/fake" \
    "$ROOT/bin/fm-control.sh" sm1 relaunch 2>&1) || rc=$?
  expect_code 1 "$rc" "fm-control relaunch must refuse a dormant mate"
  assert_contains "$out" "is dormant" "control refusal names dormancy"
  [ ! -s "$w/fake/calls" ] || fail "a refused launch must not touch the endpoint: $(cat "$w/fake/calls")"
  pass "fm-spawn --secondmate and fm-control relaunch refuse a dormant mate"
}

# --- resume ----------------------------------------------------------------------

test_resume_relaunches_and_clears_only_on_success() {
  local w out rc=0
  w=$(new_world resume-fail)
  dormant_cmd "$w" stand-down sm1 >/dev/null || fail "stand-down failed"
  out=$(FM_TEST_FAIL_NEW_WINDOW=1 dormant_cmd "$w" resume sm1) || rc=$?
  expect_code 1 "$rc" "a failed launch must fail the resume"
  assert_contains "$out" "stays dormant" "failure says the mate stays dormant"
  assert_present "$w/home/state/sm1.dormant" "a failed launch leaves dormancy in place"

  w=$(new_world resume-ok)
  dormant_cmd "$w" stand-down sm1 >/dev/null || fail "stand-down failed"
  out=$(dormant_cmd "$w" resume sm1) || fail "resume failed: $out"
  assert_contains "$out" "resumed sm1" "success line"
  assert_absent "$w/home/state/sm1.dormant" "dormancy cleared after the launch succeeded"
  assert_contains "$(cat "$w/fake/calls")" "new-window" "resume launched through the guarded spawn"
  assert_equals claude "$(cat "$w/fake/command")" "the agent is running again"
  out=$(sweep "$w")
  assert_not_contains "$out" "SECONDMATE_LIVENESS" "a resumed mate is ordinary again"
  pass "resume: launches through the guarded spawn and clears dormancy only on success"
}

test_resume_edge_cases() {
  local w out rc=0
  w=$(new_world not-dormant)
  out=$(dormant_cmd "$w" resume sm1) || rc=$?
  expect_code 1 "$rc" "resume of a mate that is not dormant must refuse"
  assert_contains "$out" "not dormant" "refusal says so"

  w=$(new_world already-running)
  dormant_cmd "$w" stand-down sm1 >/dev/null || fail "stand-down failed"
  printf 'claude' > "$w/fake/command"
  : > "$w/fake/calls"
  out=$(dormant_cmd "$w" resume sm1) || fail "resume of a running mate failed: $out"
  assert_contains "$out" "already running" "an already running agent is not relaunched"
  assert_absent "$w/home/state/sm1.dormant" "dormancy cleared for a running agent"
  [ ! -s "$w/fake/calls" ] || fail "a running agent must not be relaunched"
  pass "resume: refuses a mate that is not dormant and just clears one already running"
}

test_exact_prefixed_id_leaves_sibling_untouched() {
  local w out
  w=$(new_world exact-id fm-ops)
  mkdir -p "$w/ops/data" "$w/ops/state" "$w/fake/ops" "$w/fake/fm-ops"
  printf 'ops\n' > "$w/ops/.fm-secondmate-home"
  printf 'sibling backlog\n' > "$w/ops/data/backlog.md"
  fm_write_secondmate_meta "$w/home/state/ops.meta" "$w/ops" firstmate:fm-ops none claude
  printf -- '- ops - sibling (home: %s; scope: sibling; projects: none; added 2026-01-01)\n' "$w/ops" \
    >> "$w/home/data/secondmates.md"
  printf 'fm-ops\nfm-fm-ops\n' > "$w/fake/windows"
  cp "$w/fake/command" "$w/fake/cwd" "$w/fake/calls" "$w/fake/literal" "$w/fake/fm-ops/"
  cp "$w/fake/command" "$w/fake/calls" "$w/fake/literal" "$w/fake/ops/"
  printf '%s' "$w/ops" > "$w/fake/ops/cwd"

  out=$(dormant_cmd "$w" stand-down fm-ops) || fail "exact prefixed stand-down failed: $out"
  assert_present "$w/home/state/fm-ops.dormant" "the exact ID is stood down"
  assert_absent "$w/home/state/ops.dormant" "the sibling is not stood down"
  assert_equals zsh "$(cat "$w/fake/fm-ops/command")" "the exact endpoint is stopped"
  assert_equals claude "$(cat "$w/fake/ops/command")" "the sibling keeps running"
  [ ! -s "$w/fake/ops/literal" ] || fail "nothing may be typed to the sibling"

  out=$(dormant_cmd "$w" resume fm-ops) || fail "exact prefixed resume failed: $out"
  assert_absent "$w/home/state/fm-ops.dormant" "the exact ID is resumed"
  assert_equals claude "$(cat "$w/fake/fm-ops/command")" "the exact endpoint is running"
  assert_equals claude "$(cat "$w/fake/ops/command")" "the sibling is still running"
  [ ! -s "$w/fake/ops/calls" ] || fail "the sibling endpoint must not be replaced"
  assert_equals "sibling backlog" "$(cat "$w/ops/data/backlog.md")" "the sibling records stay intact"
  pass "stand-down and resume preserve the exact fm-prefixed ID and its sibling"
}

test_cursor_resume_accepts_dead_and_missing_endpoints() {
  local w state out
  for state in dead missing; do
    w=$(new_world "cursor-$state")
    fm_write_secondmate_meta "$w/home/state/sm1.meta" "$w/sm1" firstmate:fm-sm1 none cursor
    dormant_cmd "$w" stand-down sm1 >/dev/null || fail "Cursor stand-down failed"
    [ "$state" != missing ] || : > "$w/fake/killed"
    out=$(dormant_cmd "$w" resume sm1) || fail "Cursor resume from $state failed: $out"
    assert_absent "$w/home/state/sm1.dormant" "successful Cursor resume clears dormancy"
    assert_contains "$(cat "$w/fake/calls")" new-window "Cursor resume launches the endpoint"
    assert_grep 'harness=codex' "$w/home/state/sm1.meta" "resume uses the current launch configuration"
  done
  pass "a stopped Cursor mate resumes from dead or missing with the current harness"
}

test_stand_down_serializes_work_and_launch_admission() {
  local w pid i out rc script args
  w=$(new_world admission-race)
  FM_FAKE_STOP_GATE="$w/gate" dormant_cmd "$w" stand-down sm1 > "$w/stand-down.out" 2>&1 &
  pid=$!
  for ((i=0; i<200; i++)); do
    [ ! -e "$w/gate.entered" ] || break
    sleep 0.1
  done
  if [ ! -e "$w/gate.entered" ]; then
    : > "$w/gate.release"
    wait "$pid" || true
    fail "stand-down did not reach the stop/publication window: $(cat "$w/stand-down.out")"
  fi
  for args in send send-fire-and-forget send-key handoff control spawn spawn-relaunch; do
    case "$args" in
      send) script=fm-send.sh; set -- sm1 "please reread inherited config" ;;
      send-fire-and-forget) script=fm-send.sh; set -- sm1 --fire-and-forget reconcile-race "please reconcile" ;;
      send-key) script=fm-send.sh; set -- sm1 --key Enter ;;
      handoff) script=fm-backlog-handoff.sh; set -- sm1 queued-item ;;
      control) script=fm-control.sh; set -- sm1 relaunch ;;
      spawn) script=fm-spawn.sh; set -- sm1 --secondmate ;;
      spawn-relaunch) script=fm-spawn.sh; set -- sm1 --relaunch ;;
    esac
    rc=0
    out=$(env -u PI_CODING_AGENT -u FM_SUPERVISION_ACTOR PATH="$w/fakebin:$BASE_PATH" TMUX='' FM_BACKEND=tmux FM_HOME="$w/home" FM_FAKE_DIR="$w/fake" \
      "$ROOT/bin/$script" "$@" 2>&1) || rc=$?
    if [ "$rc" -ne 1 ] || [[ "$out" != *"admission in progress"* ]]; then
      : > "$w/gate.release"
      wait "$pid" || true
      fail "$args must refuse admission during stand-down (rc=$rc): $out"
    fi
  done
  : > "$w/gate.release"
  wait "$pid" || fail "stand-down failed: $(cat "$w/stand-down.out")"
  assert_present "$w/home/state/sm1.dormant" "stand-down publishes dormancy"
  assert_absent "$w/home/state/sm1.inbox" "no racing steer is queued"
  assert_absent "$w/home/state/.backlog-handoff-sm1.wake-pending" "no racing handoff is admitted"
  if compgen -G "$w/home/state/pending-replies/*" >/dev/null; then fail "no racing reply expectation is created"; fi
  [ ! -s "$w/fake/calls" ] || fail "no racing launch may mutate the endpoint"
  pass "stand-down serializes ordinary, automatic and key sends, handoffs and both launch forms"
}

test_record_library_roundtrip
test_exact_prefixed_id_leaves_sibling_untouched
test_cursor_resume_accepts_dead_and_missing_endpoints
test_stand_down_serializes_work_and_launch_admission
test_before_exit_alone_is_relaunched_by_the_sweep
test_stand_down_stops_records_and_keeps_everything
test_stand_down_refuses_in_flight_work
test_stand_down_refuses_pending_reply_unread_steer_and_handoff_wake
test_stand_down_lists_every_blocker
test_stand_down_refuses_remote_dormant_and_unknown
test_failed_stop_records_nothing
test_sweep_skips_a_dormant_mate_and_lists_it
test_spawn_and_control_relaunch_refuse_a_dormant_mate
test_resume_relaunches_and_clears_only_on_success
test_resume_edge_cases

echo "# all fm-secondmate-dormant tests passed"
