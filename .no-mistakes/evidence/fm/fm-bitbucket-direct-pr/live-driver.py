from pathlib import Path
import os, subprocess, shutil, re, json, shlex
root = Path.cwd()
tmp = root/'.gate-test-tmp'
evidence = Path('/home/node/.no-mistakes/evidence/01M49Z4JCXXQR6ZMPDQQC08J2K')
install = tmp/"first mate's files"
install.mkdir()
shutil.copytree(root/'bin', install/'bin')
home = tmp/'manual-user-home'
home.mkdir()
lab = tmp/'live-lab-home'
# Only explicitly selected environment settings: no operator credentials,
# fleet overrides, task state, SSH agents, login stores, or global git config.
env = {key:os.environ[key] for key in ['PATH','LANG','TERM','NO_MISTAKES_GATE'] if key in os.environ}
env.update(HOME=str(home), TMPDIR=str(tmp), USER='validation-user',
 GIT_CONFIG_GLOBAL=str(root/'tests/git-fixture.gitconfig'), GIT_CONFIG_NOSYSTEM='1',
 GIT_AUTHOR_NAME='Validation fixture', GIT_AUTHOR_EMAIL='validation@example.invalid',
 GIT_COMMITTER_NAME='Validation fixture', GIT_COMMITTER_EMAIL='validation@example.invalid')
log=[]
def run(args, cwd=root, expected=0, extra=None, record=True):
 e=env.copy()
 if extra: e.update(extra)
 p=subprocess.run(list(map(str,args)), cwd=cwd, env=e, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=30)
 if record:
  log.append('$ '+shlex.join(list(map(str,args)))+'\n'+p.stdout+p.stderr+'exit: '+str(p.returncode)+'\n')
 assert p.returncode == expected, f'{args}: expected {expected}, got {p.returncode}: {p.stdout} {p.stderr}'
 return p
run([root/'bin/fm-lab-home.sh','create',lab])
env['FM_HOME']=str(lab)
repo=lab/'projects/bb-proj'
run(['git','init','-q','-b','main',repo],record=False)
run(['git','commit','-q','--allow-empty','-m','Initial disposable project'],cwd=repo,record=False)
branch="feature/$USER/o'brien"
run(['git','checkout','-q','-b',branch],cwd=repo,record=False)
run(['git','commit','-q','--allow-empty','-m','Direct PR task: title with "quotes"','-m','Commit-derived description.\nSecond body line.'],cwd=repo,record=False)
run(['git','remote','add','origin','https://bitbucket.org/ws/bb-proj.git'],cwd=repo,record=False)
head=run(['git','rev-parse','HEAD'],cwd=repo,record=False).stdout.strip()
helper = install/'bin/fm-pr-open.sh'
url='https://bitbucket.org/ws/bb-proj/pull-requests/7'
forms=['https://bitbucket.org/ws/bb-proj.git','git@bitbucket.org:ws/bb-proj.git','ssh://git@bitbucket.org/ws/bb-proj.git','ssh://git@bitbucket.org:22/ws/bb-proj.git','ssh://git@altssh.bitbucket.org:443/ws/bb-proj.git']
# Run the actual helper, real curl/jq/git on PATH, with no request interception.
for origin in forms:
 log.append('Origin fixture: '+origin+'\n')
 run(['git','remote','set-url','origin',origin],cwd=repo,record=False)
 p=run([helper,'open'],cwd=repo,expected=1)
 assert 'requires the NO_MISTAKES_BITBUCKET_EMAIL' in p.stderr and 'NO_MISTAKES_BITBUCKET_API_TOKEN' in p.stderr
 for cmd in ['verify','ready']:
  p=run([helper,cmd,url],cwd=repo,expected=1)
  assert 'NO_MISTAKES_BITBUCKET_EMAIL' in p.stderr
# Synthetic token deliberately supplied without email: no API request is possible.
p=run([helper,'open'],cwd=repo,expected=1,extra={'NO_MISTAKES_BITBUCKET_API_TOKEN':'REDACTION_SENTINEL_TOKEN'})
assert 'REDACTION_SENTINEL_TOKEN' not in p.stdout+p.stderr
for cmd in ['verify','ready']:
 p=run([helper,cmd],cwd=repo,expected=2)
 assert 'requires the pull request URL' in p.stderr
 p=run([helper,cmd,'https://bitbucket.org/foreign/repo/pull-requests/7'],cwd=repo,expected=1)
 assert 'does not name' in p.stderr
