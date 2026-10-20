#!/usr/bin/env python3
"""Disposable product CLI checks. All state lives in the supplied worktree."""
import os, subprocess, pathlib, shutil, json
ROOT=pathlib.Path.cwd()
EVIDENCE=pathlib.Path('/home/node/.no-mistakes/evidence/01M5CS8Z14AJ6WRYGCEP0JMSHD')
LAB=ROOT/'.test-lab/cli'
LAB.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith(('FM_','HERDR_','GH_','GITHUB_','BITBUCKET_','NO_MISTAKES_BITBUCKET_','GIT_CONFIG_','TASKS_AXI_'))}
env.update(GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL='/dev/null',GIT_AUTHOR_NAME='Disposable validation',GIT_AUTHOR_EMAIL='validation@example.invalid',GIT_COMMITTER_NAME='Disposable validation',GIT_COMMITTER_EMAIL='validation@example.invalid',TMPDIR=str(ROOT/'.test-lab/tmp'))
log=(EVIDENCE/'live-cli-transcript.log').open('w')
results=[]
def run(args,cwd=ROOT,extra=None,expect=0):
    e=env.copy(); e.update(extra or {})
    p=subprocess.run([str(a) for a in args],cwd=cwd,env=e,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
    log.write('$ '+ ' '.join(str(a) for a in args)+'\n'+p.stdout+f'[exit {p.returncode}]\n');log.flush()
    if expect is not None: assert p.returncode==expect,(args,p.returncode,p.stdout)
    return p

def git(path,*args,**kw):return run(['git','-C',path,*args],**kw)
try:
    # Real installed hook chained through Firstmate's real per-launch Git hooks.
    h=LAB/'hook-home'; repo=h/'projects/iqx-demo';repo.mkdir(parents=True)
    git(repo,'init','-q','-b','main');git(repo,'remote','add','origin','https://bitbucket.org/iqxbusiness/disposable-validation.git')
    (repo/'file').write_text('initial\n')
    run(['bash',ROOT/'contrib/iqx-ixia-hook/ixia-hook-install.sh','iqx-demo'],cwd=h)
    hooks=LAB/'generated-hooks'
    run(['bash','bin/fm-git-strip-ai-trailers.sh','install',hooks,repo])
    msg='#123 retain hash subject\n\nSigned-off-by: Human Reviewer <human@example.invalid>\nCo-Authored-By: Ixia Engineering (Claude) <noreply@anthropic.com>\nCo-Authored-By: Claude <noreply@anthropic.com>'
    git(repo,'add','file');git(repo,'-c',f'core.hooksPath={hooks}','commit','-m',msg)
    body=git(repo,'show','-s','--format=%B').stdout
    trailer='Co-Authored-By: Ixia Engineering (Claude) <noreply@anthropic.com>'
    assert body.strip().endswith(trailer) and body.count(trailer)==1
    assert '#123 retain hash subject' in body and 'Signed-off-by: Human Reviewer <human@example.invalid>' in body
    assert 'Co-Authored-By: Claude <noreply@anthropic.com>' not in body
    old=git(repo,'rev-parse','HEAD').stdout
    git(repo,'-c',f'core.hooksPath={hooks}','commit','--allow-empty','--cleanup=strip','-m','# comments only',expect=1)
    assert git(repo,'rev-parse','HEAD').stdout==old
    run(['bash',ROOT/'contrib/iqx-ixia-hook/ixia-hook-verify.sh','iqx-demo'],cwd=h)
    other=h/'projects/non-iqx';other.mkdir()
    git(other,'init','-q','-b','main');git(other,'remote','add','origin','https://github.com/example/disposable.git')
    refused=run(['bash',ROOT/'contrib/iqx-ixia-hook/ixia-hook-install.sh','non-iqx'],cwd=h,expect=1)
    assert not (other/'.git/hooks/commit-msg').exists()
    results.append({'name':'IQX hook survives the merge and composes with the current Firstmate strip; empty/non-IQX operations refuse','result':'pass','live':True})

    # An actual Bitbucket-shaped URL with an unavailable forge must not bypass
    # preservation. No real credentials or network are used: curl is real and
    # its proxy points at an unused loopback endpoint.
    home=LAB/'pr-home';run(['bin/fm-lab-home.sh','create',home])
    project=LAB/'project';remote=LAB/'remote.git';worker=LAB/'worker'
    project.mkdir();remote.mkdir()
    git(remote,'init','--bare','-q','-b','main')
    git(project,'init','-q','-b','main');git(project,'commit','--allow-empty','-qm','base')
    git(project,'remote','add','origin',str(remote));git(project,'push','-q','origin','main')
    git(ROOT,'clone','-q',project,worker);git(worker,'remote','set-url','origin',str(remote));git(worker,'checkout','-qb','fm/bitbucket')
    git(worker,'commit','--allow-empty','-qm','head initially exists only in disposable worker')
    head=git(worker,'rev-parse','HEAD').stdout.strip()
    meta=home/'state/bitbucket.meta'
    meta.write_text(f'window=unused-validation-endpoint\nworktree={worker}\nproject={project}\nkind=ship\nmode=no-mistakes\nharness=claude\n')
    meta.chmod(0o600)
    pe={'FM_HOME':str(home),'NO_MISTAKES_BITBUCKET_EMAIL':'unusable-validation@example.invalid','NO_MISTAKES_BITBUCKET_API_TOKEN':'deliberately-unusable-no-login','HTTPS_PROXY':'http://127.0.0.1:9','HTTP_PROXY':'http://127.0.0.1:9','ALL_PROXY':'http://127.0.0.1:9','NO_PROXY':''}
    url='https://bitbucket.org/team/repo/pull-requests/7'
    # Execute the actual pre-review-fix product against the same unpreserved
    # head. Only fm-dod-lib.sh differs; all other bin files are copied from
    # the target. No implementation-string assertion is used.
    oldroot=LAB/'pre-fix-product';shutil.copytree(ROOT/'bin',oldroot/'bin')
    previous=subprocess.check_output(['git','show','3898274f:bin/fm-dod-lib.sh'],cwd=ROOT)
    (oldroot/'bin/fm-dod-lib.sh').write_bytes(previous)
    oldhome=LAB/'pre-fix-home';run(['bin/fm-lab-home.sh','create',oldhome])
    (oldhome/'state/bitbucket.meta').write_bytes(meta.read_bytes());(oldhome/'state/bitbucket.meta').chmod(0o600)
    oldenv=pe.copy();oldenv['FM_HOME']=str(oldhome)
    old=run([oldroot/'bin/fm-pr-check.sh','bitbucket',url],extra=oldenv)
    assert 'armed: state/bitbucket.check.sh' in old.stdout,'pre-fix reproduction did not expose the bypass'
    log.write('REGRESSION REPRODUCED: the pre-fix executable armed the poll while named HEAD existed only in the disposable worker. The target must refuse the identical request below.\n');log.flush()
    denied=run(['bin/fm-pr-check.sh','bitbucket',url],extra=pe,expect=1)
    assert f'named head {head} is unreachable outside the worker copy' in denied.stdout
    assert not (home/'state/bitbucket.check.sh').exists()
    assert 'pr=' not in meta.read_text()
    git(worker,'push','-q','origin','HEAD:refs/heads/fm/bitbucket')
    git(worker,'fetch','-q','origin')
    accepted=run(['bin/fm-pr-check.sh','bitbucket',url],extra=pe)
    assert 'armed: state/bitbucket.check.sh' in accepted.stdout
    assert 'pr='+url in meta.read_text()
    run(['git','--git-dir',remote,'show-ref'])
    log.write('Persisted task metadata after durable-head acceptance:\n'+meta.read_text())
    log.flush()
    results.append({'name':'Bitbucket CI-ready registration refuses an unpreserved head, then arms only after a real local push and fetch','result':'pass','live':True})

    # Actual public merge CLI validation: fork option coexists with upstream
    # GitLab waiver, and cannot silently cross provider/no-commit boundaries.
    message=LAB/'merge-message.txt';message.write_bytes(b'  subject from caller  \r\n\r\nbody from caller\r\n')
    rejected=run(['bin/fm-pr-merge.sh','bitbucket',url,'--message-file',message,'--','--rebase'],extra=pe,expect=2)
    assert 'message' in rejected.stdout.lower()
    rejected=run(['bin/fm-pr-merge.sh','bitbucket','https://github.com/example/repo/pull/7','--message-file',message],extra=pe,expect=2)
    assert 'Bitbucket' in rejected.stdout
    rejected=run(['bin/fm-pr-merge.sh','bitbucket',url,'--allow-no-pipeline'],extra=pe,expect=2)
    assert 'only to GitLab' in rejected.stdout
    empty=LAB/'empty-message.txt';empty.write_text(' \t\n')
    rejected=run(['bin/fm-pr-merge.sh','bitbucket',url,'--message-file',empty],extra=pe,expect=2)
    assert 'empty' in rejected.stdout.lower() or 'whitespace' in rejected.stdout.lower()
    results.append({'name':'Merge-message and no-pipeline options refuse unsupported providers, no-commit strategies, and empty messages before network mutation','result':'pass','live':True})

    # New external-review mode must never publish to shared origin, while its
    # one personal durable-copy namespace remains usable through the same hook.
    backup=LAB/'backup.git';backup.mkdir();git(backup,'init','--bare','-q','-b','main')
    git(worker,'remote','add','backup',str(backup))
    guard=LAB/'push-guard';pushhooks=LAB/'push-hooks'
    run(['bin/fm-git-push-guard.sh','write',guard,worker,'fm/bitbucket','fm/','backup','backup/'])
    run(['bin/fm-git-strip-ai-trailers.sh','install','--push-guard',guard,pushhooks,worker])
    git(worker,'commit','--allow-empty','-qm','external review snapshot')
    reviewhead=git(worker,'rev-parse','HEAD').stdout.strip()
    oldref=run(['git','--git-dir',remote,'rev-parse','refs/heads/fm/bitbucket']).stdout
    denied=git(worker,'-c',f'core.hooksPath={pushhooks}','push','origin','HEAD:refs/heads/forbidden',expect=1)
    assert 'fm-git-push-guard: refused:' in denied.stdout
    assert run(['git','--git-dir',remote,'rev-parse','--verify','refs/heads/forbidden'],expect=128).returncode==128
    assert run(['git','--git-dir',remote,'rev-parse','refs/heads/fm/bitbucket']).stdout==oldref
    denied=git(worker,'-c',f'core.hooksPath={pushhooks}','push','backup','HEAD:refs/heads/fm/bitbucket',expect=1)
    assert 'fm-git-push-guard: refused:' in denied.stdout
    git(worker,'-c',f'core.hooksPath={pushhooks}','push','backup','HEAD:refs/heads/backup/bitbucket')
    assert run(['git','--git-dir',backup,'rev-parse','refs/heads/backup/bitbucket']).stdout.strip()==reviewhead
    run(['git','--git-dir',remote,'show-ref']);run(['git','--git-dir',backup,'show-ref'])
    results.append({'name':'External-review push guard blocks shared-origin and task-branch publication but permits the configured durable backup ref','result':'pass','live':True})
except Exception as exc:
    log.write('DRIVER FAILURE: '+repr(exc)+'\n');log.flush()
    results.append({'name':'live CLI driver','result':'fail','live':True,'reason':repr(exc)})
    raise
finally:
    (EVIDENCE/'live-cli-results.json').write_text(json.dumps(results,indent=2)+'\n')
    log.close()
    shutil.rmtree(LAB,ignore_errors=True)
