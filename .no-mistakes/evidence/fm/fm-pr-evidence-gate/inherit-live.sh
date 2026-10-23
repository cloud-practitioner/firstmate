#!/usr/bin/env bash
set -eu
ROOT=$PWD
LAB="$ROOT/.test-evidence-lab"
E=/home/node/.no-mistakes/evidence/01M5K1MGANF7V1TVEJY6VCTM5Y
SRC="$LAB/home"
DST="$LAB/child"
mkdir -p "$DST/config" "$DST/data" "$DST/state"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null TMPDIR="$LAB/tmp"
unset FM_INHERITABLE_CONFIG
printf 'config/\ndata/\nstate/\n' > "$DST/.gitignore"
git -C "$DST" init -q
FM_CONFIG_INHERIT_REPORT="$LAB/inheritance.tsv"
export FM_CONFIG_INHERIT_REPORT
: > "$FM_CONFIG_INHERIT_REPORT"
. "$ROOT/bin/fm-config-inherit-lib.sh"
propagate_inheritable_config "$SRC/config" "$DST/config" "$SRC"
printf '%s\n' 'Policy copied to the new child home:'
python3 - "$SRC/config/pr-evidence" "$DST/config/pr-evidence" <<'PY'
import pathlib,sys
src,dst=map(pathlib.Path,sys.argv[1:])
assert src.read_bytes()==dst.read_bytes()
print(dst.read_text())
PY
printf '%s\n' 'Fresh CLI process uses inherited enforcement:'
FM_HOME="$DST" FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$DST/state" FM_CONFIG_OVERRIDE="$DST/config" "$ROOT/bin/fm-pr-evidence.sh" eligible project direct-PR none "$LAB/project"
# Discard runtime state only, then start a new command from the unchanged code root.
rm -rf "$DST/state"
mkdir -p "$DST/state"
printf '# Task\n## Evidence class\n{EVIDENCE}\n' > "$LAB/restart-brief.md"
rc=0
FM_HOME="$DST" FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$DST/state" FM_CONFIG_OVERRIDE="$DST/config" "$ROOT/bin/fm-pr-evidence.sh" intake "$LAB/restart-brief.md" project direct-PR none "$LAB/project" || rc=$?
[ "$rc" = 1 ]
printf 'Fresh CLI refusal after runtime state reset: exit %s\n' "$rc"
# An idempotent re-push leaves the durable policy intact.
propagate_inheritable_config "$SRC/config" "$DST/config" "$SRC"
cmp "$SRC/config/pr-evidence" "$DST/config/pr-evidence"
printf 'Inherited durable policy remains byte-identical. No live agent or fleet was launched.\n'
