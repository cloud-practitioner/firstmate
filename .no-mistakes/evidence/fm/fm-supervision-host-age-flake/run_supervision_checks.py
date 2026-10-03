#!/usr/bin/env python3
"""Disposable targeted runner; no tracked source or production code is changed."""
from pathlib import Path
import os
import subprocess
import shlex

root = Path.cwd()
evidence = Path('/home/node/.no-mistakes/evidence/01M3ZJXKJV9G4A0964GSA1RNE2')
evidence.mkdir(parents=True, exist_ok=True)
scratch = root / '.test-validation'
(scratch / 'tmp').mkdir(parents=True, exist_ok=True)
cases = [
    'test_branch_outcomes_only_on_a_host_home_off_pi',
    'test_branch_outcomes_put_captain_first_and_collapse_routine_overflow',
    'test_branch_outcomes_collapse_repeated_captain_outcomes_per_task',
    'test_branch_outcomes_present_a_long_away_window_once',
    'test_branch_outcomes_stay_unread_when_a_projection_fails',
]
legacy = [
    'test_branch_outcomes_date_a_legacy_backlog_without_adopting_it',
    'test_branch_outcomes_date_an_outcome_carried_across_a_switch_off_pi',
]
target = (root / 'tests/fm-supervision-host.test.sh').read_text()
base = subprocess.check_output(['git', 'show', '8bcf44abca9eadb29596ced4c0168a8fa530189f:tests/fm-supervision-host.test.sh'], text=True)
marker = '\nrun_case test_park_exit_probe_uses_half_second_child_sleeps\n'
real_jq = subprocess.check_output(['bash', '-c', 'command -v jq'], text=True).strip()

# Age the owned serialized fixture store immediately before invoking the real
# drain. Keep the original bash-symlink harness used by the existing suite.
# No clock replacement, sleep, source assertions, or production mutation.
shim = r'''
ORIGINAL_FAKE_CLAUDE="$FAKE_CLAUDE"
export ORIGINAL_FAKE_CLAUDE
FAKE_CLAUDE="$TMP_ROOT/age-before-drain"
cat > "$FAKE_CLAUDE" <<'SH'
#!/usr/bin/env bash
store="$FM_HOME/state/branch-outcomes.jsonl"
if [ -s "$store" ]; then
  "$VALIDATION_JQ" -c --argjson epoch "$(( $(date +%s) - VALIDATION_AGE ))" '.epoch = $epoch' "$store" > "$store.aged" || exit 91
  mv "$store.aged" "$store" || exit 92
fi
rc=0
out=$("$ORIGINAL_FAKE_CLAUDE" "$@") || rc=$?
{
  printf '\n=== %s, age fixture %ss, drain exit %s ===\n' "${FM_HOME##*/}" "$VALIDATION_AGE" "$rc"
  printf '%s\n' "$out" | grep -E '^\[seq |^BRANCH OUTCOMES|mark-processed --through' || true
} >> "$VALIDATION_RAW_LOG"
printf '%s\n' "$out"
exit "$rc"
SH
chmod +x "$FAKE_CLAUDE"
'''

