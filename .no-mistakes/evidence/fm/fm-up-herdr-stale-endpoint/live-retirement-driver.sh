#!/usr/bin/env bash
set -eu
. /home/node/.no-mistakes/evidence/01M65NDEZRAT81MFEX2NMZGR4B/live-lab-common.sh
SCENARIO=${1:-direct-sweep}
export SCENARIO
export PRIMARY="$LAB/main"
"$ROOT/bin/fm-lab-home.sh" create "$PRIMARY"
mkdir -p "$LAB/code"
cp -R "$ROOT/bin" "$LAB/code/bin"
if [ "${BASELINE_RETIREMENT:-0}" = 1 ]; then
  git show bdd369fd5dc5a255cf5e6b8915c41dd111a5a302^:bin/fm-teardown.sh > "$LAB/code/bin/fm-teardown.sh"
  echo 'BASELINE: executing the same scenario with the pre-rollback-fix teardown'
fi
export FM_HOME="$PRIMARY" FM_ROOT_OVERRIDE="$LAB/code"
MATE="$LAB/mate"; OWNER="$PRIMARY"; TASK=mine
mkdir -p "$MATE/state" "$MATE/data" "$MATE/config" "$MATE/bin"
printf 'mine\n' > "$MATE/.fm-secondmate-home"
if [[ "$SCENARIO" = recursive-* ]]; then
  OWNER="$LAB/parent"; TASK=parent
  mkdir -p "$OWNER/state" "$OWNER/data" "$OWNER/config"
  printf 'parent\n' > "$OWNER/.fm-secondmate-home"
fi
export MATE OWNER
lab workspace create --label firstmate --no-focus >/dev/null
lab pane run w1:p1 "cd '$MATE'" >/dev/null
lab tab rename w1:t1 fm-mine >/dev/null
IDENT=$(fm_backend_herdr_pane_process_identity "$LAB_SESSION" w1:p1)
write_task() {
  printf 'backend=herdr\nwindow=%s:%s\nendpoint_task_id=%s\nworktree=%s\nproject=%s\nhome=%s\nkind=secondmate\nharness=pi\nmode=secondmate\nyolo=off\nherdr_session=%s\nherdr_workspace_id=w1\nherdr_tab_id=%s\nherdr_pane_id=%s\nherdr_process_identity=%s\n' \
    "$LAB_SESSION" "$3" "$2" "$4" "$4" "$4" "$LAB_SESSION" "$5" "$3" "$6" > "$1/state/$2.meta"
}
write_task "$OWNER" mine w1:p1 "$MATE" w1:t1 "$IDENT"
if [ "$TASK" = parent ]; then
  lab tab create --workspace w1 --label fm-parent --cwd "$OWNER" --no-focus >/dev/null
  PARENT_IDENT=$(fm_backend_herdr_pane_process_identity "$LAB_SESSION" w1:p2)
  write_task "$PRIMARY" parent w1:p2 "$OWNER" w1:t2 "$PARENT_IDENT"
fi
printf -- '- mine - lab domain (home: %s; scope: disposable; projects: alpha; added 2026-10-30)\n' "$MATE" > "$PRIMARY/data/secondmates.md"
if [ "$TASK" = parent ]; then
  printf -- '- parent - lab domain (home: %s; scope: disposable; projects: alpha; added 2026-10-30)\n' "$OWNER" >> "$PRIMARY/data/secondmates.md"
fi
# Register and arm an actual production process-event runner; sleep is only
# its disposable long-poll data source, not a stand-in for the product.
FM_HOME="$MATE" "$ROOT/bin/fm-procevent.sh" register lavish wait -- /bin/sleep 300
FM_HOME="$MATE" "$ROOT/bin/fm-procevent.sh" reconcile
FM_HOME="$MATE" "$ROOT/bin/fm-procevent.sh" list
cp "$MATE/state/procevent/wait.source" "$LAB/expected.source"
CORR=$(FM_HOME="$PRIMARY" bash -c '. "$1/bin/fm-pending-reply-lib.sh"; fm_pending_reply_create "$2" "$2/state" "$3" "New routed work is in your backlog."' _ "$ROOT" "$PRIMARY" "$TASK")
printf 'confirmed:%s\n' "$CORR" > "$PRIMARY/state/.backlog-handoff-$TASK.wake-pending"
printf 'confirmed=1\n' > "$PRIMARY/state/pending-replies/.delivery-confirmed-$CORR"
cp "$PRIMARY/state/pending-replies/$CORR" "$LAB/expected.reply"
cat > "$LAB/reset.sh" <<'SH'
#!/usr/bin/env bash
set -eu
if [ "$SCENARIO" = direct-pending ]; then
  : > "$PRIMARY/state/pending-replies/unsafe"
