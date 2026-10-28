#!/usr/bin/env bash
# Pin the Pi/OpenCode recovery-loop fix: one announcement per generation, and a
# handling successor that keeps supervising instead of going blind.
set -u

# shellcheck source=tests/wake-helpers.sh
. "$(dirname "${BASH_SOURCE[0]}")/wake-helpers.sh"

WATCH="$ROOT/bin/fm-watch.sh"
TMP_ROOT=$(fm_test_tmproot fm-watch-recovery-loop)
export NODE_NO_WARNINGS=1

install_pi_watch_extension_fixture() {
  local repo=$1
  mkdir -p \
    "$repo/.pi/extensions/lib" \
    "$repo/node_modules/@earendil-works/pi-coding-agent" \
    "$repo/node_modules/@earendil-works/pi-tui" \
    "$repo/node_modules/typebox" \
    "$repo/bin"
  cp "$ROOT/.pi/extensions/fm-primary-pi-watch.ts" "$repo/.pi/extensions/fm-primary-pi-watch.ts"
  cp "$ROOT/.pi/extensions/lib/fm-branch-dispatch.ts" "$repo/.pi/extensions/lib/fm-branch-dispatch.ts"
  cp "$ROOT/.pi/extensions/lib/fm-native-contract.ts" "$repo/.pi/extensions/lib/fm-native-contract.ts"
  cp "$ROOT/.pi/extensions/lib/fm-async-exec.ts" "$repo/.pi/extensions/lib/fm-async-exec.ts"
  cp "$ROOT/.pi/extensions/lib/fm-calm-visibility.ts" "$repo/.pi/extensions/lib/fm-calm-visibility.ts"
  cp "$ROOT/.pi/extensions/lib/fm-operational-input.ts" "$repo/.pi/extensions/lib/fm-operational-input.ts"
  cp "$ROOT/bin/fm-operational-input.sh" "$repo/bin/fm-operational-input.sh"
  chmod +x "$repo/bin/fm-operational-input.sh"
  cat > "$repo/node_modules/@earendil-works/pi-coding-agent/package.json" <<'JSON'
{"name":"@earendil-works/pi-coding-agent","type":"module","exports":"./index.js"}
JSON
  cat > "$repo/node_modules/@earendil-works/pi-coding-agent/index.js" <<'JS'
export function getMarkdownTheme() { return {}; }
export class UserMessageComponent {
  render() { return []; }
  invalidate() {}
}
JS
  cat > "$repo/node_modules/@earendil-works/pi-tui/package.json" <<'JSON'
{"name":"@earendil-works/pi-tui","type":"module","exports":"./index.js"}
JSON
  cat > "$repo/node_modules/@earendil-works/pi-tui/index.js" <<'JS'
export class Box {
  addChild() {}
  clear() {}
  setBgFn() {}
}
export class Container {}
export class Text {}
JS
  cat > "$repo/node_modules/typebox/package.json" <<'JSON'
{"name":"typebox","type":"module","exports":"./index.js"}
JSON
  cat > "$repo/node_modules/typebox/index.js" <<'JS'
export const Type = {
  Object(properties) {
    return { type: "object", properties, additionalProperties: false };
  },
};
JS
}

