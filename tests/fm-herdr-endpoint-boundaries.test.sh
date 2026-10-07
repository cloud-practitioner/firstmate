#!/usr/bin/env bash
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"
. "$(dirname "${BASH_SOURCE[0]}")/herdr-test-safety.sh"
command -v jq >/dev/null 2>&1 || { echo 'skip: jq not found'; exit 0; }
herdr_forget_inherited_pane
TMP_ROOT=$(fm_test_tmproot fm-herdr-boundaries)

write_proc() {
  mkdir -p "$1/$2" "$1/sys/kernel/random"
  printf '%s (sh) S 1 %s %s 0 -1 4194304 100 0 0 0 0 0 0 0 20 0 1 0 %s 1000 100 18446744073709551615\n' \
    "$2" "$2" "$2" "$3" > "$1/$2/stat"
  printf '3f2a9c1e-0000-4000-8000-0123456789ab\n' > "$1/sys/kernel/random/boot_id"
}

write_pane() {
  local pane=$1 pid=$2 cwd=$3 agent=${4:-pi} key=${1//:/_} ws=${1%%:*}
  jq -n --arg pane "$pane" --arg tab "$ws:t${pane##*:p}" --arg ws "$ws" --arg cwd "$cwd" \
    '{result:{pane:{pane_id:$pane,tab_id:$tab,workspace_id:$ws,cwd:$cwd,foreground_cwd:$cwd}}}' > "$FM_FAKE_WORLD/pane-$key.json"
  jq -n --arg pane "$pane" --argjson pid "$pid" \
    '{result:{type:"pane_process_info",process_info:{pane_id:$pane,shell_pid:$pid}}}' > "$FM_FAKE_WORLD/process-$key.json"
  jq -n --arg agent "$agent" '{result:{agent:{agent:$agent,agent_status:"idle"}}}' > "$FM_FAKE_WORLD/agent-$key.json"
  printf '' > "$FM_FAKE_WORLD/composer-$key"
}

setup_world() {
  local dir=$1
  export FM_FAKE_WORLD="$dir/world" FM_HOME="$dir/home" FM_STATE_OVERRIDE="$dir/home/state" FM_PROC_ROOT_OVERRIDE="$dir/proc"
  mkdir -p "$FM_FAKE_WORLD" "$FM_STATE_OVERRIDE" "$dir/fakebin"
  write_proc "$FM_PROC_ROOT_OVERRIDE" 42 7000
  write_proc "$FM_PROC_ROOT_OVERRIDE" 43 7100
  cat > "$dir/fakebin/herdr" <<'SH'
#!/usr/bin/env bash
w=$FM_FAKE_WORLD
pane=${3:-}; key=${pane//:/_}
case "${1:-} ${2:-}" in
  'status --json') printf '{"client":{"version":"0.9.3","protocol":22},"server":{"running":true}}\n' ;;
  'server '*) ;;
  'session list') printf '{"sessions":[{"name":"fmtest","running":true,"socket_path":"%s/fmtest.sock"}]}\n' "$w" ;;
  'workspace list') cat "$w/workspaces.json" ;;
  'workspace get') printf '{"result":{"workspace":{"workspace_id":"w1","label":"firstmate"}}}\n' ;;
  'pane get') cat "$w/pane-$key.json" 2>/dev/null || { printf '{"error":{"code":"pane_not_found"}}\n'; exit 1; } ;;
  'pane process-info') key=${4//:/_}; cat "$w/process-$key.json" ;;
  'agent get') cat "$w/agent-$key.json" ;;
  'pane list') cat "$w/panes.json" ;;
  'tab list') printf '{"result":{"tabs":[]}}\n' ;;
  'tab get') printf '{"result":{"tab":{"tab_id":"%s","workspace_id":"%s","label":"fm-mine"}}}\n' "$pane" "${pane%%:*}" ;;
  'tab create')
    printf '{"result":{"tab":{"tab_id":"w1:t3","workspace_id":"w1"},"root_pane":{"pane_id":"w1:p3"}}}\n'
    ;;
  'pane read')
    printf '%s\n' "$pane" >> "$w/reads"
    printf '❯ %s\n' "$(cat "$w/composer-$key")"
    ;;
  'pane send-text')
    printf '%s %s\n' "$pane" "$2" >> "$w/inputs"
    printf '%s' "$4" > "$w/composer-$key"
    : > "$w/typed"
    ;;
  'pane send-keys'|'pane run'|'pane close'|'tab close')
    printf '%s %s %s\n' "$pane" "$2" "${4:-}" >> "$w/inputs"
    if [ "$2" = close ] && [ "${FM_CLOSE_REMOVES:-0}" = 1 ]; then
      rm -f "$w/pane-$key.json" "$w/process-$key.json" "$w/agent-$key.json"
    fi
    if [ "$2" = send-keys ] && [ "${4:-}" = enter ]; then
      : > "$w/entered"
      [ "${FM_KEEP_COMPOSER:-0}" = 1 ] || : > "$w/composer-$key"
    fi
    ;;
