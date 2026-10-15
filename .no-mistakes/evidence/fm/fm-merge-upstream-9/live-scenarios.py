#!/usr/bin/env python3
"""Disposable product CLI checks; run from the assigned gate worktree."""
import os, pathlib, subprocess, json, shutil, time
ROOT=pathlib.Path.cwd()
EVIDENCE=pathlib.Path('/home/node/.no-mistakes/evidence/01M4ZZGKP3RXD7YF8SFH2KDVQJ')
BASE=ROOT/'.test-validation/scenarios'
BASE.mkdir(parents=True,exist_ok=True)
ENV=os.environ.copy()
for key in list(ENV):
    if (key.startswith('FM_') and key.endswith('_OVERRIDE')) or key in ('FM_HOME','FM_GATE_REFUSE_BYPASS','FM_TEST_SEAM','FM_TEST_HARNESS','FM_TASK_ID','TASKS_AXI_FILE','TASKS_AXI_BACKEND','GIT_DIR','GIT_WORK_TREE','GIT_COMMON_DIR','GIT_CONFIG_COUNT','GIT_CONFIG_PARAMETERS'):
        ENV.pop(key,None)
ENV.update(HOME=str(ROOT/'.test-validation/user-home'),TMPDIR=str(ROOT/'.test-validation/tmp'),XDG_CONFIG_HOME=str(ROOT/'.test-validation/config'),XDG_CACHE_HOME=str(ROOT/'.test-validation/cache'),GIT_CONFIG_GLOBAL=str(ROOT/'tests/git-fixture.gitconfig'),GIT_CONFIG_NOSYSTEM='1',GIT_AUTHOR_NAME='Live Validation',GIT_AUTHOR_EMAIL='validation@example.invalid',GIT_COMMITTER_NAME='Live Validation',GIT_COMMITTER_EMAIL='validation@example.invalid')
results=[]
LOG=[]
def run(args,home=None,expect=0,extra=None,input=None,cwd=None):
    env=ENV.copy()
    if home: env['FM_HOME']=str(home)
    if extra: env.update(extra)
    LOG.append('$ '+ ' '.join(map(str,args)))
    p=subprocess.run(list(map(str,args)),cwd=cwd or ROOT,env=env,input=input,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=45)
    LOG.append(p.stdout.rstrip()+'\n[exit '+str(p.returncode)+']')
    if expect is not None: assert p.returncode==expect, p.stdout
    return p

def cli(script,*args,**kwargs):return run([ROOT/'bin'/script,*args],**kwargs)
def lab(name):
    h=BASE/name
    cli('fm-lab-home.sh','create',h)
    return h

def scenario(name,fn):
    global LOG
    LOG=[]
    try:
        fn(); result='pass'; reason='Observed the actual executable interface and persisted outputs in an isolated lab.'
    except Exception as exc:
        result='fail'; reason=repr(exc); LOG.append('ASSERTION FAILURE: '+reason)
    f=EVIDENCE/(name+'.log'); f.write_text('\n'.join(LOG)+'\n')
    results.append(dict(name=name,result=result,live=True,evidence=str(f),reason=reason))
    print(name,result,reason,flush=True)