# T1: a lost --handling-delivered handshake must not re-announce forever.
# The real Pi extension drives the real arm/watcher, with only the handshake
# RPC forced to fail. After the first recovery follow-up, wait past the old
# ~52s loop period so a regression would emit a second follow-up.
test_unacknowledged_recovery_is_announced_once_per_generation() {
  local repo home plugin fakebin out status lock_pid messages
  repo="$TMP_ROOT/t1-root"
  home="$TMP_ROOT/t1-home"
  fakebin="$TMP_ROOT/t1-fakebin"
  mkdir -p "$repo/bin" "$home/state" "$home/config" "$fakebin"
  install_pi_watch_extension_fixture "$repo"
  plugin="$repo/.pi/extensions/fm-primary-pi-watch.ts"
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$fakebin/tmux"
  cat > "$repo/bin/fm-watch-arm.sh" <<SH
#!/usr/bin/env bash
if [ "\${1:-}" = --handling-delivered ]; then
  exit 1
fi
export FM_ROOT_OVERRIDE="$ROOT"
export PATH="$fakebin:\$PATH"
exec "$ROOT/bin/fm-watch-arm.sh" "\$@"
SH
  chmod +x "$repo/bin/fm-watch-arm.sh"
  : > "$home/state/seed.meta"
  printf 'pending:downtime:seed.1.aaa\n' > "$home/state/.watcher-down"
  chmod 600 "$home/state/.watcher-down"
  printf '%s\t1\tcheck\tseed\tcheck: seed recovery\n' "$(date +%s)" > "$home/state/.wake-queue"
  out=$(
    PLUGIN="$plugin" FM_HOME="$home" FM_ROOT_OVERRIDE="$repo" \
      FM_STATE_OVERRIDE="$home/state" PATH="$fakebin:$PATH" \
      FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
      node --input-type=module 2>&1 <<'EOF'
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

let tool = null;
const prompts = [];
const pi = {
  on() {},
  registerCommand() {},
  registerTool(candidate) {
    if (candidate.name === "fm_watch_arm_pi") tool = candidate;
  },
  sendUserMessage: async (message) => {
    prompts.push(String(message));
  },
};
writeFileSync(`${process.env.FM_HOME}/state/.lock`, `${process.pid}\n`);
const mod = await import(pathToFileURL(process.env.PLUGIN).href);
mod.default(pi);
if (!tool) throw new Error("Pi watch tool was not registered");
await tool.execute("tool-call-t1", {}, undefined, undefined, {});
const deadline = Date.now() + 75000;
let firstAt = 0;
while (Date.now() < deadline) {
  const rearm = prompts.filter((message) => message.includes("check: rearm-resurface"));
  if (rearm.length > 1) {
    throw new Error(`unbounded recovery loop: ${rearm.length} rearm-resurface follow-ups`);
  }
  if (rearm.length === 1 && firstAt === 0) firstAt = Date.now();
  if (firstAt && Date.now() - firstAt >= 55000) break;
  await new Promise((resolve) => setTimeout(resolve, 200));
}
const rearm = prompts.filter((message) => message.includes("check: rearm-resurface"));
if (rearm.length !== 1) {
  throw new Error(`expected exactly one recovery follow-up, got ${rearm.length}: ${prompts.join(" || ")}`);
}
const lockPid = existsSync(`${process.env.FM_HOME}/state/.watch.lock/pid`)
  ? readFileSync(`${process.env.FM_HOME}/state/.watch.lock/pid`, "utf8").trim()
  : "";
if (!/^[0-9]+$/.test(lockPid)) throw new Error("successor watcher lock pid missing");
try {
  process.kill(Number(lockPid), 0);
} catch {
  throw new Error(`successor watcher ${lockPid} is not alive`);
}
const marker = readFileSync(`${process.env.FM_HOME}/state/.watcher-down`, "utf8").trim();
if (!marker.startsWith("announced:") && !marker.startsWith("pending:")) {
  throw new Error(`successor did not keep a live recovery episode: ${marker}`);
}
console.log(`T1_MESSAGES=${rearm.length}`);
console.log(`T1_LOCK_PID=${lockPid}`);
console.log(`T1_MARKER=${marker}`);
process.exit(0);
EOF
  )
  status=$?
  if [ "${FM_TEST_EVIDENCE:-0}" = 1 ]; then
    printf '%s\n' "$out"
  fi
  lock_pid=$(sed -n 's/^T1_LOCK_PID=//p' <<<"$out" | tail -1)
  messages=$(sed -n 's/^T1_MESSAGES=//p' <<<"$out" | tail -1)
  if [ -n "$lock_pid" ]; then
    kill -TERM "$lock_pid" 2>/dev/null || true
  fi
  expect_code 0 "$status" "an unacknowledged recovery must be announced at most once per generation: $out"
  [ "$messages" = 1 ] || fail "T1 did not report a single recovery follow-up: $out"
  pass "unacknowledged recovery is announced at most once per generation and the successor stays alive"
}

