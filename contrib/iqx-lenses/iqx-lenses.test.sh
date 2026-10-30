#!/usr/bin/env bash
# iqx-lenses.test.sh - behavior test for the fork-only IQX lens add-on.
#
# Lives with the contrib folder on purpose: the repository's tests/ inventory
# and CI discover only tests/*.test.sh, and nothing here is wired into them.
# Run by hand: bash contrib/iqx-lenses/iqx-lenses.test.sh
# Everything runs in a temporary firstmate home with synthetic data. No real
# home, project clone, worker or network is touched.
set -euo pipefail
# A shell may carry another home's FM_HOME; the test names its own home on every call.
unset FM_HOME

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
GEN="$here/mk-lens-brief.py"
ROOT=$(cd "$here/../.." && pwd -P)

TMP=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/iqx-lenses-test.XXXXXX")" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
HOME_T="$TMP/home"
TICKET=TKT-1-example
PLAN_DIR="$HOME_T/data/$TICKET/plans"
mkdir -p "$PLAN_DIR/reviews" "$HOME_T/state"
printf 'plan revision 2\n' >"$PLAN_DIR/plan.md"
printf 'dispositions\n' >"$PLAN_DIR/plan-reviews.md"
printf 'what changed since the panel\n' >"$PLAN_DIR/what-changed.md"
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

scaffold() {
  local task=$1 branch=${2-development/preview}
  set --
  if [ -n "$branch" ]; then set -- --base-branch "$branch"; fi
  FM_HOME="$HOME_T" FM_ROOT_OVERRIDE="$ROOT" FM_DATA_OVERRIDE="$HOME_T/data" \
    FM_STATE_OVERRIDE="$HOME_T/state" FM_CONFIG_OVERRIDE="$HOME_T/config" \
    bash "$ROOT/bin/fm-brief.sh" "$task" synthetic-module --scout "$@" >/dev/null
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
expect_has "panel: report pointer" "$B" "Report: $PLAN_DIR/reviews/solutions-architect.md"
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
python3 "$GEN" shadow --home "$HOME_T" --task t-sh --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens security-architect --shadow-model github-copilot/gpt-6.1-sol --extra "SHADOW-EXTRA-CONTEXT" >/dev/null
B=$(brief t-sh)
expect_has "shadow: output path" "$B" "$PLAN_DIR/reviews/shadow/security-architect-github-copilot%2Fgpt-6.1-sol.md"
expect_has "shadow: never counts for dispositions" "$B" "its output never counts for dispositions"
expect_has "shadow: benchmark role" "$B" "SHADOW benchmark reviewer on github-copilot/gpt-6.1-sol"
expect_has "shadow: extra context kept" "$B" "SHADOW-EXTRA-CONTEXT"

# --- panel with the pinned Ixia copy and a version check ----------------------------
scaffold t-pin
err=$(python3 "$GEN" panel --home "$HOME_T" --task t-pin --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst --ixia-source pinned --ixia-dir "$TMP/ixia-old" 2>&1 >/dev/null)
if grep -q 'pinned Ixia copy is version 0.9.0, the sources lock says 1.0.23' <<<"$err"; then pass "pinned copy of another version is reported"; else fail "pinned copy of another version is reported"; fi
expect_has "pinned: path named, never cloned" "$(brief t-pin)" "never clone it again"

# --- run-proof lens -----------------------------------------------------------------
scaffold t-rp
err=$(python3 "$GEN" runproof --home "$HOME_T" --task t-rp --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" \
  --dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" \
  --seed "TICKET-SEED-ONE" --ixia-dir "$TMP/ixia-ok" --extra "RUNPROOF-EXTRA-CONTEXT" 2>&1 >/dev/null)
B=$(brief t-rp)
if [ -z "$err" ]; then pass "run-proof: matching pinned copy gives no warning"; else fail "run-proof: matching pinned copy gives no warning ($err)"; fi
expect_has "run-proof: output path" "$B" "$PLAN_DIR/reviews/run-proof-claude-opus-5.5.md"
expect_has "run-proof: one output path" "$B" "ONE OUTPUT PATH: $PLAN_DIR/reviews/run-proof-claude-opus-5.5.md"
expect_has "run-proof: one read order" "$B" "ONE READ ORDER"
expect_has "run-proof: lens text embedded" "$B" "BEGIN LENS TEXT (run-proof-lens.markdown)"
check "run-proof: emitted pstack MIT notice contract" python3 - "$B" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
notice = text.split("pstack licence notice", 1)[1].split("```", 2)[1].strip()
assert notice == '''MIT License

Copyright (c) 2026 Lauren Tan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.'''
PY
expect_has "run-proof: checklist embedded" "$B" "BEGIN CHECKLIST (orchestration-checklist.markdown)"
expect_has "run-proof: fixed checklist item" "$B" "A padded SAP number on every view"
expect_has "run-proof: three Resume seeds" "$B" "A Resume after a newer opposite event"
expect_has "run-proof: sources lock embedded" "$B" "c742dd61706fbacc1b95f1a20b7b988cf096ce6c"
expect_has "run-proof: Ixia version in lock" "$B" '"version": "1.0.23"'
expect_has "run-proof: ticket seed" "$B" "TICKET-SEED-ONE"
expect_has "run-proof: extra context delivered with first inputs" "$B" "Aim the attack at the text the dispositions and the changes wrote (lens text, section 4, step 2). RUNPROOF-EXTRA-CONTEXT"
expect_has "run-proof: classes require repository coverage to leave" "$B" "Required seed and checklist classes leave the list only when a repository test covers them, not after a number of clean runs."
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
  --dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --ixia-dir "$TMP/ixia-ok" --touches runner --touches resume 2>&1 >/dev/null)
