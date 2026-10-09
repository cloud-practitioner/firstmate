#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M4H5KP1VG2X9YFP5CNNAPNGA
unset FM_HOME FM_BACKEND FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITLAB_TOKEN
export TMPDIR="$ROOT/.test-phase/tmp"
mkdir -p "$TMPDIR"
. tests/git-config-helpers.sh
ambient="$ROOT/.test-phase/ambient"
linked="$ROOT/.test-phase/linked"
cleanup() { rm -rf "$linked" "$ambient"; }
trap cleanup EXIT
mkdir -p "$ambient"
git -C "$ambient" init -q -b main
printf 'DISPOSABLE_AMBIENT_SENTINEL\n' > "$ambient/sentinel.txt"
git -C "$ambient" add sentinel.txt
git -C "$ambient" -c user.name=Live-validation -c user.email=validation@example.invalid commit -q -m 'ambient baseline'
git -C "$ambient" worktree add -q --detach "$linked" main
snapshot() {
  git -C "$ambient" for-each-ref --format='%(refname) %(objectname)'
  git -C "$ambient" worktree list --porcelain
  git -C "$ambient" ls-files --stage
  git -C "$linked" ls-files --stage
  sha256sum "$ambient/sentinel.txt" "$linked/sentinel.txt"
}
snapshot > "$EVIDENCE/git-ambient-before.txt"
gitdir=$(git -C "$linked" rev-parse --absolute-git-dir)
index=$(git -C "$linked" rev-parse --path-format=absolute --git-path index)
common=$(git -C "$linked" rev-parse --path-format=absolute --git-common-dir)
printf 'Running the real fixture runner with ALL inherited repository locations simultaneously set:\nGIT_DIR=%s\nGIT_WORK_TREE=%s\nGIT_INDEX_FILE=%s\nGIT_COMMON_DIR=%s\n' "$gitdir" "$linked" "$index" "$common"
rc=0
env GIT_DIR="$gitdir" GIT_WORK_TREE="$linked" GIT_INDEX_FILE="$index" GIT_COMMON_DIR="$common" \
  bin/fm-test-run.sh --jobs 1 --per-script-timeout-secs 180 tests/fm-test-fixtures.test.sh || rc=$?
snapshot > "$EVIDENCE/git-ambient-after.txt"
diff -u "$EVIDENCE/git-ambient-before.txt" "$EVIDENCE/git-ambient-after.txt"
printf 'real runner exit=%s; ambient refs, both indexes, worktree registrations, and sentinel bytes unchanged\n' "$rc"
[ "$rc" -eq 0 ]