# T2: a handling successor must enter its poll loop and surface a real crew
# event within a bounded startup-and-poll budget instead of sitting in a
# pre-loop wait that refreshes the liveness beacon and then exits with a
# synthetic rearm-resurface.
test_handling_successor_does_not_go_blind() {
  local dir home state fakebin child event_start now out
  dir=$(make_case recovery-gap-successor)
  home="$dir/home"
  state="$dir/state"
  fakebin="$dir/fakebin"
  mkdir -p "$home/data"
  : > "$state/crew.meta"
  printf 'pending:downtime:gap.1.aaa\n' > "$state/.watcher-down"
  chmod 600 "$state/.watcher-down"
  out="$dir/watch.out"
  PATH="$fakebin:$PATH" FM_HOME="$home" FM_STATE_OVERRIDE="$state" \
    FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=600 \
    FM_WATCH_HANDLING_SUCCESSOR=1 "$WATCH" > "$out" 2>&1 &
  child=$!
  now=0
  while [ "$now" -lt 40 ]; do
    [ "$(cat "$state/.watch.lock/pid" 2>/dev/null || true)" = "$child" ] && break
    sleep 0.1
    now=$((now + 1))
  done
  [ "$(cat "$state/.watch.lock/pid" 2>/dev/null || true)" = "$child" ] \
    || { kill -TERM "$child" 2>/dev/null || true; fail "handling successor did not take the watcher lock"; }
  sleep 0.4
  printf 'done: crew finished its task\n' >> "$state/crew.status"
  event_start=$(date +%s)
  now=0
  while [ "$now" -lt 20 ]; do
    if grep -q '^signal:' "$out" 2>/dev/null; then
      break
    fi
    sleep 0.5
    now=$((now + 1))
  done
  if ! grep -q '^signal:' "$out" 2>/dev/null; then
    kill -TERM "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
    fail "handling successor did not surface the crew event within the bounded startup-and-poll budget (waited $(( $(date +%s) - event_start ))s): $(cat "$out")"
  fi
  grep -F 'crew.status' "$out" >/dev/null \
    || { kill -TERM "$child" 2>/dev/null || true; fail "handling successor did not name the crew status file: $(cat "$out")"; }
  grep "$(printf '\tsignal\tcrew.status\t')" "$state/.wake-queue" >/dev/null \
    || { kill -TERM "$child" 2>/dev/null || true; fail "handling successor did not enqueue a durable row for the crew event"; }
  ! grep -F 'check: rearm-resurface' "$out" >/dev/null \
    || { kill -TERM "$child" 2>/dev/null || true; fail "handling successor emitted synthetic recovery instead of supervising: $(cat "$out")"; }
  if [ "${FM_TEST_EVIDENCE:-0}" = 1 ]; then
    printf 'T2_WATCH_OUTPUT=%s\n' "$(tr '\n' ' ' < "$out")"
    printf 'T2_QUEUE_ROW=%s\n' "$(grep "$(printf '\tsignal\tcrew.status\t')" "$state/.wake-queue" | tail -1)"
  fi
  kill -TERM "$child" 2>/dev/null || true
  wait "$child" 2>/dev/null || true
  pass "a resurfacing handling successor stays alive and supervises instead of going blind"
}