if grep -q 'second-model: required (plan changes runner, resume)' <<<"$err"; then pass "second-model run is called for"; else fail "second-model run is called for ($err)"; fi
expect_has "run-proof: second-model rule in the first brief" "$(brief t-rp2)" "Second-model rule: this plan changes runner, resume"
scaffold t-rp3
python3 "$GEN" runproof --home "$HOME_T" --task t-rp3 --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --model github-copilot/gpt-6.1-sol \
  --dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --ixia-dir "$TMP/ixia-ok" --touches identity >/dev/null 2>&1
expect_has "run-proof: second model gets its own output path" "$(brief t-rp3)" "$PLAN_DIR/reviews/run-proof-gpt-6.1-sol.md"
expect_has "run-proof: second model reads no first report before freeze" "$(brief t-rp3)" "Second-model run: you are the second process"

# --- --stdout leaves the brief alone --------------------------------------------------------
scaffold t-so
python3 "$GEN" panel --home "$HOME_T" --task t-so --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst --stdout >"$TMP/stdout.md"
expect_has "--stdout prints the filled brief" "$TMP/stdout.md" "business-analyst reviewer for the plan"
expect_has "--stdout leaves the scaffold unchanged" "$(brief t-so)" "{TASK}"

for kind in panel shadow; do
  for lens in solutions-architect security-architect business-analyst ux-designer; do
    task="t-$kind-$lens"
    scaffold "$task"
    args=("$kind" --home "$HOME_T" --task "$task" --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens "$lens")
    if [ "$kind" = shadow ]; then args+=(--shadow-model github-copilot/gpt-6.1-sol); fi
    python3 "$GEN" "${args[@]}" >/dev/null
  done
