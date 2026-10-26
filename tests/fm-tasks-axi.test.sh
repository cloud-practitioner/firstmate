#!/usr/bin/env bash
# Behavior tests for bin/fm-tasks-axi.sh home addressing and bootstrap's
# shadow-backlog check, over the split layout where the operational home lives
# outside the code root that carries the tracked .tasks.toml.
#
# The fork these guard against: .tasks.toml names data/backlog.md relative to
# the caller's working directory, and tasks-axi writes by renaming a temp file
# over its target, so a bare tasks-axi run from the code root turns a code-root
# symlink into the home's backlog into a private regular copy. The suite proves
# that every write through bin/fm-tasks-axi.sh lands in $FM_HOME/data from the
# code root (including archiving and relative --body-file arguments),
# that the command refuses addressing it cannot keep correct, and that bootstrap
# reports any code-root copy that is not this home's own file while staying
# silent for a link into the home, an absent copy, and the single-home layout.
# It also proves backlog dates are UTC: under a zone east and a zone west of UTC,
# at an instant where the local and UTC dates differ, every date tasks-axi
# writes or compares (created, since, done, hold-until expiry) matches the UTC
# date that the fleet snapshot uses, however the wrapper or a lifecycle helper
# reaches tasks-axi.
set -u

# shellcheck source=tests/lib.sh disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WRAPPER="$ROOT/bin/fm-tasks-axi.sh"
BOOTSTRAP="$ROOT/bin/fm-bootstrap.sh"
TMP_ROOT=$(fm_test_tmproot fm-tasks-axi)
BASE_PATH=${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}

# The developer shell may pin any of these; each case states its own layout.
unset TASKS_AXI_FILE TASKS_AXI_BACKEND FM_HOME FM_ROOT_OVERRIDE \
  FM_DATA_OVERRIDE FM_STATE_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE

HAVE_TASKS_AXI=0
command -v tasks-axi >/dev/null 2>&1 && HAVE_TASKS_AXI=1

empty_backlog() {  # <path>
  printf '## In flight\n\n## Queued\n\n## Done\n' > "$1"
}

# A code root carrying the tracked .tasks.toml and an operational home beside
# it, with the code-root backlog linked into the home the way an operator
# would try to keep the two in sync.
make_split() {  # <name>; prints the case directory
  local dir="$TMP_ROOT/$1"
  mkdir -p "$dir/code/data" "$dir/home/data" "$dir/home/state" "$dir/home/config"
  fm_test_tasks_toml "$dir/code/.tasks.toml"
  empty_backlog "$dir/home/data/backlog.md"
  ln -s "$dir/home/data/backlog.md" "$dir/code/data/backlog.md"
  printf '%s\n' "$dir"
}

# Run the wrapper from the code root, as firstmate does.
wrapper_from_code() {  # <case-dir> <tasks-axi args...>
  local dir=$1
  shift
  (cd "$dir/code" && FM_HOME="$dir/home" FM_ROOT_OVERRIDE="$dir/code" "$WRAPPER" "$@")
}

# Only the shadow-backlog lines matter here; the rest of a detect-only local
# bootstrap pass reports this host's toolchain, which is not under test, so it
# runs on the bare base PATH where every tool probe is a fast miss.
bootstrap_backlog_lines() {  # <code-root> [<home>]
  local code=$1 home=${2:-}
  if [ -n "$home" ]; then
    PATH="$BASE_PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$code" FM_BOOTSTRAP_DETECT_ONLY=1 \
      FM_BOOTSTRAP_NETWORK=skip "$BOOTSTRAP" 2>&1 | grep '^BACKLOG_RECONCILE: code-root' || true
  else
    PATH="$BASE_PATH" FM_ROOT_OVERRIDE="$code" FM_BOOTSTRAP_DETECT_ONLY=1 \
      FM_BOOTSTRAP_NETWORK=skip "$BOOTSTRAP" 2>&1 | grep '^BACKLOG_RECONCILE: code-root' || true
  fi
}