checks = r'''
# These are executable output/state checks, not source-text assertions.
home="$TMP_ROOT/normalizer-contract"
mkdir -p "$home/state" "$home/config"
: > "$home/config/supervision-host"
for age in 0 65 125 3545 7205 172805; do
  now=$(date +%s)
  outcome_row 1 "$((now - age))" alpha captain 'alpha review required' > "$home/state/branch-outcomes.jsonl"
  outcome_row 2 "$((now - age))" alpha captain 'alpha still blocked 2' >> "$home/state/branch-outcomes.jsonl"
  raw=$(FM_HOME="$home" "$ORIGINAL_FAKE_CLAUDE" -c '"$0" 2>&1' "$ROOT/bin/fm-wake-drain.sh")
  normalized=$(zero_minute_age "$raw")
  case "$age" in
    0) rendered=0m; expected=0m ;;
    65) rendered=1m; expected=0m ;;
    125) rendered=2m; expected=0m ;;
    3545) rendered=59m; expected=0m ;;
    7205) rendered=2h; expected=2h ;;
    172805) rendered=2d; expected=2d ;;
  esac
  wanted="[seq 2, newest of 2 for this task, recorded $expected ago] alpha: alpha still blocked 2"
  assert_contains "$raw" "[seq 2, newest of 2 for this task, recorded $rendered ago] alpha: alpha still blocked 2" 'raw production age did not match fixture'
  assert_contains "$normalized" "$wanted" 'normalization did not preserve the outcome contract'
  assert_contains "$normalized" 'mark-processed --through 2;' 'normalization lost the acknowledgement'
  # Normalization must not repair incorrect sequence, task, summary, duplicate
  # count, or an hour/day age that the assertion was expected to reject.
  for field in sequence task summary duplicate-count; do
    case "$field" in
      sequence) bad=${raw/'[seq 2,'/'[seq 9,'} ;;
      task) bad=${raw/'] alpha:'/'] beta:'} ;;
      summary) bad=${raw/'alpha still blocked 2'/'incorrect summary'} ;;
      duplicate-count) bad=${raw/'newest of 2 for this task'/'newest of 9 for this task'} ;;
    esac
    rc=0
    (assert_contains "$(zero_minute_age "$bad")" "$wanted" "$field mismatch must fail") > "$TMP_ROOT/rejected.log" 2>&1 || rc=$?
    [ "$rc" -eq 1 ] || fail "normalization hid a $field mismatch"
  done
  if [ "$age" -ge 7205 ]; then
    rc=0
    (assert_contains "$normalized" '[seq 2, newest of 2 for this task, recorded 0m ago]' 'hour/day mismatch must fail') > "$TMP_ROOT/rejected.log" 2>&1 || rc=$?
    [ "$rc" -eq 1 ] || fail 'normalization hid an hour/day mismatch'
  fi
  {
    printf '\n=== fixture %ss: actual drain output ===\n' "$age"
    printf '%s\n' "$raw" | grep -E '^\[seq |mark-processed --through'
    printf '\n=== normalized assertion input (test-only) ===\n'
    printf '%s\n' "$normalized" | grep -E '^\[seq |mark-processed --through'
    printf 'Sequence, task, summary, and duplicate-count mutations: rejected by existing assertion.\n'
    [ "$age" -lt 7205 ] || printf 'Incorrect minute expectation for hour/day output: rejected.\n'
  } >> "$VALIDATION_RAW_LOG"
  rm -f "$home/state/.branch-outcomes-cursor" "$home/state/.branch-outcomes-processed"
done
pass 'normalization: minutes normalize; hour/day ages and outcome metadata remain exact'
'''

runs = [
    ('target-fresh', target, 0, cases + legacy, False),
    ('base-aged-65', base, 65, cases, False),
    ('target-aged-65', target, 65, cases, False),
    ('target-aged-125', target, 125, cases, False),
    ('target-output-contract', target, 0, [], True),
]
results = []
for label, source, age, selected, contract in runs:
    prefix, sep, _ = source.partition(marker)
    if not sep:
        raise RuntimeError('test invocation boundary not found')
    generated = root / 'tests' / f'.fm-supervision-validation-{label}.sh'
    additions = shim if age else '\nORIGINAL_FAKE_CLAUDE="$FAKE_CLAUDE"\n'
    additions += checks if contract else '\n'.join(f'run_case {case}' for case in selected) + '\n'
    generated.write_text(prefix + '\n' + additions)
    env = dict(os.environ, TMPDIR=str(scratch / 'tmp'), VALIDATION_AGE=str(age),
               VALIDATION_JQ=real_jq, VALIDATION_RAW_LOG=str(evidence / f'{label}-product-output.log'))
    command = ['bash', str(generated)]
    print(f'{label}: selected {", ".join(selected) if selected else "normalizer output contract and mutation rejection"}', flush=True)
    try:
        proc = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
    finally:
        generated.unlink(missing_ok=True)
    (evidence / f'{label}-checks.log').write_text(f'Fixture age: {age}s\nSelected cases: {", ".join(selected)}\nExit: {proc.returncode}\n' + proc.stdout)
    print(proc.stdout, end='', flush=True)
    print(f'{label}: exit {proc.returncode}', flush=True)
    expected_rc = 1 if label.startswith('base-') else 0
    results.append((label, proc.returncode, expected_rc))

print('\nValidation result matrix:')
for label, actual, expected in results:
    print(f'{label}: exit={actual}, expected={expected}')
if any(actual != expected for _, actual, expected in results):
    raise SystemExit(1)
