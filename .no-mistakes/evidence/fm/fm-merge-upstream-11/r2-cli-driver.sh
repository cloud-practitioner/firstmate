#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M5GMXRP8TEGYK8ZJPXTCW65Z
export TMPDIR="$ROOT/.test-live/tmp" PATH="$ROOT/.test-live/bin:$PATH"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS NM_HOME FM_BACKEND
export FM_BACKEND=tmux
export FM_HOME="$ROOT/.test-live/cli-home"
export XDG_CONFIG_HOME="$FM_HOME/xdg-config" XDG_STATE_HOME="$FM_HOME/xdg-state" XDG_DATA_HOME="$FM_HOME/xdg-data"
bin/fm-lab-home.sh create "$FM_HOME"
trap 'rm -rf "$FM_HOME"' EXIT
printf '\n=== Capacity with no target ===\n'
bin/fm-capacity.sh | tee "$EVIDENCE/r2-capacity-no-target.txt"
grep -q 'free_lanes=unknown reason=no-target lanes=0 target=none' "$EVIDENCE/r2-capacity-no-target.txt"
printf 'kind=ship\n' > "$FM_HOME/state/ship.meta"
printf 'kind=scout\n' > "$FM_HOME/state/scout.meta"
printf 'kind=secondmate\n' > "$FM_HOME/state/mate.meta"
printf '4\n' > "$FM_HOME/config/lane-capacity"
printf '\n=== Two task lanes, one lane-free secondmate ===\n'
bin/fm-capacity.sh | tee "$EVIDENCE/r2-capacity-target.txt"
grep -q 'lanes=2 target=4 secondmates=1' "$EVIDENCE/r2-capacity-target.txt"
printf '4\n5\n' > "$FM_HOME/config/lane-capacity"
printf '\n=== Malformed capacity fails closed ===\n'
set +e
bin/fm-capacity.sh 2>&1 | tee "$EVIDENCE/r2-capacity-invalid.txt"
rc=${PIPESTATUS[0]}
set -e
printf 'exit=%s\n' "$rc"
[ "$rc" = 1 ]
rm "$FM_HOME/config/lane-capacity"
printf '\n=== Per-mate runtime pins ===\n'
printf 'claude sonnet high\nmate ops: codex gpt-5 high\nmate audit: default\n' > "$FM_HOME/config/secondmate-harness"
printf 'claude\n' > "$FM_HOME/config/crew-harness"
for id in ops audit other; do
  printf '%s: harness=%s model=%s effort=%s\n' "$id" "$(bin/fm-harness.sh secondmate "$id")" "$(bin/fm-harness.sh secondmate-model "$id")" "$(bin/fm-harness.sh secondmate-effort "$id")"
done
[ "$(bin/fm-harness.sh secondmate ops)" = codex ]
[ "$(bin/fm-harness.sh secondmate-model ops)" = gpt-5 ]
[ "$(bin/fm-harness.sh secondmate other)" = claude ]
[ -z "$(bin/fm-harness.sh secondmate-model audit)" ]
printf 'mate ops: claude\nmate ops: codex\n' > "$FM_HOME/config/secondmate-harness"
printf '\n=== Duplicate pin refuses unrelated mate too ===\n'
set +e
bin/fm-harness.sh secondmate unrelated
rc=$?
set -e
printf 'exit=%s\n' "$rc"
[ "$rc" = 1 ]
printf '\n=== Paseo ancestry does not select Paseo ===\n'
FM_BACKEND= PASEO_AGENT_ID=ancestor-agent PASEO_TERMINAL_ID=ancestor-terminal PASEO_WORKSPACE_ID=ancestor-workspace bash -c '. bin/fm-backend.sh; fm_backend_name'
printf '\n=== Explicit Paseo missing dependency fails before allocation ===\n'
rm "$FM_HOME/state/ship.meta" "$FM_HOME/state/scout.meta" "$FM_HOME/state/mate.meta"
bin/fm-brief.sh paseo-probe firstmate --scout
python3 - "$FM_HOME/data/paseo-probe/brief.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); p.write_text(p.read_text().replace('{TASK}', 'Validate unavailable backend refusal only.').replace('{FIRSTMATE_SPEC}', 'Do not allocate a terminal when the selected backend is unavailable.'))
PY
set +e
bin/fm-spawn.sh paseo-probe "$ROOT" --scout --harness claude --backend paseo
rc=$?
set -e
printf 'exit=%s metadata_created=%s\n' "$rc" "$([ -f "$FM_HOME/state/paseo-probe.meta" ] && echo yes || echo no)"
[ "$rc" != 0 ] && [ ! -f "$FM_HOME/state/paseo-probe.meta" ]
printf '\n=== Rendered ship/scout brief contracts ===\n'
bin/fm-brief.sh cli-ship example --mode local-only
bin/fm-brief.sh cli-scout example --scout
cp "$FM_HOME/data/cli-ship/brief.md" "$EVIDENCE/r2-generated-ship-brief.md"
cp "$FM_HOME/data/cli-scout/brief.md" "$EVIDENCE/r2-generated-scout-brief.md"
printf '\n=== NM home resolver with real read-only CLI ===\n'
mkdir -p "$FM_HOME/projects/cli-product" "$FM_HOME/nm-home"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
repo="$FM_HOME/projects/cli-product"
git -C "$repo" init -q -b fm/resolver-probe
git -C "$repo" -c user.name=Test -c user.email=test@example.invalid commit -q --allow-empty -m 'Disposable runtime probe'
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\n' "$FM_HOME/nm-home" > "$FM_HOME/resolver"
chmod +x "$FM_HOME/resolver"
printf '%s\n' "$FM_HOME/resolver" > "$FM_HOME/config/nm-home-resolver"
printf 'Selected SQLite home: '
bash -c '. bin/fm-nm-run-lib.sh; fm_nm_state_db "$1"' _ "$repo"
set +e
bash -c '. bin/fm-nm-run-lib.sh; fm_nm_run_bounded "$1" 15 axi status' _ "$repo"
rc=$?
set -e
printf 'NM read exit=%s; initializing a pipeline is outside this assigned phase\n' "$rc"
printf '\n=== Explicit NM_HOME overrides resolver ===\n'
mkdir -p "$FM_HOME/explicit-home"
NM_HOME="$FM_HOME/explicit-home" bash -c '. bin/fm-nm-run-lib.sh; fm_nm_state_db "$1"' _ "$repo"
