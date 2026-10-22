#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
export TMPDIR="$ROOT/.test-live/tmp" FM_BACKEND=tmux GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_DIR GIT_WORK_TREE
LAB=$(mktemp -d "$ROOT/.l.XXXXXX")
trap 'rm -rf "$LAB"' EXIT
bin/fm-lab-home.sh create "$LAB"
export FM_HOME="$LAB"
export HOME="$LAB/user-home"
mkdir -p "$HOME"
for p in iqx other; do
 mkdir -p "$LAB/projects/$p"
 git -C "$LAB/projects/$p" init -q -b main
 git -C "$LAB/projects/$p" config user.name 'Disposable validation'
 git -C "$LAB/projects/$p" config user.email 'test@example.invalid'
done
git -C "$LAB/projects/iqx" remote add origin https://bitbucket.org/iqxbusiness/disposable-validation.git
git -C "$LAB/projects/other" remote add origin https://example.invalid/other.git
printf '\n=== Install IQX hook in an isolated clone ===\n'
( cd "$LAB" && bash "$ROOT/contrib/iqx-ixia-hook/ixia-hook-install.sh" iqx )
( cd "$LAB" && bash "$ROOT/contrib/iqx-ixia-hook/ixia-hook-install.sh" iqx )
git -C "$LAB/projects/iqx" commit -q --allow-empty -m '#123 preserve fork hook' -m 'Reviewed-by: Human Reviewer <human@example.invalid>'
printf '\n=== Actual committed message ===\n'
git -C "$LAB/projects/iqx" log -1 --format=%B
msg=$(git -C "$LAB/projects/iqx" log -1 --format=%B)
[ "$(printf '%s\n' "$msg" | grep -Fc 'Co-Authored-By: Ixia Engineering (Claude) <noreply@anthropic.com>')" = 1 ]
printf '%s' "$msg" | grep -Fq 'Reviewed-by: Human Reviewer <human@example.invalid>'
printf '%s' "$msg" | grep -Fq '#123 preserve fork hook'
printf '\n=== Install refuses an unrelated origin without changing it ===\n'
set +e
( cd "$LAB" && bash "$ROOT/contrib/iqx-ixia-hook/ixia-hook-install.sh" other )
rc=$?
set -e
printf 'unrelated_origin_exit=%s hook_created=%s\n' "$rc" "$([ -f "$LAB/projects/other/.git/hooks/commit-msg" ] && echo yes || echo no)"
[ "$rc" = 1 ] && [ ! -f "$LAB/projects/other/.git/hooks/commit-msg" ]
printf '\n=== Emitted OMP supervision contract ===\n'
bin/fm-supervision-instructions.sh --harness omp > /home/node/.no-mistakes/evidence/01M5GMXRP8TEGYK8ZJPXTCW65Z/r2-generated-omp-instructions.txt
printf 'OMP supervision output captured; native OMP is not invoked.\n'
printf '\n=== Bitbucket credential refusal before a merge ===\n'
printf 'kind=ship\nworktree=%s\nproject=%s\npr=https://bitbucket.org/iqxbusiness/disposable-validation/pull-requests/1\n' "$LAB/projects/iqx" "$LAB/projects/iqx" > "$LAB/state/merge-probe.meta"
printf 'Disposable guard check\n' > "$LAB/merge-message.txt"
set +e
env -u NO_MISTAKES_BITBUCKET_EMAIL -u NO_MISTAKES_BITBUCKET_API_TOKEN "$ROOT/bin/fm-pr-merge.sh" merge-probe https://bitbucket.org/iqxbusiness/disposable-validation/pull-requests/1 --message-file "$LAB/merge-message.txt" -- --merge
rc=$?
set -e
printf 'no_credential_merge_exit=%s\n' "$rc"
[ "$rc" != 0 ]
