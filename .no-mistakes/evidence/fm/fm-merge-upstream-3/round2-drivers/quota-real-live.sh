#!/usr/bin/env bash
set -eu
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M467Y2KVPY0ZYM8V5V6DQB86
LAB=$(mktemp -d "$ROOT/.validation/tmp/quota-real.XXXXXX")
trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/config" "$LAB/cache" "$LAB/claude" "$LAB/codex"
cat > "$LAB/fault.cjs" <<'JS'
// Test-only fault injection in the real quota-axi process: the executable is
// never replaced and every successful read traverses its real snapshot reader,
// semantics calculator and JSON renderer. All provider data is disposable.
const fs=require('node:fs');
if(process.argv[1]?.endsWith('/quota-axi') || process.argv[1]?.endsWith('/quota-axi.js')) {
 if(process.argv.includes('--json')) {
  let n=fs.existsSync(process.env.PROBE_COUNT)?Number(fs.readFileSync(process.env.PROBE_COUNT,'utf8')):0;
  fs.writeFileSync(process.env.PROBE_COUNT,String(++n));
  const c=process.env.PROBE_CASE;
  const fail=c==='persistent'||n<3||(c==='reset'&&(n===4||n===5));
  fs.appendFileSync(process.env.PROBE_TRACE,JSON.stringify({attempt:n,argv:process.argv.slice(1),effect:fail?'injected dependency failure':'real snapshot read'})+'\n');
  if(fail&&c==='timeout')Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,10000);
  if(fail)throw new Error('Intentional transient dependency-process failure');
  const remaining=c==='reset'&&n===3?70:0;
  fs.writeFileSync(process.env.QUOTA_AXI_SNAPSHOT,JSON.stringify({schemaVersion:3,generatedAt:new Date().toISOString(),providers:[{provider:'codex',label:'Codex',source:'api',state:{status:'fresh',stale:false,refreshedAt:new Date().toISOString(),sourcesTried:['snapshot']},windows:[{id:'five_hour',label:'session',kind:'session',percentUsed:100-remaining,percentRemaining:remaining,windowSeconds:18000,resetsAt:new Date(Date.now()+3600000).toISOString()}]}]}));
 }
}
JS
for CASE in transient reset persistent timeout; do
 : > "$E/round2-real-quota-$CASE-calls.jsonl"
 HOME="$LAB" XDG_CONFIG_HOME="$LAB/config" XDG_CACHE_HOME="$LAB/cache" CLAUDE_CONFIG_DIR="$LAB/claude" CODEX_HOME="$LAB/codex" \
 NODE_OPTIONS="--require=$LAB/fault.cjs" QUOTA_AXI_SNAPSHOT="$LAB/snapshot.json" PROBE_CASE="$CASE" PROBE_COUNT="$LAB/$CASE.count" PROBE_TRACE="$E/round2-real-quota-$CASE-calls.jsonl" \
 bin/fm-procevent-quota.sh poll --provider codex --interval 0.01 --timeout 2 > "$E/round2-real-quota-$CASE.txt"
 case "$CASE" in
  transient|timeout) grep -qx 'status: exhausted' "$E/round2-real-quota-$CASE.txt"; grep -qx 'condition_polls: 3' "$E/round2-real-quota-$CASE.txt" ;;
  reset) grep -qx 'status: exhausted' "$E/round2-real-quota-$CASE.txt"; grep -qx 'condition_polls: 6' "$E/round2-real-quota-$CASE.txt" ;;
  persistent) grep -qx 'status: error' "$E/round2-real-quota-$CASE.txt"; grep -q '^detail: 3 consecutive read failures;' "$E/round2-real-quota-$CASE.txt" ;;
 esac
 printf '%s: real quota-axi consumed isolated snapshot; poller produced:\n' "$CASE"
 tail -4 "$E/round2-real-quota-$CASE.txt"
done
