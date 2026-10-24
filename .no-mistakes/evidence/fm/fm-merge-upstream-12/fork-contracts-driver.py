import os, pathlib, subprocess, json, shutil, re
ROOT=pathlib.Path.cwd(); EV=pathlib.Path('/home/node/.no-mistakes/evidence/01M5NDSRSC3QSFVJQR0FE670EK')
env=dict(os.environ)
for k in list(env):
    if k.startswith(('FM_','HERDR_','TASKS_AXI_','GH_','GITHUB_','REX_','BITBUCKET_','BB_','NO_MISTAKES_BITBUCKET_')) or k=='TMUX':env.pop(k,None)
env.update(TMPDIR=str(ROOT/'.test-phase/tmp'),GIT_CONFIG_GLOBAL='/dev/null',GIT_CONFIG_NOSYSTEM='1')
log=(EV/'fork-contracts-cli.log').open('w')
def run(args,expected=0,cwd=ROOT,e=None):
    log.write('$ '+' '.join(map(str,args))+'\n');log.flush()
    r=subprocess.run(list(map(str,args)),cwd=cwd,env=e or env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    log.write(r.stdout+f'[exit {r.returncode}]\n');log.flush()
    if r.returncode!=expected: raise RuntimeError(str(args)+' failed: '+r.stdout)
    return r.stdout
home=ROOT/'.test-phase/contracts';run(['bash','bin/fm-lab-home.sh','create',home]);(home/'user').mkdir()
e=dict(env,FM_HOME=str(home),HOME=str(home/'user'),FM_BACKEND='tmux')
# Drive the real Git consumer with a durable local bare remote, not a forge mock.
remote=home/'projects/remote.git';project=home/'projects/shared';wt=home/'projects/worker'
run(['git','init','--bare','--initial-branch=main',remote],e=e)
run(['git','clone',remote,project],e=e)
for p in [project]:
    run(['git','-C',p,'config','user.name','Validation Fixture'],e=e);run(['git','-C',p,'config','user.email','validation@example.invalid'],e=e)
run(['git','-C',project,'commit','--allow-empty','-m','Initial durable commit'],e=e)
run(['git','-C',project,'push','origin','HEAD:main'],e=e)
run(['git','clone',remote,wt],e=e)
run(['git','-C',wt,'config','user.name','Validation Fixture'],e=e);run(['git','-C',wt,'config','user.email','validation@example.invalid'],e=e)
run(['git','-C',wt,'checkout','--detach'],e=e)
run(['git','-C',wt,'commit','--allow-empty','-m','Unpublished worker head'],e=e)
(home/'state/task.meta').write_text(f'window=primary:fm-task\nworktree={wt}\nproject={project}\nkind=ship\nmode=no-mistakes\nharness=claude\nbackend=tmux\nspawn_gen=live-head\n')
(home/'state/task.status').write_text('done: PR https://bitbucket.org/ws/repo/pull-requests/7 checks green\n')
accept=['bash','-c','. "$1"; fm_dod_accept_ship_done ship no-mistakes "$2" "$3" "done: PR https://bitbucket.org/ws/repo/pull-requests/7 checks green"', '_', ROOT/'bin/fm-dod-lib.sh',wt,project]
before=run(accept,1,e=e)
assert 'unreachable outside the worker copy' in before
run(['git','-C',wt,'push','origin','HEAD:refs/heads/topic'],e=e)
after=run(accept,e=e)
run(['git','-C',wt,'show-ref','refs/remotes/origin/topic'],e=e)
run(['git','-C',wt,'commit','--allow-empty','-m','Private follow-up after the green head'],e=e)
new=run(accept,1,e=e)
assert 'unreachable outside the worker copy' in new
# Evidence intake fails closed, then accepts the declared UI contract.
run(['git','-C',project,'remote','set-url','origin','https://github.com/o/r.git'],e=e)
(home/'config/pr-evidence').write_text('* enforce\nsample require\n')
brief=home/'brief.md';brief.write_text('# Task\n\n## Task\n\nBuild the command.\n')
out=run(['bash','bin/fm-pr-evidence.sh','intake',brief,'sample','no-mistakes','none',project],1,e=e)
assert '[FAIL]' in out and 'Evidence class' in out
brief.write_text('# Task\n\n## Task\n\nBuild the command.\n\n## Evidence class\n\nnone: The change has no visible effect.\n')
out=run(['bash','bin/fm-pr-evidence.sh','intake',brief,'sample','no-mistakes','none',project],1,e=e)
assert 'none is not allowed' in out
brief.write_text('# Task\n\n## Task\n\nBuild the command.\n\n## Evidence class\n\nui\n')
out=run(['bash','bin/fm-pr-evidence.sh','intake',brief,'sample','no-mistakes','none',project],e=e);assert 'evidence=ui' in out
# Produce actual reviewer-visible annotated CLI evidence through the shipped gate.
ret=(EV/'retained-artifacts-cli.log').read_text()
chunks=re.split(r'\$ tasks-axi show task --full\n',ret)[1:]
for name,chunk in [('before',chunks[0]),('after',chunks[1])]:
    lines=chunk.split('[exit 0]')[0]
    # Preserve the public task display, omitting only environment-specific body archive paths.
    lines='\n'.join(l for l in lines.splitlines() if 'body_archive:' not in l)
    (EV/f'retention-{name}.txt').write_text(lines+'\n')
purpose='The answer kept the pull request as a note. Now it keeps the structured link.'
for phase,other in [('before','after'),('after','before')]:
    run(['bash','bin/fm-pr-evidence.sh','annotate-ui','--text',EV/f'retention-{phase}.txt','--against',EV/f'retention-{other}.txt','--purpose',purpose,'--label','The pull request link changed.','--out',EV/f'retention-{phase}.png'],e=e)
# Exercise real generation-bound presentation and acknowledgement without a harness.
# No in-flight tasks remain, so the liveness warning cannot open a new episode
# while this scenario verifies retirement of the exact generation it presented.
(home/'state/task.meta').unlink()
(home/'state/task.status').unlink()
run(['bash','-c','. "$1"; fm_wake_append check manual-first "check: first live event"','_',ROOT/'bin/fm-wake-lib.sh'],e=e)
drain=run(['bash','bin/fm-wake-drain.sh'],e=e)
m=re.search(r'--ack-through (\d+) --recovery-generation ([A-Za-z0-9._-]+)',drain);assert m,drain
seq,gen=m.groups();queued=(home/'state/.wake-queue').read_text()
again=run(['bash','bin/fm-wake-drain.sh'],e=e);assert 'first live event' in again and (home/'state/.wake-queue').read_text()==queued
run(['bash','bin/fm-wake-drain.sh','--ack-through','0','--recovery-generation','wrong-generation'],e=e)
assert (home/'state/.wake-queue').read_text()==queued
assert (home/'state/.watcher-down').is_file()
run(['bash','-c','. "$1"; fm_wake_append check manual-second "check: second live event"','_',ROOT/'bin/fm-wake-lib.sh'],e=e)
run(['bash','bin/fm-wake-drain.sh','--ack-through',seq,'--recovery-generation',gen],e=e)
left=(home/'state/.wake-queue').read_text();assert 'first live event' not in left and 'second live event' in left
last=run(['bash','bin/fm-wake-drain.sh'],e=e);m=re.search(r'--ack-through (\d+) --recovery-generation ([A-Za-z0-9._-]+)',last);assert m
run(['bash','bin/fm-wake-drain.sh','--ack-through',m[1],'--recovery-generation',m[2]],e=e)
assert not (home/'state/.wake-queue').read_text().strip()
# A valid sequence cutoff consumes rows independently of recovery generation;
# the wrong generation must not retire the recovery episode itself.
run(['bash','-c','. "$1"; fm_wake_append check manual-generation "check: generation-bound event"','_',ROOT/'bin/fm-wake-lib.sh'],e=e)
last=run(['bash','bin/fm-wake-drain.sh'],e=e);m=re.search(r'--ack-through (\d+) --recovery-generation ([A-Za-z0-9._-]+)',last);assert m
run(['bash','bin/fm-wake-drain.sh','--ack-through',m[1],'--recovery-generation','wrong-generation'],e=e)
assert not (home/'state/.wake-queue').read_text().strip()
assert (home/'state/.watcher-down').is_file()
assert not (home/'state/.watcher-down').read_text().startswith('acked:')
log.write('Observed: sequence-bound rows consumed; mismatched recovery episode retained.\n')
run(['bash','bin/fm-wake-drain.sh','--ack-through',m[1],'--recovery-generation',m[2]],e=e)
settled=run(['bash','bin/fm-wake-drain.sh'],e=e)
assert 'WAKE_ACK_REQUIRED' not in settled
log.write('Observed: the matching generation acknowledged the episode; a subsequent drain requires no acknowledgement.\n')
shutil.rmtree(home);log.close();print('Real CLI named-head, evidence intake/rendering, and generation-bound wake checks completed.')