esac
SH
  chmod +x "$dir/fakebin/herdr"
  export PATH="$dir/fakebin:$PATH"
  printf '{"result":{"workspaces":[{"workspace_id":"w1","label":"firstmate","active_tab_id":"w1:t1","focused":true}]}}\n' > "$FM_FAKE_WORLD/workspaces.json"
  printf '{"result":{"panes":[]}}\n' > "$FM_FAKE_WORLD/panes.json"
  : > "$FM_FAKE_WORLD/inputs"; : > "$FM_FAKE_WORLD/reads"
  . "$ROOT/bin/fm-backend.sh"
  fm_backend_source herdr
  export FM_BACKEND_HERDR_SUBMIT_MIN_SLEEP=0 FM_BACKEND_HERDR_SUBMIT_POLLS=1
}

bind_mine() {
  printf 'backend=herdr\nwindow=fmtest:w1:p1\nherdr_process_identity=proc:42:3f2a9c1e-0000-4000-8000-0123456789ab:7000\n' > "$FM_STATE_OVERRIDE/mine.meta"
  printf 'backend=herdr\nwindow=fmtest:w1:p1\nherdr_process_identity=proc:43:3f2a9c1e-0000-4000-8000-0123456789ab:7100\n' > "$FM_STATE_OVERRIDE/other.meta"
}

reset_pane() {
  cp "$FM_FAKE_WORLD/reads" "$FM_FAKE_WORLD/reads-at-reset"
  write_pane w1:p1 43 "$FM_HOME" claude
  printf 'foreign draft' > "$FM_FAKE_WORLD/composer-w1_p1"
}

test_dispatch_boundaries() {
  local op out
  for op in capture visible key busy composer; do
    (
      setup_world "$TMP_ROOT/dispatch-$op"
      write_pane w1:p1 42 "$FM_HOME" claude
      bind_mine
      fm_backend_herdr_server_ensure() {
        local n=0
        [ ! -f "$FM_FAKE_WORLD/ready-count" ] || read -r n < "$FM_FAKE_WORLD/ready-count"
        n=$((n + 1)); printf '%s\n' "$n" > "$FM_FAKE_WORLD/ready-count"
        [ "$n" -ne 2 ] || reset_pane
        return 0
      }
      case "$op" in
        capture) ! fm_backend_capture herdr fmtest:w1:p1 5 fm-mine || fail 'capture crossed a reset' ;;
        visible) ! fm_backend_visible_capture herdr fmtest:w1:p1 fm-mine || fail 'viewport crossed a reset' ;;
        key) ! fm_backend_send_key herdr fmtest:w1:p1 C-u fm-mine || fail 'key crossed a reset' ;;
        busy) out=$(fm_backend_busy_state herdr fmtest:w1:p1 fm-mine); [ "$out" = unknown ] || fail "busy borrowed foreign state: $out" ;;
        composer) out=$(fm_backend_composer_state herdr fmtest:w1:p1 fm-mine); [ "$out" = unknown ] || fail "composer borrowed foreign state: $out" ;;
      esac
      [ ! -s "$FM_FAKE_WORLD/inputs" ] && [ ! -s "$FM_FAKE_WORLD/reads" ] || fail "$op reached the replacement pane"
    ) || fail "$op boundary regression"
  done
  pass 'dispatchers revalidate the selected binding at their internal boundary'
}