test_guard_reports_regular_code_root_backlog() {
  local dir out
  dir=$(make_split guard-regular)
  out=$(bootstrap_backlog_lines "$dir/code" "$dir/home")
  assert_equals "" "$out" "a code-root link into this home must stay silent"

  rm "$dir/code/data/backlog.md"
  out=$(bootstrap_backlog_lines "$dir/code" "$dir/home")
  assert_equals "" "$out" "an absent code-root backlog must stay silent"

  printf '## In flight\n\n## Queued\n\n- [ ] stray: written from the code root\n\n## Done\n' \
    > "$dir/code/data/backlog.md"
  out=$(bootstrap_backlog_lines "$dir/code" "$dir/home")
  assert_contains "$out" "BACKLOG_RECONCILE: code-root $dir/code/data/backlog.md is not this home's $dir/home/data/backlog.md" \
    "a regular code-root backlog beside a separate home was not reported"
  assert_not_contains "$out" "done-archive.md" "an absent code-root archive was reported"
  pass "bootstrap reports a regular code-root backlog and stays silent for a link into the home or no copy"
}

test_guard_reports_foreign_link_and_archive() {
  local dir out
  dir=$(make_split guard-foreign)
  empty_backlog "$dir/elsewhere.md"
  rm "$dir/code/data/backlog.md"
  ln -s "$dir/elsewhere.md" "$dir/code/data/backlog.md"
  printf '## Done\n' > "$dir/code/data/done-archive.md"
  out=$(bootstrap_backlog_lines "$dir/code" "$dir/home")
  assert_contains "$out" "code-root $dir/code/data/backlog.md is not this home's" \
    "a code-root backlog linked outside this home was not reported"
  assert_contains "$out" "code-root $dir/code/data/done-archive.md is not this home's $dir/home/data/done-archive.md" \
    "a regular code-root archive beside a separate home was not reported"
  pass "bootstrap reports a code-root backlog linked elsewhere and a forked archive"
}

test_guard_silent_for_single_home() {
  local dir out
  dir="$TMP_ROOT/single-guard"
  mkdir -p "$dir/data"
  fm_test_tasks_toml "$dir/.tasks.toml"
  empty_backlog "$dir/data/backlog.md"
  printf '## Done\n' > "$dir/data/done-archive.md"
  out=$(bootstrap_backlog_lines "$dir")
  assert_equals "" "$out" "the single-home layout's own backlog was reported as a fork"
  out=$(bootstrap_backlog_lines "$dir" "$dir")
  assert_equals "" "$out" "FM_HOME naming the code root was reported as a fork"
  pass "bootstrap stays silent when the code root is the home"
}

# The end-to-end fork: a bare tasks-axi write from the code root. Whatever the
# installed tasks-axi does to the link, bootstrap must agree with the result:
# a replaced link is reported, a written-through link is not.
test_bare_tasks_axi_fork_is_detected() {
  local dir out
  dir=$(make_split bare-fork)
  (cd "$dir/code" && tasks-axi add bare-1 "written from the code root" >/dev/null 2>&1) \
    || fail "bare tasks-axi add failed in the code root"
  out=$(bootstrap_backlog_lines "$dir/code" "$dir/home")
  if [ -L "$dir/code/data/backlog.md" ]; then
    assert_grep "bare-1" "$dir/home/data/backlog.md" "a written-through link lost the row"
    assert_equals "" "$out" "a written-through link was reported as a fork"
    pass "bare tasks-axi wrote through the code-root link and bootstrap stayed silent"
  else
    assert_no_grep "bare-1" "$dir/home/data/backlog.md" "the replaced link still reached the home"
    assert_contains "$out" "code-root $dir/code/data/backlog.md is not this home's" \
      "bootstrap missed the fork a bare tasks-axi write left behind"
    pass "bare tasks-axi replaced the code-root link and bootstrap reported the fork"
  fi
}

test_wrapper_writes_through_to_home() {
  local dir i
  dir=$(make_split wrapper-home)
  for i in 1 2; do
    wrapper_from_code "$dir" add "ship-$i" "ship $i" >/dev/null || fail "add ship-$i failed"
    wrapper_from_code "$dir" start "ship-$i" >/dev/null || fail "start ship-$i failed"
    wrapper_from_code "$dir" "done" "ship-$i" >/dev/null || fail "done ship-$i failed"
  done
  wrapper_from_code "$dir" add call-1 "captain call" >/dev/null || fail "add call-1 failed"
  wrapper_from_code "$dir" hold call-1 --reason "awaiting the captain" --kind captain >/dev/null \
    || fail "hold call-1 failed"
  printf 'RELATIVE-BODY-MARKER\n' > "$dir/code/body.md"
  wrapper_from_code "$dir" update call-1 --body-file body.md >/dev/null \
    || fail "update with a caller-relative --body-file failed"
  wrapper_from_code "$dir" prune --keep 1 >/dev/null || fail "prune failed"

  [ -L "$dir/code/data/backlog.md" ] || fail "a wrapper write replaced the code-root link"
  [ "$dir/code/data/backlog.md" -ef "$dir/home/data/backlog.md" ] \
    || fail "the code-root link no longer names the home's backlog"
  assert_grep "call-1" "$dir/home/data/backlog.md" "the held row did not land in the home"
  assert_grep "RELATIVE-BODY-MARKER" "$dir/home/data/backlog.md" \
    "a caller-relative --body-file was not read from the caller's directory"
  assert_present "$dir/home/data/done-archive.md" "archiving did not reach the home"
  assert_grep "ship-1" "$dir/home/data/done-archive.md" "the oldest closed row was not archived in the home"
  assert_absent "$dir/code/data/done-archive.md" "archiving wrote a code-root archive"
  assert_equals "" "$(bootstrap_backlog_lines "$dir/code" "$dir/home")" \
    "bootstrap reported a fork after only wrapper writes"
  pass "fm-tasks-axi.sh writes, holds, archives, and reads relative body files through to the home from the code root"
}

