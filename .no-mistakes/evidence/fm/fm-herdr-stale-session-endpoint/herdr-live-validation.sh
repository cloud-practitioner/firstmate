#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M47HX8Y8BQRSDDHWXNW190JH
REAL_HERDR=$(command -v herdr)
REAL_PATH=$PATH
SESSION=fm-lab-x
[ ! -e herdr ] && [ ! -e .live-validation ] || { echo 'refusing preexisting fixture'; exit 1; }
mkdir -p herdr .live-validation/{tripwire,tmp,os-home,bin}
ln -s /home/node/.config/herdr/herdr.sock herdr/herdr.sock
export ROOT E REAL_HERDR REAL_PATH SESSION
export XDG_CONFIG_HOME=.
export FM_HERDR_LAB_STATE_DIR="$ROOT/.live-validation/tripwire"
export TMPDIR="$ROOT/.live-validation/tmp"
export SHELL=/bin/bash HERDR_SESSION="$SESSION"
unset FM_GATE_REFUSE_BYPASS HERDR_ENV HERDR_PANE_ID HERDR_WORKSPACE_ID HERDR_TAB_ID HERDR_SOCKET_PATH
for var in "${!FM_@}"; do case "$var" in *_OVERRIDE) unset "$var" ;; esac; done
LAB_MAIN="$ROOT/.live-validation/main"
LAB_CHILD="$ROOT/.live-validation/child"
PROJECT="$ROOT/.live-validation/project"
export TREEHOUSE_ROOT="$ROOT/.live-validation/pool"
export FM_SPAWN_NO_GUARD=1
unset FM_PROC_ROOT_OVERRIDE
# This transport wrapper does not replace Herdr or any response. It confines
# adapter invocations to the guarded helper, preserving one known cwd for
# relative sockets. Canonicalize real relative socket paths in session-list
# responses (the production adapter requires absolute paths). No synthetic
# panes/processes/statuses are returned. The fixed fm-remote route uses an alias.
cat > .live-validation/bin/herdr <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$ROOT"
printf '%q ' "$@" >> "$E/herdr-transport.log"; printf '\n' >> "$E/herdr-transport.log"
args=(); selected=${HERDR_SESSION:-$SESSION}
while [ "$#" -gt 0 ]; do
 case "$1" in
  --session) selected=$2; shift 2 ;;
  --session=*) selected=${1#*=}; shift ;;
  *) args+=("$1"); shift ;;
 esac
done
case "$selected" in "$SESSION"|fm-remote) ;; *) echo "refused foreign session $selected" >&2; exit 2 ;; esac
# Fault injection for the optional-identity scenario only: forward the
# process-info probe to a definitely absent lab pane. Herdr itself emits the
# genuine structured failure; no response or pane is mocked.
if [ -e "$ROOT/.live-validation/identity-transport-fault" ] && [ "${args[0]:-} ${args[1]:-}" = 'pane process-info' ]; then
 printf 'FAULT: process-info forwarded to absent wNo:pNo\n' >> "$E/herdr-transport.log"
 args=(pane process-info --pane wNo:pNo)
fi
case "${args[0]:-} ${args[1]:-}" in
 'session list')
   env PATH="$REAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}" |
     jq --arg root "$ROOT" --arg actual "$SESSION" --arg selected "$selected" '.sessions |= map(
       .socket_path |= (if startswith("/") then . else $root + "/" + ltrimstr("./") end)
       | if .name == $actual then .name = $selected else . end)'
   ;;
 '--version '*) exec env PATH="$REAL_PATH" "$REAL_HERDR" "${args[@]}" --session "$SESSION" ;;
 'server '*) exec env PATH="$REAL_PATH" HOME="$ROOT/.live-validation/os-home" "$ROOT/bin/fm-herdr-lab.sh" provision "$SESSION" ;;
 *) exec env PATH="$REAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}" ;;
