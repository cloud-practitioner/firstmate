from pathlib import Path
import os
import subprocess

root = Path.cwd()
evidence = Path('/home/node/.no-mistakes/evidence/01M3ZYE1DS003X0Y14YX40P7WY')
runner = root / 'tests/.fm-archive-selected.test.sh'
baseline = root / 'bin/.fm-captain-hold-before-test.sh'
tmp = root / '.fm-live-validation/test-tmp'
tmp.mkdir(exist_ok=True)
prefix = (root / 'tests/fm-captain-hold-lifecycle.test.sh').read_text().split('\ntest_uninventoried_report_decision_refuses_completion\n', 1)[0]
prefix = prefix.replace('"$ROOT/bin/fm-captain-hold.sh"', '"$CAPTAIN_TEST_BIN"')
runner.write_text(prefix + '''
case "$1" in
  archive)
    for variant in default unset inline-comment single-quoted inherited project-precedence absolute; do
      test_verify_accepts_an_answered_call_pruned_to_the_archive "$variant" || exit $?
    done
    ;;
  legacy) test_verify_refuses_a_live_legacy_row_despite_an_old_archived_answer ;;
esac
''')
baseline.write_bytes(subprocess.check_output(['git', 'show', 'e42087e4513c4483d832aa8898b28efd410fdac8:bin/fm-captain-hold.sh']))
baseline.chmod(0o700)
env = {k: v for k, v in os.environ.items() if not k.startswith(('FM_', 'HERDR_', 'TASKS_AXI_', 'TMUX', 'BD_'))}
env['TMPDIR'] = str(tmp)
log = []
try:
    for label, mode, executable, expected in (
        ('Seven existing archived-answer E2E variants on target', 'archive', root / 'bin/fm-captain-hold.sh', 0),
        ('New live-legacy precedence regression on base', 'legacy', baseline, 0),
        ('New live-legacy precedence regression on target', 'legacy', root / 'bin/fm-captain-hold.sh', 1),
    ):
        env['CAPTAIN_TEST_BIN'] = str(executable)
        p = subprocess.run(['bash', str(runner), mode], cwd=root, env=env, capture_output=True, text=True, timeout=180)
        entry = f'=== {label} ===\nCAPTAIN_TEST_BIN={executable} bash tests/.fm-archive-selected.test.sh {mode}\n{p.stdout}{p.stderr}exit: {p.returncode}\n'
        print(entry)
        log.append(entry)
        assert p.returncode == expected, entry
finally:
    runner.unlink(missing_ok=True)
    baseline.unlink(missing_ok=True)
    (evidence / 'captain-archive-targeted-regression.log').write_text('\n'.join(log))
