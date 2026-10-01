#!/usr/bin/env bash
# Live driver: a task whose record names the legacy shared root /tmp/fm-<id>
# is relaunched (real bin/fm-control.sh relaunch -> bin/fm-spawn.sh --relaunch,
# real Claude replacement) on an isolated fm-lab-* Herdr session; the record
# keeps that root, the pane gets it as GOTMPDIR, and teardown removes it.
# Usage: live-legacy-relaunch-herdr-lab.sh <worktree>
set -u
WT=$1
cd "$WT" || exit 1
HL="$WT/bin/fm-herdr-lab.sh"
ID=tmplegacy$$
SESSION=$("$HL" name legacyrl)
unset FM_HOME HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
SCRATCH=$(mktemp -d "$(cd "${TMPDIR:-/tmp}" && pwd -P)/fm-legacy-live.XXXXXX")
LAB="$SCRATCH/home"
HASH=
step() { printf '\n=== %s ===\n' "$*"; }
cleanup() {
  step "cleanup"
  [ -f "$SCRATCH/wt" ] && treehouse return --force "$(cat "$SCRATCH/wt")" >/dev/null 2>&1
  "$HL" teardown "$SESSION" && echo "herdr lab $SESSION torn down"
  find "$SCRATCH" -type d -exec chmod u+rwx {} + 2>/dev/null
  rm -rf "$SCRATCH"
  [ -n "$HASH" ] && rm -rf "/tmp/fm-$ID+$HASH"
  [ -d "/tmp/fm-$ID" ] && [ -O "/tmp/fm-$ID" ] && rm -rf "/tmp/fm-$ID"
  ls -d /tmp/fm-$ID* 2>/dev/null || echo "no /tmp/fm-$ID* remain"
}
trap cleanup EXIT

step "provision isolated herdr lab $SESSION"
"$HL" provision "$SESSION" || exit 1
export HERDR_SESSION="$SESSION"
"$WT/bin/fm-lab-home.sh" create "$LAB" || exit 1
HASH=$(printf '%s' "$LAB" | shasum -a 256 | awk '{print $1}')
printf 'off\n' > "$LAB/config/herdr-presentation-spaces"
mkdir -p "$LAB/data/$ID"
printf '# Task\n## Captain'"'"'s intent\nLive legacy relaunch check. Do nothing; just wait.\n\n## Firstmate spec\nDo nothing.\n' > "$LAB/data/$ID/brief.md"
PROJ="$SCRATCH/project"
mkdir -p "$PROJ" && git -C "$PROJ" init -q && echo scratch > "$PROJ/README.md"
git -C "$PROJ" add README.md && git -C "$PROJ" -c user.name=t -c user.email=t@example.invalid commit -qm init
git clone -q --bare "$PROJ" "$PROJ.origin.git" && git -C "$PROJ" remote add origin "file://$PROJ.origin.git"

step "spawn $ID (real claude) in the lab home"
FM_SPAWN_NO_GUARD=1 FM_HOME="$LAB" "$WT/bin/fm-spawn.sh" "$ID" "$PROJ" claude \
  --mode no-mistakes --yolo off --backend herdr > "$SCRATCH/spawn.out" 2>&1; rc=$?
grep -E '^spawned|^error' "$SCRATCH/spawn.out"; echo "spawn rc=$rc"; [ "$rc" -eq 0 ] || exit 1
META="$LAB/state/$ID.meta"
grep '^worktree=' "$META" | cut -d= -f2- > "$SCRATCH/wt"
PANE=$(grep '^herdr_pane_id=' "$META" | cut -d= -f2-)

step "rewrite the record into the pre-change shape: tasktmp=/tmp/fm-$ID"
(umask 077 && mkdir -p "/tmp/fm-$ID/gotmp")
rm -rf "$LAB/state/$ID.tasktmp"
sed -i "s|^tasktmp=.*|tasktmp=/tmp/fm-$ID|" "$META"
grep '^tasktmp=' "$META"

step "destroy the task's pane (endpoint churn) so relaunch reclaims it"
"$HL" run "$SESSION" pane close "$PANE" >/dev/null 2>&1; echo "closed pane $PANE"

step "relaunch onto a real Claude replacement"
FM_HOME="$LAB" "$WT/bin/fm-control.sh" "$ID" relaunch --note "live legacy-root relaunch check" \
  > "$SCRATCH/relaunch.out" 2>&1; rc=$?
tail -n 8 "$SCRATCH/relaunch.out"; echo "relaunch rc=$rc"
echo "meta tasktmp after relaunch: $(grep '^tasktmp=' "$META" | cut -d= -f2-)"
echo "meta harness after relaunch: $(grep '^harness=' "$META" | cut -d= -f2-)"
ls -ld "/tmp/fm-$ID/gotmp" 2>&1
ls -ld "$LAB/state/$ID.tasktmp" 2>&1
NEWPANE=$(grep '^herdr_pane_id=' "$META" | cut -d= -f2-)
sleep 4
step "replacement pane $NEWPANE capture"
"$HL" run "$SESSION" pane read "$NEWPANE" --source recent --lines 80 2>&1 | grep -E 'GOTMPDIR|launch\.' | head -n 4

step "environment of the replacement agent processes for $ID"
for f in /proc/[0-9]*/environ; do
  tr '\0' '\n' < "$f" 2>/dev/null | grep -qx "FM_TASK_ID=$ID" || continue
  pid=${f#/proc/}; pid=${pid%/environ}
  printf 'pid %s %s: %s\n' "$pid" "$(tr '\0' ' ' < /proc/$pid/cmdline | cut -c1-40)" "$(tr '\0' '\n' < "$f" | grep '^GOTMPDIR=')"
done | head -n 6

step "teardown removes the recorded legacy root"
FM_HOME="$LAB" "$WT/bin/fm-teardown.sh" "$ID" --force > "$SCRATCH/td.out" 2>&1; echo "teardown rc=$?"
grep -E 'complete|error' "$SCRATCH/td.out" | head -n 3
ls -ld "/tmp/fm-$ID" 2>&1
rm -f "$SCRATCH/wt"