esac
SH
chmod +x .live-validation/bin/herdr
export PATH="$ROOT/.live-validation/bin:$REAL_PATH"
lab() { env PATH="$REAL_PATH" "$ROOT/bin/fm-herdr-lab.sh" "$@"; }
run() { lab run "$SESSION" "$@"; }
cleanup() {
 set +e
 lab teardown "$SESSION"
 . "$ROOT/tests/fixture-tree-helpers.sh"
 fm_test_remove_spawn_launch_dirs "$ROOT/.live-validation"
 # Spawn intentionally strips its hook directories of write permissions.
 chmod -R u+w .live-validation 2>/dev/null
 rm -rf herdr .live-validation
 rm -f bin/backends/.base-herdr-live.sh
 echo 'CLEANUP: disposable lab removed; fleet-state tripwire verified.'
}
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
check() { "$@" || fail "assertion: $*"; }
meta() { fm_backend_herdr_meta_value "$1" "$2"; }
brief() {
 local home=$1 id=$2
 FM_HOME="$home" "$ROOT/bin/fm-brief.sh" "$id" fixture --mode local-only --herdr-lab
 python3 - "$home/data/$id/brief.md" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); s=p.read_text(); s=s.replace('{TASK}','Exercise the disposable Herdr endpoint only.').replace('{FIRSTMATE_SPEC}','Remain idle; do not invoke pipelines, publish, or alter other data.'); p.write_text(s)