for flag in ['--worktree','--source','--repo','--dest','--title','--description']:
 p=run([helper,'open',flag,'arbitrary-value'],cwd=repo,expected=2)
 assert 'unknown option' in p.stderr
for context in ['no-origin','github','detached']:
 log.append('Local context fixture: '+context+'\n')
 if context=='no-origin': run(['git','remote','remove','origin'],cwd=repo,record=False)
 elif context=='github': run(['git','remote','add','origin','https://user:ORIGIN_SECRET_SENTINEL@github.com/o/r.git'],cwd=repo,record=False)
 else:
  run(['git','remote','set-url','origin',forms[0]],cwd=repo,record=False)
  run(['git','checkout','-q','--detach'],cwd=repo,record=False)
 for cmd in ['open','verify','ready']:
  p=run([helper,cmd]+([] if cmd=='open' else [url]),cwd=repo,expected=1)
  assert 'ORIGIN_SECRET_SENTINEL' not in p.stdout+p.stderr
  phrase={'no-origin':'no origin remote','github':'not a Bitbucket Cloud repository','detached':'detached HEAD'}[context]
  assert phrase in p.stderr
run(['git','checkout','-q',branch],cwd=repo,record=False)
# The fixture home sits inside the gate worktree: ceiling prevents discovery of
# that parent repository, modeling an ordinary directory outside any git copy.
p=run([helper,'open'],cwd=home,expected=1,extra={'GIT_CEILING_DIRECTORIES':str(tmp)})
assert 'not a git work tree' in p.stderr
(evidence/'live-cli-refusals.log').write_text('Actual product CLI with real git/curl/jq, isolated HOME, no network or API stub.\n\n'+'\n'.join(log))
log=[]
# Render the final owned instruction contract for each origin form, then promote
# an isolated scout record through the real public CLI (no running worker needed).
(lab/'data/projects.md').write_text('- bb-proj [direct-PR] - disposable validation project\n- gh-proj [direct-PR] - disposable validation project\n')
contracts=[]
for index,origin in enumerate(forms):
 run(['git','remote','set-url','origin',origin],cwd=repo,record=False)
 task=f'live-bb-{index}'
 run([install/'bin/fm-brief.sh',task,'bb-proj','--mode','direct-PR'])
 brief=(lab/'data'/task/'brief.md').read_text()
 contract=brief[brief.index('# Definition of done'):]
 assert 'fm-pr-open.sh open' in contract and 'gh-axi pr view' not in contract
 contracts.append('## '+origin+'\n'+contract)
 scout=f'live-promote-{index}'
 run([install/'bin/fm-brief.sh',scout,'bb-proj','--scout'])
 scout_path=lab/'data'/scout/'brief.md'
 scout_text=scout_path.read_text().replace('{TASK}','Add the direct PR path for this disposable project.').replace('{FIRSTMATE_SPEC}','Investigate the existing PR commands before implementing the task.')
 scout_path.write_text(scout_text)
 (lab/'state'/f'{scout}.meta').write_text(f'kind=scout\nproject={repo}\nworktree={repo}\nwindow=fm-{scout}\n')
 run([install/'bin/fm-promote.sh',scout,'--mode','direct-PR','--yolo','off'])
 instructions=(lab/'data'/scout/'ship-instructions.md').read_text()
 promoted_contract=instructions[instructions.index('# Definition of done'):]
 assert 'fm-pr-open.sh open' in promoted_contract and 'gh-axi pr view' not in promoted_contract
 assert promoted_contract in (lab/'data'/scout/'brief.md').read_text()
 meta=(lab/'state'/f'{scout}.meta').read_text()
 assert 'kind=ship\n' in meta and 'mode=direct-PR\n' in meta
 contracts.append('## Promoted '+origin+'\n'+promoted_contract+'\n### Persisted task record\n```\n'+meta+'```\n')
