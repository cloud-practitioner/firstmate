#!/usr/bin/env python3
"""mk-lens-brief.py - fill a scaffolded scout brief for an IQX lens reviewer.

Fork-only (cloud-practitioner/firstmate), IQX Bitbucket work only, never
offered upstream; nothing in core bin/ or skills calls it. See README.

It fills the two placeholders ({TASK}, {FIRSTMATE_SPEC}) of a scout brief that
bin/fm-brief.sh already wrote at <home>/data/<task-id>/brief.md, and adapts its
write permissions and completion contract to the review and probe paths. Three kinds:

  panel     one Ixia plan-gate panel reviewer (a lens, read-only, or read and
            run for the architect lenses)
  shadow    a comparison reviewer that runs beside the real panel for the
            model benchmark; its output never counts for dispositions
  runproof  the run-proof lens: embeds the lens text, the checklist and the
            sources lock; dispositions and the "what changed" list first;
            panel reviews only after the findings are frozen

The firstmate home is explicit: --home <dir>, or FM_HOME when --home is not
given. It refuses when neither is set. Nothing is guessed and no path to a
particular home is built in. The only file written is <home>/data/<task-id>/brief.md.

Usage:
  mk-lens-brief.py panel    --home H --task T --ticket D --plan P --lens L [options]
  mk-lens-brief.py shadow   --home H --task T --ticket D --plan P --lens L --shadow-model M [options]
  mk-lens-brief.py runproof --home H --task T --ticket D --plan P --dispositions F --changes F [options]
  mk-lens-brief.py --help   (all options)

Output paths (under <home>/data/<ticket>/plans/):
  panel     reviews/<lens>.md
  shadow    reviews/shadow/<lens>-<encoded-full-model-id>.md
  runproof  reviews/run-proof-<model-last-segment>.md
  probes    probes/ (plan author prototypes) and probes/panel-<lens>/,
            probes/shadow-<lens>-<encoded-full-model-id>/,
            probes/run-proof-<model-last-segment>/ (reviewer probe files)
The task's own data/<task-id>/report.md is a one-line pointer to that path,
so the scout completion gate finds a report.

Standard library only; Python 3.8 or newer.
"""
import argparse
import json
import os
import re
import sys
from urllib.parse import quote

HERE = os.path.dirname(os.path.abspath(__file__))

DEFAULT_MODEL = "github-copilot/claude-opus-5.5"
SECOND_MODEL = "github-copilot/gpt-6.1-sol"
DEFAULT_BITBUCKET_ENV = "/workspaces/wp/.secrets/bitbucket.env"
RUN_LENSES = ("solutions-architect", "security-architect")
SHARED_TOUCHES = ("runner", "identity", "resume")


def die(msg):
    sys.stderr.write("mk-lens-brief: %s\n" % msg)
    sys.exit(2)


def warn(msg):
    sys.stderr.write("mk-lens-brief: warning: %s\n" % msg)


def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError as e:
        die("cannot read %s: %s" % (path, e))


def load_lock():
    lock = json.loads(read(os.path.join(HERE, "sources.lock.json")))
    for key in ("pstack", "ixia"):
        if key not in lock:
            die("sources.lock.json has no %r block" % key)
    for key in ("commit", "repository"):
        if key not in lock["pstack"]:
            die("sources.lock.json pstack block has no %r" % key)
    for key in ("version", "plugin_dir", "version_file", "pinned_copy", "agents"):
        if key not in lock["ixia"]:
            die("sources.lock.json ixia block has no %r" % key)
    return lock


def known_s4p_facts():
    text = read(os.path.join(HERE, "orchestration-checklist.markdown"))
    m = re.search(r"<!-- BEGIN known-s4p-facts -->\n(.*?)<!-- END known-s4p-facts -->", text, re.S)
    if not m:
        die("orchestration-checklist.markdown has no known-s4p-facts block")
    return m.group(1).strip()


def resolve_home(args):
    home = args.home or os.environ.get("FM_HOME")
    if not home:
        die("no firstmate home: pass --home <dir> or set FM_HOME (refusing to guess one)")
    if args.home and os.environ.get("FM_HOME") and os.path.realpath(args.home) != os.path.realpath(os.environ["FM_HOME"]):
        warn("FM_HOME (%s) differs from --home; using --home" % os.environ["FM_HOME"])
    home = os.path.realpath(home)
    if not os.path.isdir(os.path.join(home, "data")):
        die("%s is not a firstmate home (no data/ directory)" % home)
    return home


