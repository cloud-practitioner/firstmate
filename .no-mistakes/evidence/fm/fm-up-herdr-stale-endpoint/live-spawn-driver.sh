#!/usr/bin/env bash
set -eu
. /home/node/.no-mistakes/evidence/01M65NDEZRAT81MFEX2NMZGR4B/live-lab-common.sh
mkdir -p "$LAB/project"
git -C "$LAB/project" init -q
printf 'Disposable identity-publication test project\n' > "$LAB/project/README.md"
git -C "$LAB/project" add README.md
git -C "$LAB/project" -c user.name='Lab' -c user.email='lab@example.invalid' commit -qm initial
git clone --quiet --bare "$LAB/project" "$LAB/project.git"
git -C "$LAB/project" remote add origin "$LAB/project.git"
printf 'off\n' > "$LAB/config/herdr-presentation-spaces"
touch "$LAB/config/supervision-host"
"$ROOT/bin/fm-brief.sh" launch "$LAB/project" --scout --herdr-lab > "$LAB/scaffold.log"
cat > "$LAB/data/launch/brief.md" <<'BRIEF'
# Task
## Captain's intent
Print LAB_WORKER_READY and wait. Do not run tools, edit files, control lifecycle,
perform git operations, or start a validation pipeline. This is a throwaway probe.
## Firstmate spec
This brief was scaffolded with --herdr-lab. No worker lifecycle work is requested.
BRIEF
# Use the actual authenticated CLI if it can run; never a stand-in executable.
"$ROOT/bin/fm-spawn.sh" launch "$LAB/project" claude --scout --backend herdr > "$LAB/spawn.out" 2> "$LAB/spawn.err"
cat "$LAB/spawn.out" "$LAB/spawn.err"
META="$LAB/state/launch.meta"
cat "$META"
PANE=$(fm_backend_herdr_meta_value "$META" herdr_pane_id)
SESSION=$(fm_backend_herdr_meta_value "$META" herdr_session)
RECORDED=$(fm_backend_herdr_meta_value "$META" herdr_process_identity)
CURRENT=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
echo "FRESH PUBLICATION: recorded=$RECORDED current=$CURRENT"
[ -n "$RECORDED" ] && [ "$RECORDED" = "$CURRENT" ]
sleep 4
lab pane read "$PANE" --lines 200
lab agent get "$PANE" || true
# The real Claude process is parked at its external-import permission dialog.
# Exercise the watcher's actual reconnect subscription and push handler.
python3 - "$META" "$LAB/state/a.meta" <<'PY'
import sys
s=open(sys.argv[1]).read().splitlines()
out=[]
for line in s:
    if line.startswith('endpoint_task_id='): line='endpoint_task_id=a'
    if line.startswith('herdr_process_identity='): line='herdr_process_identity=proc:999999:00000000-0000-4000-8000-000000000000:1'
    out.append(line)
open(sys.argv[2],'w').write('\n'.join(out)+'\n')
PY
printf 'paused: waiting for an unrelated external dependency\n' > "$LAB/state/a.status"
printf 'blocked: external-import approval needed\n' > "$LAB/state/launch.status"
. "$ROOT/bin/fm-push-transition-lib.sh"
STATE="$LAB/state"
RECORD=$(fm_backend_wait_transition herdr "$SESSION" 3 "$STATE" "$SESSION:$PANE")
echo "REAL BLOCKED RECONNECT RECORD: $RECORD"
( handle_push_transition herdr "$SESSION" "$RECORD" )
cat "$STATE/.wake-queue"
MARKER=$(fm_backend_herdr_escalation_marker "$STATE" "$SESSION:$PANE")
[ -e "$MARKER" ]
[ "$(hb_surfaced_offset launch)" = "$(wc -c < "$STATE/launch.status" | tr -d '[:space:]')" ]
[ ! -e "$(_hb_surfaced_path a)" ]
echo 'PASS: stale paused claimant did not absorb the bound real Claude blocked alert; its dedupe and status markers committed'
rm "$LAB/state/a.meta" "$LAB/state/a.status"
# Rebuild the isolated named session without saved state; surviving metadata
# must not make relaunch adopt the foreign process reusing the old address.
env PATH="$REAL_PATH" "$LAB_HELPER" teardown "$LAB_SESSION"
provision
lab workspace create --label firstmate --no-focus >/dev/null
lab tab create --workspace w1 --label fm-launch --cwd "$LAB/wt" --no-focus >/dev/null
lab pane run "$PANE" "printf 'FOREIGN-RELAUNCH-GUARD\\n'" >/dev/null
FOREIGN=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
"$ROOT/bin/fm-spawn.sh" launch --relaunch --harness claude > "$LAB/relaunch.out" 2> "$LAB/relaunch.err"
cat "$LAB/relaunch.out" "$LAB/relaunch.err"
RECORDED=$(fm_backend_herdr_meta_value "$META" herdr_process_identity)
NEWPANE=$(fm_backend_herdr_meta_value "$META" herdr_pane_id)
CURRENT=$(fm_backend_herdr_pane_process_identity "$SESSION" "$NEWPANE")
echo "RELAUNCH PUBLICATION: pane=$NEWPANE recorded=$RECORDED current=$CURRENT"
[ "$NEWPANE" != "$PANE" ] && [ -n "$RECORDED" ] && [ "$RECORDED" = "$CURRENT" ]
[ "$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")" = "$FOREIGN" ]
lab pane read "$PANE" --lines 200
lab pane get "$NEWPANE"
echo 'PASS: fresh and rebound launches published the current process identity and preserved the recycled foreign pane'