test_wrapper_overrides_ambient_file() {
  local dir
  dir=$(make_split wrapper-ambient)
  empty_backlog "$dir/decoy.md"
  (cd "$dir/code" && TASKS_AXI_FILE="$dir/decoy.md" FM_HOME="$dir/home" "$WRAPPER" add amb-1 "ambient" >/dev/null) \
    || fail "add under an ambient TASKS_AXI_FILE failed"
  assert_grep "amb-1" "$dir/home/data/backlog.md" "an ambient TASKS_AXI_FILE diverted the write from the home"
  assert_no_grep "amb-1" "$dir/decoy.md" "an ambient TASKS_AXI_FILE received the write"
  wrapper_from_code "$dir" >/dev/null || fail "the no-command dashboard failed"
  pass "fm-tasks-axi.sh pins the home's backlog over an ambient TASKS_AXI_FILE and serves the dashboard"
}

test_wrapper_refusals() {
  local dir out rc before
  dir=$(make_split wrapper-refuse)
  before=$(cat "$dir/home/data/backlog.md")
  out=$(wrapper_from_code "$dir" add r-1 "explicit" --file "$dir/home/data/backlog.md" 2>&1)
  rc=$?
  expect_code 2 "$rc" "--file"
  assert_contains "$out" "drop --file" "--file refusal did not explain itself"
  out=$(wrapper_from_code "$dir" list --file="$dir/home/data/backlog.md" 2>&1)
  rc=$?
  expect_code 2 "$rc" "--file="

  mv "$dir/home/data/backlog.md" "$dir/home/real-backlog.md"
  ln -s "$dir/home/real-backlog.md" "$dir/home/data/backlog.md"
  out=$(wrapper_from_code "$dir" add r-2 "through a link" 2>&1)
  rc=$?
  expect_code 2 "$rc" "symlinked home backlog"
  assert_contains "$out" "is a symlink" "the symlinked home backlog refusal did not name the link"
  [ -L "$dir/home/data/backlog.md" ] || fail "a refused call still replaced the home link"
  assert_equals "$before" "$(cat "$dir/home/real-backlog.md")" "a refused call changed the backlog"

  out=$(cd "$dir/code" && FM_HOME="$dir/missing-home" "$WRAPPER" list 2>&1)
  rc=$?
  expect_code 2 "$rc" "missing data directory"
  pass "fm-tasks-axi.sh refuses caller --file, a symlinked home backlog, and an unresolvable home"
}

# Dispatch alone moves a row to In flight, because only bin/fm-spawn.sh
# creates the task record, status file, and inbox that go with it; a row
# hand-placed there through `add --start` would count as live work nobody runs.
test_wrapper_refuses_add_start() {
  local dir out rc before
  dir=$(make_split wrapper-add-start)
  before=$(cat "$dir/home/data/backlog.md")
  out=$(wrapper_from_code "$dir" add hs-1 "hand-started" --start 2>&1)
  rc=$?
  expect_code 2 "$rc" "add --start"
  assert_contains "$out" "bin/fm-spawn.sh" "the add --start refusal did not name the dispatch path"
  assert_equals "$before" "$(cat "$dir/home/data/backlog.md")" "a refused add --start still wrote a row"
  out=$(wrapper_from_code "$dir" create hs-c "hand-started via alias" --start 2>&1)
  rc=$?
  expect_code 2 "$rc" "create --start"
  assert_contains "$out" "bin/fm-spawn.sh" "the create --start refusal did not name the dispatch path"
  assert_equals "$before" "$(cat "$dir/home/data/backlog.md")" "a refused create --start still wrote a row"
  wrapper_from_code "$dir" add hs-2 "queued" >/dev/null || fail "plain add was refused"
  assert_grep "hs-2" "$dir/home/data/backlog.md" "plain add did not write its row"
  wrapper_from_code "$dir" start hs-2 >/dev/null || fail "start <id> was refused"
  pass "fm-tasks-axi.sh refuses add --start while plain add and start <id> pass through"
}