test_submit_boundaries() {
  local agent phase out keys
  for agent in claude pi; do
    for phase in ordinary settle confirm; do
      (
        setup_world "$TMP_ROOT/submit-$agent-$phase"
        write_pane w1:p1 42 "$FM_HOME" "$agent"
        bind_mine
        export FM_KEEP_COMPOSER=0
        [ "$phase" != confirm ] || export FM_KEEP_COMPOSER=1
        sleep() {
          case "$phase" in
            settle) [ ! -f "$FM_FAKE_WORLD/typed" ] || reset_pane ;;
            confirm) [ ! -f "$FM_FAKE_WORLD/entered" ] || reset_pane ;;
          esac
        }
        out=$(fm_backend_send_text_submit herdr fmtest:w1:p1 payload 2 0 0 fm-mine) || fail 'submit call failed'
        keys=$(grep -c 'send-keys' "$FM_FAKE_WORLD/inputs" || true)
        case "$phase" in
          ordinary) [ "$out" = empty ] && [ "$keys" = 1 ] || fail "ordinary $agent submit regressed: $out / $keys" ;;
          settle) [ "$out" != empty ] && [ "$keys" = 0 ] || fail "settle reset submitted or erased a foreign draft: $out / $keys" ;;
          confirm) [ "$out" = unknown ] && [ "$keys" = 1 ] || fail "confirmation reset borrowed foreign delivery or retried Enter: $out / $keys" ;;
        esac
        if [ "$phase" != ordinary ]; then
          [ "$(cat "$FM_FAKE_WORLD/composer-w1_p1")" = 'foreign draft' ] || fail 'foreign draft was modified'
          cmp -s "$FM_FAKE_WORLD/reads" "$FM_FAKE_WORLD/reads-at-reset" || fail 'submit read the replacement pane'
        fi
      ) || fail "$agent/$phase submit regression"
    done
  done
  pass 'submit settlement and confirmation resets neither read nor modify foreign drafts'
}

test_identity_requires_boot_and_ticks() {
  (
    setup_world "$TMP_ROOT/identity"
    write_pane w1:p1 42 "$FM_HOME"
    cat > "$TMP_ROOT/identity/fakebin/ps" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${FM_LSTART:-Wed Oct  7 02:03:32 2026}"
SH
    chmod +x "$TMP_ROOT/identity/fakebin/ps"
    local boot identity
    for boot in missing empty malformed; do
      case "$boot" in
        missing) rm -f "$FM_PROC_ROOT_OVERRIDE/sys/kernel/random/boot_id" ;;
        empty) : > "$FM_PROC_ROOT_OVERRIDE/sys/kernel/random/boot_id" ;;
        malformed) printf '%s\n' '-' > "$FM_PROC_ROOT_OVERRIDE/sys/kernel/random/boot_id" ;;
      esac
      identity=$(fm_backend_herdr_pane_process_identity fmtest w1:p1) || fail 'fallback identity unreadable'
      [ "$identity" = 'ps:42:Wed Oct  7 02:03:32 2026' ] || fail "$boot boot id produced a partial proc identity"
      FM_LSTART='Wed Oct  7 02:03:31 2026' fm_backend_herdr_identity_matches fmtest w1:p1 "$identity" || fail 'fallback rejected negative drift'
      FM_LSTART='Wed Oct  7 02:03:33 2026' fm_backend_herdr_identity_matches fmtest w1:p1 "$identity" || fail 'fallback rejected positive drift'
      ! fm_backend_herdr_identity_matches fmtest w1:p1 'proc:42:-:7000' || fail 'partial proc binding was accepted'
    done
    write_proc "$FM_PROC_ROOT_OVERRIDE" 42 7000
    identity=$(fm_backend_herdr_pane_process_identity fmtest w1:p1)
    [ "$identity" = 'proc:42:3f2a9c1e-0000-4000-8000-0123456789ab:7000' ] || fail 'complete proc identity regressed'
  ) || fail 'two-format identity regression'
  pass 'missing boot identity uses drift-tolerant ps, never partial proc'
}