def resolve_base_ref(brief, requested):
    setups = list(re.finditer(
        r"(?m)^You are in a disposable git worktree of .*, at a detached HEAD on a clean "
        r"(?:copy of its base branch\.\nBase branch: (?P<branch>[^\n]+)|default branch\.)$",
        read(brief),
    ))
    if len(setups) != 1:
        die("%s has an unsupported scout base; re-scaffold with bin/fm-brief.sh --scout" % brief)
    branch = setups[0].group("branch")
    if requested is not None and requested != branch:
        die("--base-branch %r does not match the scaffold's base %r; re-scaffold with the intended base before filling" % (requested, branch))
    return "origin/%s" % branch if branch else "the default-branch checkout named in Setup"


def slug(model):
    return model.rsplit("/", 1)[-1]


def under_home(home, p):
    """A path as the brief should name it: absolute, relative ones resolved against the home."""
    return p if os.path.isabs(p) else os.path.join(home, p)


def ixia_source_block(lock, mode, agentfile, bitbucket_env, ixia_dir):
    """How the worker reads Ixia. agentfile None: the run-proof lens, which adopts no agent file."""
    ixia = lock["ixia"]
    if mode == "pinned":
        root = os.path.abspath(ixia_dir or os.path.expanduser(ixia["pinned_copy"]))
        plugin = os.path.join(root, ixia["plugin_dir"])
        warn_version(root, lock)
        head = "Read the Ixia plugin read-only from the pinned local copy %s (never edit it, never clone it again, never install it). " % plugin
        if agentfile:
            body = (
                "Read %s/agents/%s in full and adopt it as your role and instructions for this review (it is your system prompt); "
                "also read the plan-gate and review-panel skills' rules for reviewer output and the Ixia engineering contract they cite. " % (plugin, agentfile)
            )
        else:
            body = (
                "Read the architecture-contract skill and its references there, and the plan-gate and review-panel skills' rules for reviewer output. "
            )
        return head + body + "Say the plugin version you read in the report header (the sources lock names %s)." % ixia["version"]
    head = (
        "Clone iqxbusiness/ixia-marketplace shallow into your task temp root (Bitbucket credentials: read %s inside node or python by path; "
        "never source, cat or print it). " % os.path.abspath(bitbucket_env)
    )
    if agentfile:
        body = (
            "Read plugins/ixia-stratex/agents/%s in full and adopt it as your role and instructions for this review (it is your system prompt); "
            "also read the plan-gate and review-panel skills' rules for reviewer output and the Ixia engineering contract they cite. " % agentfile
        )
    else:
        body = "Read the architecture-contract skill and its references, and the plan-gate and review-panel skills' rules for reviewer output. "
    return head + body + "Say the plugin version you read in the report header."


def warn_version(root, lock):
    """Warn (never refuse) when the pinned copy is missing or another version than the lock."""
    ixia = lock["ixia"]
    vf = os.path.join(root, ixia["version_file"])
    try:
        found = json.loads(read(vf)).get("version")
    except SystemExit:
        warn("pinned Ixia copy not readable at %s; the worker is told to say so in its header" % vf)
        return
    except ValueError:
        warn("pinned Ixia copy %s is not valid JSON" % vf)
        return
    if found != ixia["version"]:
        warn("pinned Ixia copy is version %s, the sources lock says %s" % (found, ixia["version"]))


def limits_block(home):
    return (
        "Before running ANY firstmate script (bin/fm-*), set FM_HOME=%s explicitly in that command "
        "(the shell may carry another home's FM_HOME; writing there is a defect). "
        "Never use the arc-dgw or arc-dgw-fab MCP servers. Never run the Ixia feedback skill. "
        "No SAP, Jira, Confluence or Bitbucket writes; never read, print or commit a secret." % home
    )


