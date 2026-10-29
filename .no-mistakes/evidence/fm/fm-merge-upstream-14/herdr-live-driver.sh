#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EV=/home/node/.no-mistakes/evidence/01M643TH9MB3MKY9CTY96RSFYG
export TMPDIR="$ROOT/.test-phase/tmp"
export FM_HERDR_LAB_STATE_DIR="$ROOT/.test-phase/herdr-state"
unset FM_HOME FM_BACKEND FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
export REAL_HERDR=$(command -v herdr) REAL_PATH=$PATH LAB_HELPER="$ROOT/bin/fm-herdr-lab.sh"
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
"$ROOT/bin/fm-lab-home.sh" create "$LAB"
export TREEHOUSE_ROOT="$LAB/treehouse" PI_CODING_AGENT_DIR="$LAB/pi-agent" PI_OFFLINE=1
mkdir -p "$PI_CODING_AGENT_DIR"
unset PI_CODING_AGENT PI_PROVIDER PI_MODEL PI_SESSION_ID
SESSION=$("$LAB_HELPER" name merge-live)
export SESSION
cleanup() {
  rc=$?
  PATH="$REAL_PATH" "$LAB_HELPER" teardown "$SESSION" || rc=1
  # The worker's immutable hook directory needs owner write permission for fixture disposal.
  find "$LAB" -type d -exec chmod u+rwx {} +
  # This is the one exact incidental staging directory produced by this lab's real spawn.
  HASH=$(printf '%s' "$LAB" | shasum -a 256 | awk '{print $1}')
  rm -rf "/tmp/fm-pi-check+$HASH"
  rm -rf "$LAB"
  printf 'lab teardown complete; default-session tripwire verified; exit=%s\n' "$rc"
  exit "$rc"
}
trap cleanup EXIT
# provision owns prepare for a fresh named session.
"$LAB_HELPER" provision "$SESSION"
printf 'provisioned named isolated session %s\n' "$SESSION"
mkdir -p "$LAB/transport"
cat > "$LAB/transport/herdr" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --session) [ "$2" = "$SESSION" ] || exit 78; shift 2 ;;
    --session=*) [ "${1#*=}" = "$SESSION" ] || exit 78; shift ;;
    --version|-V) exec "$REAL_HERDR" "$@" ;;
    *) args+=("$1"); shift ;;
  esac
