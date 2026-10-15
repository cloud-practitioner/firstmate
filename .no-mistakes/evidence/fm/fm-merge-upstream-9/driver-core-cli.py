import pathlib,os,subprocess,shutil,json
R=pathlib.Path.cwd();D=R/'.live-test-lab/core';D.mkdir(exist_ok=True);E=pathlib.Path('/home/node/.no-mistakes/evidence/01M4ZWHVKH10H7VQ0P4VH5RD51');H=D/'home';H.mkdir(exist_ok=True)
env={'PATH':os.environ['PATH'],'HOME':str(H),'TMPDIR':str(R/'.live-test-lab/tmp'),'LANG':'C.UTF-8','USER':'node','LOGNAME':'node','GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':str(H/'.gitconfig'),'NO_MISTAKES_GATE':'1'}
f=open(E/'core-cli-live.log','w',buffering=1)
def run(a,ok=True,cwd=R,extra=None):
 e=env.copy();e.update(extra or {})
 p=subprocess.run([str(x) for x in a],env=e,cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=35)
 f.write('$ '+' '.join(str(x) for x in a)+'\n'+p.stdout+'exit='+str(p.returncode)+'\n')
 if ok and p.returncode:raise RuntimeError(p.stdout)
 return p
try:
 A=D/'away';run(['bin/fm-lab-home.sh','create',A]);env['FM_HOME']=str(A)
 for i in range(6):(A/'state'/f'ordinary-{i}.meta').write_text(f'window=fm-ordinary-{i}\nkind=ship\n')
 (A/'state/mate.meta').write_text('window=fm-mate\nkind=secondmate\n')
 assert run(['bin/fm-afk-contract.sh','live-workers']).stdout.strip()=='6'
 out=run(['bin/fm-afk-contract.sh','enter','--words','Keep existing work within the current lane; never publish upstream.'])
 assert run(['bin/fm-afk-contract.sh','field','spend_max_concurrent_workers']).stdout.strip()=='6'
 denied=run(['bin/fm-spawn.sh','queued-probe',D,'--scout','--harness','claude'],ok=False)
 assert denied.returncode!=0 and 'caps concurrent workers at 6 and 6 ordinary' in denied.stdout
 assert not (A/'state/queued-probe.meta').exists()
 run(['bin/fm-afk-contract.sh','archive'])
 for p in (A/'state').glob('ordinary-*.meta'):p.unlink()
 run(['bin/fm-afk-contract.sh','enter','--words','Use normal empty-home floor.'])
 assert run(['bin/fm-afk-contract.sh','field','spend_max_concurrent_workers']).stdout.strip()=='4'
 run(['bin/fm-afk-contract.sh','archive'])
 run(['bin/fm-afk-contract.sh','enter','--spend','2','--words','Explicit cap wins.'])
 assert run(['bin/fm-afk-contract.sh','field','spend_max_concurrent_workers']).stdout.strip()=='2'
 run(['bin/fm-afk-contract.sh','archive'])
 G=D/'git';G.mkdir();run(['git','init','-q','-b','main',G]);run(['git','-C',G,'config','user.name','Disposable Hook Test']);run(['git','-C',G,'config','user.email','hook-test@example.invalid'])
 (G/'.githooks').mkdir();run(['git','-C',G,'config','core.hooksPath','.githooks'])
 hook=G/'.githooks/pre-commit';hook.write_text('#!/bin/sh\nprintf "Repository pre-commit inherited credential helper: "\ngit config --get credential.helper\nprintf "Repository pre-commit inherited fixture value: "\ngit config --get fixture.inherited\n[ "$(git config --get fixture.inherited)" = keep-me ]\n');hook.chmod(0o755)
 hook=G/'.githooks/pre-push';hook.write_text('#!/bin/sh\necho "Repository pre-push refuses this disposable push" >&2\nexit 23\n');hook.chmod(0o755)
 hooks=D/'launch-hooks';run(['bin/fm-git-strip-ai-trailers.sh','install',hooks,G])
 inherited={'GIT_CONFIG_COUNT':'2','GIT_CONFIG_KEY_0':'credential.helper','GIT_CONFIG_VALUE_0':'disposable-fixture-helper','GIT_CONFIG_KEY_1':'fixture.inherited','GIT_CONFIG_VALUE_1':'keep-me'}
 efile=D/'git-env.sh';run(['bin/fm-git-strip-ai-trailers.sh','env-file',hooks,efile],extra=inherited)
 (G/'result.txt').write_text('actual commit artifact\n');msg=D/'message.txt';msg.write_text('Preserve inherited configuration\n\nCo-authored-by: CommandCodeBot <noreply@commandcode.ai>\nCo-authored-by: Human Reviewer <human@example.invalid>\n')
 run(['git','-C',G,'add','.'],extra=inherited)
 p=run(['bash','-c','source "$1"; git -C "$2" commit -q -F "$3"','_',efile,G,msg],extra=inherited)
 body=run(['git','-C',G,'log','-1','--format=%B']).stdout
 assert 'CommandCodeBot' not in body and 'Human Reviewer' in body
 assert 'disposable-fixture-helper' in p.stdout and 'keep-me' in p.stdout
 bare=D/'remote.git';run(['git','init','--bare','-q',bare]);run(['git','-C',G,'remote','add','origin',bare])
 pushed=run(['bash','-c','source "$1"; git -C "$2" push origin main','_',efile,G],ok=False,extra=inherited)
 assert pushed.returncode!=0 and 'pre-push refuses' in pushed.stdout
 assert run(['git','--git-dir',bare,'rev-parse','--verify','refs/heads/main'],ok=False).returncode!=0
 C=D/'contributions';run(['bin/fm-lab-home.sh','create',C]);env['FM_HOME']=str(C)
 (C/'.tasks.toml').write_text('backend = "markdown"\n[markdown]\npath = "data/backlog.md"\narchive = "data/done-archive.md"\ndone_keep = 10\n')
 (C/'data/backlog.md').write_text('# Backlog\n\n## Queued\n- [ ] external - External review https://gitlab.example/owner/repo/-/merge_requests/7 (repo: fixture) (kind: ship)\n')
 (C/'data/external').mkdir();record={'schema':'fm-contributions.v1','task':'external','records':[{'url':'https://gitlab.example/owner/repo/-/merge_requests/7','kind':'pr','checked_at':None,'error':'forge observation unavailable: old unsupported URL error','observation':None,'pending':[],'seen':[],'verdict':None}]};recordfile=C/'data/external/contributions.json';recordfile.write_text(json.dumps(record))
 polled=run(['bin/fm-contributions.sh','poll']);assert not polled.stdout.strip()
 assert json.loads(recordfile.read_text())['records'][0]['error'] is None
 assert not (C/'state/.wake-queue').exists() or not (C/'state/.wake-queue').read_text().strip()
 snapshot=run(['bin/fm-bearings-snapshot.sh','--json']);obj=json.loads(snapshot.stdout)
 f.write('Contribution coverage summary: '+json.dumps(obj['contributions'])+'\n')
 assert obj['contributions']['unmeasured']==1 and obj['contributions']['checked']==0 and not obj['contributions']['proven_clear']
 B=D/'brief';run(['bin/fm-lab-home.sh','create',B]);env['FM_HOME']=str(B)
 root_commit=run(['git','rev-list','--max-parents=0','HEAD']).stdout.strip().splitlines()[0]
 run(['git','-C',G,'fetch','--quiet','--no-tags',R,root_commit])
 run(['git','-C',G,'remote','set-url','origin','https://github.com/kunchenguid/firstmate.git'])
 denied=run(['bin/fm-brief.sh','upstream-denied','firstmate','--mode','direct-PR','--project',G],ok=False)
 assert denied.returncode!=0 and ('authority' in denied.stdout or 'consent' in denied.stdout)
 assert not (B/'data/upstream-denied/brief.md').exists()
 run(['git','-C',G,'remote','set-url','origin','https://github.com/cloud-practitioner/firstmate.git'])
 run(['bin/fm-brief.sh','fork-target','firstmate','--mode','direct-PR','--project',G,'--upstream-consent','github.com/cloud-practitioner/firstmate'])
 f.write('Live assertions: cap default/count/floor/override and pre-allocation refusal; real Git commit kept inherited config/human trailer while stripping bot; repository pre-push blocked publication; unsupported URL remained unmeasured without a wake; upstream task refused without consent and fork task scaffolded.\n')
finally:
 f.close()
 if D.exists():
  for p in D.rglob('*'):
   if p.is_dir():p.chmod(0o700)
  shutil.rmtree(D)
