#!/usr/bin/env bash
# Live driver: runs the real fm-procevent-remote-reply.sh adapter and the real
# fm-procevent.sh runner (with the real remote entrypoint behind a fake ssh that
# execs it locally) in a disposable home with a private TMPDIR, then lists what
# each user-visible action left in that TMPDIR.
# Usage: drive-remote-reply-tmp-leak.sh <tree-root>
set -u
ROOT=$(cd "$1" && pwd -P)
W=$(mktemp -d "${TMPDIR:-/tmp}/fm-leak-drive.XXXXXX"); W=$(cd "$W" && pwd -P)
PARENT=$W/parent REMOTE=$W/remote CLAIMS=$W/claims PT=$W/ptmp FAKE=$W/fake
mkdir -p "$PARENT/data" "$PARENT/state" "$REMOTE/state" "$REMOTE/data/reply" "$CLAIMS" "$PT" "$FAKE"
ADAPTER=$ROOT/bin/fm-procevent-remote-reply.sh
. "$ROOT/bin/fm-remote-job-lib.sh"
printf -- '- ios - iOS delivery (host: remote-mac; root: %s; home: %s; scope: iOS work; projects: alpha; added 2026-08-02)\n' "$ROOT" "$REMOTE" > "$PARENT/data/secondmates.md"
printf '# Report\n\nGreen.\n' > "$REMOTE/data/reply/report.md"
: > "$REMOTE/state/parent-replies.status"
cat > "$FAKE/ssh" <<'SH'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do case "$1" in -o) shift 2 ;; --) shift; break ;; *) exit 90 ;; esac; done
[ -z "${FM_HANG_MARK:-}" ] || { printf '%s\n' "$$" > "$FM_HANG_MARK"; exec sleep 20; }
shift 2; exec "$ROOT_FOR_FAKE/bin/fm-remote-entrypoint.sh" "$@"
SH
chmod +x "$FAKE/ssh"
renv() {
  GIT_CONFIG_GLOBAL=/dev/null TMPDIR="$PT" FM_HOME="$PARENT" FM_ROOT_OVERRIDE="$ROOT" FM_PROCEVENT_CLAIM_ROOT="$CLAIMS" \
  FM_SSH_BIN="$FAKE/ssh" ROOT_FOR_FAKE="$ROOT" FM_REMOTE_JOB_PLATFORM_OVERRIDE=Linux \
  FM_REMOTE_JOB_STATE_ROOT="$W/remote-jobs" FM_REMOTE_REPLY_WAIT_SECONDS=10 "$@"
}
sha() { sha256sum "$1" | awk '{print $1}'; }
report() { # <label>
  local adapter_left locks
  adapter_left=$(cd "$PT" && ls -1A | grep -E '^fm-(remote-reply-ingest|remote-doc-reason|empty-hash)\.' || true)
  locks=$(find "$PARENT/state" -maxdepth 1 -name '.remote-reply-lifecycle-*' -printf '%f\n' 2>/dev/null)
  docs=$(find "$PARENT/data" -name '.remote-doc.*' -printf '%P\n' 2>/dev/null)
  printf '  TMPDIR adapter temp paths: %s\n' "${adapter_left:-<none>}"
  printf '  staged .remote-doc.* left: %s\n' "${docs:-<none>}"
  printf '  lifecycle lock left held : %s\n' "${locks:-<none>}"
  if [ -z "$adapter_left$docs$locks" ]; then echo "  => $1: CLEAN"; else echo "  => $1: LEAK"; fi
  rm -rf "$PT"/fm-remote-reply-ingest.* "$PT"/fm-remote-doc-reason.* "$PT"/fm-empty-hash.*
  find "$PARENT/data" -name '.remote-doc.*' -exec rm -f {} + ; rm -rf "$PARENT"/state/.remote-reply-lifecycle-*
}
stop_listener() {
  local pid; pid=$(sed -n '2p' "$CLAIMS/$SID.claim" 2>/dev/null || true)
  case "$pid" in ''|*[!0-9]*) return 0 ;; esac
  kill -TERM -- -"$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
  for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || return 0; sleep 0.05; done
}
wait_file() { for _ in $(seq 1 600); do [ -e "$1" ] && return 0; sleep 0.05; done; return 1; }
echo "tree: $ROOT (${2:-$(git -C "$ROOT" rev-parse --short HEAD)})"