(evidence/'live-brief-and-promotion.md').write_text('\n'.join(contracts))
# Execute the emitted push/open/verify/ready snippets using the REAL product from
# an installation containing spaces/apostrophes and a literal $USER branch.
quoted_task='live-quoted'
run([install/'bin/fm-brief.sh',quoted_task,'bb-proj','--mode','direct-PR','--branch-prefix',"quoted/$USER/o'brien/"])
text=(lab/'data'/quoted_task/'brief.md').read_text()
quoted_branch="quoted/$USER/o'brien/"+quoted_task
run(['git','checkout','-q','-b',quoted_branch],cwd=repo,record=False)
remote=tmp/'disposable-push.git'
run(['git','init','-q','--bare',remote],record=False)
run(['git','remote','set-url','--push','origin',remote],cwd=repo,record=False)
selected=[]
for snippet in re.findall(r'`([^`]+)`',text):
 if snippet.startswith('git push -u origin ') or snippet.endswith(' open') or snippet.endswith(' verify <pr-url>') or snippet.endswith(' ready <pr-url>'):
  selected.append(snippet.replace('<pr-url>',url))
assert len(selected)==4, selected
for snippet in selected:
 p=run(['bash','-c',snippet],cwd=repo,expected=0 if snippet.startswith('git push ') else 1)
 if not snippet.startswith('git push '): assert 'NO_MISTAKES_BITBUCKET_EMAIL' in p.stderr
remote_hash=run(['git','--git-dir',remote,'rev-parse','refs/heads/'+quoted_branch]).stdout.strip()
assert remote_hash==head
assert run(['git','--git-dir',remote,'for-each-ref','--format=%(refname)','refs/heads/']).stdout.strip()=='refs/heads/'+quoted_branch
(evidence/'live-quoted-dod.md').write_text(text[text.index('# Definition of done'):])
# GitHub scaffold stays GitHub; no-mistakes changes neither forge's DoD.
gh=lab/'projects/gh-proj'
run(['git','init','-q','-b','main',gh],record=False)
run(['git','remote','add','origin','https://github.com/o/gh-proj.git'],cwd=gh,record=False)
run([install/'bin/fm-brief.sh','live-github','gh-proj','--mode','direct-PR'])
github=(lab/'data/live-github/brief.md').read_text()
assert 'open a PR with `gh-axi`' in github and 'fm-pr-open.sh' not in github
run([install/'bin/fm-brief.sh','live-no-mistakes','bb-proj','--mode','no-mistakes'])
no_mistakes=(lab/'data/live-no-mistakes/brief.md').read_text()
assert 'fm-pr-open.sh' not in no_mistakes
(evidence/'live-unchanged-contracts.md').write_text('# GitHub direct-PR\n'+github[github.index('# Definition of done'):]+'\n# Bitbucket no-mistakes\n'+no_mistakes[no_mistakes.index('# Definition of done'):])
# Compare runtime rendered DoDs with the base commit, without starting a pipeline.
baseline_bin=tmp/'baseline-bin'
shutil.copytree(root/'bin',baseline_bin)
baseline=subprocess.run(['git','show','17a7b57015e3b3c8575d7e8775782e4b08b44869:bin/fm-dod-lib.sh'],cwd=root,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
(baseline_bin/'fm-dod-lib.sh').write_bytes(baseline.stdout)
for mode,forge in [('direct-PR','none'),('no-mistakes','none'),('local-only','none'),('direct-PR','gerrit'),('no-mistakes','gerrit')]:
 command='. "$1"; fm_dod_block "$2" unchanged-task fm/unchanged-task "$3"'
 old=run(['bash','-c',command,'_',baseline_bin/'fm-dod-lib.sh',mode,forge],record=False).stdout
 new=run(['bash','-c',command,'_',root/'bin/fm-dod-lib.sh',mode,forge],record=False).stdout
 assert old==new, (mode,forge)
 log.append(f'Rendered DoD is byte-identical to base commit: mode={mode}, forge={forge}\n')
(evidence/'live-generation-and-shell-commands.log').write_text('Real product scaffolding, promotion, and emitted snippets. No fake executable, API, worker, login, or production credential was used.\n\n'+'\n'.join(log))
print('Live guard, scaffold, promotion, quoted-command and unchanged-contract checks passed. No network request was made.')
