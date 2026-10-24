import os,pathlib,subprocess,re,shutil
R=pathlib.Path.cwd();E=pathlib.Path('/home/node/.no-mistakes/evidence/01M5NDSRSC3QSFVJQR0FE670EK');H=R/'.test-phase/watch-recovery'
env=dict(os.environ)
for k in list(env):
    if k.startswith(('FM_','HERDR_','TASKS_AXI_','REX_','GH_','GITHUB_','NO_MISTAKES_BITBUCKET_')) or k=='TMUX':env.pop(k,None)
env.update(FM_HOME=str(H),FM_BACKEND='tmux',TMPDIR=str(R/'.test-phase/tmp'),FM_POLL='1',FM_SIGNAL_GRACE='1',FM_HEARTBEAT='999999',FM_CHECK_INTERVAL='999999',TMUX=str(H/'tmux/fm-lab')+',0,0',TMUX_TMPDIR=str(H/'tmux'))
env['PATH']=str(R/'.test-phase/tools/tmux-install/bin')+':'+env['PATH']
log=(E/'watch-recovery-cli.log').open('w')
def run(args,timeout=20):
    log.write('$ '+' '.join(map(str,args))+'\n');log.flush()
    p=subprocess.Popen(list(map(str,args)),env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    expired=False
    try: out,_=p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        expired=True;p.terminate();out,_=p.communicate(timeout=10)
    log.write(out+f'[exit {p.returncode}; bounded wait expired={expired}]\n');log.flush()
    return p.returncode,out,expired
try:
    code,out,_=run(['bash','bin/fm-lab-home.sh','create',H]);assert code==0
    (H/'tmux').mkdir()
    code,out,_=run(['bash','-c','. "$1"; fm_wake_append check durable-review "check: review the retained delivery"','_',R/'bin/fm-wake-lib.sh']);assert code==0
    for number in [1,2]:
        code,out,expired=run(['bash','bin/fm-watch.sh'])
        assert not expired and code==0 and 'rearm-resurface' in out,(code,out,expired)
    code,out,_=run(['bash','bin/fm-wake-drain.sh']);assert code==0
    m=re.search(r'--ack-through (\d+) --recovery-generation ([A-Za-z0-9._-]+)',out);assert m
    code,out,_=run(['bash','bin/fm-wake-drain.sh','--ack-through',m[1],'--recovery-generation',m[2]]);assert code==0
    code,out,expired=run(['bash','bin/fm-watch.sh'],timeout=4)
    assert expired and 'rearm-resurface' not in out,(code,out,expired)
    log.write('Observed: two unacknowledged fresh cycles resurfaced the queued event; the acknowledged fresh cycle stayed quiet and alive for the bounded observation.\n')
finally:
    shutil.rmtree(H,ignore_errors=True);log.close()
print('Real watcher recovery cycles verified before and after the generation-bound acknowledgement.')
