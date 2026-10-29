import os, pathlib, subprocess, tempfile, shutil, json, shlex
ROOT=pathlib.Path.cwd()
EV=pathlib.Path('/home/node/.no-mistakes/evidence/01M643TH9MB3MKY9CTY96RSFYG')
TMP=ROOT/'.test-phase/tmp'
base=os.environ.copy()
for key in list(base):
    if key.startswith(('FM_', 'HERDR_','PI_','GIT_')) or key in ('NO_MISTAKES_BITBUCKET_EMAIL','NO_MISTAKES_BITBUCKET_API_TOKEN','GH_TOKEN','GITHUB_TOKEN'):
        base.pop(key,None)
base.update(TMPDIR=str(TMP),PYTHONDONTWRITEBYTECODE='1',GIT_CONFIG_GLOBAL='/dev/null',GIT_CONFIG_NOSYSTEM='1',GIT_AUTHOR_NAME='Disposable test',GIT_AUTHOR_EMAIL='test@example.invalid',GIT_COMMITTER_NAME='Disposable test',GIT_COMMITTER_EMAIL='test@example.invalid')
log=(EV/'cli-live.log').open('w')
def emit(s):
    print(s,flush=True);print(s,file=log,flush=True)
def run(args,env=None,cwd=ROOT,expected=0):
    cmd=[str(a) for a in args]
    emit('$ '+shlex.join(cmd))
    p=subprocess.run(cmd,cwd=cwd,env=env or base,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
    emit(p.stdout.rstrip());emit('exit='+str(p.returncode))
    if expected is not None: assert p.returncode==expected,(cmd,p.stdout,p.returncode)
    return p
labs=[]
def lab():
    p=pathlib.Path(tempfile.mkdtemp(prefix='fm-lab.',dir=TMP));labs.append(p)
    run([ROOT/'bin/fm-lab-home.sh','create',p]);e=base.copy();e['FM_HOME']=str(p);return p,e
try:
    emit('=== Merge topology consumed by Git ===')
    parents=run(['git','rev-list','--parents','-n','1','64ec5d95']).stdout.split()
    assert len(parents)==3
    for rev in ('6b81e84f','0adf422e'):
        run(['git','merge-base','--is-ancestor',rev,'acb8ff52'])
    incoming=int(run(['git','rev-list','--count','6b81e84f..0adf422e']).stdout)
    assert incoming==33
    run(['git','show','--format=fuller','--no-patch','64ec5d95'])
    (EV/'merge-topology.json').write_text(json.dumps({'merge':parents[0],'parents':parents[1:],'incoming_upstream_commits':incoming,'fork_history_retained':True,'upstream_history_retained':True},indent=2)+'\n')

    emit('=== IQX generator consumes the merged scout scaffold ===')
    h,e=lab();plans=h/'data/TKT-LAB/plans';plans.mkdir(parents=True)
    for name in ['plan.md','dispositions.md','changes.md']:(plans/name).write_text('Disposable test input for '+name+'\n')
    run([ROOT/'bin/fm-brief.sh','lens-check','disposable','--scout','--herdr-lab'],e)
    gen=['python3',ROOT/'contrib/iqx-lenses/mk-lens-brief.py','runproof','--home',h,'--task','lens-check','--ticket','TKT-LAB','--plan',plans/'plan.md','--dispositions',plans/'dispositions.md','--changes',plans/'changes.md']
    run(gen,e)
    brief=h/'data/lens-check/brief.md'
    shutil.copyfile(brief,EV/'generated-runproof-brief.md')
    first=brief.read_bytes()
    assert run(gen,e,expected=None).returncode != 0
    assert brief.read_bytes()==first
    emit('Generated run-proof brief saved; repeat fill refused without mutation.')

    emit('=== Allowlisted record snapshots, generations, and symlink refusal ===')
    h,e=lab();dest=h.parent/(h.name+'-export');labs.append(dest)
    (h/'config/record-export-root').write_text(str(dest)+'\n')
    (h/'data/export-check').mkdir();(h/'data/export-check/brief.md').write_text('Preserve the fork add-ons.\n')
    (h/'data/export-check/report.md').write_text('done: disposable record export proof\n')
    (h/'data/export-check/private.txt').write_text('not in allowlist\n')
    (h/'state/export-check.meta').write_text('kind=scout\nspawn_gen=live-validation-1\n')
    (h/'state/export-check.inbox/handled').mkdir(parents=True)
    (h/'state/export-check.inbox/001.msg').write_text('Disposable pending instruction\n')
    run([ROOT/'bin/fm-record-export.sh','sync'],e)
    inventory=sorted(str(p.relative_to(dest)) for p in dest.rglob('*') if p.is_file())
    emit('Published inventory:\n'+'\n'.join(inventory))
    assert (dest/'live/data/export-check/brief.md').read_bytes()==(h/'data/export-check/brief.md').read_bytes()
    assert not (dest/'live/data/export-check/private.txt').exists()
    run([ROOT/'bin/fm-record-export.sh','archive-task','export-check'],e)
    manifests=list(dest.rglob('manifest.v1.json'));assert len(manifests)==1
    manifest=json.loads(manifests[0].read_text());emit(json.dumps(manifest,indent=2))
    shutil.copyfile(manifests[0],EV/'export-archive-manifest.json')
    before={str(p.relative_to(dest)):p.read_bytes() for p in (dest/'live').rglob('*') if p.is_file()}
    sentinel=h/'private-sentinel';sentinel.write_text('leave me alone\n')
    (h/'data/export-check/report.md').unlink();(h/'data/export-check/report.md').symlink_to(sentinel)
    refused=run([ROOT/'bin/fm-record-export.sh','sync'],e,expected=1)
    assert 'symlink' in refused.stdout.lower() or 'regular' in refused.stdout.lower()
    after={str(p.relative_to(dest)):p.read_bytes() for p in (dest/'live').rglob('*') if p.is_file()}
    assert before==after and sentinel.read_text()=='leave me alone\n'
    emit('Unsafe input left the complete prior snapshot and sentinel byte-identical.')

    emit('=== Local landing refuses an unapproved head, then lands exactly its pinned head ===')
    h,e=lab();proj=h/'projects/landing';wt=h/'worker'
    run(['git','init','-q','-b','main',proj],e)
    run(['git','-C',proj,'commit','-q','--allow-empty','-m','base'],e)
    start=run(['git','-C',proj,'rev-parse','HEAD'],e).stdout.strip()
    run(['git','-C',proj,'worktree','add','-q','-b','fm/local-check',wt],e)
    (wt/'approved.txt').write_text('approved commit only\n')
    run(['git','-C',wt,'add','approved.txt'],e)
    run(['git','-C',wt,'commit','-q','-m','approved change'],e)
    head=run(['git','-C',wt,'rev-parse','HEAD'],e).stdout.strip()
    meta=h/'state/local-check.meta'
    meta.write_text(f'kind=ship\nmode=local-only\nbranch=fm/local-check\nproject={proj}\nworktree={wt}\nspawn_gen=live-landing-1\n')
    run([ROOT/'bin/fm-merge-local.sh','local-check'],e,expected=1)
    assert run(['git','-C',proj,'rev-parse','HEAD'],e).stdout.strip()==start
    run(['bash','-c','. "$1/bin/fm-dod-lib.sh"; fm_dod_accept_ship_done ship local-only "$2" "$3" "done [at=1790000000]: ready in branch fm/local-check" "$4/state" local-check "$4/state/local-check.meta"','_',ROOT,wt,proj,h],e)
    run([ROOT/'bin/fm-merge-local.sh','local-check'],e)
    assert run(['git','-C',proj,'rev-parse','HEAD'],e).stdout.strip()==head
    emit('Landed content: '+(proj/'approved.txt').read_text())

    emit('=== Process-event capture and queued-wake de-duplication ===')
    h,e=lab();e['FM_PROCEVENT_CLAIM_ROOT']=str(h/'claims')
    pe=ROOT/'bin/fm-procevent.sh';printf=shutil.which('printf')
    run([pe,'register','lavish','local-proof','--',printf,r'%s\n','status: feedback','prompts[1]{uid,text}:','  local,Keep fork behavior'],e)
    run([pe,'start','local-proof'],e)
    # Stop producing new events while retaining the already-captured unhandled round.
    run([pe,'retire','local-proof'],e)
    q=h/'state/.wake-queue';initial=q.read_bytes();assert len(initial.splitlines())==1
    emit('Persisted public wake record:\n'+q.read_text())
    for i in range(3):run([pe,'reconcile'],e)
    assert q.read_bytes()==initial
    result=list((h/'state/procevent-inbox').glob('*.result'));assert len(result)==1
    emit('Captured result:\n'+result[0].read_text())
    seq=result[0].name.split('.')[-2]
    run([pe,'handled','local-proof',seq],e)
    run([pe,'handled','local-proof',seq],e)
    run([pe,'retire','local-proof'],e)
    emit('Repeated reconcile preserved one queued wake; repeated acknowledgement did not re-authorize handling.')
finally:
    for p in reversed(labs):shutil.rmtree(p,ignore_errors=True)
    log.close()