def standing_intent(kind, lens, plan, owner, shadow_model):
    text = (
        "%s, 2026-10-28, standing rule: every Ixia plan-gate review panel runs as separate fresh-context reviewer processes, "
        "one per lens, read-only, none of them the plan's author; each reviewer uses its agent file from the current ixia-stratex agents/ "
        "as its system prompt, with the model the agent file names, the Security Architect lens included (Opus; moved back from GPT 6.1 sol "
        "on 2026-10-28 after the model evaluation). This process is the %s reviewer for the plan %s." % (owner, lens, plan)
    )
    if kind == "shadow":
        text += (
            " %s, 2026-10-28: keep the model benchmark for the next 5 tickets. This is a SHADOW benchmark reviewer on %s, run beside the real panel "
            "and scored blind later; its output never counts for dispositions." % (owner, shadow_model)
        )
    if lens in RUN_LENSES:
        text += (
            " %s, 2026-10-28: the Solutions Architect and Security Architect reviewers run with git and the simulator (read and run), "
            "still writing no code, commits, SAP, Jira or Bitbucket changes." % owner
        )
    return text


def runproof_intent(plan, owner, model, disp, changes):
    return (
        "%s, 2026-10-29: the run-proof lens is a separate reviewer process with tests. It runs in a Tier A plan gate when the plan changes code that "
        "the simulator or a test harness can run, after the panel's dispositions and before the plan go; its questions go with the plan-go questions. "
        "It does not run in parallel with the panel, and there is no second lens pass on the finished branch. Each finding is proven by a run. "
        "This process is the run-proof adversary on %s for the plan %s, with the dispositions %s and the plan author's list of what changed since the panel %s."
        % (owner, model, plan, disp, changes)
    )


def panel_spec(a, home, lock, paths):
    run = a.lens in RUN_LENSES
    agentfile = a.agent_file or lock["ixia"]["agents"].get(a.lens)
    if not agentfile:
        die("no agent file known for lens %r; pass --agent-file" % a.lens)
    shadow = a.kind == "shadow"
    mode = a.ixia_source or "clone"
    if run:
        access = (
            "Read and run: Read, Grep, Glob, any git read command, and you may RUN the repo's tests and the fake-SAP simulator "
            "(npm ci if needed, node --test on existing tests, test/support/model-world.ts harness, scripts that only talk to the simulator) "
            "in your own scratch worktree to check a premise; never edit tracked repo files, never commit or push;"
        )
    else:
        access = "Read-only: Read, Grep, Glob and git read commands; no edits to the repo or the plan; all other writes must stay within the scout Rules below;"
    probe_rule = ""
    if run:
        probe_rule = (
            "\n5. Probe files (read-and-run lenses): keep each throwaway probe you run as a file under %s, runnable from any checkout "
            "(no path to another checkout; find the repository root with git rev-parse --show-toplevel), so the run-proof lens and the build can run it again. "
            "Do not keep probes only in a temporary folder." % paths["probe_out"]
        )
    n = 6 if run else 5
    return (
        "1. %s\n"
        "2. Review ONLY as that reviewer. %s no SAP, Jira, Confluence or Bitbucket writes. Inputs: the plan %s (and its earlier in-session review file beside it, "
        "for context only - form your own view), the repo's AGENTS.md, CLAUDE.md and .claude/ixia-engineering-contract.md, the repo at %s "
        "(git fetch first; name the commit), and the S4P evidence the plan cites. %s\n"
        "3. Write your output verbatim, in the agent file's required format (findings with severity: BLOCKER / SHOULD-FIX / NIT or as the file says; "
        "each with file:line or plan section and evidence), to %s. Start the file with: reviewer lens, agent file and plugin version, the model you actually run on "
        "(exact id), repo commit, date. Do not dispose of findings - the plan author does that.\n"
        "4. Label each runtime claim [run] (you ran it; give the command and the output) or [read] (you read it in code, a schema or a document). "
        "A claim with no label counts as [read]. The run-proof lens probes the [read] claims first.%s\n"
        "%d. Your role in this gate: the panel keeps product decisions, documentation, wording, order across tickets, tenancy and cost, and what reading finds. "
        "There is no second panel round: the run-proof lens checks the revision after the dispositions, with tests. Do not spend your run proving what that lens will prove; "
        "use [run] where one probe settles a premise. Where two fixes you propose touch the same output field, or one SAP field from two writers, say so.\n"
        "%d. Known S4P facts (an offline run cannot see them; label anything that depends on one 'needs a live check'):\n%s\n"
        "%d. %s Append done with the count of findings by severity and the output path. Never DGW.\n"
        % (
            ixia_source_block(lock, mode, agentfile, a.bitbucket_env, a.ixia_dir),
            access,
            a.plan,
            a.base_ref,
            a.extra,
            paths["out"],
            probe_rule,
            n,
            n + 1,
            indent(known_s4p_facts()),
            n + 2,
            limits_block(home),
        )
    )