done
check "real scout output contracts agree for every reviewer kind and lens" python3 - "$HOME_T" "$PLAN_DIR" "$TMP/stdout.md" <<'PY'
import pathlib, re, sys
home, plans, stdout = map(pathlib.Path, sys.argv[1:])
cases = [
    ("t-arch", plans / "reviews/solutions-architect.md", plans / "probes/panel-solutions-architect"),
    ("t-ba", plans / "reviews/business-analyst.md", None),
    ("t-sh", plans / "reviews/shadow/security-architect-github-copilot%2Fgpt-6.1-sol.md", plans / "probes/shadow-security-architect-github-copilot%2Fgpt-6.1-sol"),
    ("t-pin", plans / "reviews/business-analyst.md", None),
    ("t-rp", plans / "reviews/run-proof-claude-opus-5.5.md", plans / "probes/run-proof-claude-opus-5.5"),
    ("t-rp2", plans / "reviews/run-proof-claude-opus-5.5.md", plans / "probes/run-proof-claude-opus-5.5"),
    ("t-rp3", plans / "reviews/run-proof-gpt-6.1-sol.md", plans / "probes/run-proof-gpt-6.1-sol"),
    ("t-so", plans / "reviews/business-analyst.md", None),
]
for kind in ("panel", "shadow"):
    for lens in ("solutions-architect", "security-architect", "business-analyst", "ux-designer"):
        reviewer = lens if kind == "panel" else lens + "-github-copilot%2Fgpt-6.1-sol"
        output = plans / "reviews" / (reviewer + ".md" if kind == "panel" else "shadow/" + reviewer + ".md")
        probes = plans / ("probes/" + kind + "-" + reviewer) if lens.endswith("architect") else None
        cases.append(("t-" + kind + "-" + lens, output, probes))
for task, output, probes in cases:
    text = (stdout if task == "t-so" else home / "data" / task / "brief.md").read_text()
    pointer = home / "data" / task / "report.md"
    rule = next(line for line in text.splitlines() if line.startswith("2. Stay inside this worktree;"))
    expected = [str(output), str(pointer)] + ([str(probes)] if probes else [])
    assert re.findall(r"`([^`]+)`", rule) == expected, (task, rule)
    assert rule.endswith("the status file below, and scratch files under your task temp root."), (task, rule)
    dod = text.split("# Definition of done\n", 1)[1]
    assert dod.startswith("Write your findings to `" + str(output) + "`.\nThe report must stand alone:"), (task, dod)
    assert "Write `" + str(pointer) + "` as a single line `Report: " + str(output) + "` and nothing else; it is only the scout completion pointer." in dod, (task, dod)
    assert "Before reporting done, read and follow" in dod, task
    assert "When the report is complete, append `done [at=<epoch>]: {one-line conclusion}`" in dod, task
    assert "Say the plugin version you read in the report header" in text, task
    assert "{TASK}" not in text and "{FIRSTMATE_SPEC}" not in text, task
PY

