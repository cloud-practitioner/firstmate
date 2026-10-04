from pathlib import Path
import subprocess
root = Path.cwd()
work = root / '.test-calm-validation'
current = (root / 'tests/fm-calm-pi-extension.test.sh').read_text()
base = subprocess.check_output(['git', 'show', '93d82355e4c37dbe4b91aba8d4e16f2789e7938e:tests/fm-calm-pi-extension.test.sh'], text=True)
for name, source in [('current', current), ('baseline', base)]:
    # Execute just the existing changed renderer/lifecycle function, unmodified.
    declarations = source[:source.rindex('\ntest_home_resolution\n')]
    (root / f'tests/.calm-validation-{name}.sh').write_text(declarations + '\ntest_rendering_and_session_lifecycle\n')