def indent(text):
    return "\n".join("   " + ln if ln else ln for ln in text.splitlines())


def second_model_touches(a):
    """What the plan changes that adds the second-model run (empty list: none)."""
    return [t for t in (a.touches or []) if t in SHARED_TOUCHES]


def runproof_spec(a, home, lock, paths):
    lens_text = read(os.path.join(HERE, "run-proof-lens.markdown")).strip()
    checklist = read(os.path.join(HERE, "orchestration-checklist.markdown")).strip()
    lock_text = json.dumps(lock, indent=2)
    seeds = list(a.seed or [])
    if a.seeds_file:
        seeds += [ln.strip("- ").strip() for ln in read(a.seeds_file).splitlines() if ln.strip()]
    seed_block = "\n".join("- %s" % s for s in seeds) if seeds else "- (none given: make them from the plan's own premises and test list, checklist section 1.9)"
    ixia_mode = a.ixia_source or "pinned"
    ixia_line = ixia_source_block(lock, ixia_mode, None, a.bitbucket_env, a.ixia_dir)
    out_file = paths["out"]
    return (
        "You are the run-proof adversary on %(model)s for the plan %(plan)s, a separate fresh reviewer that wrote none of it. "
        "Method, rules and report shape are the embedded lens text below; follow it exactly.\n\n"
        "ONE READ ORDER (read in this order and no other):\n"
        "1. The embedded lens text, checklist and sources lock below, in this brief. Read them before anything else; the checklist is the lessons of earlier runs.\n"
        "2. The Ixia contract. %(ixia)s\n"
        "3. The module at %(base)s in your scratch worktree (git fetch first; name the commit): CLAUDE.md, AGENTS.md, .claude/ixia-engineering-contract.md, "
        "the design principles and the ADRs the plan cites, the runner and the Scenarios the plan reuses, test/support and the fake-SAP simulator.\n"
        "4. Your first inputs about the plan: the plan %(plan)s (state its revision); the dispositions %(disp)s; the plan author's list of what changed since the panel %(changes)s. "
        "Aim the attack at the text the dispositions and the changes wrote (lens text, section 4, step 2). %(extra)s\n"
        "5. The plan author's prototypes and the panel's probe files in %(probes)s (start from them; they must run from any checkout).\n"
        "6. NOT YET: the panel reviews in %(reviews)s (every file there except your own output, including the shadow folder and any other run-proof report). "
        "Read them only after the line FROZEN is in your report (lens text, section 4, step 4), then write the comparison.\n\n"
        "ONE OUTPUT PATH: %(out)s. Write the whole report there, in the shape of lens text section 7, and nowhere else. "
        "Keep your probe files in %(probe_out)s, runnable from any checkout, and put the probe source in the report as Appendix A as well. "
        "Start the report with the header table (lens text section 7): lens, method references, the Ixia contract version you read, plan revision, code commit, "
        "the exact model id you run on, date.\n\n"
        "Seeds made for this ticket (checklist section 1.9; add your own from the plan's premises and test list):\n%(seeds)s\n\n"
        "Known S4P facts (give each its evidence label; a finding or a recommendation that depends on what SAP accepts says 'needs a live check' and gives the check as an option):\n%(facts)s\n\n"
        "%(second)s"
        "No dispositions. No SAP system. Product calls go in the report as questions for the product owner, each with options, cost and a recommendation. "
        "%(limits)s Append done with the counts (findings by severity, dropped hypotheses) and the output path.\n\n"
        "===== BEGIN LENS TEXT (run-proof-lens.markdown) =====\n%(lens)s\n===== END LENS TEXT =====\n\n"
        "===== BEGIN CHECKLIST (orchestration-checklist.markdown) =====\n%(checklist)s\n===== END CHECKLIST =====\n\n"
        "===== BEGIN SOURCES LOCK (sources.lock.json) =====\n%(lock)s\n===== END SOURCES LOCK =====\n"
        % {
            "model": a.model,
            "plan": a.plan,
            "ixia": ixia_line,
            "base": a.base_ref,
            "disp": a.dispositions,
            "changes": a.changes,
            "extra": a.extra,
            "probes": paths["probes"],
            "reviews": paths["reviews"],
            "out": out_file,
            "probe_out": paths["probe_out"],
            "seeds": seed_block,
            "facts": indent(known_s4p_facts()),
            "second": second_note_text(a),
            "limits": limits_block(home),
            "lens": lens_text,
            "checklist": checklist,
            "lock": lock_text,
        }
    )