def away():
    h=lab('away')
    for i in range(6): (h/'state'/('worker-'+str(i)+'.meta')).write_text('kind=ship\nwindow=fm-worker-'+str(i)+'\n')
    (h/'state/mate.meta').write_text('kind=secondmate\nwindow=remote:mate\n')
    assert cli('fm-afk-contract.sh','live-workers',home=h).stdout.strip()=='6'
    cli('fm-afk-contract.sh','enter','--words','Continue existing work; do not publish anything.',home=h)
    assert cli('fm-afk-contract.sh','field','spend_max_concurrent_workers',home=h).stdout.strip()=='6'
    cli('fm-afk-contract.sh','readback',home=h)
    before={p.name:p.read_bytes() for p in (h/'state').glob('*.meta')}
    p=cli('fm-spawn.sh','extra-worker',h/'projects/missing','--mode','local-only','--yolo','off','--harness','claude',home=h,expect=1)
    assert 'caps concurrent workers at 6' in p.stdout and '6 ordinary task(s)' in p.stdout
    assert before=={p.name:p.read_bytes() for p in (h/'state').glob('*.meta')}
    cli('fm-afk-contract.sh','enter','--words','Reduce future parallelism.','--spend','2',home=h)
    assert cli('fm-afk-contract.sh','field','spend_max_concurrent_workers',home=h).stdout.strip()=='2'
    old=(h/'state/.afk-contract').read_bytes()
    cli('fm-afk-contract.sh','enter','--spend','0',home=h,expect=2)
    assert old==(h/'state/.afk-contract').read_bytes()
    cli('fm-afk-contract.sh','archive',home=h)
    for p in (h/'state').glob('*.meta'):p.unlink()
    cli('fm-afk-contract.sh','enter','--words','No running workers.',home=h)
    assert cli('fm-afk-contract.sh','field','spend_max_concurrent_workers',home=h).stdout.strip()=='4'


def recovery():
    h=lab('recovery')
    extra={'FM_POLL':'1','FM_SIGNAL_GRACE':'1','FM_CHECK_INTERVAL':'999999','FM_HEARTBEAT':'999999'}
    cli('fm-watch-checkpoint.sh','--seconds','1',home=h,extra=extra,expect=124)
    assert not (h/'state/.watch.lock/pid').exists()
    cli('fm-watch-checkpoint.sh','--seconds','0',home=h,extra=extra,expect=2)
    # Public wake queue writer; watcher and drain are actual production commands.
    run(['bash','-c','. "$1/bin/fm-wake-lib.sh"; fm_wake_append check buried "check: unacknowledged durable wake"','_',ROOT],home=h)
    p=cli('fm-watch-checkpoint.sh','--seconds','5',home=h,extra=extra)
    assert 'check: rearm-resurface' in p.stdout
    marker=(h/'state/.watcher-down').read_text()
    queue=(h/'state/.wake-queue').read_bytes()
    assert marker.startswith('announced:downtime:')
    p=cli('fm-watch-checkpoint.sh','--seconds','1',home=h,extra=extra,expect=124)
    assert 'check: rearm-resurface' not in p.stdout
    assert marker==(h/'state/.watcher-down').read_text()
    assert queue==(h/'state/.wake-queue').read_bytes()
    LOG.append('Persisted queue after second checkpoint:\n'+queue.decode())
    cli('fm-wake-drain.sh',home=h)


def authority():
    h=lab('authority'); project=h/'projects/firstmate'
    run(['git','clone','-q','--no-local','--no-checkout',ROOT,project])
    run(['git','-C',project,'remote','set-url','origin','https://github.com/cloud-practitioner/firstmate.git'])
    p=cli('fm-brief.sh','unapproved','firstmate','--mode','direct-PR','--project',project,home=h,expect=1)
    assert 'author' in p.stdout.lower() or 'consent' in p.stdout.lower()
    assert not (h/'data/unapproved/brief.md').exists()
    cli('fm-brief.sh','wrong-scope','firstmate','--mode','direct-PR','--project',project,'--upstream-consent','github.com/kunchenguid/firstmate',home=h,expect=1)
    assert not (h/'data/wrong-scope/brief.md').exists()
    cli('fm-brief.sh','approved-fork','firstmate','--mode','direct-PR','--project',project,'--upstream-consent','github.com/cloud-practitioner/firstmate','--herdr-lab',home=h)
    output=(h/'data/approved-fork/brief.md').read_text()
    LOG.append('Generated delivery contract:\n'+'\n'.join(x for x in output.splitlines() if 'Delivery contract:' in x))
    assert 'upstream-consent=github.com/cloud-practitioner/firstmate' in output
    cli('fm-brief.sh','approved-fork','firstmate','--mode','direct-PR','--project',project,'--upstream-consent','github.com/cloud-practitioner/firstmate',home=h,expect=1)


