#!/usr/bin/env bash
# iqx-lenses.test.sh - behavior test for the fork-only IQX lens add-on.
#
# Lives with the contrib folder on purpose: the repository's tests/ inventory
# and CI discover only tests/*.test.sh, and nothing here is wired into them.
# Run by hand: bash contrib/iqx-lenses/iqx-lenses.test.sh
# Everything runs in a temporary firstmate home with synthetic data. No real
# home, project clone, worker or network is touched; run-panel.sh runs only with --dry-run.
set -euo pipefail
# A shell may carry another home's FM_HOME; the test names its own home on every call.
unset FM_HOME

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
GEN="$here/mk-lens-brief.py"
PANEL="$here/run-panel.sh"

TMP=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/iqx-lenses-test.XXXXXX")" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
HOME_T="$TMP/home"
TICKET=TKT-1-example
PLAN_DIR="$HOME_T/data/$TICKET/plans"
mkdir -p "$PLAN_DIR/reviews" "$HOME_T/state"
printf 'plan revision 2\n' >"$PLAN_DIR/plan.md"
printf 'dispositions\n' >"$PLAN_DIR/plan-reviews.md"
printf 'what changed since the panel\n' >"$PLAN_DIR/what-changed.md"
printf 'github-copilot/model-one\ngithub-copilot/model-two.5\n' >"$HOME_T/state/shadow-models.txt"
# A pinned Ixia copy with the locked version, and one with another version.
mkdir -p "$TMP/ixia-ok/plugins/ixia-stratex/.claude-plugin" "$TMP/ixia-old/plugins/ixia-stratex/.claude-plugin"
printf '{"version": "1.0.23"}\n' >"$TMP/ixia-ok/plugins/ixia-stratex/.claude-plugin/plugin.json"
printf '{"version": "0.9.0"}\n' >"$TMP/ixia-old/plugins/ixia-stratex/.claude-plugin/plugin.json"

