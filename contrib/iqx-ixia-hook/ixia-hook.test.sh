#!/usr/bin/env bash
# ixia-hook.test.sh - behavior test for the fork-only Ixia hook scripts.
#
# Lives with the contrib folder on purpose: the repository's tests/ inventory
# and CI discover only tests/*.test.sh, and nothing here is wired into them.
# Run by hand: bash contrib/iqx-ixia-hook/ixia-hook.test.sh
# Lab repositories only, under a temporary root; no real clone is touched.
# shellcheck disable=SC2016 # the bash -c snippets are meant to expand inside the child shell.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=contrib/iqx-ixia-hook/ixia-hook-lib.sh
. "$here/ixia-hook-lib.sh"

INSTALL="$here/ixia-hook-install.sh"
VERIFY="$here/ixia-hook-verify.sh"
HOOK="$here/ixia-commit-msg-hook.sh"
IXIA='Co-Authored-By: Ixia Engineering (Claude) <noreply@anthropic.com>'
SHA=39c0d3c156f1b8ba404dcd5797874947b22c07e82ed06ff15f5f6837a19e8472

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ixia-hook-test.XXXXXX")
trap 'chmod -R u+w "$TMP" 2>/dev/null || true; rm -rf "$TMP"' EXIT

# Isolate git from the invoking environment (including a firstmate pane's
# command-scope hooks override, which individual cases re-add on purpose).
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_DIR GIT_WORK_TREE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=lab GIT_AUTHOR_EMAIL=lab@example.invalid
export GIT_COMMITTER_NAME=lab GIT_COMMITTER_EMAIL=lab@example.invalid

