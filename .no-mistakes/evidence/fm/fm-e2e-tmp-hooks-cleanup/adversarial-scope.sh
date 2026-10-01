#!/usr/bin/env bash
# Adversarial check: fm_test_remove_spawn_launch_dirs only removes launch dirs
# whose hash matches a home under the fixture root; others survive; a symlinked
# root is refused; nested homes are found.
set -u
ROOT=$1
. "$ROOT/tests/fixture-tree-helpers.sh"
fx=$(mktemp -d /tmp/fm-adv-fixture.XXXXXX)
other=$(mktemp -d /tmp/fm-adv-other.XXXXXX)
mkdir -p "$fx/home/state" "$fx/nested/sm/state" "$other/state"
h_own=$(fm_test_home_hash "$fx/home"); h_nested=$(fm_test_home_hash "$fx/nested/sm"); h_other=$(fm_test_home_hash "$other")
own="/tmp/fm-advtask$$+$h_own"; nested="/tmp/fm-advtask$$+$h_nested"; foreign="/tmp/fm-advtask$$+$h_other"
mkdir -p "$own/locked" "$nested" "$foreign"; chmod 500 "$own/locked"
# symlinked root pointing at fixture: must be a no-op
ln -s "$fx" /tmp/fm-adv-link$$
fm_test_remove_spawn_launch_dirs /tmp/fm-adv-link$$
[ -d "$own" ] && echo "PASS symlinked root is refused (own launch dir still present)" || echo "FAIL symlinked root followed"
rm -f /tmp/fm-adv-link$$
fm_test_remove_spawn_launch_dirs "$fx"; rc=$?
echo "helper rc=$rc"
[ ! -e "$own" ] && echo "PASS own-home launch dir (with read-only child) removed" || echo "FAIL own launch dir left: $own"
[ ! -e "$nested" ] && echo "PASS nested secondmate-home launch dir removed" || echo "FAIL nested launch dir left"
[ -d "$foreign" ] && echo "PASS foreign-home launch dir untouched: $foreign" || echo "FAIL foreign launch dir removed"
fm_test_remove_tree "$fx"; [ ! -e "$fx" ] && echo "PASS fixture tree removed"
rm -rf "$foreign" "$other"