for kind in panel shadow runproof runproof-second; do
  for base_case in named standard default; do
    case "$base_case" in
      named) branch=feature/revision; wrong=development/preview ;;
      standard) branch=development/preview; wrong=feature/revision ;;
      default) branch=; wrong=development/preview ;;
    esac
    task="t-base-$kind-$base_case"
    scaffold "$task" "$branch"
    B=$(brief "$task")
    cp "$B" "$TMP/base-before.md"
    args=("${kind%-second}" --home "$HOME_T" --task "$task" --ticket "$TICKET" --plan "$PLAN_DIR/plan.md")
    case "$kind" in
      panel) args+=(--lens solutions-architect) ;;
      shadow) args+=(--lens security-architect --shadow-model github-copilot/gpt-6.1-sol) ;;
      runproof|runproof-second) args+=(--dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --ixia-dir "$TMP/ixia-ok") ;;
    esac
    if [ "$kind" = runproof-second ]; then args+=(--model github-copilot/gpt-6.1-sol); fi
    python3 "$GEN" "${args[@]}" --stdout >"$TMP/base-output.md"
    if [ -n "$branch" ]; then
      expect_has "$kind: inherits $base_case base in setup" "$TMP/base-output.md" "Base branch: $branch"
      expect_has "$kind: inherits $base_case base in review inputs" "$TMP/base-output.md" "at origin/$branch "
      python3 "$GEN" "${args[@]}" --base-branch "$branch" --stdout >"$TMP/base-match.md"
      check "$kind: matching explicit $base_case base preserves output" cmp -s "$TMP/base-output.md" "$TMP/base-match.md"
    else
      expect_has "$kind: default-branch setup retained" "$TMP/base-output.md" "at a detached HEAD on a clean default branch."
      expect_has "$kind: default-branch review inputs agree" "$TMP/base-output.md" "at the default-branch checkout named in Setup "
      expect_hasnt "$kind: no hardcoded default branch" "$TMP/base-output.md" "origin/development/preview"
    fi
    check "$kind: inherited $base_case stdout leaves scaffold untouched" cmp -s "$B" "$TMP/base-before.md"
    for delivery in write stdout; do
      delivery_args=()
      if [ "$delivery" = stdout ]; then delivery_args=(--stdout); fi
      out=$(python3 "$GEN" "${args[@]}" --base-branch "$wrong" ${delivery_args[@]+"${delivery_args[@]}"} 2>&1) && rc=0 || rc=$?
      if [ "$rc" -ne 0 ] && grep -q "does not match the scaffold's base" <<<"$out" && cmp -s "$B" "$TMP/base-before.md"; then
        pass "$kind: mismatched $base_case base refused before $delivery"
      else
        fail "$kind: mismatched $base_case base refused before $delivery"
      fi
    done
    python3 "$GEN" "${args[@]}" >/dev/null
    check "$kind: inherited $base_case write matches stdout" cmp -s "$B" "$TMP/base-output.md"
  done
done

for lens in solutions-architect security-architect; do
  for variant in other-provider other-model; do
    case "$variant" in
      other-provider) model=openai/gpt-6.1-sol ;;
      other-model) model=github-copilot/claude-opus-5.5 ;;
    esac
    task="t-shadow-$variant-$lens"
    scaffold "$task"
    python3 "$GEN" shadow --home "$HOME_T" --task "$task" --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" \
      --lens "$lens" --shadow-model "$model" >/dev/null
  done
done
check "concurrent architect reviewers retain separate reports and same-named probes" python3 - "$HOME_T" "$PLAN_DIR" <<'PY'
import pathlib, re, sys
home, plans = map(pathlib.Path, sys.argv[1:])
artifacts = {}
for lens in ("solutions-architect", "security-architect"):
    cases = [
        ("t-panel-" + lens, plans / ("reviews/" + lens + ".md"), plans / ("probes/panel-" + lens)),
        ("t-shadow-" + lens, plans / ("reviews/shadow/" + lens + "-github-copilot%2Fgpt-6.1-sol.md"), plans / ("probes/shadow-" + lens + "-github-copilot%2Fgpt-6.1-sol")),
        ("t-shadow-other-provider-" + lens, plans / ("reviews/shadow/" + lens + "-openai%2Fgpt-6.1-sol.md"), plans / ("probes/shadow-" + lens + "-openai%2Fgpt-6.1-sol")),
        ("t-shadow-other-model-" + lens, plans / ("reviews/shadow/" + lens + "-github-copilot%2Fclaude-opus-5.5.md"), plans / ("probes/shadow-" + lens + "-github-copilot%2Fclaude-opus-5.5")),
    ]
    for task, output, probes in cases:
        text = (home / "data" / task / "brief.md").read_text()
        rule = next(line for line in text.splitlines() if line.startswith("2. Stay inside this worktree;"))
        permitted = re.findall(r"`([^`]+)`", rule)
        assert permitted[0] == str(output), (task, permitted)
        assert permitted[2] == str(probes), (task, permitted)
        assert "keep each throwaway probe you run as a file under " + str(probes) + ", runnable from any checkout" in text, task
        assert "Write your findings to `" + str(output) + "`." in text, task
        for artifact in (output, probes / "check-target.ts"):
            assert artifact not in artifacts, (task, artifact)
            artifact.parent.mkdir(parents=True, exist_ok=True)
            artifact.write_text(task)
            artifacts[artifact] = task