test_wrapper_single_home() {
  local dir
  dir="$TMP_ROOT/single-wrapper"
  mkdir -p "$dir/data"
  fm_test_tasks_toml "$dir/.tasks.toml"
  empty_backlog "$dir/data/backlog.md"
  (cd "$dir" && FM_ROOT_OVERRIDE="$dir" "$WRAPPER" add solo-1 "single home" >/dev/null) \
    || fail "add in the single-home layout failed"
  assert_grep "solo-1" "$dir/data/backlog.md" "the single-home layout lost its own backlog write"
  pass "fm-tasks-axi.sh keeps the single-home layout addressing its own code-root backlog"
}

# Fake clock for node: freezes Date at FM_TEST_FAKE_NOW, so the instant is fixed
# whatever the wall-clock hour while TZ still drives every local date getter.
write_fake_clock() {  # <destination-file>
  cat > "$1" <<'JS'
const RealDate = Date;
const fixed = RealDate.parse(process.env.FM_TEST_FAKE_NOW);
class FakeDate extends RealDate {
  constructor(...args) {
    if (args.length === 0) super(fixed);
    else super(...args);
  }
  static now() { return fixed; }
}
globalThis.Date = FakeDate;
JS
}

# One zone at one instant, driven only through the wrapper. $utc_today is the
# UTC calendar day of the instant; the zone's local day is a different one.
assert_backlog_dates_are_utc() {  # <zone> <instant> <utc-today> <utc-tomorrow> <local-today>
  local zone=$1 instant=$2 utc_today=$3 utc_tomorrow=$4 local_today=$5
  local dir clock out held snap
  dir=$(make_split "utc-dates-${zone//\//-}")
  clock="$dir/fake-clock.cjs"
  write_fake_clock "$clock"
  fm_utc_run() {
    TZ=$zone NODE_OPTIONS="--require $clock" FM_TEST_FAKE_NOW=$instant \
      FM_HOME="$dir/home" FM_ROOT_OVERRIDE="$dir/code" "$WRAPPER" "$@"
  }
  # The scenario only means something while the two dates really differ.
  assert_equals "$local_today" "$(TZ=$zone date -d "$instant" +%F 2>/dev/null || TZ=$zone date -j -f %Y-%m-%dT%H:%M:%SZ "$instant" +%F)" \
    "the scenario's local date for $zone is wrong"
  [ "$local_today" != "$utc_today" ] || fail "the $zone scenario must straddle a UTC date boundary"

  fm_utc_run add d-ship "ship dated" --kind ship >/dev/null || fail "add failed under $zone"
  fm_utc_run add d-due "hold due today" --kind captain >/dev/null || fail "add failed under $zone"
  fm_utc_run add d-later "hold due tomorrow" --kind captain >/dev/null || fail "add failed under $zone"
  fm_utc_run start d-ship >/dev/null || fail "start failed under $zone"
  fm_utc_run hold d-due --kind captain --until "$utc_today" --reason "due on the UTC day" >/dev/null \
    || fail "hold failed under $zone"
  fm_utc_run hold d-later --kind captain --until "$utc_tomorrow" --reason "due after the UTC day" >/dev/null \
    || fail "hold failed under $zone"
  out=$(fm_utc_run show d-ship 2>&1)
  assert_contains "$out" "created: $utc_today" "created is not the UTC date under $zone"
  assert_not_contains "$out" "$local_today" "created leaked the $zone local date"
  assert_contains "$(grep -F 'd-ship' "$dir/home/data/backlog.md")" "since $utc_today" \
    "the transition date is not the UTC date under $zone"

  # tasks-axi's own expiry decision: a hold is inactive on and after its date.
  held=$(fm_utc_run list --state held --fields hold_until 2>&1)
  assert_contains "$held" "d-later" "a hold due after the UTC day expired early under $zone"
  assert_not_contains "$held" "d-due" "a hold due on the UTC day was still active under $zone"

  # The fleet snapshot counts the same two holds the same way at the same instant.
  snap=$(FM_HOME="$dir/home" FM_ROOT_OVERRIDE="$dir/code" FM_SNAPSHOT_NOW=$instant TZ=$zone "$ROOT/bin/fm-fleet-snapshot.sh" --json 2>/dev/null)
  printf '%s' "$snap" | jq -e '
    ([.backlog.records[] | select(.id == "d-due")][0]) as $due
    | ([.backlog.records[] | select(.id == "d-later")][0]) as $later
    | $due.captain_actionable == true and $later.captain_actionable == false
  ' >/dev/null || fail "the fleet snapshot disagrees with tasks-axi about hold expiry under $zone"

  fm_utc_run "done" d-ship >/dev/null || fail "done failed under $zone"
  assert_contains "$(grep -F 'd-ship' "$dir/home/data/backlog.md")" "done $utc_today" \
    "the completion date is not the UTC date under $zone"
  assert_not_contains "$(grep -F 'd-ship' "$dir/home/data/backlog.md")" "$local_today" \
    "a $zone local date reached the shipped row"
}

