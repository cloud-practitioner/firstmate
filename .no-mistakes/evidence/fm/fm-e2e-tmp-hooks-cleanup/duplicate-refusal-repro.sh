#!/usr/bin/env bash
# Deterministic repro of the presentation-e2e duplicate-refusal flake: a 2s
# delay stands in for machine load between report-agent and recovery.
set -u
ROOT=$1; H="$ROOT/bin/fm-herdr-lab.sh"
. "$ROOT/bin/backends/herdr.sh"
S=$("$H" name duprepro); "$H" provision "$S" >/dev/null || exit 1
export HERDR_SESSION=$S
lab() { "$H" run "$S" "$@"; }
st=$(mktemp -d /tmp/fm-duprepro.XXXXXX)
for variant in shell-only foreground-process; do
  id="dup-$variant"
  tok=$(fm_backend_herdr_projection_journal_create "$st" "$id")
  j=$(fm_backend_herdr_projection_journal_path "$st" "$id")
  d1=$(lab workspace create --cwd /tmp --label "firstmate/$id · p:$tok" --no-focus)
  lab workspace create --cwd /tmp --label "copy/$id · p:$tok" --no-focus >/dev/null
  p=$(printf '%s' "$d1" | jq -r '.result.root_pane.pane_id')
  if [ "$variant" = foreground-process ]; then
    lab pane run "$p" "sleep 600" >/dev/null
    for _ in $(seq 1 100); do [ "$(fm_backend_herdr_pane_process_state_sample "$S" "$p")" = other ] && break; sleep 0.1; done
  fi
  lab pane report-agent "$p" --source fm-projection-e2e --agent test-agent --state idle >/dev/null
  sleep 2
  if fm_backend_herdr_projection_recovery_allows_flat "$S" "$j" "$id" 2>/dev/null; then
    echo "$variant: recovery ALLOWED flat fallback (the test's 'should refuse' assertion fails)"
  else
    echo "$variant: recovery REFUSED duplicate launch (the test's assertion holds)"
  fi
done
rm -rf "$st"; "$H" teardown "$S" && echo "lab $S torn down"