for artifact, task in artifacts.items():
    assert artifact.read_text() == task, (task, artifact)
PY

for kind in panel shadow runproof runproof-second; do
  for source in pinned clone; do
    for form in relative absolute; do
      scaffold "t-path-$kind-$source-$form"
    done
  done
done
check "dependency paths identify the checked files from another working directory" python3 - "$GEN" "$HOME_T" "$PLAN_DIR" "$TMP" <<'PY'
import json, os, pathlib, re, subprocess, sys
gen, home, plans, tmp = map(pathlib.Path, sys.argv[1:])
invocation = tmp / "invocation"
worker = tmp / "worker"
worker.mkdir()
ixia = invocation / "vendor/ixia"
plugin = ixia / "plugins/ixia-stratex"
(plugin / ".claude-plugin").mkdir(parents=True)
(plugin / ".claude-plugin/plugin.json").write_text('{"version": "0.9.0"}\n')
(plugin / "agents").mkdir()
for agent in ("plan-architect.md", "plan-security.md"):
    (plugin / "agents" / agent).write_text("synthetic " + agent)
credential = invocation / "credentials/bitbucket.env"
credential.parent.mkdir()
credential.write_text("SYNTHETIC_CREDENTIAL_FILE\n")
os.chdir(worker)
for kind in ("panel", "shadow", "runproof", "runproof-second"):
    for source in ("pinned", "clone"):
        for form in ("relative", "absolute"):
            task = "t-path-" + kind + "-" + source + "-" + form
            brief = home / "data" / task / "brief.md"
            before = brief.read_text()
            args = [sys.executable, str(gen), kind.split("-")[0], "--home", str(home), "--task", task,
                    "--ticket", plans.parent.name, "--plan", str(plans / "plan.md"), "--ixia-source", source]
            agent = None
            if kind == "panel":
                agent = "plan-architect.md"
                args += ["--lens", "solutions-architect"]
            elif kind == "shadow":
                agent = "plan-security.md"
                args += ["--lens", "security-architect", "--shadow-model", "github-copilot/gpt-6.1-sol"]
            else:
                args += ["--dispositions", str(plans / "plan-reviews.md"), "--changes", str(plans / "what-changed.md")]
                if kind == "runproof-second":
                    args += ["--model", "github-copilot/gpt-6.1-sol"]
            dependency = ixia if source == "pinned" else credential
            supplied = str(dependency) if form == "absolute" else os.path.relpath(dependency, invocation)
            args += ["--ixia-dir" if source == "pinned" else "--bitbucket-env", supplied]
            emitted = subprocess.run(args + ["--stdout"], cwd=invocation, capture_output=True, text=True, check=True)
            assert brief.read_text() == before, task
            written = subprocess.run(args, cwd=invocation, capture_output=True, text=True, check=True)
            assert brief.read_text() == emitted.stdout, task
            assert written.stderr == emitted.stderr, task
            if source == "pinned":
                match = re.search(r"pinned local copy (.*?) \(never edit it", emitted.stdout)
                delivered = pathlib.Path(match.group(1))
                assert delivered.is_absolute() and delivered == plugin, (task, delivered)
                assert json.loads((delivered / ".claude-plugin/plugin.json").read_text())["version"] == "0.9.0", task
                assert "pinned Ixia copy is version 0.9.0, the sources lock says 1.0.23" in emitted.stderr, task
                if agent:
                    assert "Read " + str(delivered / "agents" / agent) + " in full" in emitted.stdout, task
                    assert (delivered / "agents" / agent).read_text() == "synthetic " + agent, task
            else:
                match = re.search(r"Bitbucket credentials: read (.*?) inside node or python by path;", emitted.stdout)
                delivered = pathlib.Path(match.group(1))
                assert delivered.is_absolute() and delivered == credential, (task, delivered)
                assert delivered.read_text() == "SYNTHETIC_CREDENTIAL_FILE\n", task
                assert "SYNTHETIC_CREDENTIAL_FILE" not in emitted.stdout + emitted.stderr, task