test_teardown_preserves_foreign_processes() {
  local scenario
  for scenario in flat projected descendants descendant-process; do
    (
      local dir="$TMP_ROOT/teardown-$scenario" wt proj mate out pid state target
      setup_world "$dir"
      wt="$dir/wt"; proj="$dir/project"; state="$FM_STATE_OVERRIDE"; target=w1:p1
      fm_git_worktree "$proj" "$wt" foreign-worker
      mkdir -p "$FM_HOME/data" "$FM_HOME/config" "$dir/user-home"
      (cd "$wt" && exec sleep 300) & pid=$!
      trap 'kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null || true' EXIT
      write_proc "$FM_PROC_ROOT_OVERRIDE" "$pid" 7200
      write_pane "$target" "$pid" "$wt"
      if [ "$scenario" = descendants ]; then
        mate="$dir/mate"; mkdir -p "$mate/state" "$mate/data" "$mate/config"
        printf 'mine\n' > "$mate/.fm-secondmate-home"
        fm_write_meta "$state/mine.meta" backend=herdr window=fmtest:w1:p2 endpoint_task_id=mine \
          "worktree=$mate" "project=$mate" "home=$mate" kind=secondmate harness=pi mode=secondmate yolo=off \
          herdr_session=fmtest herdr_workspace_id=w1 herdr_tab_id=w1:t2 herdr_pane_id=w1:p2 \
          'herdr_process_identity=proc:42:3f2a9c1e-0000-4000-8000-0123456789ab:7000'
        write_pane w1:p2 43 "$dir/unrelated"
        state="$mate/state"
      fi
      fm_write_meta "$state/mine.meta" backend=herdr window=fmtest:w1:p1 endpoint_task_id=mine \
        "worktree=$wt" "project=$proj" kind=scout harness=pi \
        herdr_session=fmtest herdr_workspace_id=w1 herdr_tab_id=w1:t1 herdr_pane_id=w1:p1 \
        'herdr_process_identity=proc:42:3f2a9c1e-0000-4000-8000-0123456789ab:7000'
      if [ "$scenario" = descendant-process ]; then
        write_pane w1:p1 "$BASHPID" "$dir/unrelated"
        write_proc "$FM_PROC_ROOT_OVERRIDE" "$BASHPID" 7300
      fi
      if [ "$scenario" = projected ]; then
        local token
        token=$(fm_backend_herdr_projection_journal_create "$state" mine) || fail 'journal creation failed'
        fm_backend_herdr_projection_journal_bind "$state/mine.herdr-presentation" mine "$FM_HOME" fmtest \
          w1 w1:t1 w1:p1 w2 firstmate "└ mine · p:$token" fm-mine || fail 'journal binding failed'
      fi
      cat > "$dir/fakebin/lsof" <<'SH'
#!/usr/bin/env bash
printf 'p%s\nfcwd\nn%s\n' "$FM_FOREIGN_PID" "$FM_FOREIGN_WT"
SH
      cat > "$dir/fakebin/treehouse" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FM_FAKE_WORLD/returns"
SH
      chmod +x "$dir/fakebin/lsof" "$dir/fakebin/treehouse"
      out=$(FM_FOREIGN_PID="$pid" FM_FOREIGN_WT="$wt" HOME="$dir/user-home" FM_ROOT_OVERRIDE="$FM_HOME" \
        "$ROOT/bin/fm-teardown.sh" mine --force 2>&1) && fail "$scenario teardown accepted a destructive cleanup"
      assert_contains "$out" 'foreign herdr' "$scenario refusal did not explain foreign ownership"
      kill -0 "$pid" 2>/dev/null || fail "$scenario teardown signalled the foreign process"
      [ -f "$state/mine.meta" ] && [ -d "$wt" ] || fail "$scenario teardown removed durable state or worktree"
      [ ! -s "$FM_FAKE_WORLD/returns" ] && [ ! -s "$FM_FAKE_WORLD/inputs" ] || fail "$scenario teardown returned a worktree or closed the foreign pane"
    ) || fail "$scenario cleanup regression"
  done
  pass 'flat, projected, and recursive cleanup preserve foreign pane processes'
}