# T3: a row appended after the predecessor closes but before its handling
# successor can inspect the queue must survive the handoff and reach main.
test_handling_successor_resurfaces_a_row_appended_during_startup() {
  local dir home state fakebin child blocker now out
  dir=$(make_case recovery-startup-append)
  home="$dir/home"
  state="$dir/state"
  fakebin="$dir/fakebin"
  mkdir -p "$home/data"
  printf 'pending:downtime:later.1.aaa\n' > "$state/.watcher-down"
  chmod 600 "$state/.watcher-down"
  printf '%s\t1\tstale\tfm-demo\tstale: fm-demo (the delivered wake)\n' "$(date +%s)" > "$state/.wake-queue"
  printf '1\n' > "$state/.wake-queue.seq"
  out="$dir/watch.out"

  FM_HOME="$home" FM_STATE_OVERRIDE="$state" bash -c '
    . "$1"
    fm_lock_acquire_wait "$FM_WAKE_QUEUE_LOCK" || exit 1
    : > "$2/queue-held"
    while [ ! -e "$2/append-now" ]; do sleep 0.02; done
    fm_wake_append_locked check inbox:n1 "check: captain inbox note n1 - from Basecamp" || exit 1
    fm_lock_release "$FM_WAKE_QUEUE_LOCK"
  ' _ "$ROOT/bin/fm-wake-lib.sh" "$state" &
  blocker=$!
  now=0
  while [ "$now" -lt 100 ] && [ ! -e "$state/queue-held" ]; do
    sleep 0.02
    now=$((now + 1))
  done
  [ -e "$state/queue-held" ] || { kill "$blocker" 2>/dev/null || true; fail "fixture: queue lock was not held"; }

  PATH="$fakebin:$PATH" FM_HOME="$home" FM_STATE_OVERRIDE="$state" \
    FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=600 \
    FM_WATCH_HANDLING_SUCCESSOR=1 "$WATCH" > "$out" 2>&1 &
  child=$!
  now=0
  while [ "$now" -lt 40 ]; do
    [ "$(cat "$state/.watch.lock/pid" 2>/dev/null || true)" = "$child" ] && break
    sleep 0.1
    now=$((now + 1))
  done
  [ "$(cat "$state/.watch.lock/pid" 2>/dev/null || true)" = "$child" ] \
    || { kill -TERM "$child" "$blocker" 2>/dev/null || true; fail "handling successor did not take the watcher lock"; }
  : > "$state/append-now"
  wait "$blocker" || { kill -TERM "$child" 2>/dev/null || true; fail "fixture: startup append failed"; }
  now=0
  while [ "$now" -lt 40 ] && [ ! -e "$state/.last-watcher-beat" ]; do
    sleep 0.1
    now=$((now + 1))
  done
  [ -e "$state/.last-watcher-beat" ] \
    || { kill -TERM "$child" 2>/dev/null || true; fail "fixture: handling successor never finished startup"; }
  FM_HOME="$home" FM_STATE_OVERRIDE="$state" bash -c '
    . "$1"
    fm_recovery_marker_begin_handling "$2/.watcher-down" later.1.aaa || exit 1
    fm_lock_acquire_wait "$FM_WAKE_QUEUE_LOCK" || exit 1
    awk -F "\t" "\$2 != 1" "$FM_WAKE_QUEUE" > "$FM_WAKE_QUEUE.tmp" \
      && mv -f "$FM_WAKE_QUEUE.tmp" "$FM_WAKE_QUEUE" || exit 1
    fm_lock_release "$FM_WAKE_QUEUE_LOCK"
    fm_recovery_marker_handling_settled "$2/.watcher-down"
  ' _ "$ROOT/bin/fm-wake-lib.sh" "$state" \
    || { kill -TERM "$child" 2>/dev/null || true; fail "fixture: handled-turn settlement failed"; }

  now=0
  while [ "$now" -lt 40 ] && kill -0 "$child" 2>/dev/null; do
    sleep 0.25
    now=$((now + 1))
  done
  if kill -0 "$child" 2>/dev/null; then
    kill -TERM "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
    fail "handling successor never resurfaced the startup-window row: $(cat "$out"; cat "$state/.watcher-down")"
  fi
  wait "$child" 2>/dev/null || true
  [ "$(grep -c '^check: rearm-resurface$' "$out")" -eq 1 ] \
    || fail "handling successor did not close once with the recovery wake: $(cat "$out")"
  grep "$(printf '\tcheck\tinbox:n1\t')" "$state/.wake-queue" >/dev/null \
    || fail "the resurfaced inbox row must stay queued for main"
  grep -E '^(pending|announced):downtime:' "$state/.watcher-down" >/dev/null \
    || fail "the resurfaced close must leave a deliverable downtime episode: $(cat "$state/.watcher-down")"
  pass "a handling successor resurfaces a row appended during startup"
}

