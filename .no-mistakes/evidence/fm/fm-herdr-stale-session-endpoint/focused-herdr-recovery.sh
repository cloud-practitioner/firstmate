#!/usr/bin/env bash
# Isolated real-Herdr E2E coverage for the default-on disposable single-task
# presentation projection, its explicit opt-out, and its best-effort
# owning-parent ordering across primary and secondmate homes.
# The test drives the real spawn and teardown scripts, a real Treehouse pool,
# and the guarded named-session lab helper.
set -u

ROOT="/home/node/.no-mistakes/worktrees/450411b3e67c/01M47HX8Y8BQRSDDHWXNW190JH"
HERDR_LAB_HELPER=${HERDR_LAB_HELPER:-$ROOT/bin/fm-herdr-lab.sh}

fail() { printf 'not ok - %s\n' "$1" >&2; cleanup_all; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

command -v herdr >/dev/null 2>&1 || { echo "skip: herdr not found"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "skip: jq not found"; exit 0; }
command -v treehouse >/dev/null 2>&1 || { echo "skip: treehouse not found"; exit 0; }
[ -x "$HERDR_LAB_HELPER" ] || { echo "skip: Herdr lab helper not executable at $HERDR_LAB_HELPER"; exit 0; }

REAL_HERDR=$(command -v herdr)
REAL_TREEHOUSE=$(command -v treehouse)
HERDR_ORIGINAL_PATH=$PATH
TMP_ROOT=$(mktemp -d "$(cd "${TMPDIR:-/tmp}" && pwd -P)/fm-herdr-presentation.XXXXXX")
FAKEBIN="$TMP_ROOT/fakebin"
HERDR_CALL_LOG="$TMP_ROOT/herdr-calls.log"
TREEHOUSE_CALL_LOG="$TMP_ROOT/treehouse-calls.log"
TREEHOUSE_LOCK_DIR="$TMP_ROOT/treehouse-call.lock"
MOVE_CALL_LOG="$TMP_ROOT/workspace-move-calls.log"
FOCUS_AUDIT_LOG="$TMP_ROOT/focus-audit.log"
ACTIVE_SEEDED_CONTROL="$TMP_ROOT/active-seeded-control"
POST_CREATE_ABORT_CONTROL="$TMP_ROOT/post-create-abort-control"
SLOW_HOLDER_CONTROL="$TMP_ROOT/slow-holder-control"
mkdir -p "$FAKEBIN"
: > "$HERDR_CALL_LOG"
: > "$TREEHOUSE_CALL_LOG"
: > "$MOVE_CALL_LOG"
: > "$FOCUS_AUDIT_LOG"
REAL_MOVER="$ROOT/bin/backends/herdr-workspace-move.py"
export REAL_HERDR REAL_TREEHOUSE REAL_MOVER HERDR_CALL_LOG TREEHOUSE_CALL_LOG TREEHOUSE_LOCK_DIR MOVE_CALL_LOG FOCUS_AUDIT_LOG HERDR_ORIGINAL_PATH HERDR_LAB_HELPER
export ACTIVE_SEEDED_CONTROL POST_CREATE_ABORT_CONTROL SLOW_HOLDER_CONTROL TMP_ROOT

# Log every production-adapter call, remove its already-validated trailing
# session flag, and send the operation through the lab helper so that helper
# remains the sole process which appends the real trailing session flag.
# The adapter's deliberately session-independent version read cannot pass the
# helper's leading-option guard, so the wrapper sends only that read straight
# to the absolute real binary with the same explicit trailing lab session.
cat > "$FAKEBIN/herdr" <<'SH'
#!/usr/bin/env bash
set -u
{
  first=1
  for arg in "$@"; do
    [ "$first" -eq 0 ] && printf '\t'
    printf '%s' "$arg"
    first=0
  done
  printf '\n'
} >> "$HERDR_CALL_LOG"
args=("$@")
last_index=$((${#args[@]} - 1))
flag_index=$((last_index - 1))
if [ "${#args[@]}" -ge 2 ] \
   && [ "${args[$flag_index]}" = --session ] \
   && [ "${args[$last_index]}" = "${HERDR_LAB_SESSION:?}" ]; then
  unset "args[$last_index]" "args[$flag_index]"
fi
set -- "${args[@]}"
for arg in "$@"; do
  case "$arg" in
    --session|--session=*)
      echo "test wrapper: unexpected caller-supplied session flag" >&2
      exit 1
      ;;
  esac
done
if [ "${1:-}" = --version ]; then
  exec env PATH="$HERDR_ORIGINAL_PATH" "$REAL_HERDR" "$@" --session "$HERDR_LAB_SESSION"
fi
focus_snapshot() {
  local list row workspace tab tabs
  list=$(env PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" run "$HERDR_LAB_SESSION" workspace list) || return 1
  row=$(printf '%s' "$list" | jq -r '
    [.result.workspaces[]? | select(.focused == true)]
    | select(length == 1)
    | .[0]
    | select((.workspace_id | type) == "string" and (.active_tab_id | type) == "string")
    | [.workspace_id, .active_tab_id]
    | @tsv
  ') || return 1
  [ -n "$row" ] || return 1
  workspace=${row%%$'\t'*}
  tab=${row#*$'\t'}
  tabs=$(env PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" run "$HERDR_LAB_SESSION" tab list --workspace "$workspace") || return 1
  printf '%s' "$tabs" | jq -e --arg tab "$tab" '
    ([.result.tabs[]? | select(.focused == true)] | length) == 1
    and ([.result.tabs[]? | select(.focused == true)][0].tab_id == $tab)
  ' >/dev/null 2>&1 || return 1
  printf '%s/%s' "$workspace" "$tab"
}

arg_value() {
  local want=$1 previous= arg
  shift
  for arg in "$@"; do
    if [ "$previous" = "$want" ]; then
      printf '%s' "$arg"
      return 0
    fi
    previous=$arg
  done
  return 1
}

label=$(arg_value --label "$@" || true)
if [ "${1:-} ${2:-}" = "workspace list" ] && [ -d "$ACTIVE_SEEDED_CONTROL" ]; then
  stage=$(cat "$ACTIVE_SEEDED_CONTROL/stage" 2>/dev/null || true)
  if [ "$stage" = task-created ]; then
    printf '%s\n' post-task-snapshot > "$ACTIVE_SEEDED_CONTROL/stage"
  elif [ "$stage" = post-task-snapshot ]; then
    seeded_tab=$(cat "$ACTIVE_SEEDED_CONTROL/seeded-tab")
    inject_before=$(focus_snapshot || printf ambiguous/ambiguous)
    env PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" run "$HERDR_LAB_SESSION" tab focus "$seeded_tab" >/dev/null
    inject_after=$(focus_snapshot || printf ambiguous/ambiguous)
    printf 'active-seeded-inject\t%s\t%s\t%s\n' "$inject_before" "$inject_after" "$seeded_tab" >> "$FOCUS_AUDIT_LOG"
    printf '%s\n' injected > "$ACTIVE_SEEDED_CONTROL/stage"
  fi
fi

mutation=
mutation_target=${3:-}
case "${1:-} ${2:-}" in
  "workspace create") mutation=workspace-create; mutation_target=$label ;;
  "tab create") mutation=tab-create; mutation_target=$label ;;
  "pane close") mutation=pane-close ;;
  "tab focus") mutation=tab-focus ;;
esac
refusal_probe=0
if [ "${1:-} ${2:-}" = "pane get" ] && [ -d "$ACTIVE_SEEDED_CONTROL" ] \
   && [ "$(cat "$ACTIVE_SEEDED_CONTROL/stage" 2>/dev/null || true)" = injected ] \
   && [ "${3:-}" = "$(cat "$ACTIVE_SEEDED_CONTROL/seeded-pane" 2>/dev/null || true)" ]; then
  refusal_probe=1
  refusal_before=$(focus_snapshot || printf ambiguous/ambiguous)
fi
before=
[ -z "$mutation" ] || before=$(focus_snapshot || printf ambiguous/ambiguous)
# A slow-holder fixture stretches one named task tab create, which runs while
# its spawn holds the shared session presentation lock, and logs when each
# stretched call starts and ends.
slow_holder=0
if [ "$mutation" = tab-create ] && [ -n "$label" ] && [ -e "$SLOW_HOLDER_CONTROL/$label" ]; then
  slow_holder=1
  printf '%s\tstart\t%s\n' "$label" "$(date +%s)" >> "$SLOW_HOLDER_CONTROL/log"
  sleep "$(cat "$SLOW_HOLDER_CONTROL/$label")"
fi
if out=$(env PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" run "$HERDR_LAB_SESSION" "$@"); then
  status=0
else
  status=$?
fi
[ "$slow_holder" -eq 0 ] || printf '%s\tend\t%s\n' "$label" "$(date +%s)" >> "$SLOW_HOLDER_CONTROL/log"
if [ "$status" -eq 0 ] && [ "$mutation" = workspace-create ]; then
  case "$label" in
    $'└ active-seeded · p:'*)
      mkdir -p "$ACTIVE_SEEDED_CONTROL"
      printf '%s\n' "$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id')" > "$ACTIVE_SEEDED_CONTROL/workspace"
      printf '%s\n' "$(printf '%s' "$out" | jq -r '.result.tab.tab_id')" > "$ACTIVE_SEEDED_CONTROL/seeded-tab"
      printf '%s\n' "$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')" > "$ACTIVE_SEEDED_CONTROL/seeded-pane"
      ;;
    $'└ abort-a · p:'*|$'└ abort-b · p:'*)
      task=${label#$'└ '}; task=${task%% *}
      mkdir -p "$POST_CREATE_ABORT_CONTROL/$task"
      printf '%s\n' "$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id')" > "$POST_CREATE_ABORT_CONTROL/$task/workspace"
      ;;
  esac
fi
if [ "$status" -eq 0 ] && [ "$mutation" = tab-create ]; then
  case "$label" in
    fm-active-seeded)
      printf '%s\n' "$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')" > "$ACTIVE_SEEDED_CONTROL/task-pane"
      printf '%s\n' task-created > "$ACTIVE_SEEDED_CONTROL/stage"
      ;;
    fm-abort-a|fm-abort-b)
      task=${label#fm-}
      mkdir -p "$POST_CREATE_ABORT_CONTROL/$task"
      printf '%s\n' "$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')" > "$POST_CREATE_ABORT_CONTROL/$task/task-pane"
      ;;
  esac
fi
if [ "$status" -eq 0 ] && [ "${1:-} ${2:-}" = "pane get" ] && [ -d "$POST_CREATE_ABORT_CONTROL" ]; then
  for task_dir in "$POST_CREATE_ABORT_CONTROL"/abort-*; do
    [ -d "$task_dir" ] || continue
    [ "${3:-}" = "$(cat "$task_dir/task-pane" 2>/dev/null || true)" ] || continue
    out=$(printf '%s' "$out" | jq --arg cwd "$POST_CREATE_ABORT_CONTROL/not-a-worktree" '.result.pane.foreground_cwd = $cwd')
    break
  done
fi
if [ -n "$mutation" ]; then
  after=$(focus_snapshot || printf ambiguous/ambiguous)
  printf '%s\t%s\t%s\t%s\n' "$mutation" "$before" "$after" "$mutation_target" >> "$FOCUS_AUDIT_LOG"
fi
if [ "$refusal_probe" -eq 1 ]; then
  refusal_after=$(focus_snapshot || printf ambiguous/ambiguous)
  printf 'seeded-prune-refusal\t%s\t%s\t%s\n' "$refusal_before" "$refusal_after" "${3:-}" >> "$FOCUS_AUDIT_LOG"
fi
[ -z "$out" ] || printf '%s\n' "$out"
exit "$status"
SH

cat > "$FAKEBIN/treehouse" <<'SH'
#!/usr/bin/env bash
set -u
{
  first=1
  for arg in "$@"; do
    [ "$first" -eq 0 ] && printf '\t'
    printf '%s' "$arg"
    first=0
  done
  printf '\n'
} >> "$TREEHOUSE_CALL_LOG"
if [ -d "$POST_CREATE_ABORT_CONTROL" ] && [ "${1:-}" = get ]; then
  exit 0
fi
# Treehouse's pool allocator is outside the Herdr concurrency contract under
# test. Serialize its calls so simultaneous recovery spawns cannot race for
# one pool slot before reaching the Herdr session lock exercised below.
while ! mkdir "$TREEHOUSE_LOCK_DIR" 2>/dev/null; do
  sleep 0.01
done
release_treehouse_lock() { rmdir "$TREEHOUSE_LOCK_DIR" 2>/dev/null || true; }
trap release_treehouse_lock EXIT
trap 'exit 1' HUP INT TERM
"$REAL_TREEHOUSE" "$@"
exit $?
SH

cat > "$FAKEBIN/herdr-workspace-mover" <<'SH'
#!/usr/bin/env bash
set -u
focus_snapshot() {
  local list row workspace tab tabs
  list=$(env PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" run "$HERDR_LAB_SESSION" workspace list) || return 1
  row=$(printf '%s' "$list" | jq -r '
    [.result.workspaces[]? | select(.focused == true)]
    | select(length == 1)
    | .[0]
    | [.workspace_id, .active_tab_id]
    | @tsv
  ') || return 1
  [ -n "$row" ] || return 1
  workspace=${row%%$'\t'*}
  tab=${row#*$'\t'}
  tabs=$(env PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" run "$HERDR_LAB_SESSION" tab list --workspace "$workspace") || return 1
  printf '%s' "$tabs" | jq -e --arg tab "$tab" '
    ([.result.tabs[]? | select(.focused == true)] | length) == 1
    and ([.result.tabs[]? | select(.focused == true)][0].tab_id == $tab)
  ' >/dev/null 2>&1 || return 1
  printf '%s/%s' "$workspace" "$tab"
}
printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$MOVE_CALL_LOG"
before=$(focus_snapshot || printf ambiguous/ambiguous)
if out=$("$REAL_MOVER" "$@"); then
  status=0
else
  status=$?
fi
after=$(focus_snapshot || printf ambiguous/ambiguous)
printf 'workspace-move\t%s\t%s\t%s\n' "$before" "$after" "$2" >> "$FOCUS_AUDIT_LOG"
[ -z "$out" ] || printf '%s\n' "$out"
exit "$status"
SH
chmod +x "$FAKEBIN/herdr" "$FAKEBIN/treehouse"
chmod +x "$FAKEBIN/herdr-workspace-mover"
export PATH="$FAKEBIN:$PATH"
export FM_BACKEND_HERDR_WORKSPACE_MOVER="$FAKEBIN/herdr-workspace-mover"

# shellcheck source=tests/herdr-test-safety.sh
. "$ROOT/tests/herdr-test-safety.sh"
# This suite runs against its own isolated lab session, so a Herdr pane
# inherited from the terminal it was launched in must not follow spawn into it
# as a cross-session parent identity. Every projection below is anchored on the
# parent this suite sets up, not on the developer's own workspace.
herdr_forget_inherited_pane

HERDR_LAB_SESSION=$(PATH="$HERDR_ORIGINAL_PATH" \
  "$HERDR_LAB_HELPER" name fm-herdr-presentation-projection)
export HERDR_SESSION="$HERDR_LAB_SESSION" HERDR_LAB_SESSION
LAB_READY=0
RECORDED_WORKTREES=""
LOCK_CONTENTION_OWNER_PID=
cleanup_all() {
  local wt
  if [ -n "$LOCK_CONTENTION_OWNER_PID" ]; then
    kill "$LOCK_CONTENTION_OWNER_PID" 2>/dev/null || true
    wait "$LOCK_CONTENTION_OWNER_PID" 2>/dev/null || true
    LOCK_CONTENTION_OWNER_PID=
  fi
  while IFS= read -r wt; do
    [ -n "$wt" ] || continue
    [ -d "$wt" ] || continue
    "$REAL_TREEHOUSE" return --force "$wt" >/dev/null 2>&1 || true
  done <<EOF
$RECORDED_WORKTREES
EOF
  if [ "$LAB_READY" -eq 1 ]; then
    PATH="$HERDR_ORIGINAL_PATH" \
      "$HERDR_LAB_HELPER" teardown "$HERDR_LAB_SESSION" >/dev/null 2>&1 || true
    LAB_READY=0
  fi
  # Tasks this suite never tears down, such as the anchor, keep their
  # read-only state/<id>.git-hooks strip directories and their staged launch
  # directories outside the tree (tests/fixture-tree-helpers.sh).
  mkdir -p "/home/node/.no-mistakes/evidence/01M47HX8Y8BQRSDDHWXNW190JH/focused-recovery-details"
  cp "$TMP_ROOT"/*-resume.out "$TMP_ROOT"/*-reclaim.out "$TMP_ROOT"/*-idempotent.out "$TMP_ROOT"/*-teardown.out "$TMP_ROOT"/*-first.out "$TMP_ROOT"/herdr-calls.log "$TMP_ROOT"/slow-holder-control/log "/home/node/.no-mistakes/evidence/01M47HX8Y8BQRSDDHWXNW190JH/focused-recovery-details/" 2>/dev/null || true
  fm_test_remove_spawn_launch_dirs "$TMP_ROOT"
  fm_test_remove_tree "$TMP_ROOT"
}
trap cleanup_all EXIT

PATH="$HERDR_ORIGINAL_PATH" \
  "$HERDR_LAB_HELPER" provision "$HERDR_LAB_SESSION" \
  || fail "could not provision the isolated Herdr lab"
LAB_READY=1

lab() {
  PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" run "$HERDR_LAB_SESSION" "$@"
}

focus_snapshot() {
  local list row workspace tab tabs
  list=$(lab workspace list) || fail "could not read the active workspace for focus instrumentation"
  row=$(printf '%s' "$list" | jq -r '
    [.result.workspaces[]? | select(.focused == true)]
    | select(length == 1)
    | .[0]
    | select((.workspace_id | type) == "string" and (.active_tab_id | type) == "string")
    | [.workspace_id, .active_tab_id]
    | @tsv
  ') || fail "could not parse the active workspace and tab"
  [ -n "$row" ] || fail "focus instrumentation found an ambiguous active workspace"
  workspace=${row%%$'\t'*}
  tab=${row#*$'\t'}
  tabs=$(lab tab list --workspace "$workspace") || fail "could not verify the active tab"
  printf '%s' "$tabs" | jq -e --arg tab "$tab" '
    ([.result.tabs[]? | select(.focused == true)] | length) == 1
    and ([.result.tabs[]? | select(.focused == true)][0].tab_id == $tab)
  ' >/dev/null 2>&1 || fail "workspace active_tab_id disagreed with the focused tab"
  printf '%s/%s' "$workspace" "$tab"
}

assert_focus_is() {  # <expected> <case-name>
  local expected=$1 case_name=$2 actual
  actual=$(focus_snapshot)
  [ "$actual" = "$expected" ] || fail "$case_name changed active workspace/tab from $expected to $actual"
}

focus_audit_line_count() { wc -l < "$FOCUS_AUDIT_LOG" | tr -d '[:space:]'; }

assert_raw_presentation_mutations_preserved_since() {  # <line-count> <case-name>
  local start=$1 case_name=$2 changed
  changed=$(sed -n "$((start + 1)),\$p" "$FOCUS_AUDIT_LOG" | awk -F '\t' '
    ($1 == "workspace-create" || $1 == "tab-create" || $1 == "workspace-move" || $1 == "pane-close") && $2 != $3 {
      print $0
    }
  ')
  [ -z "$changed" ] || fail "$case_name changed active workspace/tab inside a create, move, or seeded cleanup: $changed"
}

# The focus-safe emptying-close plan removes a last pane through Herdr's
# pane-death path with no pane.close mutation at all (the raw explicit-close
# defect is demonstrated by tests/fm-backend-herdr-focus-flash-e2e.test.sh);
# a fallback plain close must preserve or immediately restore exact focus.
assert_cleanup_focus_preserved() {  # <line-count> <pane-id> <expected-focus>
  local start=$1 pane_id=$2 expected=$3
  sed -n "$((start + 1)),\$p" "$FOCUS_AUDIT_LOG" | awk -F '\t' -v pane="$pane_id" -v expected="$expected" '
    $1 == "pane-close" && $4 == pane {
      saw_close = 1
      if ($2 != expected) { bad = 1 }
      else if ($3 == expected) { preserved = 1 }
      else { drift = $3 }
      next
    }
    saw_close && drift != "" && $1 == "tab-focus" && $2 == drift && $3 == expected {
      preserved = 1
    }
    END { exit(bad || (saw_close && !preserved) ? 1 : 0) }
  ' || fail "projected pane close did not preserve or restore the exact active workspace and tab"
  if lab pane get "$pane_id" >/dev/null 2>&1; then
    fail "projected cleanup left exact pane $pane_id alive"
  fi
}

remember_meta_worktree() {  # <meta>
  local wt
  wt=$(grep '^worktree=' "$1" | cut -d= -f2-)
  [ -n "$wt" ] || fail "metadata did not record a worktree"
  RECORDED_WORKTREES="${RECORDED_WORKTREES}${wt}"$'\n'
  printf '%s' "$wt"
}

make_project() {  # <dir>
  local dir=$1
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '# Herdr projection E2E fixture\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" -c user.name='Firstmate Tests' -c user.email='tests@example.invalid' commit -qm initial
  git clone --quiet --bare "$dir" "$dir.origin.git"
  git -C "$dir" remote add origin "file://$dir.origin.git"
}

write_ship_brief() {  # <home> <id> [description]
  local home=$1 id=$2 description=${3:-Herdr presentation fixture $2}
  mkdir -p "$home/data/$id"
  cat > "$home/data/$id/brief.md" <<EOF
# Task
## Captain's intent
$description

## Firstmate spec
Verify projected workspace behavior for $id.
EOF
}

spawn_task() {  # <id> <home> <project>
  local id=$1 home=$2 project=$3
  FM_GATE_REFUSE_BYPASS=1 FM_SPAWN_NO_GUARD=1 FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$ROOT/bin/fm-spawn.sh" "$id" "$project" "sh -c 'while :; do sleep 60; done'" --mode no-mistakes --yolo off --backend herdr
}

finish_concurrent_spawn() {  # <id> <status> <stdout> <stderr>
  local id=$1 status=$2 out=$3 err=$4
  [ "$status" -ne 0 ] || return 0
  grep -F "task set is locked" "$err" >/dev/null 2>&1 \
    || fail "concurrent projected spawn $id failed unexpectedly: $(cat "$err")"
  spawn_task "$id" "$HOME_DIR" "$PROJECT_DIR" > "$out" 2> "$err" \
    || fail "projected spawn $id retry failed after task-set publication completed: $(cat "$err")"
}

finish_concurrent_expected_abort() {  # <id> <status> <stdout> <stderr>
  local id=$1 status=$2 out=$3 err=$4
  [ "$status" -ne 0 ] || fail "post-create abort fixture $id unexpectedly succeeded"
  if grep -F "task set is locked" "$err" >/dev/null 2>&1; then
    if spawn_task "$id" "$HOME_DIR" "$PROJECT_DIR" > "$out" 2> "$err"; then
      fail "post-create abort fixture $id unexpectedly succeeded after task-set publication completed"
    fi
  fi
}

spawn_secondmate_task() {
  local id=$1 home=$2
  FM_GATE_REFUSE_BYPASS=1 FM_SPAWN_NO_GUARD=1 FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" \
    "$ROOT/bin/fm-spawn.sh" "$id" "$home" "sh -c 'while :; do sleep 60; done'" --secondmate --backend herdr
}

teardown_task() {  # <id> <home>
  local id=$1 home=$2
  FM_GATE_REFUSE_BYPASS=1 FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_CONFIG_OVERRIDE="$home/config" \
    "$ROOT/bin/fm-teardown.sh" "$id" --force
}

finish_concurrent_teardown() {  # <id> <status> <stdout> <stderr>
  local id=$1 status=$2 out=$3 err=$4
  [ "$status" -ne 0 ] || return 0
  if ! grep -F "session presentation lock is contended" "$err" >/dev/null 2>&1 \
     && ! grep -F "another Treehouse slot allocation or return is in progress" "$err" >/dev/null 2>&1; then
    fail "projected teardown $id failed unexpectedly: $(cat "$err")"
  fi
  teardown_task "$id" "$HOME_DIR" > "$out" 2> "$err" \
    || fail "projected teardown $id retry failed after presentation cleanup completed: $(cat "$err")"
}

# In-place husk reclaim is the compatibility path for records without a
# process binding. A restart replaces the shell, so identity-bearing records
# intentionally cannot authorize reclaim of the restored pane.
use_legacy_restart_record() {  # <meta>
  local meta=$1
  if ! awk -F= '$1 != "herdr_process_identity"' "$meta" > "$meta.legacy" \
    || ! mv "$meta.legacy" "$meta"; then
    fail "could not prepare legacy restart record $meta"
  fi
}

normalize_meta() {  # <meta>
  sed -E \
    -e 's|^window=.*$|window=<herdr-container-id>|' \
    -e 's|^herdr_workspace_id=.*$|herdr_workspace_id=<herdr-container-id>|' \
    -e 's|^herdr_tab_id=.*$|herdr_tab_id=<herdr-container-id>|' \
    -e 's|^herdr_pane_id=.*$|herdr_pane_id=<herdr-container-id>|' \
    -e 's|^herdr_process_identity=.*$|herdr_process_identity=<pane-process-incarnation>|' \
    -e 's|^spawn_gen=.*$|spawn_gen=<spawn-incarnation>|' \
    "$1"
}

log_line_count() { wc -l < "$HERDR_CALL_LOG" | tr -d '[:space:]'; }

projection_labels_from_log() {  # <start-line>
  local start=$1
  sed -n "$((start + 1)),\$p" "$HERDR_CALL_LOG" | awk -F '\t' '
    $1 == "workspace" && $2 == "create" {
      for (i = 1; i < NF; i += 1) {
        if ($i == "--label" && $(i + 1) ~ /^└ /) {
          print $(i + 1)
        }
      }
    }
  '
}

session_presentation_lock_path() {
  PATH="$FAKEBIN:$PATH" HERDR_SESSION="$HERDR_LAB_SESSION" bash -c '
    . "$0/bin/backends/herdr.sh"
    fm_backend_herdr_presentation_session_lock_path "$1"
  ' "$ROOT" "$HERDR_LAB_SESSION"
}

assert_no_ordering_lifecycle_calls_since() {  # <line-count> <case-name>
  local start=$1 name=$2 calls
  calls=$(sed -n "$((start + 1)),\$p" "$HERDR_CALL_LOG")
  if printf '%s\n' "$calls" | grep -E $'^(workspace\t(close|rename)|tab\tclose|session\t(stop|delete)|server)' >/dev/null 2>&1; then
    fail "$name introduced a workspace/tab/session lifecycle or label mutation call"
  fi
}

assert_no_projection_mutation_since() {  # <line-count> <case-name>
  local start=$1 name=$2 calls
  calls=$(sed -n "$((start + 1)),\$p" "$HERDR_CALL_LOG")
  if printf '%s\n' "$calls" | grep -E $'^(workspace\t(create|close|rename)|tab\t(create|close)|pane\tclose|session\t(stop|delete)|server)' >/dev/null 2>&1; then
    fail "$name performed a create, close, delete, rename, or lifecycle call during recovery inspection"
  fi
}

HOME_DIR="$TMP_ROOT/home"
PROJECT_DIR="$TMP_ROOT/project"
RECOVERY_PROJECT_DIR="$TMP_ROOT/recovery-project"
mkdir -p "$HOME_DIR/state" "$HOME_DIR/config" \
  "$HOME_DIR/data/anchor" "$HOME_DIR/data/shape" \
  "$HOME_DIR/data/order-a" "$HOME_DIR/data/order-b" \
  "$HOME_DIR/data/order-fail" "$HOME_DIR/data/fm-hibit-resume-r1" \
  "$HOME_DIR/data/wheelhouse-healing-r1"
mkdir -p "$HOME_DIR/data/active-seeded" "$HOME_DIR/data/abort-a" "$HOME_DIR/data/abort-b" \
  "$HOME_DIR/data/lock-contended" "$HOME_DIR/data/default-on"
touch "$HOME_DIR/state/.last-watcher-beat"
# Presentation spaces are on by default, so the flat baseline below opts out
# explicitly; the projected cases each restate the setting they exercise.
printf 'off\n' > "$HOME_DIR/config/herdr-presentation-spaces"
write_ship_brief "$HOME_DIR" anchor 'Projection anchor fixture.'
write_ship_brief "$HOME_DIR" shape 'Projection E2E fixture.'
write_ship_brief "$HOME_DIR" order-a 'Projection ordering fixture A.'
write_ship_brief "$HOME_DIR" order-b 'Projection ordering fixture B.'
write_ship_brief "$HOME_DIR" order-fail 'Projection ordering failure fixture.'
write_ship_brief "$HOME_DIR" fm-hibit-resume-r1 'Hi Bit-style projection restart fixture.'
write_ship_brief "$HOME_DIR" wheelhouse-healing-r1 'Wheelhouse-style projection restart fixture.'
write_ship_brief "$HOME_DIR" active-seeded 'Projection active seeded fixture.'
write_ship_brief "$HOME_DIR" abort-a 'Projection abort fixture A.'
write_ship_brief "$HOME_DIR" abort-b 'Projection abort fixture B.'
write_ship_brief "$HOME_DIR" lock-contended 'Projection lock contention fixture.'
write_ship_brief "$HOME_DIR" default-on 'Projection default-on fixture.'
make_project "$PROJECT_DIR"
make_project "$RECOVERY_PROJECT_DIR"

# Keep one ordinary primary task live so the durable firstmate workspace is
# first and remains present while disposable workers are projected around it.
spawn_task anchor "$HOME_DIR" "$PROJECT_DIR" > "$TMP_ROOT/anchor.out" 2> "$TMP_ROOT/anchor.err" \
  || fail "opted-out anchor spawn failed: $(cat "$TMP_ROOT/anchor.err")"
ANCHOR_META="$HOME_DIR/state/anchor.meta"
remember_meta_worktree "$ANCHOR_META" >/dev/null
FIRSTMATE_WSID=$(grep '^herdr_workspace_id=' "$ANCHOR_META" | cut -d= -f2-)
[ -n "$FIRSTMATE_WSID" ] || fail "anchor metadata did not record the firstmate workspace"

# The same task id and project run once opted out and once projected, so
# Treehouse commands and metadata can be compared after normalizing endpoint
# IDs, pane process identity, and the deliberately fresh per-spawn incarnation.

printf 'on\n' > "$HOME_DIR/config/herdr-presentation-spaces"
SECOND_HOME_A="$TMP_ROOT/home-2ndmate-alpha"
SECOND_HOME_B="$TMP_ROOT/home-2ndmate-bravo"
for pair in "alpha:$SECOND_HOME_A" "bravo:$SECOND_HOME_B"; do
  child="${pair#*:}"
  mkdir -p "$child/state" "$child/config" "$child/data"
  printf '%s\n' "${pair%%:*}" > "$child/.fm-secondmate-home"
  printf 'on\n' > "$child/config/herdr-presentation-spaces"
  touch "$child/state/.last-watcher-beat"
  lab workspace create --cwd "$child" --label "2ndmate-${pair%%:*}" --no-focus >/dev/null
done


for RESTART_ID in fm-hibit-resume-r1 wheelhouse-healing-r1; do
  spawn_task "$RESTART_ID" "$HOME_DIR" "$RECOVERY_PROJECT_DIR" > "$TMP_ROOT/$RESTART_ID-first.out" 2> "$TMP_ROOT/$RESTART_ID-first.err" \
    || fail "$RESTART_ID fixture's projected spawn failed: $(cat "$TMP_ROOT/$RESTART_ID-first.err")"
  RESTART_META="$HOME_DIR/state/$RESTART_ID.meta"
  OLD_RESTART_WT=$(remember_meta_worktree "$RESTART_META")
  OLD_RESTART_WSID=$(grep '^herdr_workspace_id=' "$RESTART_META" | cut -d= -f2-)
  OLD_RESTART_PANE=$(grep '^herdr_pane_id=' "$RESTART_META" | cut -d= -f2-)
  OLD_RESTART_LABEL=$(lab workspace get "$OLD_RESTART_WSID" | jq -r '.result.workspace.label')
  [ "$(grep '^version=' "$HOME_DIR/state/$RESTART_ID.herdr-presentation")" = version=2 ] \
    || fail "$RESTART_ID fresh projection did not publish an exact restart binding"
  EXPECTED_CONCISE=${RESTART_ID#fm-}
  case "$OLD_RESTART_LABEL" in
    "└ $EXPECTED_CONCISE · p:"*) ;;
    *) fail "$RESTART_ID fresh projection label did not apply concise prefix handling: $OLD_RESTART_LABEL" ;;
  esac
  PATH="$HERDR_ORIGINAL_PATH" \
    "$HERDR_LAB_HELPER" stop "$HERDR_LAB_SESSION" >/dev/null \
    || fail "could not stop the isolated session for $RESTART_ID validation"
  PATH="$HERDR_ORIGINAL_PATH" \
    "$HERDR_LAB_HELPER" provision "$HERDR_LAB_SESSION" \
    || fail "could not reprovision the isolated session for $RESTART_ID validation"
  # Stopping the whole Herdr session also ends the anchor's agent. Its restored
  # shell remains useful as the durable layout anchor, but its task record no
  # longer represents a live slot owner and must not poison later slot reuse.
  rm -f "$ANCHOR_META"
  lab pane get "$OLD_RESTART_PANE" >/dev/null 2>&1 \
    || fail "$RESTART_ID restart did not preserve the projected pane structurally"
  if lab agent get "$OLD_RESTART_PANE" >/dev/null 2>&1; then
    fail "$RESTART_ID restart fixture unexpectedly retained a registered agent"
  fi
  BOUND_RESTART_STATE=$(FM_HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" bash -c '
    . "$1/bin/fm-backend.sh"
    fm_backend_agent_state herdr "$2" "fm-$3"
  ' bash "$ROOT" "$(grep '^window=' "$RESTART_META" | cut -d= -f2-)" "$RESTART_ID")
  [ "$BOUND_RESTART_STATE" = missing ] \
    || fail "$RESTART_ID process-bound record accepted a replacement shell: $BOUND_RESTART_STATE"
  use_legacy_restart_record "$RESTART_META"
  RECLAIM_FOCUS=$(focus_snapshot)
  spawn_task "$RESTART_ID" "$HOME_DIR" "$RECOVERY_PROJECT_DIR" > "$TMP_ROOT/$RESTART_ID-reclaim.out" 2> "$TMP_ROOT/$RESTART_ID-reclaim.err" \
    || fail "$RESTART_ID same-identity reclaim failed: $(cat "$TMP_ROOT/$RESTART_ID-reclaim.err")"
  NEW_RESTART_WT=$(remember_meta_worktree "$RESTART_META")
  NEW_RESTART_WSID=$(grep '^herdr_workspace_id=' "$RESTART_META" | cut -d= -f2-)
  NEW_RESTART_PANE=$(grep '^herdr_pane_id=' "$RESTART_META" | cut -d= -f2-)
  [ "$NEW_RESTART_WSID" = "$OLD_RESTART_WSID" ] \
    || fail "$RESTART_ID reclaim flattened into a different workspace"
  [ "$NEW_RESTART_PANE" != "$OLD_RESTART_PANE" ] \
    || fail "$RESTART_ID reclaim reused the old husk pane"
  [ "$(lab workspace get "$NEW_RESTART_WSID" | jq -r '.result.workspace.label')" = "$OLD_RESTART_LABEL" ] \
    || fail "$RESTART_ID reclaim renamed or replaced the projected workspace"
  if lab pane get "$OLD_RESTART_PANE" >/dev/null 2>&1; then
    fail "$RESTART_ID reclaim did not close the exact old husk pane"
  fi
  [ "$(grep '^pane_id=' "$HOME_DIR/state/$RESTART_ID.herdr-presentation" | cut -d= -f2-)" = "$NEW_RESTART_PANE" ] \
    || fail "$RESTART_ID reclaim did not advance the exact journal binding"
  assert_focus_is "$RECLAIM_FOCUS" "$RESTART_ID same-identity reclaim"

  if [ "$RESTART_ID" = fm-hibit-resume-r1 ]; then
    PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" stop "$HERDR_LAB_SESSION" >/dev/null \
      || fail "could not stop the isolated session for idempotent reclaim"
    PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" provision "$HERDR_LAB_SESSION" \
      || fail "could not reprovision the isolated session for idempotent reclaim"
    PRIOR_RESTART_WT=$NEW_RESTART_WT
    PRIOR_RESTART_PANE=$NEW_RESTART_PANE
    use_legacy_restart_record "$RESTART_META"
    spawn_task "$RESTART_ID" "$HOME_DIR" "$RECOVERY_PROJECT_DIR" > "$TMP_ROOT/$RESTART_ID-idempotent.out" 2> "$TMP_ROOT/$RESTART_ID-idempotent.err" \
      || fail "$RESTART_ID repeated reclaim failed: $(cat "$TMP_ROOT/$RESTART_ID-idempotent.err")"
    NEW_RESTART_WT=$(remember_meta_worktree "$RESTART_META")
    NEW_RESTART_WSID=$(grep '^herdr_workspace_id=' "$RESTART_META" | cut -d= -f2-)
    NEW_RESTART_PANE=$(grep '^herdr_pane_id=' "$RESTART_META" | cut -d= -f2-)
    [ "$NEW_RESTART_WSID" = "$OLD_RESTART_WSID" ] \
      || fail "$RESTART_ID repeated reclaim changed workspace identity"
    [ "$NEW_RESTART_PANE" != "$PRIOR_RESTART_PANE" ] \
      || fail "$RESTART_ID repeated reclaim reused the prior husk pane"
    if [ "$PRIOR_RESTART_WT" != "$NEW_RESTART_WT" ]; then
      "$REAL_TREEHOUSE" return --force "$PRIOR_RESTART_WT" >/dev/null 2>&1 || true
    fi
  fi

  teardown_task "$RESTART_ID" "$HOME_DIR" > "$TMP_ROOT/$RESTART_ID-teardown.out" 2> "$TMP_ROOT/$RESTART_ID-teardown.err" \
    || fail "$RESTART_ID teardown after reclaim failed: $(cat "$TMP_ROOT/$RESTART_ID-teardown.err")"
  [ ! -e "$HOME_DIR/state/$RESTART_ID.herdr-presentation" ] \
    || fail "$RESTART_ID exact reclaimed teardown did not retire its journal"
  "$REAL_TREEHOUSE" return --force "$OLD_RESTART_WT" >/dev/null 2>&1 || true
  "$REAL_TREEHOUSE" return --force "$NEW_RESTART_WT" >/dev/null 2>&1 || true
done
pass "real Herdr lab: process-bound restarts reject replacement shells; legacy Hi Bit and Wheelhouse records reclaim one nested space with exact focus and idempotence"

# A legacy secondmate child binds and reclaims only inside its own home and parent.
CROSS_RESTART_ID=wheel-child-resume
mkdir -p "$SECOND_HOME_A/data/$CROSS_RESTART_ID"
write_ship_brief "$SECOND_HOME_A" "$CROSS_RESTART_ID" 'Cross-home restart fixture.'
spawn_task "$CROSS_RESTART_ID" "$SECOND_HOME_A" "$RECOVERY_PROJECT_DIR" > "$TMP_ROOT/cross-restart-first.out" 2> "$TMP_ROOT/cross-restart-first.err" \
  || fail "cross-home restart fixture failed: $(cat "$TMP_ROOT/cross-restart-first.err")"
CROSS_RESTART_META="$SECOND_HOME_A/state/$CROSS_RESTART_ID.meta"
CROSS_OLD_WT=$(remember_meta_worktree "$CROSS_RESTART_META")
CROSS_OLD_WSID=$(grep '^herdr_workspace_id=' "$CROSS_RESTART_META" | cut -d= -f2-)
CROSS_OLD_PANE=$(grep '^herdr_pane_id=' "$CROSS_RESTART_META" | cut -d= -f2-)
CROSS_OLD_LABEL=$(lab workspace get "$CROSS_OLD_WSID" | jq -r '.result.workspace.label')
CROSS_BOUND_HOME=$(grep '^home=' "$SECOND_HOME_A/state/$CROSS_RESTART_ID.herdr-presentation" | cut -d= -f2-)
[ "$CROSS_BOUND_HOME" = "$(cd "$SECOND_HOME_A" && pwd -P)" ] \
  || fail "cross-home restart journal did not bind the secondmate's exact home"
[ ! -e "$HOME_DIR/state/$CROSS_RESTART_ID.herdr-presentation" ] \
  || fail "cross-home restart published a journal in the primary home"
PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" stop "$HERDR_LAB_SESSION" >/dev/null \
  || fail "could not stop the isolated session for cross-home restart"
PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" provision "$HERDR_LAB_SESSION" \
  || fail "could not reprovision the isolated session for cross-home restart"
use_legacy_restart_record "$CROSS_RESTART_META"
spawn_task "$CROSS_RESTART_ID" "$SECOND_HOME_A" "$RECOVERY_PROJECT_DIR" > "$TMP_ROOT/cross-restart-resume.out" 2> "$TMP_ROOT/cross-restart-resume.err" \
  || fail "cross-home same-identity reclaim failed: $(cat "$TMP_ROOT/cross-restart-resume.err")"
CROSS_NEW_WT=$(remember_meta_worktree "$CROSS_RESTART_META")
CROSS_NEW_WSID=$(grep '^herdr_workspace_id=' "$CROSS_RESTART_META" | cut -d= -f2-)
CROSS_NEW_PANE=$(grep '^herdr_pane_id=' "$CROSS_RESTART_META" | cut -d= -f2-)
[ "$CROSS_NEW_WSID" = "$CROSS_OLD_WSID" ] && [ "$CROSS_NEW_PANE" != "$CROSS_OLD_PANE" ] \
  || fail "cross-home reclaim did not replace one pane inside the same secondmate child workspace"
[ "$(lab workspace get "$CROSS_NEW_WSID" | jq -r '.result.workspace.label')" = "$CROSS_OLD_LABEL" ] \
  || fail "cross-home reclaim changed the secondmate child's presentation label"
teardown_task "$CROSS_RESTART_ID" "$SECOND_HOME_A" > "$TMP_ROOT/cross-restart-teardown.out" 2> "$TMP_ROOT/cross-restart-teardown.err" \
  || fail "cross-home reclaimed teardown failed: $(cat "$TMP_ROOT/cross-restart-teardown.err")"
"$REAL_TREEHOUSE" return --force "$CROSS_OLD_WT" >/dev/null 2>&1 || true
"$REAL_TREEHOUSE" return --force "$CROSS_NEW_WT" >/dev/null 2>&1 || true
pass "real Herdr lab: secondmate restart binding and reclaim stay isolated to the exact child home and parent"

# Two legacy homes recovering concurrently serialize on the named session
# lock and each replace only their own exact husk.
PRIMARY_WAVE_ID=resume-wave-primary
BRAVO_WAVE_ID=resume-wave-bravo
mkdir -p "$HOME_DIR/data/$PRIMARY_WAVE_ID" "$SECOND_HOME_B/data/$BRAVO_WAVE_ID"
write_ship_brief "$HOME_DIR" "$PRIMARY_WAVE_ID" 'Concurrent primary recovery fixture.'
write_ship_brief "$SECOND_HOME_B" "$BRAVO_WAVE_ID" 'Concurrent secondmate recovery fixture.'
spawn_task "$PRIMARY_WAVE_ID" "$HOME_DIR" "$RECOVERY_PROJECT_DIR" > "$TMP_ROOT/primary-wave-first.out" 2> "$TMP_ROOT/primary-wave-first.err" \
  || fail "primary recovery-wave fixture failed: $(cat "$TMP_ROOT/primary-wave-first.err")"
spawn_task "$BRAVO_WAVE_ID" "$SECOND_HOME_B" "$RECOVERY_PROJECT_DIR" > "$TMP_ROOT/bravo-wave-first.out" 2> "$TMP_ROOT/bravo-wave-first.err" \
  || fail "secondmate recovery-wave fixture failed: $(cat "$TMP_ROOT/bravo-wave-first.err")"
PRIMARY_WAVE_META="$HOME_DIR/state/$PRIMARY_WAVE_ID.meta"
BRAVO_WAVE_META="$SECOND_HOME_B/state/$BRAVO_WAVE_ID.meta"
PRIMARY_WAVE_OLD_WT=$(remember_meta_worktree "$PRIMARY_WAVE_META")
BRAVO_WAVE_OLD_WT=$(remember_meta_worktree "$BRAVO_WAVE_META")
PRIMARY_WAVE_WSID=$(grep '^herdr_workspace_id=' "$PRIMARY_WAVE_META" | cut -d= -f2-)
BRAVO_WAVE_WSID=$(grep '^herdr_workspace_id=' "$BRAVO_WAVE_META" | cut -d= -f2-)
PRIMARY_WAVE_OLD_PANE=$(grep '^herdr_pane_id=' "$PRIMARY_WAVE_META" | cut -d= -f2-)
BRAVO_WAVE_OLD_PANE=$(grep '^herdr_pane_id=' "$BRAVO_WAVE_META" | cut -d= -f2-)
PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" stop "$HERDR_LAB_SESSION" >/dev/null \
  || fail "could not stop the isolated session for concurrent recovery"
PATH="$HERDR_ORIGINAL_PATH" "$HERDR_LAB_HELPER" provision "$HERDR_LAB_SESSION" \
  || fail "could not reprovision the isolated session for concurrent recovery"
use_legacy_restart_record "$PRIMARY_WAVE_META"
use_legacy_restart_record "$BRAVO_WAVE_META"
CONCURRENT_RECOVERY_FOCUS=$(focus_snapshot)
# A live holder that keeps the session lock past the recovery wait is stuck:
# recovery refuses clearly before any Herdr mutation.
STUCK_RECOVERY_READY="$TMP_ROOT/stuck-recovery-ready"
STUCK_RECOVERY_RELEASE="$TMP_ROOT/stuck-recovery-release"
STUCK_RECOVERY_LOCK=$(session_presentation_lock_path) \
  || fail "could not resolve the session presentation lock for stuck-holder recovery"
ROOT="$ROOT" READY="$STUCK_RECOVERY_READY" RELEASE="$STUCK_RECOVERY_RELEASE" \
  LOCK="$STUCK_RECOVERY_LOCK" bash -c '
  . "$ROOT/bin/fm-wake-lib.sh"
  fm_lock_try_acquire "$LOCK" || exit 1
  : > "$READY"
  while [ ! -e "$RELEASE" ]; do sleep 0.05; done
  fm_lock_release "$LOCK"
' &
LOCK_CONTENTION_OWNER_PID=$!
while [ ! -e "$STUCK_RECOVERY_READY" ] && kill -0 "$LOCK_CONTENTION_OWNER_PID" 2>/dev/null; do sleep 0.01; done
[ -e "$STUCK_RECOVERY_READY" ] || fail "could not hold the session presentation lock for stuck-holder recovery"
STUCK_RECOVERY_CALLS=$(log_line_count)
if FM_TEST_HERDR_RECOVERY_LOCK_WAIT=1 spawn_task "$PRIMARY_WAVE_ID" "$HOME_DIR" "$RECOVERY_PROJECT_DIR" \
  > "$TMP_ROOT/stuck-recovery.out" 2> "$TMP_ROOT/stuck-recovery.err"; then
  STUCK_RECOVERY_STATUS=0
else
  STUCK_RECOVERY_STATUS=$?
fi
: > "$STUCK_RECOVERY_RELEASE"
wait "$LOCK_CONTENTION_OWNER_PID" || fail "stuck-holder recovery lock owner failed"
LOCK_CONTENTION_OWNER_PID=
[ "$STUCK_RECOVERY_STATUS" -ne 0 ] || fail "recovery behind a stuck session lock holder unexpectedly succeeded"
grep -F "herdr presentation recovery could not acquire its session lock within 1s; refusing a concurrent resume" \
  "$TMP_ROOT/stuck-recovery.err" >/dev/null 2>&1 \
  || fail "recovery behind a stuck holder did not refuse clearly: $(cat "$TMP_ROOT/stuck-recovery.err")"
[ "$(grep '^herdr_pane_id=' "$PRIMARY_WAVE_META" | cut -d= -f2-)" = "$PRIMARY_WAVE_OLD_PANE" ] \
  || fail "a refused stuck-holder recovery changed the task endpoint"
if sed -n "$((STUCK_RECOVERY_CALLS + 1)),\$p" "$HERDR_CALL_LOG" | grep -E $'^(workspace|tab|pane)\t(create|close|focus|move)' >/dev/null; then
  fail "a refused stuck-holder recovery mutated Herdr: $(sed -n "$((STUCK_RECOVERY_CALLS + 1)),\$p" "$HERDR_CALL_LOG")"
fi
assert_focus_is "$CONCURRENT_RECOVERY_FOCUS" "refused stuck-holder recovery"
# Each recovery's husk-replacement tab create is stretched past the former
# fixed five-second lock budget, so whichever recovery wins the session lock
# holds it long enough that the other must wait for it rather than refuse.
SLOW_HOLDER_SECONDS=8
mkdir -p "$SLOW_HOLDER_CONTROL"
printf '%s\n' "$SLOW_HOLDER_SECONDS" > "$SLOW_HOLDER_CONTROL/fm-$PRIMARY_WAVE_ID"
printf '%s\n' "$SLOW_HOLDER_SECONDS" > "$SLOW_HOLDER_CONTROL/fm-$BRAVO_WAVE_ID"
CONCURRENT_RECOVERY_START=$(date +%s)
spawn_task "$PRIMARY_WAVE_ID" "$HOME_DIR" "$RECOVERY_PROJECT_DIR" > "$TMP_ROOT/primary-wave-resume.out" 2> "$TMP_ROOT/primary-wave-resume.err" &
PRIMARY_WAVE_PID=$!
spawn_task "$BRAVO_WAVE_ID" "$SECOND_HOME_B" "$RECOVERY_PROJECT_DIR" > "$TMP_ROOT/bravo-wave-resume.out" 2> "$TMP_ROOT/bravo-wave-resume.err" &
BRAVO_WAVE_PID=$!
wait "$PRIMARY_WAVE_PID" || fail "concurrent primary recovery failed: $(cat "$TMP_ROOT/primary-wave-resume.err")"
wait "$BRAVO_WAVE_PID" || fail "concurrent secondmate recovery failed: $(cat "$TMP_ROOT/bravo-wave-resume.err")"
[ "$(grep -c $'\tstart\t' "$SLOW_HOLDER_CONTROL/log")" = 2 ] \
  && [ "$(grep -c $'\tend\t' "$SLOW_HOLDER_CONTROL/log")" = 2 ] \
  || fail "concurrent recovery did not stretch both husk replacements: $(cat "$SLOW_HOLDER_CONTROL/log")"
SLOW_FIRST_END=$(awk -F '\t' '$2 == "end" { print $3; exit }' "$SLOW_HOLDER_CONTROL/log")
SLOW_SECOND_START=$(awk -F '\t' '$2 == "start" { n++; if (n == 2) { print $3; exit } }' "$SLOW_HOLDER_CONTROL/log")
[ "$SLOW_SECOND_START" -ge "$SLOW_FIRST_END" ] \
  || fail "concurrent recoveries overlapped their husk replacements instead of serializing: $(cat "$SLOW_HOLDER_CONTROL/log")"
[ $((SLOW_SECOND_START - CONCURRENT_RECOVERY_START)) -ge "$SLOW_HOLDER_SECONDS" ] \
  || fail "the second concurrent recovery was not held behind the slow lock holder: $(cat "$SLOW_HOLDER_CONTROL/log")"
rm -rf "$SLOW_HOLDER_CONTROL"
PRIMARY_WAVE_NEW_WT=$(remember_meta_worktree "$PRIMARY_WAVE_META")
BRAVO_WAVE_NEW_WT=$(remember_meta_worktree "$BRAVO_WAVE_META")
PRIMARY_WAVE_NEW_PANE=$(grep '^herdr_pane_id=' "$PRIMARY_WAVE_META" | cut -d= -f2-)
BRAVO_WAVE_NEW_PANE=$(grep '^herdr_pane_id=' "$BRAVO_WAVE_META" | cut -d= -f2-)
[ "$(grep '^herdr_workspace_id=' "$PRIMARY_WAVE_META" | cut -d= -f2-)" = "$PRIMARY_WAVE_WSID" ] \
  && [ "$(grep '^herdr_workspace_id=' "$BRAVO_WAVE_META" | cut -d= -f2-)" = "$BRAVO_WAVE_WSID" ] \
  || fail "concurrent recovery flattened one task into a different workspace"
[ "$PRIMARY_WAVE_NEW_PANE" != "$PRIMARY_WAVE_OLD_PANE" ] \
  && [ "$BRAVO_WAVE_NEW_PANE" != "$BRAVO_WAVE_OLD_PANE" ] \
  || fail "concurrent recovery reused an old husk pane"
if lab pane get "$PRIMARY_WAVE_OLD_PANE" >/dev/null 2>&1 \
   || lab pane get "$BRAVO_WAVE_OLD_PANE" >/dev/null 2>&1; then
  fail "concurrent recovery left an old husk pane behind"
fi
assert_focus_is "$CONCURRENT_RECOVERY_FOCUS" "concurrent cross-home recovery"
teardown_task "$PRIMARY_WAVE_ID" "$HOME_DIR" > "$TMP_ROOT/primary-wave-teardown.out" 2> "$TMP_ROOT/primary-wave-teardown.err" \
  || fail "concurrent primary recovery teardown failed: $(cat "$TMP_ROOT/primary-wave-teardown.err")"
teardown_task "$BRAVO_WAVE_ID" "$SECOND_HOME_B" > "$TMP_ROOT/bravo-wave-teardown.out" 2> "$TMP_ROOT/bravo-wave-teardown.err" \
  || fail "concurrent secondmate recovery teardown failed: $(cat "$TMP_ROOT/bravo-wave-teardown.err")"
"$REAL_TREEHOUSE" return --force "$PRIMARY_WAVE_OLD_WT" >/dev/null 2>&1 || true
"$REAL_TREEHOUSE" return --force "$BRAVO_WAVE_OLD_WT" >/dev/null 2>&1 || true
"$REAL_TREEHOUSE" return --force "$PRIMARY_WAVE_NEW_WT" >/dev/null 2>&1 || true
"$REAL_TREEHOUSE" return --force "$BRAVO_WAVE_NEW_WT" >/dev/null 2>&1 || true
pass "real Herdr lab: concurrent cross-home recoveries replace exact husks under one session lock with no focus drift"