PY
}
spawn() {
 local home=$1 id=$2
 FM_HOME="$home" "$ROOT/bin/fm-spawn.sh" "$id" "$PROJECT" "sh -c 'printf LIVE_WORKER_$id; sleep 600'" --mode local-only --yolo off --backend herdr
}
relaunch() {
 local home=$1 id=$2
 FM_HOME="$home" "$ROOT/bin/fm-spawn.sh" "$id" --relaunch --harness "sh -c 'printf LIVE_RECOVERED_$id; sleep 600'"
}
# Provision invokes prepare internally on a fresh session.
HOME="$ROOT/.live-validation/os-home" lab provision "$SESSION"
"$ROOT/bin/fm-lab-home.sh" create "$LAB_MAIN"
"$ROOT/bin/fm-lab-home.sh" create "$LAB_CHILD"
printf 'mate\n' > "$LAB_CHILD/.fm-secondmate-home"
printf 'off\n' > "$LAB_MAIN/config/herdr-presentation-spaces"
printf 'off\n' > "$LAB_CHILD/config/herdr-presentation-spaces"
printf 'manual\n' > "$LAB_MAIN/config/backlog-backend"
printf 'manual\n' > "$LAB_CHILD/config/backlog-backend"
mkdir -p "$PROJECT"
git -C "$PROJECT" init -q
echo '# Disposable runtime fixture' > "$PROJECT/README.md"
git -C "$PROJECT" add README.md
git -C "$PROJECT" -c user.name='Runtime Test' -c user.email='runtime@example.invalid' commit -qm initial
git clone --quiet --bare "$PROJECT" "$ROOT/.live-validation/origin.git"
git -C "$PROJECT" remote add origin "file://$ROOT/.live-validation/origin.git"
brief "$LAB_MAIN" mine
brief "$LAB_CHILD" kid
export FM_HOME="$LAB_MAIN"
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
printf '\nSCENARIO: fresh primary and secondmate-home spawns publish portable process identities\n'
spawn "$LAB_MAIN" mine
spawn "$LAB_CHILD" kid
cp "$LAB_MAIN/state/mine.meta" "$E/primary-initial.meta"
cp "$LAB_CHILD/state/kid.meta" "$E/child-initial.meta"
OLD_MAIN=$(meta "$LAB_MAIN/state/mine.meta" window)
OLD_CHILD=$(meta "$LAB_CHILD/state/kid.meta" window)
MAIN_WT=$(meta "$LAB_MAIN/state/mine.meta" worktree)
CHILD_WT=$(meta "$LAB_CHILD/state/kid.meta" worktree)
OLD_MAIN_IDENTITY=$(meta "$LAB_MAIN/state/mine.meta" herdr_process_identity)
OLD_CHILD_IDENTITY=$(meta "$LAB_CHILD/state/kid.meta" herdr_process_identity)
[ -n "$OLD_MAIN_IDENTITY" ] && [ -n "$OLD_CHILD_IDENTITY" ] || fail 'identity absent from successful spawn'
[ "$(FM_PROC_ROOT_OVERRIDE="$ROOT/.live-validation/no-proc" fm_backend_herdr_pane_process_identity "$SESSION" "${OLD_MAIN#*:}")" = "$OLD_MAIN_IDENTITY" ] || fail 'primary binding differs from real pane process'
[ "$(fm_backend_herdr_pane_process_identity "$SESSION" "${OLD_CHILD#*:}")" = "$OLD_CHILD_IDENTITY" ] || fail 'child binding differs from real pane process'
printf 'PRIMARY endpoint=%s identity=%s\nCHILD endpoint=%s identity=%s\n' "$OLD_MAIN" "$OLD_MAIN_IDENTITY" "$OLD_CHILD" "$OLD_CHILD_IDENTITY"
check fm_backend_target_exists herdr "$OLD_MAIN" fm-mine
fm_backend_capture herdr "$OLD_MAIN" 20 fm-mine
printf '\nSCENARIO: same-process relabeling remains readable\n'
MAIN_TAB=$(meta "$LAB_MAIN/state/mine.meta" herdr_tab_id)
run tab rename "$MAIN_TAB" renamed-worker
check fm_backend_target_exists herdr "$OLD_MAIN" fm-mine
check fm_backend_send_key herdr "$OLD_MAIN" Enter fm-mine
fm_backend_capture herdr "$OLD_MAIN" 20 fm-mine
run tab rename "$MAIN_TAB" fm-mine
printf 'PASS: same process remains usable despite a changed label and unavailable /proc fixture.\n'

printf '\nSCENARIO: fresh session reuses exact addresses with matching task labels and worktrees\n'
lab teardown "$SESSION"
HOME="$ROOT/.live-validation/os-home" lab provision "$SESSION"
# Counter reset is exercised by the real session's delete/recreate, not mocks.
run workspace create --label firstmate --cwd "$MAIN_WT"
run tab create --workspace w1 --label fm-mine --cwd "$MAIN_WT" --no-focus
run workspace create --label 2ndmate-mate --cwd "$CHILD_WT" --no-focus
run tab create --workspace w2 --label fm-kid --cwd "$CHILD_WT" --no-focus
[ "$OLD_MAIN" = "$SESSION:w1:p2" ] && [ "$OLD_CHILD" = "$SESSION:w2:p2" ] || fail 'fixture addresses did not match reset counters'
run pane run w1:p2 "printf 'FOREIGN_PRIMARY_SENTINEL\\n'"
run pane run w2:p2 "printf 'FOREIGN_CHILD_SENTINEL\\n'"
# Reproduce the original failure using only the base adapter's passive read
# against this real disposable recycled endpoint, never its lifecycle verbs.
git show 17a7b57015e3b3c8575d7e8775782e4b08b44869:bin/backends/herdr.sh > "$ROOT/bin/backends/.base-herdr-live.sh"
base_state=$(FM_HOME="$LAB_MAIN" bash -c '. "$ROOT/bin/fm-backend.sh"; . "$ROOT/bin/backends/.base-herdr-live.sh"; fm_backend_herdr_agent_state "$SESSION:w1:p2"')
rm "$ROOT/bin/backends/.base-herdr-live.sh"
printf 'Base-commit recycled endpoint liveness=%s (adoptable); fixed adapter must report missing.\n' "$base_state"
[ "$base_state" = dead ] || fail 'base failure was not reproduced'
for spec in "$LAB_MAIN mine $OLD_MAIN $OLD_MAIN_IDENTITY" "$LAB_CHILD kid $OLD_CHILD $OLD_CHILD_IDENTITY"; do
 read -r home id target identity <<< "$spec"
 export FM_HOME="$home"
 current=$(fm_backend_herdr_pane_process_identity "$SESSION" "${target#*:}")
 [ "$current" != "$identity" ] || fail 'fresh process has original identity'
 state=$(fm_backend_agent_state herdr "$target" "fm-$id")
 printf '%s recorded=%s actual=%s liveness=%s\n' "$id" "$identity" "$current" "$state"
 [ "$state" = missing ] || fail 'recycled endpoint was adopted'
 if fm_backend_target_exists herdr "$target" "fm-$id"; then fail 'foreign endpoint reports owned'; fi
 if fm_backend_capture herdr "$target" 20 "fm-$id"; then fail 'foreign capture allowed'; fi
 if fm_backend_send_key herdr "$target" C-c "fm-$id"; then fail 'foreign input allowed'; fi
 if fm_backend_send_text_submit herdr "$target" 'printf UNSAFE_INPUT' 1 0 0 "fm-$id"; then fail 'foreign text allowed'; fi
 fm_backend_herdr_kill_serialized "$SESSION" "${target#*:}" "fm-$id"
 check fm_backend_herdr_endpoint_confirmed_gone "$target" "fm-$id"
 run pane get "${target#*:}"
 printf 'PASS: %s missing; capture, keys and text refused; foreign pane preserved.\n' "$id"
done

printf '\nSCENARIO: bootstrap and watcher probes cannot borrow another claimant at the same address\n'
export FM_HOME="$LAB_MAIN"
cp "$LAB_MAIN/state/mine.meta" "$LAB_MAIN/state/current-a.meta"
printf 'herdr_process_identity=%s\n' "$(fm_backend_herdr_pane_process_identity "$SESSION" w1:p2)" >> "$LAB_MAIN/state/current-a.meta"
cp "$LAB_MAIN/state/mine.meta" "$LAB_MAIN/state/stale-b.meta"
printf 'harness=claude\nkind=secondmate\n' >> "$LAB_MAIN/state/stale-b.meta"
. "$ROOT/bin/fm-secondmate-liveness-lib.sh"
for probe_mode in full poll; do
 fm_secondmate_liveness_probe "$LAB_MAIN/state/stale-b.meta" stale-b "$probe_mode"
 printf 'Probe mode=%s state=%s disposition=%s kill=%s\n' "$probe_mode" "$FM_SM_LIVE_STATE" "$FM_SM_LIVE_STATUS" "$FM_SM_LIVE_KILL"
 [ "$FM_SM_LIVE_STATE" = missing ] && [ "$FM_SM_LIVE_STATUS" = relaunchable ] && [ "$FM_SM_LIVE_KILL" = 0 ] || fail 'probe borrowed the other record ownership'
done
rm "$LAB_MAIN/state/current-a.meta" "$LAB_MAIN/state/stale-b.meta"
printf 'PASS: both recovery probes select their own task and refuse adoption/kill of the recycled endpoint.\n'

printf '\nSCENARIO: legacy records retain their documented best-effort compatibility\n'
export FM_HOME="$LAB_MAIN"
python3 - "$LAB_MAIN/state/mine.meta" "$LAB_MAIN/state/legacy.meta" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); pathlib.Path(sys.argv[2]).write_text(''.join(line for line in p.read_text().splitlines(True) if not line.startswith('herdr_process_identity=')))
PY
check fm_backend_target_exists herdr "$OLD_MAIN" fm-legacy
fm_backend_capture herdr "$OLD_MAIN" 10 fm-legacy
rm "$LAB_MAIN/state/legacy.meta"
printf 'PASS: a no-identity record is not blanket-rejected when its worktree matches.\n'

printf '\nSCENARIO: remote parent-route state does not borrow ambient worker ownership\n'
REMOTE="$ROOT/.live-validation/remote"
"$ROOT/bin/fm-lab-home.sh" create "$REMOTE"
printf 'remote\n' > "$REMOTE/.fm-secondmate-home"
ln -s "$ROOT/AGENTS.md" "$REMOTE/AGENTS.md"
ln -s "$ROOT/bin" "$REMOTE/bin"
mkdir -p "$REMOTE/state/parent-route"
python3 - "$LAB_MAIN/state/mine.meta" "$REMOTE/state/parent-route/remote.meta" "$SESSION" <<'PY'
import pathlib,sys
src,out,session=sys.argv[1:]
s=pathlib.Path(src).read_text().replace('window='+session+':','window=fm-remote:').replace('herdr_session='+session,'herdr_session=fm-remote').replace('endpoint_task_id=mine','endpoint_task_id=remote')
pathlib.Path(out).write_text(s)
PY
# Ambient worker metadata deliberately holds the current, foreign identity.
cp "$REMOTE/state/parent-route/remote.meta" "$REMOTE/state/ambient.meta"
printf 'herdr_process_identity=%s\n' "$(fm_backend_herdr_pane_process_identity "$SESSION" w1:p2)" >> "$REMOTE/state/ambient.meta"
remote_state=$(FM_HOME="$REMOTE" "$ROOT/bin/fm-remote-secondmate-control.sh" state remote)
printf 'Remote state: %s\n' "$remote_state"
[ "$remote_state" = missing ] || fail 'remote route borrowed ambient worker state'
remote_capture=$(FM_HOME="$REMOTE" "$ROOT/bin/fm-remote-secondmate-control.sh" capture remote 20)
[ -z "$remote_capture" ] || fail 'remote captured foreign screen'
printf 'Remote capture: <empty>\n'
FM_HOME="$REMOTE" "$ROOT/bin/fm-remote-secondmate-control.sh" observe remote
FM_HOME="$REMOTE" "$ROOT/bin/fm-remote-secondmate-control.sh" send remote 'Do not deliver to the foreign pane' fire-and-forget
run pane read w1:p2 --lines 200
printf 'PASS: remote state and capture use parent-route; the durable doorbell is not typed into the recycled pane.\n'

printf '\nSCENARIO: recovery creates a new binding without adopting or closing matching foreign shells\n'
for spec in "$LAB_MAIN mine $OLD_MAIN $MAIN_WT" "$LAB_CHILD kid $OLD_CHILD $CHILD_WT"; do
 read -r home id target wt <<< "$spec"
 export FM_HOME="$home"
 relaunch "$home" "$id"
 new=$(meta "$home/state/$id.meta" window)
 [ "$new" != "$target" ] || fail 'recovery adopted foreign address'
 [ "$(meta "$home/state/$id.meta" worktree)" = "$wt" ] || fail 'recovery replaced worktree'
 [ "$(meta "$home/state/$id.meta" herdr_process_identity)" = "$(fm_backend_herdr_pane_process_identity "$SESSION" "${new#*:}")" ] || fail 'replacement identity not published'
 check fm_backend_target_exists herdr "$new" "fm-$id"
 fm_backend_capture herdr "$new" 20 "fm-$id"
 run pane get "${target#*:}"
 cp "$home/state/$id.meta" "$E/$id-recovered.meta"
 printf 'PASS: %s rebound from %s to %s and kept worktree %s.\n' "$id" "$target" "$new" "$wt"
done

printf '\nSCENARIO: passive stopped-server probe stays read-only; active capture checks ownership after restoration\n'
export FM_HOME="$LAB_MAIN"
RESTART_TARGET=$(meta "$LAB_MAIN/state/mine.meta" window)
lab stop "$SESSION"
[ "$(fm_backend_agent_state herdr "$RESTART_TARGET" fm-mine)" = missing ] || fail 'stopped server not missing'
status=$(run status --json)
printf '%s\n' "$status"
[ "$(printf '%s' "$status" | jq -r .server.running)" = false ] || fail 'passive liveness started server'
if fm_backend_capture herdr "$RESTART_TARGET" 20 fm-mine; then fail 'active capture adopted the restored foreign shell'; fi
printf 'PASS: passive probe did not start server; active capture restored it but refused the changed process.\n'

printf '\nSCENARIO: repeated recovery preserves unclaimed same-label panes after another restart\n'
for spec in "$LAB_MAIN mine $OLD_MAIN w1" "$LAB_CHILD kid $OLD_CHILD w2"; do
 read -r home id original ws <<< "$spec"
 export FM_HOME="$home"
 previous=$(meta "$home/state/$id.meta" window)
 relaunch "$home" "$id"
 new=$(meta "$home/state/$id.meta" window)
 [ "$new" != "$previous" ] || fail 'second recovery adopted a replaced process'
 run pane get "${original#*:}"
 run pane get "${previous#*:}"
 run tab list --workspace "$ws"
 printf 'PASS: repeated %s recovery kept both %s and %s and rebound to %s.\n' "$id" "$original" "$previous" "$new"
done

printf '\nSCENARIO: response-owned projected abort ignores an ambient stale address claim\n'
export FM_HOME="$LAB_MAIN"
printf 'on\n' > "$LAB_MAIN/config/herdr-presentation-spaces"
brief "$LAB_MAIN" abort-b
printf 'backend=herdr\nwindow=%s:w3:p2\nworktree=%s\nherdr_process_identity=%s\n' "$SESSION" "$MAIN_WT" "$OLD_MAIN_IDENTITY" > "$LAB_MAIN/state/stale-a.meta"
# The real Treehouse CLI reads this project-local TOML after the Herdr pane
# has been created. A parser failure prevents worktree acquisition naturally.
printf '[invalid\n' > "$PROJECT/treehouse.toml"
if spawn "$LAB_MAIN" abort-b; then fail 'spawn acquired a worktree with malformed Treehouse configuration'; fi
rm "$PROJECT/treehouse.toml"
[ ! -e "$LAB_MAIN/state/abort-b.meta" ] || fail 'abort published task metadata'
[ -f "$LAB_MAIN/state/stale-a.meta" ] || fail 'abort erased the stale unrelated record'
run workspace list
if run pane get w3:p2; then fail 'response-owned abort left task pane behind'; fi
if run workspace get w3; then fail 'response-owned abort left projected workspace behind'; fi
printf 'PASS: failed real Treehouse allocation cleaned the newly created pane and workspace despite stale A claiming that address.\n'
rm "$LAB_MAIN/state/stale-a.meta"
printf 'off\n' > "$LAB_MAIN/config/herdr-presentation-spaces"

printf '\nSCENARIO: teardown closes owned replacements and removes records while preserving foreign panes\n'
# Forced Treehouse return intentionally reaps all processes in the task's
# worktree. Put foreign panes outside that separate cleanup scope first.
mkdir -p "$ROOT/.live-validation/foreign"
for pane in w1:p1 w1:p2 w1:p3 w2:p1 w2:p2 w2:p3; do
 run pane run "$pane" "cd '$ROOT/.live-validation/foreign'"
done
sleep 1
for spec in "$LAB_MAIN mine $OLD_MAIN" "$LAB_CHILD kid $OLD_CHILD"; do
 read -r home id old <<< "$spec"
 new=$(meta "$home/state/$id.meta" window)
 FM_HOME="$home" "$ROOT/bin/fm-teardown.sh" "$id" --force
 [ ! -e "$home/state/$id.meta" ] || fail 'successful teardown retained endpoint record'
 if run pane get "${new#*:}"; then fail 'owned replacement survived teardown'; fi
 run pane get "${old#*:}"
 printf 'PASS: %s owned replacement removed; same-label foreign shell retained.\n' "$id"
done
printf '\nSCENARIO: live flat/projected metadata differs only in endpoint and process incarnations\n'
export FM_HOME="$LAB_MAIN"
brief "$LAB_MAIN" shape
printf 'off\n' > "$LAB_MAIN/config/herdr-presentation-spaces"
spawn "$LAB_MAIN" shape
cp "$LAB_MAIN/state/shape.meta" "$E/shape-flat.meta"
FM_HOME="$LAB_MAIN" "$ROOT/bin/fm-teardown.sh" shape --force
printf 'on\n' > "$LAB_MAIN/config/herdr-presentation-spaces"
spawn "$LAB_MAIN" shape
cp "$LAB_MAIN/state/shape.meta" "$E/shape-projected.meta"
shape_target=$(meta "$LAB_MAIN/state/shape.meta" window)
shape_ws=$(meta "$LAB_MAIN/state/shape.meta" herdr_workspace_id)
[ "$shape_ws" != w1 ] || fail 'projected spawn used flat parent'
[ "$(meta "$E/shape-flat.meta" herdr_process_identity)" != "$(meta "$E/shape-projected.meta" herdr_process_identity)" ] || fail 'two panes shared the same process identity'
[ "$(meta "$LAB_MAIN/state/shape.meta" herdr_process_identity)" = "$(fm_backend_herdr_pane_process_identity "$SESSION" "${shape_target#*:}")" ] || fail 'projected identity not bound to actual process'
# Execute the changed E2E test's normalizer over actual persisted product output.
eval "$(python3 - <<'PY'
from pathlib import Path
s=Path('tests/fm-backend-herdr-presentation-e2e.test.sh').read_text()
i=s.index('normalize_meta() {'); j=s.index('\n}\n',i)+3
print(s[i:j])
PY
)"
normalize_meta "$E/shape-flat.meta" > "$E/shape-flat.normalized.meta"
normalize_meta "$E/shape-projected.meta" > "$E/shape-projected.normalized.meta"
cmp "$E/shape-flat.normalized.meta" "$E/shape-projected.normalized.meta" || fail 'live metadata contract comparison differed'
run workspace get "$shape_ws"
fm_backend_capture herdr "$shape_target" 20 fm-shape
FM_HOME="$LAB_MAIN" "$ROOT/bin/fm-teardown.sh" shape --force
if run pane get "${shape_target#*:}"; then fail 'owned projected pane survived teardown'; fi
if run workspace get "$shape_ws"; then fail 'owned projection survived teardown'; fi
[ ! -e "$LAB_MAIN/state/shape.meta" ] || fail 'projection teardown retained record'
printf 'PASS: flat/projected metadata contract holds, identities differ as expected, and owned projected cleanup removes pane/workspace/record.\n'

printf '\nSCENARIO: an actually unavailable ps fails closed for a bound pane\n'
NO_PS="$ROOT/.live-validation/no-ps-bin"
mkdir -p "$NO_PS"
for tool in bash env jq; do ln -s "$(command -v "$tool")" "$NO_PS/$tool"; done
ln -s "$ROOT/.live-validation/bin/herdr" "$NO_PS/herdr"
run tab create --workspace w1 --label fm-unreadable --cwd "$ROOT/.live-validation/foreign" --no-focus
unreadable_pane=$(run tab list --workspace w1 | jq -r '.result.tabs[] | select(.label=="fm-unreadable") | .tab_id')
unreadable_pane=$(run pane list --workspace w1 | jq -r --arg tab "$unreadable_pane" '.result.panes[] | select(.tab_id==$tab) | .pane_id')
identity=$(fm_backend_herdr_pane_process_identity "$SESSION" "$unreadable_pane")
printf 'backend=herdr\nwindow=%s:%s\nherdr_process_identity=%s\n' "$SESSION" "$unreadable_pane" "$identity" > "$LAB_MAIN/state/unreadable.meta"
state=$(PATH="$NO_PS" fm_backend_agent_state herdr "$SESSION:$unreadable_pane" fm-unreadable)
printf 'With ps genuinely absent from PATH: state=%s\n' "$state"
[ "$state" = unreadable ] || fail 'unreadable identity licensed recovery'
if PATH="$NO_PS" fm_backend_capture herdr "$SESSION:$unreadable_pane" 20 fm-unreadable; then fail 'missing ps allowed capture'; fi
if PATH="$NO_PS" fm_backend_send_key herdr "$SESSION:$unreadable_pane" C-c fm-unreadable; then fail 'missing ps allowed key'; fi
if PATH="$NO_PS" fm_backend_herdr_kill_serialized "$SESSION" "$unreadable_pane" fm-unreadable; then fail 'missing ps allowed close'; fi
if PATH="$NO_PS" fm_backend_herdr_endpoint_confirmed_gone "$SESSION:$unreadable_pane" fm-unreadable; then fail 'missing ps allowed removal while pane present'; fi
run pane get "$unreadable_pane"
run pane close "$unreadable_pane"
check fm_backend_herdr_endpoint_confirmed_gone "$SESSION:$unreadable_pane" fm-unreadable
rm "$LAB_MAIN/state/unreadable.meta"
printf 'PASS: unreadable identity blocks use, recovery, close and record removal; authoritative absence still confirms removal.\n'

printf '\nSCENARIO: fresh spawn and relaunch continue when process-info transport is unavailable\n'
# A missing ps alone cannot reach publication because it also prevents the
# independent lock-owner proof. Fault only process-info via the lab proxy,
# returning Herdr's real absent-pane error while all other operations stay live.
if run pane process-info --pane wNo:pNo; then fail 'fault target unexpectedly exists'; fi
touch "$ROOT/.live-validation/identity-transport-fault"
brief "$LAB_MAIN" optional
printf 'off\n' > "$LAB_MAIN/config/herdr-presentation-spaces"
spawn "$LAB_MAIN" optional
optional_target=$(meta "$LAB_MAIN/state/optional.meta" window)
optional_gen=$(meta "$LAB_MAIN/state/optional.meta" spawn_gen)
[ -z "$(meta "$LAB_MAIN/state/optional.meta" herdr_process_identity)" ] || fail 'failed process-info spawn did not omit identity'
cp "$LAB_MAIN/state/optional.meta" "$E/optional-initial.meta"
fm_backend_capture herdr "$optional_target" 20 fm-optional
check fm_backend_send_key herdr "$optional_target" C-c fm-optional
sleep 1
relaunch "$LAB_MAIN" optional
[ "$(meta "$LAB_MAIN/state/optional.meta" window)" = "$optional_target" ] || fail 'legacy owned relaunch changed endpoint'
[ "$(meta "$LAB_MAIN/state/optional.meta" spawn_gen)" != "$optional_gen" ] || fail 'relaunch did not republish'
[ -z "$(meta "$LAB_MAIN/state/optional.meta" herdr_process_identity)" ] || fail 'failed process-info relaunch did not omit identity'
fm_backend_capture herdr "$optional_target" 20 fm-optional
cp "$LAB_MAIN/state/optional.meta" "$E/optional-relaunched.meta"
rm "$ROOT/.live-validation/identity-transport-fault"
FM_HOME="$LAB_MAIN" "$ROOT/bin/fm-teardown.sh" optional --force
printf 'PASS: a real process-info failure did not abort spawn or relaunch; both records omit identity and retain the legacy binding.\n'
run workspace list
printf '\nALL LIVE SCENARIOS PASSED\n'