# A captured, unhandled, main-owned process-event result is re-announced by
# every watcher poll. Each append used to open a new recovery episode, so the
# handling successor closed at once with check: rearm-resurface and the Pi
# extension queued another identical follow-up, one per second, until main ran
# `handled`. These two cases drive the real extension, arm, watcher and
# fm-procevent.sh with a sendUserMessage that settles at once like Pi queueing
# a follow-up while main streams, and read the outcome from the prompts it saw,
# the durable queue and the recovery marker.
pe_home() {  # <home> <fm-procevent args...>
  local home=$1
  shift
  (unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE; FM_PROCEVENT_CLAIM_ROOT="$home/claims" FM_HOME="$home" "$ROOT/bin/fm-procevent.sh" "$@")
}

seed_captured_procevent_result() {  # <home>
  local home=$1 i=0
  pe_home "$home" register lavish delivery-src -- \
    /bin/sh -c 'printf "session:\n  file: /a.html\n  status: waiting\n"' >/dev/null || return 1
  pe_home "$home" reconcile >/dev/null || return 1
  while [ "$i" -lt 100 ] && [ ! -s "$home/state/.wake-queue" ]; do
    sleep 0.1
    i=$((i + 1))
  done
  # The runner publishes before it releases its claim; retire only after that.
  i=0
  while [ "$i" -lt 100 ] && [ -e "$home/claims/delivery-src.claim" ]; do
    sleep 0.1
    i=$((i + 1))
  done
  pe_home "$home" retire delivery-src >/dev/null || return 1
  [ -s "$home/state/.wake-queue" ]
}

