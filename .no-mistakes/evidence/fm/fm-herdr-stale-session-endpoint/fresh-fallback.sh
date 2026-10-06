#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
export LIVE_ROOT="$ROOT" LIVE_PATH="$PATH" LIVE_REAL_HERDR="$(command -v herdr)" LIVE_REAL_PS="$(command -v ps)"
export FM_HERDR_LAB_STATE_DIR="$ROOT/.live-validation/tripwires" HERDR_CONFIG_PATH="$ROOT/.live-validation/config.toml"
export TREEHOUSE_ROOT="$ROOT/.live-validation/pool"
mkdir -p "$TREEHOUSE_ROOT"
lab() { (cd "$ROOT"; HOME=.live-validation/user XDG_CONFIG_HOME=.live-validation/user/.config PATH="$LIVE_PATH" bin/fm-herdr-lab.sh "$@"); }
SESSION=$(lab name fresh)
export LIVE_SESSION="$SESSION" HERDR_SESSION="$SESSION" PATH="$ROOT/.live-validation/bin:$PATH"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_CLIENT_SOCKET_PATH
for v in "${!FM_@}"; do case "$v" in *_OVERRIDE) unset "$v" ;; esac; done
unset FM_GATE_REFUSE_BYPASS
export TMPDIR="$ROOT/.live-validation/tmp" HOME="$ROOT/.live-validation/user" CLAUDE_CONFIG_DIR="$ROOT/.live-validation/claude"
export FM_HOME="$ROOT/.live-validation/fresh-home"
bin/fm-lab-home.sh create "$FM_HOME" >/dev/null
printf 'off\n' > "$FM_HOME/config/herdr-presentation-spaces"
printf 'manual\n' > "$FM_HOME/config/backlog-backend"
. bin/fm-backend.sh
. bin/fm-lock-lib.sh
fm_backend_source herdr
cleanup() {
  rc=$?
  rm -f "$ROOT/.live-validation/bin/ps"
  lab teardown "$SESSION" || rc=1
  . "$ROOT/tests/fixture-tree-helpers.sh"
  fm_test_remove_spawn_launch_dirs "$ROOT/.live-validation"
  echo 'TEARDOWN: lab absent; default-session tripwire unchanged'
  exit "$rc"
}
trap cleanup EXIT
lab provision "$SESSION"
bin/fm-brief.sh fresh "$ROOT/.live-validation/project" --mode local-only --herdr-lab >/dev/null
python3 - "$FM_HOME/data/fresh/brief.md" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read().replace('{TASK}', 'Do not run tools, edit files, or contact services. Await teardown.').replace('{FIRSTMATE_SPEC}', 'This is disposable endpoint-only validation, not a coding assignment.')
open(p, 'w').write(s)
PY
cat > .live-validation/bin/ps <<'SH'
#!/usr/bin/env bash
case "$*" in '-o lstart= -p '*) exit 1 ;; *) exec "$LIVE_REAL_PS" "$@" ;; esac
SH
chmod +x .live-validation/bin/ps
printf 'SCENARIO: fresh spawn succeeds when the portable identity read fails\n'
bin/fm-spawn.sh fresh "$ROOT/.live-validation/project" --backend herdr --harness claude --mode local-only --yolo off
META="$FM_HOME/state/fresh.meta"
[ -f "$META" ]
[ -z "$(fm_backend_herdr_meta_value "$META" herdr_process_identity)" ]
TARGET=$(fm_backend_target_of_meta "$META")
WT=$(fm_backend_herdr_meta_value "$META" worktree)
[ "$WT" != "$ROOT/.live-validation/project" ]
[ "$(git -C "$WT" rev-parse --show-toplevel)" = "$WT" ]
echo "fresh spawn target=$TARGET; identity omitted; real isolated worktree=$WT"
rm .live-validation/bin/ps
sleep 2
lab run "$SESSION" pane process-info --pane "${TARGET#*:}"
lab run "$SESSION" pane get "${TARGET#*:}"
fm_backend_kill herdr "$TARGET" '' fm-fresh
fm_backend_herdr_endpoint_confirmed_gone "$TARGET" fm-fresh
echo 'fresh fallback endpoint removed and absence confirmed'
