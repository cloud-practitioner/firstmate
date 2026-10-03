#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C
export TMPDIR="$ROOT/.test-phase-tmp"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE TASKS_AXI_FILE TASKS_AXI_BACKEND FM_GATE_REFUSE_BYPASS
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
trap 'rm -rf "$LAB"' EXIT
bin/fm-lab-home.sh create "$LAB" >/dev/null
export FM_HOME=$LAB
cp .tasks.toml "$LAB/.tasks.toml"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$LAB/data/backlog.md"
tasks() { (cd "$LAB" && tasks-axi "$@"); }
captain() { "$ROOT/bin/fm-captain-hold.sh" "$@"; }
{
  printf 'Real tasks-axi and Firstmate CLI, isolated marked lab; no stubs\n'
  for id in review-a review-b; do
    tasks add "$id" "Investigation $id" --kind scout --repo demo --start
    printf 'project=demo\nkind=scout\nmode=scout\nharness=claude\nspawn_gen=lab-%s\n' "$id" > "$LAB/state/$id.meta"
    printf 'done: report complete\n' > "$LAB/state/$id.status"
  done
  REASON=$'Choose (safe mode)\nKeep café and literal fm-hold-v1:YWJj.'
  captain hold call-a --title 'Choose safe mode' --reason "$REASON" --repo demo --origin review-a
  "$ROOT/bin/fm-tasks-axi.sh" show call-a --full
  "$ROOT/bin/fm-fleet-snapshot.sh" --json > "$EVIDENCE/hold-snapshot.json"
  jq -e --arg reason "$REASON" '.backlog.records[] | select(.id=="call-a") | .hold_reason==$reason' "$EVIDENCE/hold-snapshot.json" >/dev/null
  jq '.backlog.records[] | select(.id=="call-a") | {id,hold_kind,hold_reason,captain_actionable}' "$EVIDENCE/hold-snapshot.json"
  BEFORE=$(sha256sum "$LAB/state/review-b.meta")
  if captain complete review-b call-a; then echo 'ERROR: wrong-origin completion succeeded'; exit 1; else echo 'Wrong-origin completion refused'; fi
  test "$BEFORE" = "$(sha256sum "$LAB/state/review-b.meta")"
  captain hold review-a --reason 'origin work itself held' --repo demo
  if captain complete review-a review-a; then echo 'ERROR: self completion succeeded'; exit 1; else echo 'Self-inventory refused'; fi
  captain complete review-a call-a
  captain verify review-a
  printf 'Recorded inventory:\n'; grep -E 'decision' "$LAB/state/review-a.meta"
  printf 'Use safe mode.\n' > "$LAB/answer.txt"
  captain answer call-a --decision-file "$LAB/answer.txt"
  captain verify review-a
  "$ROOT/bin/fm-tasks-axi.sh" show call-a --full
} > "$EVIDENCE/hold-cli.log" 2>&1
{
  printf 'Local bare remote plus real fleet-sync, symlink alias and non-clone boundary\n'
  git init -q -b main "$LAB/work"
  git -C "$LAB/work" config user.name Lab
  git -C "$LAB/work" config user.email lab@example.invalid
  printf 'v1\n' > "$LAB/work/value.txt"
  git -C "$LAB/work" add value.txt
  git -C "$LAB/work" commit -qm v1
  git clone -q --bare "$LAB/work" "$LAB/remote.git"
  git clone -q "$LAB/remote.git" "$LAB/clone"
  ln -s "$LAB/clone" "$LAB/projects/alias"
  git -C "$LAB/work" remote add origin "$LAB/remote.git"
  printf 'v2\n' > "$LAB/work/value.txt"
  git -C "$LAB/work" commit -qam v2
  git -C "$LAB/work" push -q origin main
  "$ROOT/bin/fm-fleet-sync.sh" alias
  test "$(git -C "$LAB/clone" rev-parse HEAD)" = "$(git -C "$LAB/work" rev-parse HEAD)"
  printf 'Synced clone value: '; head -1 "$LAB/clone/value.txt"
  mkdir "$LAB/projects/not-a-clone"
  HEAD_BEFORE=$(git rev-parse HEAD)
  "$ROOT/bin/fm-fleet-sync.sh" not-a-clone
  test "$HEAD_BEFORE" = "$(git rev-parse HEAD)"
  printf 'Enclosing worktree HEAD remained %s\n' "$HEAD_BEFORE"
} > "$EVIDENCE/fleet-sync-cli.log" 2>&1
printf 'hold and fleet-sync live checks completed\n'