# <name> <ack-at-secs, 0 for none> <window-secs: observation window, or the longest
# wait for the re-announcement after an ack> <quiet-secs> <after-handled-secs>
# Prints LOOP_* facts; the successor watcher is stopped afterwards.
run_procevent_loop_scenario() {
  local name=$1 ack_at=$2 window=$3 quiet=$4 after=$5
  local repo="$TMP_ROOT/$name-root" home="$TMP_ROOT/$name-home" fakebin="$TMP_ROOT/$name-fakebin"
  local out status watcher_pid
  mkdir -p "$repo/bin" "$home/state" "$home/config" "$home/claims" "$fakebin"
  install_pi_watch_extension_fixture "$repo"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/tmux"
  chmod +x "$fakebin/tmux"
  make_fake_crew_state "$fakebin" >/dev/null
  cat > "$repo/bin/fm-watch-arm.sh" <<SH
#!/usr/bin/env bash
export FM_ROOT_OVERRIDE="$ROOT"
export PATH="$fakebin:\$PATH"
exec "$ROOT/bin/fm-watch-arm.sh" "\$@"
SH
  chmod +x "$repo/bin/fm-watch-arm.sh"
  seed_captured_procevent_result "$home" || fail "$name fixture captured no process-event result"
  out=$(
    PLUGIN="$repo/.pi/extensions/fm-primary-pi-watch.ts" FM_HOME="$home" FM_ROOT_OVERRIDE="$repo" \
      FM_STATE_OVERRIDE="$home/state" PATH="$fakebin:$PATH" FM_PROCEVENT_CLAIM_ROOT="$home/claims" \
      FM_CREW_STATE_BIN="$fakebin/fm-crew-state.sh" ROOT="$ROOT" \
      WINDOW_SECS="$window" ACK_AT_SECS="$ack_at" QUIET_SECS="$quiet" AFTER_SECS="$after" \
      FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
      node --input-type=module 2>&1 <<'EOF'
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const state = `${process.env.FM_HOME}/state`;
let tool = null;
const prompts = [];
const markers = [];
const pi = {
  on() {},
  registerCommand() {},
  registerTool(candidate) {
    if (candidate.name === "fm_watch_arm_pi") tool = candidate;
  },
  // Pi queues a follow-up while main streams and returns at once.
  sendUserMessage: async (message) => {
    const text = String(message);
    prompts.push((text.match(/FIRSTMATE WATCHER WAKE: ([^\n]*)/) || [])[1] || text.slice(0, 80));
  },
};
const sample = () => {
  try { markers.push(readFileSync(`${state}/.watcher-down`, "utf8").trim()); } catch {}
};
const keyRows = () => {
  try {
    return readFileSync(`${state}/.wake-queue`, "utf8").split("\n")
      .filter((row) => row.split("\t")[3] === "procevent:delivery-src:1").length;
  } catch { return 0; }
};
const run = (args) => spawnSync("bash", ["-c", args], { encoding: "utf8", env: process.env });
const wait = async (secs) => {
  const until = Date.now() + secs * 1000;
  while (Date.now() < until) { sample(); await new Promise((resolve) => setTimeout(resolve, 250)); }
};
const rearm = () => prompts.filter((reason) => reason.includes("check: rearm-resurface")).length;

writeFileSync(`${state}/.lock`, `${process.pid}\n`);
const mod = await import(pathToFileURL(process.env.PLUGIN).href);
mod.default(pi);
await tool.execute("recovery-loop", {}, undefined, undefined, {});

const ackAt = Number(process.env.ACK_AT_SECS);
if (ackAt > 0) {
  // Acknowledge only after main was woken for the result: a loaded host can
  // start the first cycle later than any fixed delay.
  const firstDeadline = Date.now() + 40000;
  while (prompts.length === 0 && Date.now() < firstDeadline) await wait(0.25);
  if (prompts.length === 0) throw new Error("the captured result never woke main");
  await wait(ackAt);
  // Main drains and acknowledges the queued wake WITHOUT marking it handled.
  const drain = run('"$ROOT/bin/fm-wake-drain.sh"');
  const m = (drain.stderr || "").match(/--ack-through ([0-9]+) --recovery-generation ([A-Za-z0-9._-]+)/);
  if (!m) throw new Error(`drain printed no acknowledgement command: ${drain.stderr}`);
  run(`"$ROOT/bin/fm-wake-drain.sh" --ack-through ${m[1]} --recovery-generation ${m[2]}`);
  const atAck = prompts.length;
  // The one bounded re-announcement lands on the next poll; a loaded host may
  // delay it, so wait for it (bounded) before measuring the quiet period.
  const deadline = Date.now() + Number(process.env.WINDOW_SECS) * 1000;
  while (prompts.length === atAck && Date.now() < deadline) await wait(0.5);
  await wait(3);
  const settled = prompts.length;
  await wait(Number(process.env.QUIET_SECS));
  console.log(`LOOP_FOLLOWUPS_AFTER_ACK=${settled - atAck}`);
  console.log(`LOOP_FOLLOWUPS_DURING_QUIET=${prompts.length - settled}`);
} else {
  await wait(Number(process.env.WINDOW_SECS));
}
const before = prompts.length;
console.log(`LOOP_FOLLOWUPS=${before}`);
console.log(`LOOP_CAPTURED_FOLLOWUPS=${prompts.filter((reason) => reason.includes("process-event result captured")).length}`);
console.log(`LOOP_REARM_FOLLOWUPS=${rearm()}`);
console.log(`LOOP_KEY_ROWS=${keyRows()}`);
console.log(`LOOP_GENERATIONS=${new Set(markers.map((marker) => marker.split(":").pop())).size}`);
const watcherPid = existsSync(`${state}/.watch.lock/pid`) ? readFileSync(`${state}/.watch.lock/pid`, "utf8").trim() : "";
console.log(`LOOP_WATCHER_PID=${watcherPid}`);
let alive = 0;
try { process.kill(Number(watcherPid), 0); alive = 1; } catch {}
console.log(`LOOP_WATCHER_ALIVE=${alive}`);
run('unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE; "$ROOT/bin/fm-procevent.sh" handled delivery-src 1');
await wait(Number(process.env.AFTER_SECS));
console.log(`LOOP_FOLLOWUPS_AFTER_HANDLED=${prompts.length - before}`);
console.log(`LOOP_KEY_ROWS_AFTER_HANDLED=${keyRows()}`);
process.exit(0);
EOF
  )
  status=$?
  watcher_pid=$(sed -n 's/^LOOP_WATCHER_PID=//p' <<<"$out" | tail -1)
  if [ -n "$watcher_pid" ]; then
    kill -TERM "$watcher_pid" 2>/dev/null || true
  fi
  expect_code 0 "$status" "$name driver failed: $out"
  if [ "${FM_TEST_EVIDENCE:-0}" = 1 ]; then
    printf '%s\n' "$out" >&2
  fi
  printf '%s\n' "$out"
}

