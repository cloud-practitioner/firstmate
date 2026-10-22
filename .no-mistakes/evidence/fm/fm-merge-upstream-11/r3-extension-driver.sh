#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EV=/home/node/.no-mistakes/evidence/01M5GMXRP8TEGYK8ZJPXTCW65Z
LAB=$(mktemp -d "$ROOT/.l.XXXXXX")
PKG=$(mktemp -d "$EV/.r3-fixtures/file-signal.XXXXXX")
listener=
cleanup() { [ -z "$listener" ] || { kill "$listener" 2>/dev/null || true; wait "$listener" 2>/dev/null || true; }; chmod -R u+w "$LAB" "$PKG"; rm -rf "$LAB" "$PKG"; }
trap cleanup EXIT
bin/fm-lab-home.sh create "$LAB"
export FM_HOME="$LAB" HOME="$LAB/user" FM_PROCEVENT_CLAIM_ROOT="$LAB/claims" XDG_STATE_HOME="$LAB/xdg-state" FM_BACKEND=tmux
mkdir -p "$HOME" "$FM_PROCEVENT_CLAIM_ROOT"
cp -R docs/examples/process-event-extension/. "$PKG/"
chmod 755 "$PKG" "$PKG/file-signal.mjs"
chmod 644 "$PKG/firstmate-extension.json"
printf '\n=== Bind and verify shipped file-signal adapter through actual Bash lifecycle ===\n'
binding=$(bin/fm-extension.sh bind "$PKG" --adapter file-signal --trust-same-user-code --consent artifact-references)
printf '%s\n' "$binding"
digest=$(printf '%s\n' "$binding" | awk '/^binding-digest:/{print $2}')
bin/fm-extension.sh verify org.firstmate.example.file-signal
printf '\n=== Register a real external file event ===\n'
registration=$(bin/fm-procevent.sh register-extension file-signal build-observer --config-ref "file:$LAB/build-result.txt")
printf '%s\n' "$registration"
owner=$(printf '%s\n' "$registration" | awk '/^owner-token:/{print $2}')
bin/fm-procevent.sh start build-observer > "$LAB/listener.out" 2>&1 & listener=$!
for ((i=0;i<100;i++)); do [ ! -f "$LAB/claims/build-observer.claim" ] || break; sleep .1; done
[ -f "$LAB/claims/build-observer.claim" ]
printf 'build 42 completed successfully\n' > "$LAB/build-result.txt"
wait "$listener"; listener=
printf '\n=== Captured evidence and actual lifecycle output ===\n'
python3 - "$LAB/listener.out" <<'PY'
import sys
print(open(sys.argv[1]).read())
PY
result=$(find "$LAB/state/procevent-inbox" -type f -name '*.result' | head -1)
[ -n "$result" ]
cp "$result" "$EV/r3-extension-captured.result"
python3 - "$result" <<'PY'
import sys
s=open(sys.argv[1]).read(); print(s); assert 'build 42 completed successfully' in s
PY
bin/fm-procevent.sh classify "$result"
[ ! -e "$LAB/state/procevent/build-observer.source" ]
printf 'terminal_source_retired=yes\n'
bin/fm-procevent.sh retire build-observer --if-owner "$owner"
printf '\n=== Acknowledge the captured event and retire the binding ===\n'
seq=${result##*/}; seq=${seq#build-observer.}; seq=${seq%.result}
bin/fm-procevent.sh handled build-observer "$seq"
bin/fm-extension.sh retire-binding org.firstmate.example.file-signal --if-binding-digest "$digest"
