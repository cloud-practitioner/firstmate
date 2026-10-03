# Supervision age-flake targeted validation

## Scope and classification

Base: `8bcf44abca9eadb29596ced4c0168a8fa530189f`

Target: `a3d1dbc0bf6a8354df86eaa63ea6d566d9f3eab8`

Only `tests/fm-supervision-host.test.sh` changes; there is no changed runtime product surface.
These are **non-live behavior/regression checks**, not a real harness or fleet validation.
The existing suite's bash symlinks stand in for primary harness ancestry.
The real outcome-store, drain, and acknowledgement scripts execute against disposable, worktree-local fixture homes.
No operator fleet, primary checkout, credentials, or default tmux/Herdr session was touched.

## Commands and selected checks

Executed `python3 .test-validation/run_supervision_checks.py` twice.
The disposable driver retained the existing test definitions and replaced only the final suite invocation list with these focused selectors:

- `test_branch_outcomes_only_on_a_host_home_off_pi`
- `test_branch_outcomes_put_captain_first_and_collapse_routine_overflow`
- `test_branch_outcomes_collapse_repeated_captain_outcomes_per_task`
- `test_branch_outcomes_present_a_long_away_window_once`
- `test_branch_outcomes_stay_unread_when_a_projection_fails`

Fresh-clock validation additionally ran:

- `test_branch_outcomes_date_a_legacy_backlog_without_adopting_it`
- `test_branch_outcomes_date_an_outcome_carried_across_a_switch_off_pi`

A separate output-contract check invoked the real drain with recorded fixture ages of 0, 65, 125, 3545, 7205, and 172805 seconds.
It passed the emitted output through the changed test helper and existing assertion function.
It verified 0m/1m/2m/59m normalization, exact 2h/2d preservation, acknowledgement preservation, and assertion rejection after mutating sequence, task, summary, or duplicate count.
Hour/day output still rejects an incorrect 0m expectation.
These checks assert executable output, not implementation-source contents.

## Regression proof

To simulate a minute boundary without a sleep or clock replacement, a fixture-only launcher rewrote each generated JSONL row's epoch to current time minus 65 or 125 seconds immediately before invoking the suite's original harness and real drain.
The initial launcher accidentally emitted multiline JSON, violating the store's JSONL contract.
Both versions correctly refused that malformed setup; those logs are preserved under `setup-attempt-*`.
After correcting serialization to `jq -c`, all checks were re-driven:

| Check | Observed exit | Expected exit |
| --- | --- | --- |
| Target, fresh outcomes plus legacy dates | 0 | 0 |
| Base, outcomes aged 65 seconds | 1 | 1 |
| Target, outcomes aged 65 seconds | 0 | 0 |
| Target, outcomes aged 125 seconds | 0 | 0 |
| Target, normalization and mutation rejection | 0 | 0 |

The corrected base failure is specifically the reported mismatch:

```text
missing: '[seq 1, recorded 0m ago] demo: PR ready for review'
[seq 1, recorded 1m ago] demo: PR ready for review
```

`base-aged-65-checks.log` contains the assertion failure and actual emitted outcome.
`target-aged-65-product-output.log` and `target-aged-125-product-output.log` contain actual fixture drain outputs, including acknowledgement targets and held-back rows.
`target-output-contract-product-output.log` shows raw drain output alongside test-normalized assertion input, including unchanged hour/day output.
The contract transcript includes both attempts because that independent check passed on each invocation.

## Cleanup and boundaries

The generated drivers in `tests/` and `.test-validation/` were removed.
Final `git status --short` was empty; no tracked files were changed by validation.
The reproduced driver is retained as `run_supervision_checks.py` in this evidence directory; its scratch-directory creation is self-contained for reproduction.
No complete repository suite, linter, formatter, static analysis, other gate phase, or live primary was run.
No screenshot was needed: this is test-only shell assertion logic, not a visual/UI change.