loop_fact() {  # <output> <name>
  sed -n "s/^LOOP_$2=//p" <<<"$1" | tail -1
}

test_unhandled_procevent_result_does_not_loop_rearm_resurface() {
  local out
  out=$(run_procevent_loop_scenario t4 0 15 0 5)
  [ "$(loop_fact "$out" CAPTURED_FOLLOWUPS)" = 1 ] \
    || fail "T4 expected exactly one process-event follow-up: $out"
  [ "$(loop_fact "$out" REARM_FOLLOWUPS)" = 0 ] \
    || fail "T4 an unhandled result looped check: rearm-resurface follow-ups: $out"
  [ "$(loop_fact "$out" FOLLOWUPS)" = 1 ] || fail "T4 queued more than one follow-up: $out"
  [ "$(loop_fact "$out" KEY_ROWS)" -le 1 ] || fail "T4 queued the result more than once: $out"
  [ "$(loop_fact "$out" GENERATIONS)" -le 1 ] || fail "T4 minted more than one recovery generation: $out"
  [ "$(loop_fact "$out" WATCHER_ALIVE)" = 1 ] || fail "T4 the successor watcher is not alive: $out"
  [ "$(loop_fact "$out" FOLLOWUPS_AFTER_HANDLED)" = 0 ] || fail "T4 handled result woke main again: $out"
  pass "an unhandled process-event result queues one follow-up and no rearm-resurface loop"
}

test_procevent_reannouncement_after_ack_without_handled_is_bounded() {
  local out
  out=$(run_procevent_loop_scenario t5 2 20 10 5)
  [ "$(loop_fact "$out" CAPTURED_FOLLOWUPS)" = 1 ] \
    || fail "T5 expected exactly one process-event follow-up: $out"
  [ "$(loop_fact "$out" FOLLOWUPS_AFTER_ACK)" -le 1 ] \
    || fail "T5 more than one follow-up after an acknowledgement without handled: $out"
  [ "$(loop_fact "$out" FOLLOWUPS_DURING_QUIET)" = 0 ] \
    || fail "T5 the re-announcement kept waking main after it settled: $out"
  [ "$(loop_fact "$out" KEY_ROWS)" = 1 ] || fail "T5 expected exactly one queued copy: $out"
  [ "$(loop_fact "$out" WATCHER_ALIVE)" = 1 ] || fail "T5 the successor watcher is not alive: $out"
  [ "$(loop_fact "$out" FOLLOWUPS_AFTER_HANDLED)" = 0 ] || fail "T5 handled result woke main again: $out"
  [ "$(loop_fact "$out" KEY_ROWS_AFTER_HANDLED)" = 1 ] || fail "T5 handled result queued a new row: $out"
  pass "a result acknowledged without handled is re-announced at most once, then stays quiet until handled"
}

test_handling_successor_does_not_go_blind
test_handling_successor_resurfaces_a_row_appended_during_startup
test_unacknowledged_recovery_is_announced_once_per_generation
test_unhandled_procevent_result_does_not_loop_rearm_resurface
test_procevent_reannouncement_after_ack_without_handled_is_bounded
