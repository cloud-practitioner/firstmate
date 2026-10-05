#!/usr/bin/env bash
set -eu
umask 022
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M467Y2KVPY0ZYM8V5V6DQB86
export PATH="$ROOT/.validation/tools/usr/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/.validation/tools/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export GIT_CONFIG_GLOBAL="$ROOT/tests/git-fixture.gitconfig" GIT_CONFIG_NOSYSTEM=1
unset FM_HOME FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
LAB=$(mktemp -d "$ROOT/l.XXXXXX")
bin/fm-lab-home.sh create "$LAB" >/dev/null
mkdir -p "$LAB/tmux"
cleanup() {
 TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server 2>/dev/null || true
 rm -rf "$LAB"
}
trap cleanup EXIT
export FM_HOME="$LAB" TMUX_TMPDIR="$LAB/tmux"
tmux -L fm-lab -f /dev/null new-session -d -s primary -n fm-primary -x 120 -y 40 -c "$PWD" 'sleep 240'
export TMUX=$(tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')
for MODE in local-only no-mistakes; do
 for KIND in tracked untracked mixed; do
  CASE="$LAB/projects/$MODE-$KIND"
  mkdir -p "$CASE"
  git -C "$CASE" init -q -b main
  printf 'landed content\n' > "$CASE/feature.txt"
  git -C "$CASE" add feature.txt
  git -C "$CASE" -c user.name=Test -c user.email=test@example.invalid commit -qm baseline
  WT="$CASE/task"
  git -C "$CASE" worktree add -q -b fm/dirty "$WT" main
  if [ "$MODE" = no-mistakes ]; then
   git -C "$CASE" update-ref refs/remotes/origin/main HEAD
  fi
  ID="dirty-$MODE-$KIND"
  tmux -L fm-lab new-window -d -t primary -n "fm-$ID" -c "$WT" 'sleep 240'
  printf 'window=primary:fm-%s\nbackend=tmux\nendpoint_task_id=%s\nworktree=%s\nproject=%s\nkind=ship\nmode=%s\nspawn_gen=s1.1.1\n' "$ID" "$ID" "$WT" "$CASE" "$MODE" > "$LAB/state/$ID.meta"
  if [ "$KIND" != untracked ]; then
   printf 'uncommitted work\n' > "$WT/feature.txt"
   [ "$MODE" != local-only ] || git -C "$WT" add feature.txt
  fi
  if [ "$KIND" != tracked ]; then
   mkdir "$WT/00 proof scratch" "$WT/.claude"
   printf 'proof\n' > "$WT/00 proof scratch/server.log"
   touch "$WT/.claude/settings.local.json" "$WT/.fm-grok-turnend"
   for N in 01 02 03 04 05 06 07 08 09 10 11; do touch "$WT/$N-scratch.txt"; done
  fi
  BEFORE=$(git -C "$WT" status --porcelain)
  cp "$LAB/state/$ID.meta" "$LAB/before.meta"
  RC=0
  bin/fm-teardown.sh "$ID" > "$E/round2-teardown-$KIND-$MODE.txt" 2>&1 || RC=$?
  [ "$RC" -eq 1 ]
  grep -q 'REFUSED:' "$E/round2-teardown-$KIND-$MODE.txt"
  case "$KIND" in
   untracked) grep -q 'untracked-only leftovers' "$E/round2-teardown-$KIND-$MODE.txt" ;;
   *) grep -q 'includes tracked edits' "$E/round2-teardown-$KIND-$MODE.txt" ;;
  esac
  if [ "$KIND" != tracked ]; then
   grep -q '00 proof scratch/' "$E/round2-teardown-$KIND-$MODE.txt"
   grep -q 'additional untracked paths omitted' "$E/round2-teardown-$KIND-$MODE.txt"
   ! grep -q '10-scratch.txt\|11-scratch.txt\|settings.local.json\|grok-turnend' "$E/round2-teardown-$KIND-$MODE.txt"
  fi
  cmp "$LAB/before.meta" "$LAB/state/$ID.meta"
  [ "$BEFORE" = "$(git -C "$WT" status --porcelain)" ]
  tmux -L fm-lab has-session -t "primary:fm-$ID"
  printf '\nObserved: exit=%s; metadata and git status unchanged; private runtime endpoint still alive.\n' "$RC" >> "$E/round2-teardown-$KIND-$MODE.txt"
  echo "$KIND/$MODE: refused and preserved"
 done
done
bin/fm-brief.sh scratch-proof probe --mode local-only > "$E/round2-brief-command.txt"
cp "$LAB/data/scratch-proof/brief.md" "$E/round2-generated-brief.md"
python3 - "$E/round2-generated-brief.md" "$LAB" <<'PY'
import sys
text=open(sys.argv[1]).read(); home=sys.argv[2]
# This is the public generated launch prompt, not implementation-source inspection.
assert 'Leave the worktree clean before reporting done.' in text
assert home+'/data/scratch-proof/' in text
assert home+'/state/scratch-proof.tasktmp' in text
assert 'never write them to a fixed path in shared /tmp' in text
assert 'steering-inbox records authorized below' in text
print('Generated brief preserves upstream clean-worktree guidance and fork task-private scratch paths.')
PY
