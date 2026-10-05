#!/usr/bin/env bash
set -eu
ROOT=$PWD
E=/home/node/.no-mistakes/evidence/01M467Y2KVPY0ZYM8V5V6DQB86
LAB=$(mktemp -d "$ROOT/.validation/tmp/quota-proof.XXXXXX")
trap 'rm -rf "$LAB"' EXIT
mkdir "$LAB/bin"
cat > "$LAB/bin/quota-axi" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then printf 'quota-axi 0.1.51\n'; exit 0; fi
n=0; [ ! -f "$QUOTA_FEED_COUNT" ] || read -r n < "$QUOTA_FEED_COUNT"
n=$((n+1)); printf '%s\n' "$n" > "$QUOTA_FEED_COUNT"
case "$QUOTA_FEED_CASE:$n" in
  transient:1|transient:2|reset:1|reset:2|reset:4|reset:5|persistent:*) exit 42 ;;
  reset:3) percent=70; runway=through_reset ;;
  *) percent=0; runway=exhausted_now ;;
esac
printf '{"schemaVersion":5,"providers":[{"provider":"codex","quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":%s,"runway":{"status":"%s"}}]}}]}\n' "$percent" "$runway"
SH
chmod +x "$LAB/bin/quota-axi"
for SCENARIO in transient reset persistent; do
  PATH="$LAB/bin:$PATH" QUOTA_FEED_COUNT="$LAB/$SCENARIO.count" QUOTA_FEED_CASE="$SCENARIO" \
    "$ROOT/bin/fm-procevent-quota.sh" poll --provider codex --interval 0.01 --timeout 1 > "$E/quota-$SCENARIO.txt"
  case "$SCENARIO" in
    transient) grep -q '^status: exhausted$' "$E/quota-$SCENARIO.txt"; grep -q '^condition_polls: 3$' "$E/quota-$SCENARIO.txt" ;;
    reset) grep -q '^status: exhausted$' "$E/quota-$SCENARIO.txt"; grep -q '^condition_polls: 6$' "$E/quota-$SCENARIO.txt" ;;
    persistent) grep -q '^status: error$' "$E/quota-$SCENARIO.txt"; grep -q '^detail: 3 consecutive read failures;' "$E/quota-$SCENARIO.txt" ;;
  esac
done
printf 'Production quota poller consumed disposable provider feeds: two transient failures recovered; a healthy read reset the failure streak; three consecutive failures surfaced an error.\n'
