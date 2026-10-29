# Run-proof lens (IQX plan gate)

Fork-only. IQX Bitbucket work only. Never offered upstream. See `README`.

The run-proof lens is one reviewer process that attacks a plan with tests.
A finding survives only when a run proves it.
It does not replace the Ixia review panel and does not apply fixes.

## 1. When it runs

- **Scope.** A Tier A plan gate where the plan changes code that the simulator or a test harness can run.
- **Skip** a Tier A plan with nothing to run offline: documentation only, infrastructure layout, contract text. The lens can prove nothing there and would drop every hypothesis. Say the skip and its reason in the plan gate record.
- **Timing.** After the panel's dispositions and before the plan go. Its questions go to the product owner together with the plan-go questions, in one decision round.
- **Not in parallel with the panel.** About half of the findings in the first runs were in text that a disposition, an answer, or a panel premise wrote after the panel ran.
- **No second lens pass** on the finished branch for now. The code-review pipeline reads the branch.
- **Models.** `claude-opus-5.5` by default. Add a second model (`gpt-6.1-sol`, the only other model tested) when the plan changes the shared runner, the identity unit, or a Resume rule. The two models found different defects in the one run where both ran, so run them as two separate processes that do not read each other's report before their own findings are frozen.
- A bundle outside the known bundles on one runner: look at the first run before making the lens standard for that kind of change.

## 2. Method by reference

The method comes from pstack, by reference. Nothing from pstack is installed or enabled.

- Repository: `https://github.com/cursor/plugins`, folder `pstack/`, commit `c742dd61706fbacc1b95f1a20b7b988cf096ce6c` (see `sources.lock.json`).
- `pstack/skills/interrogate/SKILL.md`: adversaries try to break a change or a design; "A finding survives only when a run proves it. Report the findings. Do not apply fixes."
- `pstack/skills/arena/SKILL.md`, Phase F (Verify), as `interrogate` uses it: verify each finding by running its command again. Keep a finding when the output shows the failure and the failure breaks the intent. Drop the rest. Merge findings that share a root cause.
- Read both files from a shallow clone at the locked commit in your task temp root, if you want the full text. The lens text here is complete without them.

Not used from pstack: the fan-out of several adversaries, a worktree for each adversary, the arena's judge and synthesis phases (C, D, E), and its commit, push, pull request and tracker steps. This lens is one adversary in one scratch worktree.

pstack licence notice (the licence requires this notice with copied or quoted text; only the lines quoted above are copied):

```
MIT License

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
SOFTWARE.
```

## 3. Ixia overrides

- **The Ixia contract wins over pstack.** Read it from the pinned local copy named in `sources.lock.json` (plugin `ixia-stratex`, version 1.0.23), read-only. State the version you read in the report header. If the pinned copy has another version than the lock, say so in the header and go on.
- Do not copy Ixia plugin text into a report or into a repository. Name the file and the rule.
- **Severities are Ixia's words:** BLOCKER, SHOULD-FIX, CONSIDER.
- **Read-only limits.** No SAP, Jira, Confluence or Bitbucket write. No commit, push or pull request outside your scratch worktree. Never use the `arc-dgw` or `arc-dgw-fab` MCP servers. Never run the Ixia feedback skill. Never read, print or commit a secret; read a credential file by path inside a program, never with `cat`, `source` or `echo`.
- **No dispositions.** The plan author disposes of every finding. A product call goes in the report as a question with options and a recommendation.
- A finding breaks the module's rules, the ticket's acceptance lines or the plan's own statements. It is not a finding that it breaks a pstack rule.

## 4. Order of work

Follow this order. One read order, one output path (the brief names the path).

1. **Read** the plan, the dispositions, and the plan author's list "what changed since the panel". Read the checklist (seeds, fixed checklist, simulator switches and gaps, known S4P facts) before the work starts. Read the plan author's prototypes and the panel's probe files in the probes folder the brief names; start from them. Do not read the panel's reviews yet.
2. **Attack the dispositions.**
   - Run each accepted control against the reviewer's own test.
   - Probe each state that the control's trigger does not include: not reached, failed, unknown, deadline stop, refused before it.
   - Probe together each pair of fixes that touch the same output field, or the same SAP field from two writers.
   - Run each published outcome sentence or table on the real runner.