PY

LINK_HOME="$TMP/linked-home"
ln -s "$HOME_T" "$LINK_HOME"
for kind in panel shadow runproof runproof-second; do
  for spelling in linked-linked linked-canonical canonical-linked; do
    case "$spelling" in
      linked-linked) scaffold_home=$LINK_HOME; generator_home=$LINK_HOME ;;
      linked-canonical) scaffold_home=$LINK_HOME; generator_home=$HOME_T ;;
      canonical-linked) scaffold_home=$HOME_T; generator_home=$LINK_HOME ;;
    esac
    task="t-home-$kind-$spelling"
    HOME_T="$scaffold_home" scaffold "$task"
    B=$(brief "$task")
    expect_has "$kind: $spelling scaffold preserves its report spelling" "$B" "Write your findings to \`$scaffold_home/data/$task/report.md\`."
    check "$kind: $spelling report does not yet exist" test ! -e "$HOME_T/data/$task/report.md"
    cp "$B" "$TMP/home-before.md"
    args=("${kind%-second}" --home "$generator_home" --task "$task" --ticket "$TICKET" --plan "$PLAN_DIR/plan.md")
    case "$kind" in
      panel) args+=(--lens solutions-architect) ;;
      shadow) args+=(--lens security-architect --shadow-model github-copilot/gpt-6.1-sol) ;;
      runproof|runproof-second) args+=(--dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --ixia-dir "$TMP/ixia-ok") ;;
    esac
    if [ "$kind" = runproof-second ]; then args+=(--model github-copilot/gpt-6.1-sol); fi
    python3 "$GEN" "${args[@]}" --stdout >"$TMP/home-output.md"
    check "$kind: $spelling stdout preserves scaffold" cmp -s "$B" "$TMP/home-before.md"
    expect_has "$kind: $spelling output names the expected task report" "$TMP/home-output.md" "Write \`$HOME_T/data/$task/report.md\` as a single line"
    expect_hasnt "$kind: $spelling original report instruction was replaced" "$TMP/home-output.md" "Write your findings to \`$scaffold_home/data/$task/report.md\`."
    python3 "$GEN" "${args[@]}" >/dev/null
    check "$kind: $spelling write matches stdout" cmp -s "$B" "$TMP/home-output.md"
  done
done

for invalid in wrong-task wrong-home; do
  task="t-home-$invalid"
  HOME_T="$LINK_HOME" scaffold "$task"
  B=$(brief "$task")
  case "$invalid" in
    wrong-task) target="$LINK_HOME/data/another-task/report.md" ;;
    wrong-home) target="$TMP/another-home/data/$task/report.md" ;;
  esac
  python3 - "$B" "$target" <<'PY'