done
exec env PATH="$REAL_PATH" "$LAB_HELPER" run "$SESSION" "${args[@]}"
SH
chmod +x "$LAB/transport/herdr"
export PATH="$LAB/transport:$REAL_PATH" FM_HOME="$LAB" FM_BACKEND=herdr HERDR_SESSION="$SESSION"
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr
fm_backend_herdr_version_check
CONTAINER_RAW=$(fm_backend_herdr_container_ensure "$LAB" "" "$SESSION")
CONTAINER=${CONTAINER_RAW%%$'\t'*}
SEEDED=${CONTAINER_RAW#*$'\t'}
printf 'container=%s seeded=%s\n' "$CONTAINER" "$SEEDED"
IDS=$(fm_backend_herdr_create_task "$CONTAINER" fm-merge-check "$LAB" "$SEEDED")
read -r TAB PANE <<< "$IDS"
TARGET="$SESSION:$PANE"
IDENTITY=$(fm_backend_herdr_pane_process_identity "$SESSION" "$PANE")
printf 'task endpoint=%s tab=%s identity=%s\n' "$TARGET" "$TAB" "$IDENTITY"
printf 'backend=herdr\nbackend_session=%s\nbackend_target=%s\nwindow=%s\nendpoint_task_id=merge-check\nworktree=%s\nproject=%s\nharness=claude\nkind=scout\nmode=scout\nherdr_process_identity=%s\n' "$SESSION" "$TARGET" "$TARGET" "$LAB" "$LAB" "$IDENTITY" > "$LAB/state/merge-check.meta"
fm_backend_herdr_send_text_line "$TARGET" "printf 'REAL-HERDR-ENDPOINT-OK\\n'"
sleep 1
CAPTURE=$(fm_backend_herdr_capture "$TARGET" 30)
printf '%s\n' "$CAPTURE"
[[ "$CAPTURE" = *REAL-HERDR-ENDPOINT-OK* ]]
"$ROOT/bin/fm-send.sh" merge-check $'Keep the preserved fork additions.\nDo not merge without approval.'
printf '\nDurable instruction record (public inbox protocol):\n'
python3 - "$LAB/state/merge-check.inbox" <<'PY'
import pathlib,sys
p=list(pathlib.Path(sys.argv[1]).glob('*.msg'))
assert len(p)==1, p
print(p[0].read_text())
PY
# Launch the real installed Pi through the product's public spawn interface.
PROJECT="$LAB/projects/fixture"
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git init -q -b main "$PROJECT"
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$PROJECT" -c user.name=Lab -c user.email=lab@example.invalid commit -q --allow-empty -m fixture
"$ROOT/bin/fm-brief.sh" pi-check fixture --scout --herdr-lab
python3 - "$LAB/data/pi-check/brief.md" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]);p.write_text(p.read_text().replace('{TASK}','Verify an isolated Pi launch without MCP servers.').replace('{FIRSTMATE_SPEC}','Do not run commands or edit files. Reply with PI-LAB-READY, then stop.'))
PY
set +e
"$ROOT/bin/fm-spawn.sh" pi-check "$PROJECT" --scout --harness pi --mcp off --backend herdr > "$LAB/pi-spawn.log" 2>&1
PI_SPAWN_RC=$?
set -e
printf '\nReal Pi spawn exit=%s\n' "$PI_SPAWN_RC"
python3 - "$LAB/pi-spawn.log" <<'PY'
import pathlib,sys
print(pathlib.Path(sys.argv[1]).read_text())
PY
cp "$LAB/pi-spawn.log" "$EV/real-pi-spawn.log"
if [ "$PI_SPAWN_RC" = 0 ]; then
  PI_TARGET=$(awk -F= '$1=="window" {print substr($0,8)}' "$LAB/state/pi-check.meta")
  sleep 5
  fm_backend_herdr_capture "$PI_TARGET" 80 > "$LAB/pi-before-trust.txt"
  if grep -q 'Trust project folder?' "$LAB/pi-before-trust.txt"; then
    # Select only session-scoped trust, never mutate an operator trust store.
    fm_backend_herdr_send_key "$PI_TARGET" Down
    fm_backend_herdr_send_key "$PI_TARGET" Down
    fm_backend_herdr_send_key "$PI_TARGET" Enter
    sleep 5
  fi
  fm_backend_herdr_visible_capture "$PI_TARGET" 60 | tee "$EV/real-pi-pane.txt"
  "$LAB_HELPER" run "$SESSION" pane process-info --pane "${PI_TARGET#*:}" > "$EV/real-pi-process.json"
  cp "$LAB/state/pi-check.meta" "$EV/real-pi-task-meta.txt"
  # Seed a registered persistent-mate record using this real, idle Pi endpoint.
  # No harness, login, stop operation, or backend is replaced by a mock.
  PI_WT=$(awk -F= '$1=="worktree" {print substr($0,10)}' "$LAB/state/pi-check.meta")
  mkdir -p "$PI_WT/state" "$PI_WT/data"
  printf 'pi-check\n' > "$PI_WT/.fm-secondmate-home"
  printf '# Backlog\n\n## In flight\n\n## Queued\n\n## Done\n' > "$PI_WT/data/backlog.md"
  printf -- '- pi-check - a test mate (home: %s; scope: validation; projects: none; added 2026-10-29)\n' "$PI_WT" > "$LAB/data/secondmates.md"
  python3 - "$LAB/state/pi-check.meta" "$PI_WT" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]);s=p.read_text().replace('kind=scout','kind=secondmate').replace('mode=scout','mode=secondmate');p.write_text(s+'home='+sys.argv[2]+'\n')
PY
  : > "$PI_WT/state/active-child.meta"
  if "$ROOT/bin/fm-secondmate-dormant.sh" stand-down pi-check --reason 'Disposable validation'; then
    echo 'ERROR: a mate with active child work was stopped'; exit 1
  fi
  [ ! -f "$LAB/state/pi-check.dormant" ]
  rm "$PI_WT/state/active-child.meta"
  "$ROOT/bin/fm-secondmate-dormant.sh" stand-down pi-check --reason 'Disposable validation'
  "$ROOT/bin/fm-secondmate-dormant.sh" list | tee "$EV/real-secondmate-dormant.txt"
  [ -f "$LAB/state/pi-check.dormant" ] && [ -f "$LAB/state/pi-check.meta" ] && [ -f "$PI_WT/data/backlog.md" ]
  if "$ROOT/bin/fm-send.sh" pi-check 'Do not admit work while dormant'; then
    echo 'ERROR: dormant mate admitted a steer'; exit 1
  fi
  echo 'Live mate stand-down preserved its home and durable record; busy and dormant admission guards both refused'

