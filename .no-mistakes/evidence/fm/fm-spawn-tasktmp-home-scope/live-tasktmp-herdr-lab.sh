#!/usr/bin/env bash
# Live driver: real bin/fm-spawn.sh / bin/fm-teardown.sh against two marked
# disposable lab homes on an isolated fm-lab-* Herdr session.
# Usage: live-tasktmp-herdr-lab.sh <worktree>
set -u
WT=$1
cd "$WT" || exit 1
HL="$WT/bin/fm-herdr-lab.sh"
ID=tmpscope$$
ADV_ID=tmpadv$$
SESSION=$("$HL" name tasktmp)
# Never let the real fleet home or the inherited default-session pane follow us in.
unset FM_HOME HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
SCRATCH=$(mktemp -d "$(cd "${TMPDIR:-/tmp}" && pwd -P)/fm-tasktmp-live.XXXXXX")
# Lab A deliberately has a space in its path to exercise GOTMPDIR quoting.
LAB_A="$SCRATCH/home a"
LAB_B="$SCRATCH/home-b"
step() { printf '\n=== %s ===\n' "$*"; }
cleanup() {
  step "cleanup"
  for wt in $(cat "$SCRATCH"/*.wt 2>/dev/null); do treehouse return --force "$wt" >/dev/null 2>&1; done
  "$HL" teardown "$SESSION" && echo "herdr lab $SESSION torn down"
  find "$SCRATCH" -type d -exec chmod u+rwx {} + 2>/dev/null
  rm -rf "$SCRATCH"
  for h in "$HASH_A" "$HASH_B"; do [ -n "$h" ] && rm -rf "/tmp/fm-$ID+$h" "/tmp/fm-$ADV_ID+$h"; done
  ls -d /tmp/fm-$ID* /tmp/fm-$ADV_ID* 2>/dev/null || echo "no /tmp/fm-$ID* or /tmp/fm-$ADV_ID* remain"
}
HASH_A=; HASH_B=
trap cleanup EXIT

step "provision isolated herdr lab $SESSION"
"$HL" provision "$SESSION" || exit 1
export HERDR_SESSION="$SESSION"

"$WT/bin/fm-lab-home.sh" create "$LAB_A" && "$WT/bin/fm-lab-home.sh" create "$LAB_B" || exit 1
HASH_A=$(printf '%s' "$LAB_A" | shasum -a 256 | awk '{print $1}')
HASH_B=$(printf '%s' "$LAB_B" | shasum -a 256 | awk '{print $1}')
for h in "$LAB_A" "$LAB_B"; do
  printf 'off\n' > "$h/config/herdr-presentation-spaces"
  mkdir -p "$h/data/$ID"
  printf '# Task\n## Captain'"'"'s intent\nLive tasktmp scoping check.\n\n## Firstmate spec\nPrint GOTMPDIR.\n' > "$h/data/$ID/brief.md"
done
PROJ="$SCRATCH/project"
mkdir -p "$PROJ" && git -C "$PROJ" init -q && echo scratch > "$PROJ/README.md"
git -C "$PROJ" add README.md && git -C "$PROJ" -c user.name=t -c user.email=t@example.invalid commit -qm init
git clone -q --bare "$PROJ" "$PROJ.origin.git" && git -C "$PROJ" remote add origin "file://$PROJ.origin.git"

spawn() { # <home> <id>
  FM_SPAWN_NO_GUARD=1 FM_HOME="$1" "$WT/bin/fm-spawn.sh" "$2" "$PROJ" \
    "sh -c 'echo GOTMPDIR_IS=\"\$GOTMPDIR\"; ls -ld \"\$GOTMPDIR\"; exec sleep 900'" \
    --mode no-mistakes --yolo off --backend herdr
}

step "before: no shared legacy root"
ls -ld "/tmp/fm-$ID" 2>&1

for pair in "A:$LAB_A" "B:$LAB_B"; do
  name=${pair%%:*}; home=${pair#*:}
  step "spawn task $ID in home $name ($home)"
  spawn "$home" "$ID" > "$SCRATCH/$name.out" 2>&1; rc=$?
  tail -n 5 "$SCRATCH/$name.out"; echo "spawn rc=$rc"
  [ "$rc" -eq 0 ] || exit 1
  grep '^worktree=' "$home/state/$ID.meta" | cut -d= -f2- > "$SCRATCH/$name.wt"
  echo "meta tasktmp=$(grep '^tasktmp=' "$home/state/$ID.meta" | cut -d= -f2-)"
  stat -c '%a %U %n' "$home/state/$ID.tasktmp" "$home/state/$ID.tasktmp/gotmp"
  sleep 3
  pane=$(grep '^herdr_pane_id=' "$home/state/$ID.meta" | cut -d= -f2-)
  echo "--- home $name pane $pane capture right after its spawn ---"
  "$HL" run "$SESSION" pane read "$pane" --source recent --lines 40 2>&1 | grep -v '^\s*$' | tail -n 8
  echo "--- herdr panes in lab now ---"
  "$HL" run "$SESSION" pane list 2>&1 | jq -c '[.result.panes[]? | {pane_id, cwd}]' 2>/dev/null
done

step "shared legacy root after both spawns"
ls -ld "/tmp/fm-$ID" 2>&1

sleep 2
for pair in "A:$LAB_A" "B:$LAB_B"; do
  name=${pair%%:*}; home=${pair#*:}
  pane=$(grep '^herdr_pane_id=' "$home/state/$ID.meta" | cut -d= -f2-)
  step "home $name pane $pane capture (crewmate shell sees GOTMPDIR)"
  "$HL" run "$SESSION" pane read "$pane" --source recent --lines 40 2>&1 | grep -v '^\s*$' | tail -n 12
done

step "teardown $ID in home A only"
FM_HOME="$LAB_A" "$WT/bin/fm-teardown.sh" "$ID" --force > "$SCRATCH/tdA.out" 2>&1; echo "teardown rc=$?"
tail -n 4 "$SCRATCH/tdA.out"
ls -ld "$LAB_A/state/$ID.tasktmp" 2>&1
echo "home B root still present:"; stat -c '%a %n' "$LAB_B/state/$ID.tasktmp/gotmp" 2>&1

step "adversarial: pre-planted symlink at home B's root for $ADV_ID is refused"
mkdir -p "$LAB_B/data/$ADV_ID" && cp "$LAB_B/data/$ID/brief.md" "$LAB_B/data/$ADV_ID/brief.md"
mkdir -p "$SCRATCH/attacker"
ln -s "$SCRATCH/attacker" "$LAB_B/state/$ADV_ID.tasktmp"
spawn "$LAB_B" "$ADV_ID" > "$SCRATCH/adv.out" 2>&1; echo "spawn rc=$?"
grep -i 'task temp root' "$SCRATCH/adv.out"
echo "attacker dir contents: [$(ls -A "$SCRATCH/attacker")]"
echo "adv meta exists? $( [ -e "$LAB_B/state/$ADV_ID.meta" ] && echo yes || echo no)"
rm -f "$LAB_B/state/$ADV_ID.tasktmp"

step "adversarial: group-writable pre-existing root is refused"
mkdir "$LAB_B/state/$ADV_ID.tasktmp" && chmod 0770 "$LAB_B/state/$ADV_ID.tasktmp"
spawn "$LAB_B" "$ADV_ID" > "$SCRATCH/adv2.out" 2>&1; echo "spawn rc=$?"
grep -i 'task temp root' "$SCRATCH/adv2.out"
rmdir "$LAB_B/state/$ADV_ID.tasktmp"

step "leak check: home B is never torn down, just deleted (a disposable test home)"
for wt in $(cat "$SCRATCH"/B.wt); do treehouse return --force "$wt" >/dev/null 2>&1; done
"$HL" run "$SESSION" pane close "$(grep '^herdr_pane_id=' "$LAB_B/state/$ID.meta" | cut -d= -f2-)" >/dev/null 2>&1
find "$LAB_B" -type d -exec chmod u+rwx {} + 2>/dev/null; rm -rf "$LAB_B"
echo "task temp roots left in /tmp for $ID:"; ls -d "/tmp/fm-$ID" 2>&1
echo "launch dirs (separate pre-existing namespace) left in /tmp for $ID:"; ls -d /tmp/fm-$ID+* 2>&1