else
  env PATH="$REAL_PATH" "$LAB_HELPER" teardown "$LAB_SESSION"
  env PATH="$REAL_PATH" "$LAB_HELPER" provision "$LAB_SESSION"
  env PATH="$REAL_PATH" "$LAB_HELPER" run "$LAB_SESSION" workspace create --label firstmate --no-focus
  env PATH="$REAL_PATH" "$LAB_HELPER" run "$LAB_SESSION" pane run w1:p1 "cd '$MATE'; printf 'FOREIGN-RETAIN-ME\\n'"
  for i in {1..30}; do
    cwd=$(env PATH="$REAL_PATH" "$LAB_HELPER" run "$LAB_SESSION" pane get w1:p1 | jq -r .result.pane.foreground_cwd)
    [ "$cwd" != "$MATE" ] || break
    sleep .1
  done
  [ "$cwd" = "$MATE" ]
fi
: > "$LAB/reset-ran"
echo "FAULT INJECTED: $SCENARIO" >> "$LAB/race.log"
SH
cat > "$MATE/bin/fm-procevent.sh" <<'SH'
#!/usr/bin/env bash
set -eu
"$ROOT/bin/fm-procevent.sh" "$@"
if [ "${1:-}" = sweep-home ] && [ "${2:-}" != --preflight ]; then
  [ ! -e "$MATE/state/procevent/wait.source" ]
  echo 'PRODUCTION sweep-home removed the source registration' >> "$LAB/race.log"
  case "$SCENARIO" in *-sweep) "$LAB/reset.sh" >> "$LAB/race.log" 2>&1 ;; esac
fi
SH
REAL_MV=$(command -v mv); export REAL_MV
cat > "$LAB/wrappers/mv" <<'SH'
#!/usr/bin/env bash
set -eu
"$REAL_MV" "$@"
case "${!#}" in
  */.backlog-handoff-mine.wake-retiring/marker)
    case "$SCENARIO" in direct-stage|direct-pending) "$LAB/reset.sh" >> "$LAB/race.log" 2>&1 ;; esac ;;
esac
SH
chmod +x "$LAB/reset.sh" "$MATE/bin/fm-procevent.sh" "$LAB/wrappers/mv"
printf '\nRETIREMENT SCENARIO: %s\n' "$SCENARIO"
RC=0
"$LAB/code/bin/fm-teardown.sh" "$TASK" --force > "$LAB/teardown.out" 2> "$LAB/teardown.err" || RC=$?
cat "$LAB/teardown.out" "$LAB/teardown.err"
[ ! -f "$LAB/race.log" ] || cat "$LAB/race.log"
if [[ "$SCENARIO" = *-owned ]]; then
  [ "$RC" = 0 ] && [ ! -e "$MATE" ] && [ ! -e "$PRIMARY/state/$TASK.meta" ]
  [ ! -e "$PRIMARY/state/.backlog-handoff-$TASK.wake-pending" ] && [ ! -e "$PRIMARY/state/pending-replies/$CORR" ]
  echo 'PASS: ordinary owned retirement committed home removal and notification retirement'
else
  [ "$RC" != 0 ] && [ -f "$LAB/reset-ran" ]
  [ -d "$MATE" ] && [ -f "$OWNER/state/mine.meta" ] && [ -f "$PRIMARY/state/$TASK.meta" ]
  cmp "$MATE/state/procevent/wait.source" "$LAB/expected.source"
  cmp "$PRIMARY/state/pending-replies/$CORR" "$LAB/expected.reply"
  [ "$(cat "$PRIMARY/state/.backlog-handoff-$TASK.wake-pending")" = "confirmed:$CORR" ]
  [ "$(cat "$PRIMARY/state/pending-replies/.delivery-confirmed-$CORR")" = confirmed=1 ]
  [ ! -e "$PRIMARY/state/.backlog-handoff-$TASK.wake-retiring" ]
  FM_HOME="$MATE" "$ROOT/bin/fm-procevent.sh" list
  [ -f "$MATE/state/procevent/wait.runner" ]
  if [ "$SCENARIO" != direct-pending ]; then lab pane get w1:p1; fi
  echo 'PASS: refused retirement retained the home, rearmed the actual process-event registration, and restored the pending wake/reply contract'
fi