fi
# Run real Claude only through the guarded launcher and a staged long command.
HOST_BEFORE=$(readlink "$HOME/.local/bin/claude" || true)
SHIM=$("$ROOT/bin/fm-live-claude.sh" shim "$LAB/claude-shim")
printf '{"mcpServers":{}}\n' > "$LAB/no-mcp.json"
python3 - "$SHIM/claude" "$LAB" <<'PY'
import pathlib,shlex,sys
cli,lab=sys.argv[1:];p=pathlib.Path(lab)
args=['env','-u','NO_MISTAKES_GATE','-u','FM_GATE_REFUSE_BYPASS','-u','FM_ROOT_OVERRIDE','-u','FM_STATE_OVERRIDE','-u','FM_DATA_OVERRIDE','-u','FM_CONFIG_OVERRIDE','-u','FM_PROJECTS_OVERRIDE',cli,'-p','Reply only with CLAUDE-LAB-READY.','--no-session-persistence','--setting-sources','','--tools','','--strict-mcp-config','--mcp-config',str(p/'no-mcp.json'),'--system-prompt','You are a disposable validation probe. Do not use tools. Reply with exactly the requested token. '+('Padding for a long staged command. '*50),'--output-format','json']
(p/'claude-launch.sh').write_text('timeout 60 '+shlex.join(args)+' > '+shlex.quote(str(p/'claude-answer.json'))+' 2>&1; printf "CLAUDE_EXIT=%s\\n" "$?" > '+shlex.quote(str(p/'claude-finished'))+'\n')
print('Staged real Claude launch bytes:',(p/'claude-launch.sh').stat().st_size)
PY
fm_backend_herdr_send_text_line "$TARGET" ". '$LAB/claude-launch.sh'"
for _ in $(seq 1 130); do [ ! -f "$LAB/claude-finished" ] || break; sleep 0.5; done
if [ -f "$LAB/claude-finished" ]; then
  cp "$LAB/claude-answer.json" "$EV/real-claude-answer.json"
  python3 - "$LAB/claude-answer.json" "$LAB/claude-finished" <<'PY'
import pathlib,sys
for f in sys.argv[1:]:print(pathlib.Path(f).read_text())
PY
else
  echo 'Real Claude did not finish inside bounded wait'
fi
[ "$HOST_BEFORE" = "$(readlink "$HOME/.local/bin/claude" || true)" ]
echo 'Real Claude host launcher unchanged'
# Active adversarial probe: matching labels and cwd must not authorize a recycled PID.
cp "$LAB/state/merge-check.meta" "$LAB/state/before.meta-copy"
python3 - "$LAB/state/merge-check.meta" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]);s=p.read_text();s='\n'.join('herdr_process_identity=proc:99999999:invalid:0' if x.startswith('herdr_process_identity=') else x for x in s.splitlines())+'\n';p.write_text(s)
PY
# kill is intentionally idempotent and may return zero for a refused close;
# surviving exact endpoint, not exit code, is the observable safety contract.
fm_backend_herdr_kill "$TARGET" '' fm-merge-check
"$LAB_HELPER" run "$SESSION" pane get "$PANE"
echo 'Foreign process identity close preserved the exact endpoint as expected'
mv "$LAB/state/before.meta-copy" "$LAB/state/merge-check.meta"
fm_backend_herdr_kill "$TARGET" '' fm-merge-check
if "$LAB_HELPER" run "$SESSION" pane get "$PANE"; then echo 'ERROR: own endpoint remains'; exit 1; else echo 'Owned endpoint closed and confirmed absent'; fi
# Explicit default-session attempts must fail before invoking Herdr lifecycle.
if "$LAB_HELPER" teardown default; then exit 1; else echo 'Default-session teardown refused'; fi
if "$LAB_HELPER" run "$SESSION" session delete default; then exit 1; else echo 'Session lifecycle escape refused'; fi
if "$LAB_HELPER" run "$SESSION" status --session default; then exit 1; else echo 'Caller session override refused'; fi