test_projection_recovery_ignores_only_bound_foreign_panes() {
  (
    local dir="$TMP_ROOT/projection" journal token label rc
    setup_world "$dir"
    write_pane w1:p1 43 "$FM_HOME"
    bind_mine
    journal="$FM_STATE_OVERRIDE/mine.herdr-presentation"
    token=$(fm_backend_herdr_projection_journal_create "$FM_STATE_OVERRIDE" mine) || fail 'journal creation failed'
    label="└ mine · p:$token"
    fm_backend_herdr_projection_journal_bind "$journal" mine "$FM_HOME" fmtest \
      w1 w1:t1 w1:p1 w2 firstmate "$label" fm-mine || fail 'journal binding failed'
    jq -n --arg label "$label" '{result:{workspaces:[{workspace_id:"w1",label:$label}]}}' > "$FM_FAKE_WORLD/workspaces.json"
    printf '{"result":{"panes":[{"pane_id":"w1:p1"}]}}\n' > "$FM_FAKE_WORLD/panes.json"
    fm_backend_herdr_pane_agent_state() { printf live; }
    fm_backend_herdr_projection_live_binding_matches() { return 0; }
    fm_backend_herdr_projection_recovery_allows_flat fmtest "$journal" mine || fail 'foreign recorded pane blocked flat recovery'
    rc=0
    fm_backend_herdr_projection_reclaim_task fmtest "$journal" mine "$FM_HOME" \
      w1 w1:t1 w1:p1 firstmate fm-mine "$FM_HOME" || rc=$?
    [ "$rc" = 2 ] || fail "foreign recorded pane was reclaimed or blocked fallback: $rc"
    printf '{"result":{"panes":[{"pane_id":"w1:p1"},{"pane_id":"w1:p2"}]}}\n' > "$FM_FAKE_WORLD/panes.json"
    ! fm_backend_herdr_projection_recovery_allows_flat fmtest "$journal" mine || fail 'unbound live presentation candidate was ignored'
    [ ! -s "$FM_FAKE_WORLD/inputs" ] || fail 'recovery modified the foreign pane'
  ) || fail 'presentation recovery regression'
  pass 'presentation recovery distinguishes foreign recorded panes from unbound live candidates'
}