def second_note_text(a):
    touched = second_model_touches(a)
    if a.model == SECOND_MODEL:
        return (
            "Second-model run: you are the second process on this plan. Do not read the first model's run-proof report until your own findings are frozen.\n\n"
        )
    if touched:
        return (
            "Second-model rule: this plan changes %s, so a second run on %s is added after this one. "
            "Do not wait for it; do not read its report until your findings are frozen.\n\n" % (", ".join(touched), SECOND_MODEL)
        )
    return ""


def fill(brief_path, task_text, spec_text, paths):
    s = read(brief_path)
    for tok in ("{TASK}", "{FIRSTMATE_SPEC}"):
        if s.count(tok) != 1:
            die("%s must contain %s exactly once (found %d); re-scaffold the brief with bin/fm-brief.sh --scout" % (brief_path, tok, s.count(tok)))
    report = os.path.join(os.path.dirname(brief_path), "report.md")
    scaffold_reports = re.findall(r"(?m)^# Definition of done\nWrite your findings to `([^`\n]+)`\.$", s)
    if (len(scaffold_reports) != 1 or not os.path.isabs(scaffold_reports[0])
            or os.path.realpath(scaffold_reports[0]) != os.path.realpath(report)):
        die("%s has an unsupported scout report path; re-scaffold with bin/fm-brief.sh --scout" % brief_path)
    probe_permission = "probe files under `%s`, " % paths["probe_out"] if paths.get("probe_out") else ""
    standalone = "The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend."
    replacements = (
        (
            "2. Stay inside this worktree; the only files you may write outside it are the report, the status file below, and scratch files under your task temp root.",
            "2. Stay inside this worktree; the only files you may write outside it are the findings report `%s`, the completion pointer `%s`, %sthe status file below, and scratch files under your task temp root."
            % (paths["out"], report, probe_permission),
        ),
        (
            "Write your findings to `%s`.\n%s" % (scaffold_reports[0], standalone),
            "Write your findings to `%s`.\n%s\nWrite `%s` as a single line `Report: %s` and nothing else; it is only the scout completion pointer."
            % (paths["out"], standalone, report, paths["out"]),
        ),
        (
            "The report is the only thing that survives, so anything worth keeping must be in it.",
            "The findings report is the durable record; include all evidence worth keeping in it, along with the source of any retained probes.",
        ),
    )
    for old, new in replacements:
        if s.count(old) != 1:
            die("%s has an unsupported scout scaffold; re-scaffold with bin/fm-brief.sh --scout" % brief_path)
        s = s.replace(old, new, 1)
    s = re.sub(
        r"(?m)^(?:If your deliverable is a visual artifact|Lavish is unavailable).*",
        "No board work: do not arm, poll or edit any board.",
        s,
    )
    return re.sub(r"\{TASK\}|\{FIRSTMATE_SPEC\}", lambda m: task_text if m.group(0) == "{TASK}" else spec_text, s)