def git_hooks():
    h=lab('hooks'); project=h/'projects/example'; project.mkdir()
    run(['git','init','-q',project])
    hook=project/'.git/hooks/pre-commit'
    hook.write_text('#!/bin/sh\ngit config --get-all credential.helper > "$(git rev-parse --show-toplevel)/hook-config.txt"\n')
    hook.chmod(0o700)
    hooks=h/'state/launch-hooks'; exports=h/'state/exports.sh'
    cli('fm-git-strip-ai-trailers.sh','install',hooks,project)
    inherited={'GIT_CONFIG_COUNT':'2','GIT_CONFIG_KEY_0':'credential.helper','GIT_CONFIG_VALUE_0':'','GIT_CONFIG_KEY_1':'credential.helper','GIT_CONFIG_VALUE_1':'!printf disposable-helper'}
    cli('fm-git-strip-ai-trailers.sh','env-file',hooks,exports,extra=inherited)
    (project/'answer.txt').write_text('42\n');run(['git','-C',project,'add','answer.txt'])
    run(['bash','-c','. "$1"; git -C "$2" commit -m "Live hook check" --trailer "Co-authored-by: CommandCodeBot <noreply@commandcode.ai>" --trailer "Co-authored-by: Jane Doe <jane@example.invalid>"','_',exports,project],extra=inherited)
    message=run(['git','-C',project,'log','-1','--format=full']).stdout
    assert 'CommandCodeBot' not in message and 'Jane Doe' in message
    helpers=(project/'hook-config.txt').read_text()
    LOG.append('Repository hook observed inherited credential.helper values:\n'+helpers)
    assert helpers=='\n!printf disposable-helper\n'
    # Real local Git transport; no publication to a hosted repository.
    remote=h/'projects/disposable-remote.git';run(['git','init','-q','--bare',remote])
    hook=project/'.git/hooks/pre-push';hook.write_text('#!/bin/sh\necho "project pre-push guard refused disposable publication" >&2\nexit 1\n');hook.chmod(0o700)
    p=run(['bash','-c','. "$1"; git -C "$2" push "$3" HEAD:refs/heads/probe','_',exports,project,remote],extra=inherited,expect=1)
    assert 'project pre-push guard refused' in p.stdout
    assert run(['git','-C',remote,'show-ref'],expect=1).stdout==''


def stale_event():
    h=lab('busy');state=h/'state'
    old=cli('fm-busy-event.sh','arm',state,'worker','--source','claude-hook','--event','launch-brief',home=h).stdout.strip()
    new=cli('fm-busy-event.sh','arm',state,'worker','--source','claude-hook','--event','replacement-launch',home=h).stdout.strip()
    assert old!=new
    before={p.name:p.read_bytes() for p in state.glob('worker.*') if p.is_file()}
    p=cli('fm-busy-event.sh','apply',state,'worker','idle','--gen',old,'--source','claude-hook','--event','Stop','--turn-ended',home=h,expect=None)
    assert p.returncode!=0
    assert not (state/'worker.turn-ended').exists()
    assert before=={p.name:p.read_bytes() for p in state.glob('worker.*') if p.is_file()}
    cli('fm-busy-event.sh','apply',state,'worker','idle','--gen',new,'--source','claude-hook','--event','Stop','--turn-ended',home=h)
    assert (state/'worker.turn-ended').exists()
    for p in state.glob('worker.*'):
        if p.is_file():LOG.append('Persisted '+p.name+': '+p.read_text())


