from pathlib import Path
import os, re, subprocess, json
root = Path.cwd()
evidence = Path('/home/node/.no-mistakes/evidence/01M49Z4JCXXQR6ZMPDQQC08J2K')
evidence.mkdir(parents=True, exist_ok=True)
selectors = {
 'fm-pr-bitbucket': [
  'test_remote_path_names_only_bitbucket_cloud_repositories',
  'test_project_pr_host_follows_the_origin_remote',
  'test_open_creates_a_non_draft_pull_request',
  'test_open_reuses_an_existing_pull_request',
  'test_draft_is_refused_by_open_and_repaired_by_ready',
  'test_verify_checks_state_branch_and_head',
  'test_open_never_leaks_credentials',
  'test_open_accepts_supported_bitbucket_origins',
  'test_commands_require_current_bitbucket_context',
  'test_verify_and_ready_require_a_url',
  'test_discovery_distinguishes_forks_from_the_origin',
  'test_read_back_enforces_source_identity_before_accepting_or_updating',
  'test_open_recovers_a_missing_creation_id_by_reopening'],
 'fm-dod-lib': ['test_pr_based_dod_draft_check_uses_gh_axi',
  'test_direct_pr_dod_is_forge_aware',
  'test_bitbucket_dod_commands_preserve_shell_arguments'],
 'fm-brief': ['test_ship_modes_generate_clean_briefs',
  'test_direct_pr_brief_follows_the_origin_remote']
}
for suite, names in selectors.items():
 source = (root/'tests'/f'{suite}.test.sh').read_text()
 # Retain the existing executable test functions, but select only this intent's cases.
 source = re.sub(r'^test_[A-Za-z0-9_]+\s*$', '', source, flags=re.M)
 source = re.sub(r'^echo "all .* tests passed"$', '', source, flags=re.M)
 source += '\n' + '\n'.join(names) + '\n'
 source += f'''\npython3 - "$TMP_ROOT" '{evidence}' '{suite}' <<'PY'
from pathlib import Path
import sys
fixture, evidence, suite = map(Path, sys.argv[1:])
outputs = []
if str(suite) == 'fm-pr-bitbucket':
 for case in sorted(fixture.iterdir()):
  if not case.is_dir(): continue
  outputs.append('## ' + case.name + '\\nAPI responses here are stubbed; this is NOT live Bitbucket evidence.\\n')
  for name in ['stdout', 'stderr', 'bb/create-body.json', 'bb/ready-body.json']:
   path = case/name
   if path.is_file():
    text = path.read_text()
    outputs.append('### ' + name + '\\n```\\n' + text + '\\n```\\n')
else:
 for path in sorted(fixture.rglob('*.md')):
  if path.name == 'projects.md': continue
  text = path.read_text()
  if 'Delivery contract:' not in text: continue
  if '# Definition of done' in text:
   text = text[text.index('# Definition of done'):]
  outputs.append('## ' + str(path.relative_to(fixture)) + '\\n' + text + '\\n')
(evidence/(str(suite) + '-product-output.md')).write_text('\\n'.join(outputs))
PY
'''
 driver = root/'tests'/f'.gate-selected-{suite}.sh'
 driver.write_text(source)
 env = os.environ.copy()
 env['TMPDIR'] = str(root/'.gate-test-tmp')
 # Do not allow any selected case to use operator credentials or fleet paths.
 for key in list(env):
  if key.startswith('NO_MISTAKES_BITBUCKET_') or key.startswith('FM_') or key in ['TASKS_AXI_FILE','TASKS_AXI_BACKEND']:
   env.pop(key)
 proc = subprocess.run(['bash',str(driver)], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
 (evidence/f'{suite}-targeted-tests.log').write_text('Selected existing executable tests:\n' + '\n'.join(names) + '\n\n' + proc.stdout + f'\nexit: {proc.returncode}\n')
 driver.unlink()
 print(suite + ': ' + str(proc.returncode) + '\n' + proc.stdout)
 if proc.returncode:
  raise SystemExit(proc.returncode)