fails=0
pass() { echo "ok - $1"; }
fail() { echo "not ok - $1" >&2; fails=$((fails + 1)); }
check() { # check <description> <command...>
  local d=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
has() { grep -qF -- "$2" "$1"; }
hasnt() { ! grep -qF -- "$2" "$1"; }
expect_has() { # expect_has <description> <file> <fixed text>
  if has "$2" "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi
}
expect_hasnt() {
  if hasnt "$2" "$3"; then pass "$1"; else fail "$1 (found: $3)"; fi
}

scaffold() { # scaffold <task-id>: a scout brief as bin/fm-brief.sh writes it, reduced to what the generator touches
  mkdir -p "$HOME_T/data/$1"
  cat >"$HOME_T/data/$1/brief.md" <<'BRIEF'
# Task
## Captain's intent
{TASK}

## Firstmate spec
{FIRSTMATE_SPEC}

# Definition of done
Write your findings to a report.
If your deliverable is a visual artifact the captain will review and iterate on, use the lavish-axi rule: arm your board.
When the report is complete, append done.
BRIEF
}
brief() { echo "$HOME_T/data/$1/brief.md"; }

# --- the lock and the folder -------------------------------------------------
check "sources lock names the pstack commit in full" python3 - "$here/sources.lock.json" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
assert re.fullmatch(r"c742dd61[0-9a-f]{32}", d["pstack"]["commit"]), d["pstack"]["commit"]
assert d["ixia"]["version"] == "1.0.23"
assert d["pstack"]["license"] == "MIT" and "Lauren Tan" in d["pstack"]["copyright"]
PY
if grep -rIl -e 'firstmate-fdfdd8' -e '/home/node/' -e 'Vu (' -e 'iqxo' "$here" | grep -v 'iqx-lenses.test.sh' >/dev/null; then
  fail "folder holds no private home path, person name or home label"
else
  pass "folder holds no private home path, person name or home label"
fi
expect_has "lens text carries the pstack licence notice" "$here/run-proof-lens.markdown" "Copyright (c) 2026 Lauren Tan"
expect_has "lens text names the locked pstack commit" "$here/run-proof-lens.markdown" "c742dd61706fbacc1b95f1a20b7b988cf096ce6c"

# --- refusals -----------------------------------------------------------------
scaffold t-refuse
out=$(env -u FM_HOME python3 "$GEN" panel --task t-refuse --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst 2>&1) && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'no firstmate home' <<<"$out"; then pass "generator refuses without a home"; else fail "generator refuses without a home"; fi
out=$(python3 "$GEN" panel --home "$TMP/nope" --task t-refuse --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst 2>&1) && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'not a firstmate home' <<<"$out"; then pass "generator refuses a directory that is no home"; else fail "generator refuses a directory that is no home"; fi
out=$(python3 "$GEN" panel --home "$HOME_T" --task t-missing --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst 2>&1) && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'no scaffolded brief' <<<"$out"; then pass "generator refuses a task with no scaffolded brief"; else fail "generator refuses a task with no scaffolded brief"; fi
out=$(python3 "$GEN" runproof --home "$HOME_T" --task t-refuse --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" 2>&1) && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && grep -q -- '--dispositions and --changes' <<<"$out"; then pass "run-proof refuses without dispositions and the changes list"; else fail "run-proof refuses without dispositions and the changes list"; fi
out=$(FM_HOME="$HOME_T" python3 "$GEN" shadow --task t-refuse --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst 2>&1) && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'shadow needs --shadow-model' <<<"$out"; then pass "shadow refuses without a model"; else fail "shadow refuses without a model"; fi

# --- panel reviewer: read and run lens ----------------------------------------
scaffold t-arch
FM_HOME="$HOME_T" python3 "$GEN" panel --task t-arch --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens solutions-architect --extra "EXTRA-CONTEXT" >/dev/null
B=$(brief t-arch)
expect_hasnt "panel: placeholders filled" "$B" "{TASK}"
expect_hasnt "panel: placeholders filled (spec)" "$B" "{FIRSTMATE_SPEC}"
expect_has "panel: output path" "$B" "$PLAN_DIR/reviews/solutions-architect.md"
expect_has "panel: agent file" "$B" "plan-architect.md"
expect_has "panel: read and run limits" "$B" "Read and run:"
expect_has "panel: [run] and [read] labels" "$B" "[run]"
expect_has "panel: [read] label" "$B" "[read]"
expect_has "panel: probes kept beside the plan" "$B" "$PLAN_DIR/probes/panel-solutions-architect"
expect_has "panel: runnable from any checkout" "$B" "git rev-parse --show-toplevel"
expect_has "panel: known S4P facts" "$B" "SAP_BUPA_BUPTDTRANSMIT"
expect_has "panel: no second round, lens checks the revision" "$B" "There is no second panel round"
expect_has "panel: role kept" "$B" "product decisions, documentation, wording, order across tickets, tenancy and cost"
expect_has "panel: home pinned for fm scripts" "$B" "set FM_HOME=$HOME_T explicitly"
expect_has "panel: never DGW" "$B" "Never use the arc-dgw or arc-dgw-fab MCP servers"
expect_has "panel: never the feedback skill" "$B" "Never run the Ixia feedback skill"
expect_has "panel: standing rule" "$B" "standing rule: every Ixia plan-gate review panel runs as separate fresh-context reviewer processes"
expect_has "panel: extra context kept" "$B" "EXTRA-CONTEXT"
expect_has "panel: clone mode reads credentials by path" "$B" "inside node or python by path"
expect_has "panel: report pointer" "$B" "'Report: <output path>'"
expect_has "panel: board work removed" "$B" "No board work: do not arm, poll or edit any board."
expect_hasnt "panel: lavish line gone" "$B" "arm your board"
out=$(FM_HOME="$HOME_T" python3 "$GEN" panel --task t-arch --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens solutions-architect 2>&1) && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'exactly once' <<<"$out"; then pass "generator refuses an already filled brief"; else fail "generator refuses an already filled brief"; fi

# --- panel reviewer: read-only lens -------------------------------------------
scaffold t-ba
python3 "$GEN" panel --home "$HOME_T" --task t-ba --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst >/dev/null
B=$(brief t-ba)
expect_has "BA: read-only limits" "$B" "Read-only: Read, Grep, Glob and git read commands"
expect_hasnt "BA: no probe-file rule" "$B" "Probe files (read-and-run lenses)"
expect_has "BA: agent file" "$B" "plan-ba.md"

# --- shadow reviewer ------------------------------------------------------------
scaffold t-sh
python3 "$GEN" shadow --home "$HOME_T" --task t-sh --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens security-architect --shadow-model github-copilot/gpt-6.1-sol >/dev/null
B=$(brief t-sh)
expect_has "shadow: output path" "$B" "$PLAN_DIR/reviews/shadow/security-architect-gpt-6.1-sol.md"
expect_has "shadow: never counts for dispositions" "$B" "its output never counts for dispositions"
expect_has "shadow: benchmark role" "$B" "SHADOW benchmark reviewer on github-copilot/gpt-6.1-sol"

# --- panel with the pinned Ixia copy and a version check ----------------------------
scaffold t-pin
err=$(python3 "$GEN" panel --home "$HOME_T" --task t-pin --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst --ixia-source pinned --ixia-dir "$TMP/ixia-old" 2>&1 >/dev/null)
if grep -q 'pinned Ixia copy is version 0.9.0, the sources lock says 1.0.23' <<<"$err"; then pass "pinned copy of another version is reported"; else fail "pinned copy of another version is reported"; fi
expect_has "pinned: path named, never cloned" "$(brief t-pin)" "never clone it again"

# --- run-proof lens -----------------------------------------------------------------
scaffold t-rp
err=$(python3 "$GEN" runproof --home "$HOME_T" --task t-rp --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" \
  --dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" \
  --seed "TICKET-SEED-ONE" --ixia-dir "$TMP/ixia-ok" 2>&1 >/dev/null)
B=$(brief t-rp)
if [ -z "$err" ]; then pass "run-proof: matching pinned copy gives no warning"; else fail "run-proof: matching pinned copy gives no warning ($err)"; fi
expect_has "run-proof: output path" "$B" "$PLAN_DIR/reviews/run-proof-claude-opus-5.5.md"
expect_has "run-proof: one output path" "$B" "ONE OUTPUT PATH: $PLAN_DIR/reviews/run-proof-claude-opus-5.5.md"
expect_has "run-proof: one read order" "$B" "ONE READ ORDER"
expect_has "run-proof: lens text embedded" "$B" "BEGIN LENS TEXT (run-proof-lens.markdown)"
expect_has "run-proof: licence notice embedded" "$B" "Copyright (c) 2026 Lauren Tan"
expect_has "run-proof: checklist embedded" "$B" "BEGIN CHECKLIST (orchestration-checklist.markdown)"
expect_has "run-proof: fixed checklist item" "$B" "A padded SAP number on every view"
expect_has "run-proof: three Resume seeds" "$B" "A Resume after a newer opposite event"
expect_has "run-proof: sources lock embedded" "$B" "c742dd61706fbacc1b95f1a20b7b988cf096ce6c"
expect_has "run-proof: Ixia version in lock" "$B" '"version": "1.0.23"'
expect_has "run-proof: ticket seed" "$B" "TICKET-SEED-ONE"
expect_has "run-proof: known S4P facts" "$B" "SAP_BUPA_BUPTDTRANSMIT"
expect_has "run-proof: pinned Ixia copy" "$B" "$TMP/ixia-ok/plugins/ixia-stratex"
expect_has "run-proof: probes folder" "$B" "$PLAN_DIR/probes/run-proof-claude-opus-5.5"
expect_has "run-proof: never DGW" "$B" "Never use the arc-dgw or arc-dgw-fab MCP servers"
expect_has "run-proof: never the feedback skill" "$B" "Never run the Ixia feedback skill"
expect_has "run-proof: no dispositions" "$B" "No dispositions."
disp_at=$(grep -n -F "the dispositions $PLAN_DIR/plan-reviews.md" "$B" | head -1 | cut -d: -f1)
notyet_at=$(grep -n -F "6. NOT YET: the panel reviews" "$B" | head -1 | cut -d: -f1)
if [ -n "$disp_at" ] && [ -n "$notyet_at" ] && [ "$disp_at" -lt "$notyet_at" ]; then pass "run-proof: dispositions are read before the panel reviews"; else fail "run-proof: dispositions are read before the panel reviews"; fi
expect_has "run-proof: panel reviews only after the freeze" "$B" "Read them only after the line FROZEN is in your report"
expect_hasnt "run-proof: no second-model note without a touch" "$B" "Second-model rule"
expect_hasnt "run-proof: placeholders filled" "$B" "{FIRSTMATE_SPEC}"

# --- run-proof second-model rule ---------------------------------------------------------
scaffold t-rp2
err=$(python3 "$GEN" runproof --home "$HOME_T" --task t-rp2 --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" \
  --dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --touches runner --touches resume 2>&1 >/dev/null)
if grep -q 'second-model: required (plan changes runner, resume)' <<<"$err"; then pass "second-model run is called for"; else fail "second-model run is called for ($err)"; fi
expect_has "run-proof: second-model rule in the first brief" "$(brief t-rp2)" "Second-model rule: this plan changes runner, resume"
scaffold t-rp3
python3 "$GEN" runproof --home "$HOME_T" --task t-rp3 --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --model github-copilot/gpt-6.1-sol \
  --dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --touches identity >/dev/null 2>&1
expect_has "run-proof: second model gets its own output path" "$(brief t-rp3)" "$PLAN_DIR/reviews/run-proof-gpt-6.1-sol.md"
expect_has "run-proof: second model reads no first report before freeze" "$(brief t-rp3)" "Second-model run: you are the second process"

# --- --stdout leaves the brief alone --------------------------------------------------------
scaffold t-so
python3 "$GEN" panel --home "$HOME_T" --task t-so --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst --stdout >"$TMP/stdout.md"
expect_has "--stdout prints the filled brief" "$TMP/stdout.md" "business-analyst reviewer for the plan"
expect_has "--stdout leaves the scaffold unchanged" "$(brief t-so)" "{TASK}"

# --- run-panel.sh, dry run only ------------------------------------------------------------------
out=$(env -u FM_HOME bash "$PANEL" --ticket-dir "$TICKET" --key TKT-1 --plan "$PLAN_DIR/plan.md" --dry-run 2>&1) && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'no firstmate home' <<<"$out"; then pass "run-panel refuses without a home"; else fail "run-panel refuses without a home"; fi
out=$(bash "$PANEL" --home "$HOME_T" --ticket-dir "$TICKET" --key TKT-1 --plan "$PLAN_DIR/plan.md" --dry-run 2>&1)
for want in "TKT-1-rev-arch" "TKT-1-rev-sec" "TKT-1-rev-ba" "--model github-copilot/claude-sonnet-5.5" "--harness pi" "--effort high" "--base-branch development/preview"; do
  if grep -qF -- "$want" <<<"$out"; then pass "run-panel real mode: $want"; else fail "run-panel real mode: $want"; fi
done
if grep -q 'would run: env FM_HOME=' <<<"$out"; then pass "run-panel pins FM_HOME on every spawn"; else fail "run-panel pins FM_HOME on every spawn"; fi
if [ -e "$HOME_T/data/TKT-1-rev-arch" ]; then fail "run-panel dry run writes nothing"; else pass "run-panel dry run writes nothing"; fi
out=$(bash "$PANEL" --home "$HOME_T" --ticket-dir "$TICKET" --key TKT-1 --plan "$PLAN_DIR/plan.md" --mode shadow-sec --dry-run 2>&1)
if grep -q 'TKT-1-sh-sec-model-one' <<<"$out" && grep -q 'TKT-1-sh-sec-model-two5' <<<"$out" && grep -q -- '--model github-copilot/model-two.5' <<<"$out"; then pass "run-panel shadow mode reads the models file"; else fail "run-panel shadow mode reads the models file"; fi
out=$(bash "$PANEL" --home "$HOME_T" --ticket-dir "$TICKET" --key TKT-1 --plan "$PLAN_DIR/plan.md" --mode runproof \
  --dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --touches identity --dry-run 2>&1)
if grep -q 'TKT-1-runproof-2' <<<"$out" && grep -q -- '--model github-copilot/gpt-6.1-sol' <<<"$out"; then pass "run-panel run-proof adds the second model for a touch"; else fail "run-panel run-proof adds the second model for a touch"; fi
out=$(bash "$PANEL" --home "$HOME_T" --ticket-dir "$TICKET" --key TKT-1 --plan "$PLAN_DIR/plan.md" --mode runproof \
  --dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --dry-run 2>&1)
if grep -q 'TKT-1-runproof' <<<"$out" && ! grep -q 'TKT-1-runproof-2' <<<"$out"; then pass "run-panel run-proof runs one model without a touch"; else fail "run-panel run-proof runs one model without a touch"; fi

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed" >&2; exit 1; fi