test_backlog_dates_are_utc_in_any_zone() {
  # 20:00Z is already tomorrow east of UTC; 03:00Z is still yesterday west of it.
  assert_backlog_dates_are_utc Australia/Sydney 2026-10-26T20:00:00Z 2026-10-26 2026-10-27 2026-10-27
  assert_backlog_dates_are_utc America/Los_Angeles 2026-10-27T03:00:00Z 2026-10-27 2026-10-28 2026-10-26
  pass "tasks-axi dates and hold expiry follow the UTC day under Australia/Sydney and America/Los_Angeles"
}

# Every route to tasks-axi, not only the wrapper, must run it on UTC: a probe
# stub records the zone it was started in.
test_every_tasks_axi_route_runs_on_utc() {
  local dir bin log
  dir="$TMP_ROOT/utc-routes"
  bin="$dir/bin"
  log="$dir/zones.log"
  mkdir -p "$bin" "$dir/code/data"
  cat > "$bin/tasks-axi" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${TZ:-unset}" >> "$FM_TEST_ZONE_LOG"
case "${1:-}" in
  --version) echo "tasks-axi 0.2.6" ;;
esac
exit 0
SH
  chmod +x "$bin/tasks-axi"
  : > "$log"
  fm_test_tasks_toml "$dir/code/.tasks.toml"
  empty_backlog "$dir/code/data/backlog.md"
  (
    export PATH="$bin:$PATH" TZ=Australia/Sydney FM_TEST_ZONE_LOG="$log"
    export FM_ROOT_OVERRIDE="$dir/code" FM_HOME="$dir/code"
    "$WRAPPER" list >/dev/null
    "$WRAPPER" show anything >/dev/null
    # shellcheck source=bin/fm-tasks-axi-lib.sh disable=SC1091
    . "$ROOT/bin/fm-tasks-axi-lib.sh"
    # shellcheck source=bin/fm-backlog-transition-lib.sh disable=SC1091
    . "$ROOT/bin/fm-backlog-transition-lib.sh"
    (fm_tasks_axi list) >/dev/null
    (FM_TASKS_AXI_TIMEOUT=30 fm_tasks_axi list) >/dev/null
    fm_tasks_axi_version_parts >/dev/null || true  # the stub answers no feature text; only its zone is read
    fm_tasks_axi_update_has_archive_body >/dev/null || true  # the stub answers no feature text; only its zone is read
    fm_tasks_axi_mv_has_multi_id >/dev/null || true  # the stub answers no feature text; only its zone is read
  ) || fail "a tasks-axi route failed against the zone probe"
  assert_equals "UTC" "$(sort -u "$log" | paste -sd, -)" "a tasks-axi route ran in a zone other than UTC"
  [ "$(wc -l < "$log")" -ge 7 ] || fail "the zone probe saw fewer tasks-axi calls than the routes made"
  pass "wrapper, lifecycle helper (plain and timed), and probes start tasks-axi on UTC under TZ=Australia/Sydney"
}

test_guard_reports_regular_code_root_backlog
test_guard_reports_foreign_link_and_archive
test_guard_silent_for_single_home
if [ "$HAVE_TASKS_AXI" = 1 ]; then
  test_bare_tasks_axi_fork_is_detected
  test_wrapper_writes_through_to_home
  test_wrapper_overrides_ambient_file
  test_wrapper_refusals
  test_wrapper_refuses_add_start
  test_wrapper_single_home
  test_backlog_dates_are_utc_in_any_zone
  test_every_tasks_axi_route_runs_on_utc
else
  echo "skip: tasks-axi not found; home-addressing cases not run"
fi
