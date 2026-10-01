#!/usr/bin/env bash
# Live validation driver: real bin/fm-spawn.sh / bin/fm-teardown.sh in two
# disposable marked lab homes, on an isolated fm-lab-* Herdr session through
# bin/fm-herdr-lab.sh. Proves each task's temp root is scoped to its home.
set -u
REPO=${REPO:?}
EV=${EV:?}
cd "$REPO"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
LAB_HELPER="$REPO/bin/fm-herdr-lab.sh"
SESSION=$("$LAB_HELPER" name tasktmp)
export HERDR_SESSION="$SESSION"
SCRATCH=$(mktemp -d "$(cd "${TMPDIR:-/tmp}" && pwd -P)/fm-tasktmp-live.XXXXXX")
A="$SCRATCH/home-a"
B="$SCRATCH/home b with space"
C="$SCRATCH/home-c"
ID="tt$$x"
step() { printf '\n=== %s\n' "$*"; }
cleanup() {
  step "cleanup"
  for h in "$A" "$B" "$C"; do
    for m in "$h"/state/*.meta; do
      [ -f "$m" ] || continue
      wt=$(grep '^worktree=' "$m" | cut -d= -f2-)
      [ -n "$wt" ] && treehouse return --force "$wt" >/dev/null 2>&1
    done
  done
  "$LAB_HELPER" teardown "$SESSION" && echo "lab session $SESSION torn down"
  find "$SCRATCH" -type d -exec chmod u+rwx {} + 2>/dev/null
  rm -rf "$SCRATCH"
  rm -rf "/tmp/fm-$ID+"* 2>/dev/null
  echo "legacy root /tmp/fm-$ID exists after cleanup? $([ -e "/tmp/fm-$ID" ] && echo yes || echo no)"
}
trap cleanup EXIT

step "provision isolated Herdr lab session $SESSION"
"$LAB_HELPER" provision "$SESSION" || exit 1

for h in "$A" "$B" "$C"; do
  "$REPO/bin/fm-lab-home.sh" create "$h" >/dev/null || exit 1
  printf 'off\n' > "$h/config/herdr-presentation-spaces"
  mkdir -p "$h/data/$ID"
  printf '# Task\n## Captain'"'"'s intent\nLive tasktmp check.\n\n## Firstmate spec\nNothing.\n' > "$h/data/$ID/brief.md"
done
PROJ="$SCRATCH/proj"
mkdir -p "$PROJ"; git -C "$PROJ" init -q; echo '# p' > "$PROJ/README.md"
git -C "$PROJ" add README.md; git -C "$PROJ" -c user.name=t -c user.email=t@e.invalid commit -qm init
git clone -q --bare "$PROJ" "$PROJ.origin.git"; git -C "$PROJ" remote add origin "file://$PROJ.origin.git"

[ -e "/tmp/fm-$ID" ] && { echo "precondition: /tmp/fm-$ID already exists"; exit 1; }

spawn() {  # <home> <label>
  FM_SPAWN_NO_GUARD=1 FM_HOME="$1" "$REPO/bin/fm-spawn.sh" "$ID" "$PROJ" \
    "sh -c 'echo GOTMPDIR=[\$GOTMPDIR]; exec sleep 900'" --mode no-mistakes --yolo off --backend herdr
}
show_root() {  # <home>
  local m="$1/state/$ID.meta" t
  t=$(grep '^tasktmp=' "$m" | cut -d= -f2-)
  echo "meta tasktmp=$t"
  stat -c '%A %U %n' "$t" "$t/gotmp"
}
capture() {  # <home>
  local pane
  pane=$(grep '^herdr_pane_id=' "$1/state/$ID.meta" | cut -d= -f2-)
  ( . "$REPO/bin/fm-backend.sh"; fm_backend_source herdr; fm_backend_herdr_capture "$SESSION:$pane" 40 ) | grep -E 'GOTMPDIR' | tail -3
}

step "S1: spawn task $ID in home A"
spawn "$A"; echo "spawn rc=$?"
show_root "$A"
echo "legacy /tmp/fm-$ID created? $([ -e "/tmp/fm-$ID" ] && echo yes || echo no)"
sleep 3
echo "pane A sees:"; capture "$A"

step "S2: spawn the SAME task id $ID in home B (path contains spaces)"
spawn "$B"; echo "spawn rc=$?"
show_root "$B"
echo "legacy /tmp/fm-$ID created? $([ -e "/tmp/fm-$ID" ] && echo yes || echo no)"
sleep 3
echo "pane B sees:"; capture "$B"
TA=$(grep '^tasktmp=' "$A/state/$ID.meta" | cut -d= -f2-)
TB=$(grep '^tasktmp=' "$B/state/$ID.meta" | cut -d= -f2-)
[ "$TA" != "$TB" ] && echo "distinct roots: yes" || echo "distinct roots: NO"
echo marker-from-A > "$TA/gotmp/a-file"

step "S3: tear down $ID in home A; B's root must survive"
FM_HOME="$A" "$REPO/bin/fm-teardown.sh" "$ID"; echo "teardown rc=$?"
echo "A root exists after teardown? $([ -e "$TA" ] && echo yes || echo no)"
echo "A meta exists after teardown? $([ -e "$A/state/$ID.meta" ] && echo yes || echo no)"
echo "B root exists after A's teardown? $([ -d "$TB/gotmp" ] && echo yes || echo no)"
FM_HOME="$B" "$REPO/bin/fm-teardown.sh" "$ID"; echo "teardown B rc=$?"
echo "B root exists after its own teardown? $([ -e "$TB" ] && echo yes || echo no)"

step "S4 (adversarial): pre-planted symlink at home C's task temp root"
mkdir -p "$SCRATCH/decoy"
ln -s "$SCRATCH/decoy" "$C/state/$ID.tasktmp"
spawn "$C"; echo "spawn rc=$?"
echo "C meta written? $([ -e "$C/state/$ID.meta" ] && echo yes || echo no)"
echo "decoy got gotmp? $([ -e "$SCRATCH/decoy/gotmp" ] && echo yes || echo no)"
rm -f "$C/state/$ID.tasktmp"
step "S4b (adversarial): group-writable pre-existing root in home C"
mkdir "$C/state/$ID.tasktmp"; chmod 777 "$C/state/$ID.tasktmp"
spawn "$C"; echo "spawn rc=$?"
echo "C meta written? $([ -e "$C/state/$ID.meta" ] && echo yes || echo no)"
