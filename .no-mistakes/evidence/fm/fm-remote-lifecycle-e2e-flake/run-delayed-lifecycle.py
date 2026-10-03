#!/usr/bin/env python3
"""Disposable instrumentation of the changed E2E test; polling and assertions unchanged."""
import os
import subprocess
import time
from pathlib import Path

root = Path('/home/node/.no-mistakes/worktrees/450411b3e67c/01M40012HAGF4C4Q91QNT4Q373')
evidence = Path('/home/node/.no-mistakes/evidence/01M40012HAGF4C4Q91QNT4Q373')
scratch = root / '.no-mistakes/test-phase'
driver = root / 'tests/.remote-lifecycle-validation.test.sh'
src = (root / 'tests/fm-remote-secondmate-lifecycle-e2e.test.sh').read_text()
# Abort on unexpected source, rather than silently exercising the wrong seam.
def inject(old, new):
    global src
    assert src.count(old) == 1, old
    src = src.replace(old, new)

# The first inherit-block is spawn, the second is the reported config-push wait.
inject('    cat > "$FM_FAKE_INHERIT_PAYLOAD"', '''    if [ -f "$FM_FAKE_INHERIT_PAYLOAD.delay-seen" ]; then
      printf 'FAULT: second inheritance arrival delayed 45 seconds\\n' >&2
      sleep 45
    else
      touch "$FM_FAKE_INHERIT_PAYLOAD.delay-seen"
    fi
    cat > "$FM_FAKE_INHERIT_PAYLOAD"''')
inject('    touch "$FM_FAKE_LAUNCH_ENTERED"', '''    printf 'FAULT: respawn launch arrival delayed 45 seconds\\n' >&2
    sleep 45
    touch "$FM_FAKE_LAUNCH_ENTERED"''')
watch_start = 'FM_STATE_OVERRIDE="$WATCH_STATE" FM_SECONDMATE_LIVENESS_SECS=1 FM_POLL=1 \\\n'
inject(watch_start, '( sleep 45;\n' + watch_start)
inject('  > "$TMP_ROOT/watch-liveness.out" 2> "$TMP_ROOT/watch-liveness.err" &',
       '  > "$TMP_ROOT/watch-liveness.out" 2> "$TMP_ROOT/watch-liveness.err" ) &')
# The fixture is inside a worktree, not /tmp: explicitly stop Git discovery
# at the negative non-checkout fixture, so its ancestor cannot make it a repo.
inject('mkdir -p "$TMP_ROOT/not-a-checkout"', '''mkdir -p "$TMP_ROOT/not-a-checkout"
printf 'gitdir: %s/nonexistent\\n' "$TMP_ROOT/not-a-checkout" > "$TMP_ROOT/not-a-checkout/.git"''')
# Keep actual CLI/state artifacts, not just the suite's assertion reporter.
inject('  rm -rf -- "$TMP_ROOT"\n}', f'''  for rel in seed-keep.out config-concurrent-first.out config-concurrent-second.out spawn-retirement.out teardown-serialized.out watch-liveness.out watch-liveness.err watch-liveness-state/.wake-queue watch-liveness-state/.secondmate-relaunch-ios watch-liveness-state/ios.meta; do
    if [ -f "$TMP_ROOT/$rel" ]; then
      cp "$TMP_ROOT/$rel" '{evidence}/'"$(printf '%s' "$rel" | tr / _)"
    fi
  done
  chmod -R u+w -- "$TMP_ROOT" 2>/dev/null || true
  rm -rf -- "$TMP_ROOT"
}}''')
inject('pass "config push and bootstrap serialize remote inheritance convergence"',
       f'''cp "$REMOTE_HOME/data/captain-shared.md" '{evidence}/converged-captain-shared.md'
pass "config push and bootstrap serialize remote inheritance convergence"''')
# Delay observability: capture each polling counter as soon as its leg passes.
for marker, counter in [
    ('pass "config push and bootstrap serialize remote inheritance convergence"', 'inherit_wait'),
    ('pass "watch liveness: a dead remote secondmate is auto-relaunched on its own host with one wake"', 'watch_wait'),
    ('pass "remote retirement refuses child work, then removes only its own endpoint while a shared-session sibling survives"', 'launch_wait'),
]:
    inject(marker, marker + f'\nprintf "VALIDATION_POLLS {counter}=%s\\n" "${counter}"')
src += '\nprintf "VALIDATION_POLLS config=%s watcher=%s respawn=%s\\n" "$inherit_wait" "$watch_wait" "$launch_wait"\n'
assert not driver.exists()
env = {k: v for k, v in os.environ.items()
       if not k.startswith(('FM_', 'TASKS_AXI_', 'HERDR_', 'GIT_'))
       and k not in ('TMUX', 'TMUX_PANE', 'ZELLIJ', 'CLAUDE_CONFIG_DIR')}
env.update(HOME=str(scratch/'home'), TMPDIR=str(scratch/'tmp'),
           XDG_CONFIG_HOME=str(scratch/'home/config'),
           XDG_DATA_HOME=str(scratch/'home/data'),
           XDG_CACHE_HOME=str(scratch/'home/cache'), FM_SNAPSHOT_BUDGET='120')
cmd = ['bin/fm-test-run.sh', str(driver.relative_to(root)),
       '--per-script-timeout-secs', '1800', '--json', str(evidence/'delayed-lifecycle-timing.json')]
try:
    driver.write_text(src)
    with (evidence/'delayed-lifecycle.log').open('w') as log:
        log.write('Scenario: delayed inheritance transaction, delayed watcher start, delayed respawn launch; each fault is a real sleep 45, original counted polling/assertions unchanged. SSH/Herdr/tmux remain the existing mocked boundaries, not live fleet validation.\n')
        log.write('Setup: isolated HOME/TMPDIR in the worktree; a git-init ancestor bounds disposable remote workers to the fixture, and a dangling .git sentinel explicitly makes the not-a-checkout negative fixture non-discoverable.\n')
        log.write('Environment workaround: FM_SNAPSHOT_BUDGET=120 for the unchanged structured-ledger snapshot, whose default 5 seconds expired under host load 29 on 4 CPUs in the prior attempt. This is not a changed polling bound.\n')
        log.write('Command: ' + ' '.join(cmd) + '\n'); log.flush()
        start = time.monotonic()
        result = subprocess.run(cmd, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
        log.write(f'Command exit={result.returncode} elapsed_seconds={time.monotonic()-start:.3f}\n')
    print(f'delayed lifecycle exit={result.returncode}; evidence={evidence}/delayed-lifecycle.log')
finally:
    driver.unlink(missing_ok=True)
raise SystemExit(result.returncode)
