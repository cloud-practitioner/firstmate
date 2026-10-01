#!/usr/bin/env bash
# Live validation driver: a real Claude ship task in a disposable marked lab
# home on an isolated fm-lab-* Herdr session. Its record is rewritten to the
# legacy shared root /tmp/fm-<id> (what a task spawned before this change
# recorded), then a real bin/fm-control.sh relaunch must keep that root, and
# bin/fm-teardown.sh must remove it.
set -u
REPO=${REPO:?}
cd "$REPO"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
export DISABLE_AUTOUPDATER=1
LAB_HELPER="$REPO/bin/fm-herdr-lab.sh"
SESSION=$("$LAB_HELPER" name relaunch)
export HERDR_SESSION="$SESSION"
SCRATCH=$(mktemp -d "$(cd "${TMPDIR:-/tmp}" && pwd -P)/fm-relaunch-live.XXXXXX")
H="$SCRATCH/home"
ID="lr$$x"
LEGACY="/tmp/fm-$ID"
step() { printf '\n=== %s\n' "$*"; }
cleanup() {
  step "cleanup"
  if [ -f "$H/state/$ID.meta" ]; then
    FM_HOME="$H" "$REPO/bin/fm-teardown.sh" "$ID" --force >/dev/null 2>&1
    wt=$(grep '^worktree=' "$H/state/$ID.meta" 2>/dev/null | cut -d= -f2-)
    [ -n "$wt" ] && treehouse return --force "$wt" >/dev/null 2>&1
  fi
  "$LAB_HELPER" teardown "$SESSION" && echo "lab session $SESSION torn down"
  find "$SCRATCH" -type d -exec chmod u+rwx {} + 2>/dev/null
  rm -rf "$SCRATCH" "$LEGACY" "/tmp/fm-$ID+"*
}
trap cleanup EXIT
pane_text() {
  local pane
  pane=$(grep '^herdr_pane_id=' "$H/state/$ID.meta" | cut -d= -f2-)
  ( . "$REPO/bin/fm-backend.sh"; fm_backend_source herdr; fm_backend_herdr_capture "$SESSION:$pane" "${1:-60}" )
}
wait_idle() {  # wait until the agent reports idle via the herdr pane agent state
  local i st pane
  for i in $(seq 1 90); do
    pane=$(grep '^herdr_pane_id=' "$H/state/$ID.meta" | cut -d= -f2-)
    st=$("$LAB_HELPER" run "$SESSION" pane get "$pane" 2>/dev/null | jq -r '.result.pane.agent_status // .result.pane.agent_state // empty')
    [ "$st" = idle ] && { echo "agent idle after ${i}x2s"; return 0; }
    sleep 2
  done
  echo "agent never reached idle (last status: ${st:-?})"; return 1
}

step "provision isolated Herdr lab session $SESSION"
"$LAB_HELPER" provision "$SESSION" || exit 1
"$REPO/bin/fm-lab-home.sh" create "$H" >/dev/null || exit 1
printf 'off\n' > "$H/config/herdr-presentation-spaces"
mkdir -p "$H/data/$ID"
cat > "$H/data/$ID/brief.md" <<'EOF'
# Task
## Captain's intent
Reply with the single word READY and then stop; do not run any tools or edit any files.

## Firstmate spec
Reply READY and wait. Make no changes.
EOF
PROJ="$SCRATCH/proj"
mkdir -p "$PROJ"; git -C "$PROJ" init -q; echo '# p' > "$PROJ/README.md"
git -C "$PROJ" add README.md; git -C "$PROJ" -c user.name=t -c user.email=t@e.invalid commit -qm init
git clone -q --bare "$PROJ" "$PROJ.origin.git"; git -C "$PROJ" remote add origin "file://$PROJ.origin.git"
[ -e "$LEGACY" ] && { echo "precondition: $LEGACY already exists"; exit 1; }

step "spawn real Claude ship task $ID"
FM_SPAWN_NO_GUARD=1 FM_HOME="$H" "$REPO/bin/fm-spawn.sh" "$ID" "$PROJ" --mode local-only --yolo off \
  --harness claude --model haiku --backend herdr; echo "spawn rc=$?"
grep -E '^(tasktmp|harness|backend)=' "$H/state/$ID.meta"
wait_idle
pane_text 25 | grep -v '^\s*$' | tail -6
echo "initial Claude agent process environment:"
wt0=$(grep '^worktree=' "$H/state/$ID.meta" | cut -d= -f2-)
for pid in $(pgrep -u "$(id -u)" -f claude); do [ "$(readlink "/proc/$pid/cwd" 2>/dev/null)" = "$wt0" ] && { printf 'pid %s comm=%s ' "$pid" "$(cat /proc/$pid/comm)"; tr '\0' '\n' < "/proc/$pid/environ" | grep '^GOTMPDIR='; }; done

step "simulate a pre-change task: rewrite its record to the legacy shared root $LEGACY"
SCOPED=$(grep '^tasktmp=' "$H/state/$ID.meta" | cut -d= -f2-)
sed -i "s|^tasktmp=.*|tasktmp=$LEGACY|" "$H/state/$ID.meta"
rm -rf "$SCOPED"
(umask 077; mkdir "$LEGACY"); mkdir "$LEGACY/gotmp"; echo legacy-sentinel > "$LEGACY/gotmp/sentinel"
grep '^tasktmp=' "$H/state/$ID.meta"

step "relaunch through fm-control"
FM_HOME="$H" "$REPO/bin/fm-control.sh" "$ID" relaunch --note "continuing after relaunch; reply READY and stop"; echo "relaunch rc=$?"
grep '^tasktmp=' "$H/state/$ID.meta"
echo "legacy root kept with sentinel? $([ -f "$LEGACY/gotmp/sentinel" ] && echo yes || echo no)"
echo "home-scoped root recreated by relaunch? $([ -e "$SCOPED" ] && echo yes || echo no) ($SCOPED)"
sleep 3
agent_env() {
  local wt pid
  wt=$(grep '^worktree=' "$H/state/$ID.meta" | cut -d= -f2-)
  for pid in $(pgrep -u "$(id -u)" -f claude); do
    [ "$(readlink "/proc/$pid/cwd" 2>/dev/null)" = "$wt" ] || continue
    printf 'pid %s comm=%s ' "$pid" "$(cat /proc/$pid/comm)"; tr '\0' '\n' < "/proc/$pid/environ" | grep '^GOTMPDIR='
  done
}
echo "relaunched Claude agent process environment:"; agent_env

step "teardown removes the recorded legacy root"
FM_HOME="$H" "$REPO/bin/fm-teardown.sh" "$ID"; echo "teardown rc=$?"
echo "legacy root exists after teardown? $([ -e "$LEGACY" ] && echo yes || echo no)"