def build_parser():
    p = argparse.ArgumentParser(description="Fill a scaffolded scout brief for an IQX lens reviewer (fork-only; see README).")
    p.add_argument("kind", choices=("panel", "shadow", "runproof"))
    p.add_argument("--home", help="firstmate home directory (else FM_HOME; refuses when neither is set)")
    p.add_argument("--task", required=True, help="scout task id whose brief.md was scaffolded by bin/fm-brief.sh --scout")
    p.add_argument("--ticket", required=True, help="ticket folder name under <home>/data/")
    p.add_argument("--plan", required=True, help="plan path (absolute, or relative to the home)")
    p.add_argument("--lens", help="panel/shadow lens: solutions-architect, security-architect, business-analyst, ux-designer")
    p.add_argument("--agent-file", help="override the Ixia agent file name for the lens")
    p.add_argument("--shadow-model", help="shadow: the model id the benchmark reviewer runs on")
    p.add_argument("--model", default=DEFAULT_MODEL, help="runproof: the model id the process runs on (default %(default)s)")
    p.add_argument("--dispositions", help="runproof: the dispositions file (a first input)")
    p.add_argument("--changes", help="runproof: the plan author's 'what changed since the panel' list (a first input)")
    p.add_argument("--panel-reviews", help="runproof: panel reviews folder, read only after the findings are frozen (default <ticket>/plans/reviews)")
    p.add_argument("--seed", action="append", help="runproof: a seed made for this ticket (repeatable)")
    p.add_argument("--seeds-file", help="runproof: a file with one ticket seed per line")
    p.add_argument("--touches", action="append", choices=SHARED_TOUCHES,
                   help="runproof: what the plan changes (runner, identity, resume); any of them adds the second-model run")
    p.add_argument("--extra", default="", help="extra context sentence appended to the inputs")
    p.add_argument("--owner", default="Product owner", help="how the standing rules name the product owner (default %(default)s)")
    p.add_argument("--intent-file", help="a file of verbatim owner words to append to the captain's intent")
    p.add_argument("--base-branch", help="assert the module base branch matches the scaffold (default: inherit the scaffold's base)")
    p.add_argument("--ixia-source", choices=("pinned", "clone"),
                   help="where the worker reads Ixia (default: pinned for runproof, clone for panel and shadow)")
    p.add_argument("--ixia-dir", help="override the pinned Ixia marketplace copy (relative to the invocation directory; default: the path in sources.lock.json)")
    p.add_argument("--bitbucket-env", default=DEFAULT_BITBUCKET_ENV,
                   help="credential file the worker reads by path, never printing it (relative to the invocation directory; clone mode; default %(default)s)")
    p.add_argument("--stdout", action="store_true", help="print the filled brief instead of writing it")
    return p


def main(argv):
    a = build_parser().parse_args(argv)
    home = resolve_home(a)
    lock = load_lock()
    brief = os.path.join(home, "data", a.task, "brief.md")
    if not os.path.isfile(brief):
        die("no scaffolded brief at %s (run bin/fm-brief.sh <task> <repo> --scout first)" % brief)
    a.base_ref = resolve_base_ref(brief, a.base_branch)
    plans = os.path.join(home, "data", a.ticket, "plans")
    a.plan = under_home(home, a.plan)

    if a.kind in ("panel", "shadow"):
        if not a.lens:
            die("%s needs --lens" % a.kind)
        if a.kind == "shadow":
            if not a.shadow_model:
                die("shadow needs --shadow-model")
            reviewer = "%s-%s" % (a.lens, quote(a.shadow_model, safe=""))
            out = os.path.join(plans, "reviews", "shadow", "%s.md" % reviewer)
        else:
            reviewer = a.lens
            out = os.path.join(plans, "reviews", "%s.md" % reviewer)
        paths = {"out": out}
        if a.lens in RUN_LENSES:
            paths["probe_out"] = os.path.join(plans, "probes", "%s-%s" % (a.kind, reviewer))
        task_text = standing_intent(a.kind, a.lens, a.plan, a.owner, a.shadow_model)
        spec = panel_spec(a, home, lock, paths)
    else:
        if not a.dispositions or not a.changes:
            die("runproof needs --dispositions and --changes (they are the lens's first inputs)")
        a.dispositions = under_home(home, a.dispositions)
        a.changes = under_home(home, a.changes)
        for label, f in (("plan", a.plan), ("dispositions", a.dispositions), ("changes list", a.changes)):
            if not os.path.isfile(f):
                die("runproof %s not found: %s" % (label, f))
        paths = {
            "out": os.path.join(plans, "reviews", "run-proof-%s.md" % slug(a.model)),
            "probes": os.path.join(plans, "probes"),
            "probe_out": os.path.join(plans, "probes", "run-proof-%s" % slug(a.model)),
            "reviews": under_home(home, a.panel_reviews) if a.panel_reviews else os.path.join(plans, "reviews"),
        }
        task_text = runproof_intent(a.plan, a.owner, a.model, a.dispositions, a.changes)
        spec = runproof_spec(a, home, lock, paths)
        touched = second_model_touches(a)
        if touched and a.model != SECOND_MODEL:
            sys.stderr.write("mk-lens-brief: second-model: required (plan changes %s); also generate with --model %s\n" % (", ".join(touched), SECOND_MODEL))

    if a.intent_file:
        task_text += "\n\n" + read(a.intent_file).strip()
    text = fill(brief, task_text, spec, paths)
    if a.stdout:
        sys.stdout.write(text)
        return 0
    with open(brief, "w", encoding="utf-8") as f:
        f.write(text)
    print("ok %s" % paths["out"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