import pathlib, re, sys
brief = pathlib.Path(sys.argv[1])
brief.write_text(re.sub(r"(?m)^Write your findings to `[^`\n]+`\.$", lambda _: "Write your findings to `" + sys.argv[2] + "`.", brief.read_text(), count=1))
PY
  cp "$B" "$TMP/home-invalid-before.md"
  for delivery in write stdout; do
    delivery_args=()
    if [ "$delivery" = stdout ]; then delivery_args=(--stdout); fi
    out=$(python3 "$GEN" panel --home "$LINK_HOME" --task "$task" --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" \
      --lens business-analyst ${delivery_args[@]+"${delivery_args[@]}"} 2>&1) && rc=0 || rc=$?
    if [ "$rc" -ne 0 ] && grep -q 'unsupported scout report path' <<<"$out" && cmp -s "$B" "$TMP/home-invalid-before.md"; then
      pass "$invalid report is refused before $delivery without modifying the brief"
    else
      fail "$invalid report is refused before $delivery without modifying the brief"
    fi
  done
done

scaffold t-incompatible
B=$(brief t-incompatible)
python3 - "$B" <<'PY'
import pathlib, sys
brief = pathlib.Path(sys.argv[1])
brief.write_text(brief.read_text().replace("2. Stay inside this worktree;", "2. Use another write policy;", 1))
PY
cp "$B" "$TMP/incompatible-before.md"
out=$(python3 "$GEN" panel --home "$HOME_T" --task t-incompatible --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" --lens business-analyst 2>&1) && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'unsupported scout scaffold' <<<"$out" && cmp -s "$B" "$TMP/incompatible-before.md"; then
  pass "incompatible scaffold is refused without modifying the brief"
else
  fail "incompatible scaffold is refused without modifying the brief"
fi

# --- opt-in --ground-rules ------------------------------------------------------------
GR="$TMP/synthetic-ground-rules.md"
printf '# Synthetic ground rules\nGR-1 example rule\n' >"$GR"
gen_kind() { # gen_kind <task> <kind> [extra generator args...]: scaffold, generate to stdout
  local task=$1 kind=$2
  shift 2
  scaffold "$task"
  local args=("$kind" --home "$HOME_T" --task "$task" --ticket "$TICKET" --plan "$PLAN_DIR/plan.md")
  case "$kind" in
    panel) args+=(--lens solutions-architect) ;;
    shadow) args+=(--lens security-architect --shadow-model github-copilot/gpt-6.1-sol) ;;
    runproof) args+=(--dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --ixia-dir "$TMP/ixia-ok") ;;
  esac
  python3 "$GEN" "${args[@]}" "$@" --stdout
}
for kind in panel shadow runproof; do
  gen_kind "t-gr0-$kind" "$kind" >"$TMP/gr-off-$kind.md"
  gen_kind "t-gr1-$kind" "$kind" --ground-rules "$GR" >"$TMP/gr-on-$kind.md"
  # The task id is the only input that differs between the two generations; mask it.
  python3 - "$kind" "$TMP/gr-off-$kind.md" "$TMP/gr-on-$kind.md" <<'PY'
import pathlib, sys
for index, name in enumerate(sys.argv[2:]):
    path = pathlib.Path(name)
    task = ("t-gr%d-%s" % (index, sys.argv[1])).encode()
    path.write_bytes(path.read_bytes().replace(task, b"TASK"))
PY
  # Without the option nothing of the feature shows, and nothing a run produced before is gone.
  expect_hasnt "$kind: without --ground-rules no ground-rules text" "$TMP/gr-off-$kind.md" "GROUND RULES"
  expect_hasnt "$kind: without --ground-rules no premise rule text" "$TMP/gr-off-$kind.md" "Production-only premise rule"
  expect_hasnt "$kind: without --ground-rules no conditional-section markers" "$TMP/gr-off-$kind.md" "ground-rules-premise-rule"
  # With it, each kind names the file and the rule ids, and only adds text.
  expect_has "$kind: with --ground-rules the file is a mandatory read" "$TMP/gr-on-$kind.md" "GROUND RULES (mandatory read): before you review anything, read the ground-rules file $GR in full."
  expect_has "$kind: with --ground-rules the rule ids are cited" "$TMP/gr-on-$kind.md" "Cite the rule ids you rely on in each finding."
  diff_status=0
  diff "$TMP/gr-off-$kind.md" "$TMP/gr-on-$kind.md" >"$TMP/gr-diff-$kind.txt" || diff_status=$?
  if [ "$diff_status" -gt 1 ]; then
    exit "$diff_status"
  fi
  if grep -q '^<' "$TMP/gr-diff-$kind.txt"; then
    fail "$kind: --ground-rules only adds text (a line of the default output changed or went)"
  else
    pass "$kind: --ground-rules only adds text to the default output"
  fi