def forge_binding():
    h=lab('forge')
    (h/'data/projects.md').write_text('- demo [direct-PR +yolo forge=forgejo] - disposable lab (added 2026-10-15)\n')
    assert cli('fm-project-mode.sh','--forge','demo',home=h).stdout.strip()=='forgejo'
    assert cli('fm-project-mode.sh','demo',home=h).stdout.strip()=='direct-PR on'
    cli('fm-brief.sh','forge-task','demo','--mode','direct-PR','--forge','forgejo',home=h)
    output=(h/'data/forge-task/brief.md').read_text()
    (EVIDENCE/'generated-forgejo-brief.md').write_text(output)
    assert 'Delivery contract: mode=direct-PR forge=forgejo' in output
    cli('fm-brief.sh','bad-local','demo','--mode','local-only','--forge','forgejo',home=h,expect=1)
    assert not (h/'data/bad-local/brief.md').exists()

def unsupported_contribution():
    h=lab('unsupported')
    (h/'data/backlog.md').write_text('# Backlog\n\n## Queued\n- [ ] unsupported - Filed https://gitlab.com/o/r/-/merge_requests/2 (repo: sample) (kind: ship) (hold: choose scope) (hold-kind: captain)\n')
    p=cli('fm-fleet-snapshot.sh','--contribution-input',home=h)
    inp=h/'input.json'; inp.write_text(p.stdout)
    p=cli('fm-contributions.sh','snapshot',inp,'--all',home=h)
    out=json.loads(p.stdout)
    assert out['known']==1 and out['unmeasured']==1 and out['checked']==0
    assert out['counts']['captain']==0 and out['counts']['fleet']==0
    assert not out['complete'] and not out['proven_clear']
    p=cli('fm-contributions.sh','poll',home=h)
    assert p.stdout==''
    assert not (h/'state/.wake-queue').exists() or not (h/'state/.wake-queue').read_bytes()


def concurrent_relaunch():
    h=lab('relaunch');state=h/'state';lock=state/'.control-mate.lock'
    (state/'mate.meta').write_text('kind=secondmate\nharness=claude\nwindow=fm-mate\n')
    dialog=state/'mate.composer-dialog';dialog.write_text('in-flight lifecycle dialog\n')
    meta=(state/'mate.meta').read_bytes()
    env=ENV.copy();env['FM_HOME']=str(h)
    cmd=['bash','-c','. "$1/bin/fm-wake-lib.sh"; fm_lock_try_acquire "$2" || exit 1; echo ready; read -r done; fm_lock_release "$2"','_',str(ROOT),str(lock)]
    LOG.append('$ '+' '.join(cmd))
    holder=subprocess.Popen(cmd,env=env,text=True,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    try:
        assert holder.stdout.readline().strip()=='ready'
        for tool,args in [('fm-control.sh',['mate','relaunch','--note','Competing lifecycle attempt']),('fm-spawn.sh',['mate','--relaunch','--harness','claude'])]:
            p=cli(tool,*args,home=h,expect=1)
            assert 'another lifecycle action is already running' in p.stdout
        assert meta==(state/'mate.meta').read_bytes()
        assert dialog.read_text()=='in-flight lifecycle dialog\n'
        LOG.append('The contended lifecycle left the secondmate metadata and active dialog byte-identical; no endpoint was touched.')
    finally:
        holder.communicate('done\n',timeout=5)
        assert holder.returncode==0

for name,fn in [('away-cap-and-spawn-refusal',away),('watcher-recovery-once',recovery),('fork-publication-authority',authority),('git-hooks-preserve-config-and-human-trailers',git_hooks),('stale-stop-cannot-idle-replacement',stale_event),('forgejo-binding-and-invalid-mode-refusal',forge_binding),('unsupported-contribution-stays-unmeasured',unsupported_contribution),('concurrent-secondmate-relaunch-refuses-without-mutation',concurrent_relaunch)]:
    scenario(name,fn)
(EVIDENCE/'live-results.json').write_text(json.dumps(results,indent=2)+'\n')
# All disposable data remains inside the worktree, and is torn down in this turn.
for p in BASE.rglob('*'):
    if p.is_dir(): p.chmod(p.stat().st_mode | 0o700)
    elif not p.is_symlink(): p.chmod(p.stat().st_mode | 0o600)
shutil.rmtree(BASE)