3. **Run the seeds and the fixed checklist** of the checklist file. Put the plan's S4P data shapes into the simulator before probing. For each acceptance test, list the simulator switch or value list it needs.
4. **Freeze the findings.** Write the findings section of the report and add the line `FROZEN <date and time>` after it. Only then read the panel reviews and compare. A finding does not change after the freeze, except that a later probe may add a new finding marked as found after the freeze.

## 5. Probe rules

- **Each probe asserts the intent.** A failing test is the finding. The build uses the probe as its acceptance test with no change. A probe that asserts the defect (passes while the defect is there) is a defect of the probe.
- **Print the state after every call**, not only the asserted one: the answer, the writes sent, and the simulator's SAP state.
- **Read a passing finding-probe again before you drop it.** A probe can pass for the wrong reason (a lock or gate in the first step changes what the second step does).
- **Run each probe twice** and compare the output with times and generated ids masked.
- **Do not drop a hypothesis because of the threat model** when the plan lists it as a test.
- **Where the plan describes code that is not built**, probe the existing code the plan says it reuses, run the plan's rule as written on a prototype, and say which of the two each finding is.
- **Runnable from any checkout.** Keep probe files in the probes folder the brief names, with no path to another checkout. Find the repository root with `git rev-parse --show-toplevel`. Keep the probe source in the report too, because the scratch checkout is deleted.
- **Simulator switches.** Name the switches and value lists each probe needs, and say what the simulator lacks (see the checklist, section 3). A rule the simulator cannot show is not dropped; it is labelled.
- Throwaway probe scripts go in your scratch worktree or task temp folder. Never edit a tracked repository file outside the scratch worktree.

## 6. Evidence labels

Every finding and every recommendation carries one label.

- `simulator-tested`: a run on the real runner and the simulator proves it.
- `S4P-seen consequence`: the run proves the write, and cited S4P evidence (a recorded live check, a known fact in the checklist) proves the result.
- `needs a live check`: it depends on what SAP accepts or stores, and the simulator cannot show it. Give the live check as an option, with the exact read or call and what result decides.

A blocker that has no fix in the module (a fix that needs a platform change, a SAP change, or another team) says so and offers the product owner two options: accept a named limit, or wait.

## 7. Report shape

One Markdown file at the output path. A report stands alone.

1. **Header table:** lens, method references (pstack commit), contract version, plan revision, code head (commit), model (exact id), date, the one output path.
2. **Intent** in your own words.
3. **How the probes run:** the real parts, the scratch parts, the simulator switches and gaps, the command that runs all probes, the clock.
4. **Findings**, each with: id, severity, the seed or checklist class, evidence label, the rule it breaks, the command, the output (with the state after each call), what the intent requires, and the fix or the options. For a blocker with no fix in the module, the two options of section 6.
5. **Dropped hypotheses:** each with the probe or check that removed it and why. Count them.
6. `FROZEN <date and time>`.
7. **Comparison with the panel** (written after the freeze): for each finding, whether the panel raised it (same mechanism, in part, not raised) and how. Then the confirmation value: which accepted controls and panel claims you ran, and whether each held. Panel findings you did not raise, and whether any contradicts a probe.
8. **Questions for the product owner:** each with what it is, a concrete moment, options, the cost of each option, and a recommendation. A question that depends on SAP says `needs a live check` and gives the check as an option.
9. **Cost:** wall time, probe count, probe run time, the main time sink.
10. **What this run taught about the checklist:** classes to add, classes that now have a repository test and leave the list, friction in the brief. This feeds the upkeep rule.
11. **Appendix A:** the probe source. **Appendix B:** the probe output.
12. **Done line:** counts of findings by severity, dropped count, output path.