test_ordinary_teardown_and_projected_restart() {
  (
    local dir="$TMP_ROOT/ordinary-teardown" out
    setup_world "$dir"
    mkdir -p "$FM_HOME/data" "$FM_HOME/config" "$dir/user-home"
    write_pane w1:p1 42 "$dir/unrelated"
    fm_write_meta "$FM_STATE_OVERRIDE/mine.meta" backend=herdr window=fmtest:w1:p1 endpoint_task_id=mine \
      "worktree=$dir/missing-worktree" "project=$dir/missing-project" kind=scout harness=pi \
      herdr_session=fmtest herdr_workspace_id=w1 herdr_tab_id=w1:t1 herdr_pane_id=w1:p1 \
      'herdr_process_identity=proc:42:3f2a9c1e-0000-4000-8000-0123456789ab:7000'
    fm_fake_exit0 "$dir/fakebin" lsof treehouse
    out=$(FM_CLOSE_REMOVES=1 HOME="$dir/user-home" FM_ROOT_OVERRIDE="$FM_HOME" \
      "$ROOT/bin/fm-teardown.sh" mine --force 2>&1) || fail "owned cleanup regressed: $out"
    [ ! -f "$FM_STATE_OVERRIDE/mine.meta" ] && [ ! -f "$FM_FAKE_WORLD/pane-w1_p1.json" ] || fail 'ordinary cleanup did not close and retire the owned endpoint'
  ) || fail 'owned cleanup regression'
  (
    local dir="$TMP_ROOT/projected-restart" wt proj token label out
    setup_world "$dir"
    wt="$dir/wt"; proj="$dir/project"
    fm_test_spawn_home "$FM_HOME" codex
    fm_test_spawn_brief "$FM_HOME" mine
    fm_git_worktree "$proj" "$wt" restart-mine
    fm_fake_exit0 "$dir/fakebin" codex treehouse gh-axi
    fm_test_fake_tmux_spawn "$dir/fakebin"
    fm_test_fake_sleep_noop "$dir/fakebin"
    printf 'on\n' > "$FM_HOME/config/herdr-presentation-spaces"
    write_pane w2:p2 43 "$dir/unrelated" codex
    write_pane w1:p3 43 "$wt" codex
    fm_write_meta "$FM_STATE_OVERRIDE/mine.meta" backend=herdr window=fmtest:w2:p2 endpoint_task_id=mine \
      "worktree=$wt" "project=$proj" kind=ship harness=codex mode=no-mistakes yolo=off \
      herdr_session=fmtest herdr_workspace_id=w2 herdr_tab_id=w2:t2 herdr_pane_id=w2:p2 \
      'herdr_process_identity=proc:42:3f2a9c1e-0000-4000-8000-0123456789ab:7000'
    token=$(fm_backend_herdr_projection_journal_create "$FM_STATE_OVERRIDE" mine) || fail 'restart journal creation failed'
    label="└ mine · p:$token"
    fm_backend_herdr_projection_journal_bind "$FM_STATE_OVERRIDE/mine.herdr-presentation" mine "$FM_HOME" fmtest \
      w2 w2:t2 w2:p2 w1 firstmate "$label" fm-mine || fail 'restart journal binding failed'
    jq -n --arg label "$label" '{result:{workspaces:[{workspace_id:"w1",label:"firstmate"},{workspace_id:"w2",label:$label}]}}' > "$FM_FAKE_WORLD/workspaces.json"
    printf '{"result":{"panes":[{"pane_id":"w2:p2"}]}}\n' > "$FM_FAKE_WORLD/panes.json"
    out=$(HERDR_SESSION=fmtest fm_test_run_spawn "$FM_HOME" "$wt" "$dir/fakebin" mine "$proj" \
      --backend herdr --mode no-mistakes --yolo off) || fail "projected restart refused a recycled endpoint: $out"
    [ "$(fm_backend_target_of_meta "$FM_STATE_OVERRIDE/mine.meta")" = fmtest:w1:p3 ] || fail 'projected restart did not recover flat'
    [ -f "$FM_FAKE_WORLD/pane-w2_p2.json" ] || fail 'projected restart removed the foreign endpoint'
    ! grep -q '^w2:p2 ' "$FM_FAKE_WORLD/inputs" || fail 'projected restart steered or closed the foreign endpoint'
  ) || fail 'projected restart regression'
  pass 'ordinary cleanup still completes and projected restart recovers flat after a reset'
}

test_dispatch_boundaries
test_submit_boundaries
test_identity_requires_boot_and_ticks
test_teardown_preserves_foreign_processes
test_projection_recovery_ignores_only_bound_foreign_panes
test_ordinary_teardown_and_projected_restart