done
expect_has "runproof: with --ground-rules the premise rule is in the lens text" "$TMP/gr-on-runproof.md" "## 8. Production-only premise rule (only when the brief names a ground-rules file)"
expect_has "runproof: with --ground-rules the rule is active" "$TMP/gr-on-runproof.md" "the production-only premise rule (lens text, section 8) is active"
expect_has "runproof: activation governs all probing and seeds" "$TMP/gr-on-runproof.md" "it governs all attacks, probes and seeds below, overriding conflicting instructions."
expect_has "runproof: premise rule overrides inherited probing and ticket seeds" "$TMP/gr-on-runproof.md" "overriding section 4's attack and seed instructions, section 5's probe rules and checklist section 1.9's ticket seeds wherever they conflict."
expect_has "runproof: plan tests and all ticket seeds require confirmation before probing" "$TMP/gr-on-runproof.md" "Do not attack or probe an unconfirmed premise, even when the plan lists it as a test or it appears in a supplied or generated seed."
expect_has "runproof: premise rule asks, never builds a finding" "$TMP/gr-on-runproof.md" "Any other premise is not a finding."
expect_has "runproof: unconfirmed premise is one plain question" "$TMP/gr-on-runproof.md" "Ask it as one plain question in the report's questions section, headed \"unconfirmed premise\""
expect_hasnt "runproof: conditional-section markers are not shown" "$TMP/gr-on-runproof.md" "ground-rules-premise-rule"
for kind in panel shadow; do
  expect_hasnt "$kind: premise rule is a run-proof lens text only" "$TMP/gr-on-$kind.md" "production-only premise rule"
  expect_hasnt "$kind: no premise-based finding suppression" "$TMP/gr-on-$kind.md" "do not build the finding on it"
  expect_hasnt "$kind: no unconfirmed-premise policy" "$TMP/gr-on-$kind.md" "unconfirmed premise"
done
# Without the option the embedded lens text is exactly the lens file minus the conditional section.
check "runproof: without --ground-rules the embedded lens text is the unchanged lens" python3 - "$here/run-proof-lens.markdown" "$TMP/gr-off-runproof.md" <<'PY'
import sys
lens = open(sys.argv[1]).read().split("<!-- BEGIN ground-rules-premise-rule -->")[0].strip()
brief = open(sys.argv[2]).read()
begin = "===== BEGIN LENS TEXT (run-proof-lens.markdown) =====\n"
end = "\n===== END LENS TEXT ====="
assert brief.split(begin)[1].split(end)[0] == lens
PY
# The ground-rules file is a path only: its content is never copied into the brief.
expect_hasnt "ground-rules content is not embedded" "$TMP/gr-on-panel.md" "GR-1 example rule"
# A relative path resolves against the home.
mkdir -p "$HOME_T/data/rules"
cp "$GR" "$HOME_T/data/rules/ground-rules.md"
gen_kind t-gr-rel panel --ground-rules data/rules/ground-rules.md >"$TMP/gr-rel.md"
expect_has "a relative --ground-rules path resolves against the home" "$TMP/gr-rel.md" "read the ground-rules file $HOME_T/data/rules/ground-rules.md in full."
# A missing or unreadable file is refused before anything is written.
scaffold t-gr-bad
cp "$(brief t-gr-bad)" "$TMP/gr-bad-before.md"
for bad in "$TMP/no-such-ground-rules.md" "$TMP"; do
  out=$(python3 "$GEN" runproof --home "$HOME_T" --task t-gr-bad --ticket "$TICKET" --plan "$PLAN_DIR/plan.md" \
    --dispositions "$PLAN_DIR/plan-reviews.md" --changes "$PLAN_DIR/what-changed.md" --ground-rules "$bad" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'ground-rules file .* is missing or unreadable' <<<"$out" && cmp -s "$(brief t-gr-bad)" "$TMP/gr-bad-before.md"; then
    pass "a missing or unreadable --ground-rules file is refused without modifying the brief"
  else
    fail "a missing or unreadable --ground-rules file is refused without modifying the brief ($bad)"
  fi
done

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed" >&2; exit 1; fi