SID=$(renv "$ADAPTER" source-id ios)
echo; echo "[1] runner path: arm, start listener, remote mate appends a done line with report=, runner autohandles"
renv "$ADAPTER" arm ios
renv "$ROOT/bin/fm-procevent.sh" start "$SID" > "$W/start1.out" 2>&1 &
wait_file "$CLAIMS/$SID.claim" || echo "  !! runner never claimed"
printf 'done [corr=0123456789abcdef] [at=1700000000]: build verified report=data/reply/report.md\n' >> "$REMOTE/state/parent-replies.status"
wait_file "$PARENT/state/procevent-inbox/$SID.1.handled" || echo "  !! never handled"
sleep 0.5
echo "  parent ios.status: $(cat "$PARENT/state/ios.status")"
echo "  mirrored doc     : $(ls "$PARENT/data/remote-secondmates/ios/data/reply/" 2>/dev/null)"
stop_listener
report "runner autohandle of a delta"

echo; echo "[2] runner path: remote log replaced (truncation) -> continuity break captured and autohandled"
printf 'failed [corr=fedcba9876543210]: source was replaced\n' > "$REMOTE/state/parent-replies.status"
renv "$ROOT/bin/fm-procevent.sh" start "$SID" > "$W/start2.out" 2>&1
R2=$(find "$PARENT/state/procevent-inbox" -name "$SID.2.result" -print -quit)
echo "  classify: $(renv "$ADAPTER" classify "$R2")"
echo "  escalation: $(grep -F 'remote-reply-continuity-ios' "$PARENT/state/ios.status" | head -1)"
report "runner autohandle of a continuity break"
echo "  manual handle of that continuity result:"
rc=0; renv "$ADAPTER" handle ios 2 "$R2" > "$W/h2.out" 2>&1 || rc=$?
sed 's/^/    /' "$W/h2.out"; echo "    rc=$rc"
report "manual handle of continuity break"
echo "  direct ingest of that continuity result:"
rc=0; renv "$ADAPTER" ingest ios "$R2" > "$W/i2.out" 2>&1 || rc=$?
sed 's/^/    /' "$W/i2.out"; echo "    rc=$rc"
report "direct ingest of continuity break"

echo; echo "[3] adversarial: corrupted result (payload digest mismatch) -> die after staging"
R1=$PARENT/state/procevent-inbox/$SID.1.result
sed 's/^payload_bytes=.*/payload_bytes=99/' "$R1" > "$W/bad.result"
rc=0; renv "$ADAPTER" ingest ios "$W/bad.result" > "$W/bad.out" 2>&1 || rc=$?
sed 's/^/    /' "$W/bad.out"; echo "    rc=$rc"
report "die after staging (ingest)"
rc=0; renv "$ADAPTER" handle ios 9 "$W/bad.result" > "$W/badh.out" 2>&1 || rc=$?
sed 's/^/    /' "$W/badh.out"; echo "    rc=$rc"
report "die after staging (lifecycle-locked handle)"

echo; echo "[4] adversarial: SIGTERM delivered to ingest while the report= document fetch hangs"
rm -rf "$PARENT/state/remote-replies" "$PARENT/data/remote-secondmates"
rm -f "$W/hang"
GIT_CONFIG_GLOBAL=/dev/null FM_HANG_MARK="$W/hang" TMPDIR="$PT" FM_HOME="$PARENT" FM_ROOT_OVERRIDE="$ROOT" FM_SSH_BIN="$FAKE/ssh" \
  "$ADAPTER" ingest ios "$R1" > "$W/sig.out" 2>&1 &
pid=$!
for _ in $(seq 1 200); do [ -s "$W/hang" ] && break; sleep 0.05; done
echo "  during fetch, TMPDIR holds: $(cd "$PT" && ls -1A | grep -E '^fm-' | tr '\n' ' ')"
kill -TERM "$pid"; kill -TERM "$(cat "$W/hang")" 2>/dev/null; wait "$pid"; echo "  ingest exit status: $?"
report "SIGTERM during document fetch"

echo; echo "[5] all other TMPDIR entries (non-adapter) for transparency:"; (cd "$PT" && ls -1A | sed 's/^/  /')
if [ -f "$W/remote-jobs/worker.pid" ]; then fm_remote_job_stop_worker_tree "$(cat "$W/remote-jobs/worker.pid")" >/dev/null 2>&1 || true; fi
TMPDIR="$PT" FM_HOME="$PARENT" FM_PROCEVENT_CLAIM_ROOT="$CLAIMS" "$ROOT/bin/fm-procevent.sh" sweep-home >/dev/null 2>&1 || true
[ "${KEEP:-0}" = 1 ] && echo "kept $W" || rm -rf "$W"
