#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EVIDENCE=/home/node/.no-mistakes/evidence/01M4GAYTSCP6NAPPQR2V9325M0
export PATH="$ROOT/.v/tmux-3.6a:$PATH"
export TMPDIR="$ROOT/.v/tmp"
LAB="$ROOT/.v/h"
ID=prlab
PR=https://github.com/cli/cli/pull/1
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS
unset HERDR_ENV HERDR_SESSION HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH
unset TMUX TMUX_PANE FM_TASK_ID TASKS_AXI_FILE TASKS_AXI_BACKEND
unset CLAUDECODE FM_PI_HARNESS PI_CODING_AGENT FM_OMP_HARNESS
export FM_HOME="$LAB" FM_BACKEND=tmux
export HOME="$LAB/user" PI_CODING_AGENT_DIR="$LAB/pi" XDG_CONFIG_HOME="$LAB/user/config" XDG_CACHE_HOME="$LAB/user/cache" XDG_DATA_HOME="$LAB/user/data"
export GIT_CONFIG_GLOBAL="$ROOT/tests/git-fixture.gitconfig" GIT_CONFIG_NOSYSTEM=1
cleanup() {
  local rc=$?
  trap - EXIT
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server 2>/dev/null || true
  # Remove only the home-bound launch staging directory this test generated.
  launch_hash=$(printf '%s' "$LAB" | sha256sum | awk '{print $1}')
  rm -rf "/tmp/fm-$ID+$launch_hash"
  if [ -d "$LAB" ]; then chmod -R u+w "$LAB"; rm -rf "$LAB"; fi
  echo "Disposed lab home and private fm-lab tmux server (rc=$rc)."
  exit "$rc"
}
trap cleanup EXIT
bin/fm-lab-home.sh create "$LAB"
mkdir -p "$LAB/tmux" "$HOME" "$LAB/pi" "$LAB/data/$ID" "$LAB/projects/example"
printf 'tmux\n' > "$LAB/config/backend"
PROJECT="$LAB/projects/example"
WT="$LAB/wt"
git -C "$PROJECT" init -q
git -C "$PROJECT" -c user.name=Validation -c user.email=validation@example.invalid commit --allow-empty -qm seed
git -C "$PROJECT" worktree add -q -b "fm/$ID" "$WT"
printf '# Task\n## Captain\x27s intent\nPreserve the existing PR while replacing the worker.\n\n## Firstmate spec\nRemain idle. Do not modify files or run any project commands.\n' > "$LAB/data/$ID/brief.md"
# Run the actual installed Pi CLI, not a stand-in. No model request is needed
# to exercise replacement-process and metadata publication behavior.
TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab new-session -d -s primary -x 120 -y 40 -c "$WT" -e FM_HOME="$LAB" 'pi --offline --no-approve --no-extensions --no-context-files --no-mcp --no-skills --no-prompt-templates; exec bash --noprofile --norc'
TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab rename-window -t primary:0 "fm-$ID"
export TMUX="$(TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab display-message -p -t primary '#{socket_path},#{pid},0')"
{
  printf 'window=primary:fm-%s\nendpoint_task_id=%s\nworktree=%s\nproject=%s\nharness=pi\nkind=ship\nmode=no-mistakes\nyolo=off\nbranch=fm/%s\nmodel=default\neffort=default\n' "$ID" "$ID" "$WT" "$PROJECT" "$ID"
} > "$LAB/state/$ID.meta"
. "$ROOT/bin/fm-backend.sh"
. "$ROOT/bin/fm-pr-lib.sh"
. "$ROOT/bin/fm-trace-context-lib.sh"
for n in $(seq 1 30); do
  [ "$(fm_backend_agent_state tmux "primary:fm-$ID")" != alive ] || break
  sleep 1