fails=0
pass() { echo "ok - $1"; }
fail() { echo "not ok - $1" >&2; fails=$((fails + 1)); }
check() { # check <description> <command...>
  local d=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
check_not() {
  local d=$1
  shift
  if "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}

new_home() { mkdir -p "$TMP/$1/projects"; echo "$TMP/$1"; }
new_clone() { # new_clone <home> <name> <origin-url>
  local c="$1/projects/$2"
  git init -q "$c"
  git -C "$c" remote add origin "$3"
  git -C "$c" commit -q --allow-empty -m "init"
}
hook_of() { echo "$1/projects/$2/.git/hooks/commit-msg"; }

check "bundled hook has the approved sha256" test "$(ixia_sha256 "$HOOK")" = "$SHA"

for s in "$INSTALL" "$VERIFY"; do
  check "$(basename "$s") --help exits 0" bash "$s" --help
  rc=0
  bash "$s" >/dev/null 2>&1 || rc=$?
  check "$(basename "$s") without projects exits 2" test "$rc" = 2
  for option in --home --home="$TMP"; do
    rc=0
    bash "$s" "$option" "$TMP" iqxa >/dev/null 2>&1 || rc=$?
    check "$(basename "$s") rejects $option (exit 2)" test "$rc" = 2
  done
done

# --- install -----------------------------------------------------------------
H=$(new_home h1)
new_clone "$H" iqxa 'git@bitbucket.org:iqxbusiness/iqxa.git'
new_clone "$H" iqxb 'https://bitbucket.org/IQXBusiness/iqxb.git'
new_clone "$H" gh 'git@github.com:someone/gh.git'
new_clone "$H" other 'git@bitbucket.org:otherorg/x.git'
mkdir -p "$H/projects/plain"

out=$(cd "$H" && bash "$INSTALL" iqxa iqxb) && rc=0 || rc=$?
check "install two IQX clones exits 0" test "$rc" = 0
check "install reports installed" grep -q '^installed iqxa ' <<<"$out"
check "hook installed with approved bytes" cmp -s "$HOOK" "$(hook_of "$H" iqxa)"
check "hook installed mode 755" test "$(stat -c %a "$(hook_of "$H" iqxa)" 2>/dev/null || stat -f %Lp "$(hook_of "$H" iqxa)")" = 755
check "mixed-case org clone installed" test -x "$(hook_of "$H" iqxb)"

out=$(cd "$H" && bash "$INSTALL" iqxa) && rc=0 || rc=$?
check "reinstall is idempotent (exit 0, unchanged)" bash -c '[ "$1" = 0 ] && grep -q "^unchanged iqxa " <<<"$2"' _ "$rc" "$out"

for p in gh other plain missing; do
  rc=0
  out=$(cd "$H" && bash "$INSTALL" "$p") || rc=$?
  check "install refuses $p (exit 1, STOP)" bash -c '[ "$1" = 1 ] && grep -q "^STOP $2:" <<<"$3"' _ "$rc" "$p" "$out"
done
check_not "refused clone got no hook" test -e "$(hook_of "$H" gh)"
check_not "refused plain dir got no hooks" test -e "$H/projects/plain/.git"

# one refusal does not stop the others, and the exit code reflects it
H2=$(new_home h2)
new_clone "$H2" iqxa 'git@bitbucket.org:iqxbusiness/iqxa.git'
new_clone "$H2" gh 'git@github.com:someone/gh.git'
rc=0
(cd "$H2" && bash "$INSTALL" gh iqxa) >/dev/null 2>&1 || rc=$?
check "mixed run exits 1" test "$rc" = 1
check "mixed run still installs the good clone" cmp -s "$HOOK" "$(hook_of "$H2" iqxa)"

# unrelated existing commit-msg is never clobbered
H3=$(new_home h3)
new_clone "$H3" iqxa 'git@bitbucket.org:iqxbusiness/iqxa.git'
printf '#!/bin/sh\necho mine\n' >"$(hook_of "$H3" iqxa)"
chmod 755 "$(hook_of "$H3" iqxa)"
before=$(ixia_sha256 "$(hook_of "$H3" iqxa)")
rc=0
out=$(cd "$H3" && bash "$INSTALL" iqxa) || rc=$?
check "unrelated commit-msg refused" bash -c '[ "$1" = 1 ] && grep -q "^STOP iqxa:" <<<"$2"' _ "$rc" "$out"
check "unrelated commit-msg left unchanged" test "$(ixia_sha256 "$(hook_of "$H3" iqxa)")" = "$before"

printf '#!/bin/sh\n# ixia-commit-msg-hook v0\nexit 0\n' >"$TMP/marked-hook"
cp "$TMP/marked-hook" "$(hook_of "$H3" iqxa)"
out=$(cd "$H3" && bash "$INSTALL" iqxa) && rc=0 || rc=$?
check "differing version-marked hook refused" bash -c '[ "$1" = 1 ] && grep -q "^STOP iqxa:" <<<"$2"' _ "$rc" "$out"
check "version-marked hook left unchanged" cmp -s "$TMP/marked-hook" "$(hook_of "$H3" iqxa)"

# a non-executable identical copy gets its mode fixed
cp "$HOOK" "$(hook_of "$H3" iqxa)"
chmod 644 "$(hook_of "$H3" iqxa)"
(cd "$H3" && bash "$INSTALL" iqxa) >/dev/null
check "install repairs a 644 copy" test -x "$(hook_of "$H3" iqxa)"

# repository core.hooksPath is refused
H4=$(new_home h4)
new_clone "$H4" iqxa 'git@bitbucket.org:iqxbusiness/iqxa.git'
git -C "$H4/projects/iqxa" config core.hooksPath .githooks
rc=0
out=$(cd "$H4" && bash "$INSTALL" iqxa) || rc=$?
check "repository core.hooksPath refused" bash -c '[ "$1" = 1 ] && grep -q "core.hooksPath" <<<"$2"' _ "$rc" "$out"
check_not "nothing written for hooksPath clone" test -e "$(hook_of "$H4" iqxa)"

# a firstmate-pane style command-scope override must not redirect the install
H5=$(new_home h5)
new_clone "$H5" iqxa 'git@bitbucket.org:iqxbusiness/iqxa.git'
mkdir -p "$TMP/pane-hooks"
(cd "$H5" && GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0="$TMP/pane-hooks" \
  GIT_CONFIG_KEY_1=user.name GIT_CONFIG_VALUE_1=pane bash "$INSTALL" iqxa) >/dev/null
check "install ignores the pane hooks override" cmp -s "$HOOK" "$(hook_of "$H5" iqxa)"
check_not "pane hooks directory untouched" test -e "$TMP/pane-hooks/commit-msg"

# --- verify ------------------------------------------------------------------
git -C "$H/projects/iqxa" worktree add -q "$TMP/slot1" -b slot1
git -C "$H/projects/iqxa" worktree add -q "$TMP/slot2" -b slot2
head_before=$(git -C "$H/projects/iqxa" rev-parse HEAD)
reflog_before=$(git -C "$H/projects/iqxa" reflog --all | wc -l)
objs_before=$(git -C "$H/projects/iqxa" count-objects | tr -d '\n')

out=$(cd "$H" && bash "$VERIFY" iqxa iqxb) && rc=0 || rc=$?
check "verify passes installed clones" test "$rc" = 0
check "verify counts worktrees sharing the hook" grep -q '^ok iqxa (3 worktrees share ' <<<"$out"
check "verify leaves real clone untouched" test \
  "$(git -C "$H/projects/iqxa" rev-parse HEAD)" = "$head_before" -a \
  "$(git -C "$H/projects/iqxa" reflog --all | wc -l)" = "$reflog_before" -a \
  "$(git -C "$H/projects/iqxa" count-objects | tr -d '\n')" = "$objs_before"
check "verify works from a pane-style override" bash -c \
  'cd "$2" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0="$3" bash "$1" iqxa' _ "$VERIFY" "$H" "$TMP/pane-hooks"

for p in gh other plain; do
  rc=0
  out=$(cd "$H" && bash "$VERIFY" "$p") || rc=$?
  check "verify fails $p" bash -c '[ "$1" = 1 ] && grep -q "^FAIL $2:" <<<"$3"' _ "$rc" "$p" "$out"
done

H6=$(new_home h6)
new_clone "$H6" none 'git@bitbucket.org:iqxbusiness/none.git'
out=$(cd "$H6" && bash "$VERIFY" none) && rc=0 || rc=$?
check "verify fails a missing hook" bash -c '[ "$1" = 1 ] && grep -q "hook missing" <<<"$2"' _ "$rc" "$out"

chmod 644 "$(hook_of "$H" iqxb)"
out=$(cd "$H" && bash "$VERIFY" iqxb) && rc=0 || rc=$?
check "verify fails a 644 hook" bash -c '[ "$1" = 1 ] && grep -q "not 755" <<<"$2"' _ "$rc" "$out"
chmod 755 "$(hook_of "$H" iqxb)"

printf '\n# local edit\n' >>"$(hook_of "$H" iqxb)"
out=$(cd "$H" && bash "$VERIFY" iqxb) && rc=0 || rc=$?
check "verify fails an altered hook" bash -c '[ "$1" = 1 ] && grep -q "differs" <<<"$2"' _ "$rc" "$out"

git -C "$H/projects/iqxa" config core.hooksPath .githooks
out=$(cd "$H" && bash "$VERIFY" iqxa) && rc=0 || rc=$?
check "verify fails a hooksPath clone" bash -c '[ "$1" = 1 ] && grep -q "core.hooksPath" <<<"$2"' _ "$rc" "$out"
git -C "$H/projects/iqxa" config --unset core.hooksPath

# --- the installed hook itself, through a real commit in a lab clone -----------
C="$H5/projects/iqxa"
git -C "$C" commit -q --allow-empty -m 'IQX-1: plain'
check "plain commit ends with exactly one Ixia line" bash -c \
  '[ "$(git -C "$1" log -1 --format=%B | sed "/^\$/d" | tail -n 1)" = "$2" ] && [ "$(git -C "$1" log -1 --format=%B | grep -cxF "$2")" = 1 ]' _ "$C" "$IXIA"
git -C "$C" commit -q --allow-empty -m 'IQX-2: typed' -m "$IXIA"
check "typed Ixia line is not duplicated" test "$(git -C "$C" log -1 --format=%B | grep -cxF "$IXIA")" = 1
git -C "$C" commit -q --allow-empty --no-verify -m 'IQX-3: skipped'
check_not "--no-verify skips the hook (documented gap)" bash -c 'git -C "$1" log -1 --format=%B | grep -qxF "$2"' _ "$C" "$IXIA"

echo
if [ "$fails" -ne 0 ]; then
  echo "$fails check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