done
[ "$(fm_backend_agent_state tmux "primary:fm-$ID")" = alive ]
echo 'Initial real Pi process: alive; terminal grid: 120x40.'
TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab capture-pane -p -t primary > "$EVIDENCE/live-initial-pane.txt"
echo "Registering existing public merged PR through fm-pr-check.sh: $PR"
bin/fm-pr-check.sh "$ID" "$PR"
# X fields are part of the owned metadata protocol, and may follow the PR pair.
printf 'x_request=prlab-request\nx_platform=validation\n' >> "$LAB/state/$ID.meta"
fm_pr_metadata_identity_parse "$LAB/state/$ID.meta"
HEAD_BEFORE=$(fm_meta_get "$LAB/state/$ID.meta" pr_head)
[ -n "$HEAD_BEFORE" ]
for trace in off on on-reused; do
  echo "=== Scenario: real worker relaunch, trace=$trace ==="
  actual_trace=$trace
  [ "$trace" != on-reused ] || actual_trace=on
  previous_carrier=$(fm_meta_get "$LAB/state/$ID.meta" traceparent)
  printf '%s\n' "$$" > "$LAB/state/.lock"
  printf '%s %s\n' "$$" "$actual_trace" > "$LAB/state/.trace-context-effective"
  export FM_TRACE_CONTEXT="$actual_trace"
  bin/fm-control.sh "$ID" relaunch --note "Resume monitoring the recorded PR; do not modify project files."
  fm_pr_metadata_identity_parse "$LAB/state/$ID.meta"
  [ "$FM_PR_META_URL" = "$PR" ]
  [ "$(fm_meta_get "$LAB/state/$ID.meta" pr_head)" = "$HEAD_BEFORE" ]
  [ "$(fm_meta_get "$LAB/state/$ID.meta" x_request)" = prlab-request ]
  [ -n "$(fm_meta_get "$LAB/state/$ID.meta" control_relaunch_tx)" ]
  if [ "$actual_trace" = on ]; then
    fm_trace_context_valid "$(fm_meta_get "$LAB/state/$ID.meta" traceparent)"
  fi
  if [ "$trace" = on-reused ]; then
    [ "$(fm_meta_get "$LAB/state/$ID.meta" traceparent)" = "$previous_carrier" ]
    [ "$(grep -c '^traceparent=' "$LAB/state/$ID.meta")" -eq 1 ]
    echo "Prior trace carrier was reused exactly once: $previous_carrier"
  fi
  fm_pr_poll_artifacts_content_valid "$LAB/state" "$ID" "$ROOT/bin/fm-pr-poll.sh"
  echo "PR identity and original authenticated poll remain valid: $FM_PR_META_URL, head=$HEAD_BEFORE"
  cp "$LAB/state/$ID.meta" "$EVIDENCE/live-$trace.meta"
  for n in $(seq 1 30); do
    screen=$(TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab capture-pane -p -t primary)
    case "$screen" in
      *'Trust project folder?'*)
        echo 'Accepting trust for this disposable fixture session only.'
        TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab send-keys -t primary Down Down Enter
        ;;
    esac
    [ "$(fm_backend_composer_state tmux "primary:fm-$ID")" != empty ] || break
    sleep 1
  done
  echo "Settled composer: $(fm_backend_composer_state tmux "primary:fm-$ID")"
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab capture-pane -p -t primary > "$EVIDENCE/live-$trace-pane.txt"
done
# Actively try the formerly rejected tail shape against the real watcher.
cp "$LAB/state/$ID.meta" "$LAB/state/meta.good"
printf 'control_relaunch_tx=adversarial-tail\n' >> "$LAB/state/$ID.meta"
if fm_pr_metadata_identity_parse "$LAB/state/$ID.meta"; then
  echo 'FAIL: malformed trailing transaction unexpectedly authenticated'; exit 1
fi
echo '=== Scenario: watcher refuses corrupted PR metadata ==='
FM_CHECK_INTERVAL=0 FM_POLL=0.1 FM_HEARTBEAT=999999 FM_SIGNAL_GRACE=0 timeout 40 bin/fm-watch.sh > "$EVIDENCE/live-corrupt-watch.log" 2>&1
# Persisted wake is the public watcher output contract.
python3 - "$EVIDENCE/live-corrupt-watch.log" <<'PY'
import sys
out=open(sys.argv[1]).read()
print(out,end='')
assert 'rejected unauthenticated state checks:' in out and 'prlab.check.sh' in out
PY
[ -f "$LAB/state/$ID.check.sh" ]
[ ! -e "$LAB/state/$ID.pr-poll-merge-notified" ]
# Restore the exact good persisted record and acknowledge the handled wake
# through the product's durable wake protocol, including recovery generation.
cp "$LAB/state/meta.good" "$LAB/state/$ID.meta"
bin/fm-wake-drain.sh > "$LAB/drain.out" 2> "$LAB/drain.err"
read -r sequence generation < <(python3 - "$LAB/drain.err" <<'PY'
import re,sys
out=open(sys.argv[1]).read()
m=re.search(r'WAKE_ACK_REQUIRED:.*--ack-through ([0-9]+) --recovery-generation ([A-Za-z0-9._-]+)',out)
assert m,out
print(m[1],m[2])
PY
)
bin/fm-wake-drain.sh --ack-through "$sequence" --recovery-generation "$generation"
echo '=== Scenario: watcher detects merge after relaunch without rearming ==='
FM_CHECK_INTERVAL=0 FM_POLL=0.1 FM_HEARTBEAT=999999 FM_SIGNAL_GRACE=0 timeout 40 bin/fm-watch.sh > "$EVIDENCE/live-merged-watch.log" 2>&1
python3 - "$EVIDENCE/live-merged-watch.log" "$LAB/state/.wake-queue" <<'PY'
import sys
out=open(sys.argv[1]).read()
wakes=open(sys.argv[2]).read()
print(out,end=''); print(wakes,end='')
assert 'prlab.check.sh: merged' in out
assert 'check: merge landed: prlab https://github.com/cli/cli/pull/1 external' in wakes
assert 'rejected unauthenticated' not in out
PY
[ ! -e "$LAB/state/$ID.check.sh" ]
[ ! -e "$LAB/state/$ID.pr-poll" ]
[ -f "$LAB/state/$ID.pr-poll-merge-notified" ]
cp "$LAB/state/.wake-queue" "$EVIDENCE/live-merge-wake.log"
cp "$LAB/state/$ID.pr-poll-merge-notified" "$EVIDENCE/live-merge-notified.txt"
echo 'Watcher observed the real GitHub merge, recorded the outcome, queued the wake, and retired the original poll.'
