#!/usr/bin/env python3
"""Execute the base CLI with real tasks-axi to demonstrate the reported false acceptance."""
import os, pathlib, shutil, subprocess, tempfile
ROOT = pathlib.Path.cwd()
OUT = pathlib.Path(__file__).parent
base = subprocess.run(['git','show','47aff866dbe0612bd43df66d8fa76576e06a2b3e:bin/fm-captain-hold.sh'],check=True,capture_output=True,text=True).stdout
# This source snapshot executes unchanged behavior; only bind its library directory to this worktree.
base = base.replace('SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"', 'SCRIPT_DIR="' + str(ROOT / 'bin') + '"')
script = OUT / 'before-fix-captain-hold.sh'
script.write_text(base)
script.chmod(0o700)
h = pathlib.Path(tempfile.mkdtemp(prefix='fm-lab.'))
env = {k:v for k,v in os.environ.items() if not (k.startswith('FM_') or k.startswith('TASKS_AXI_') or k=='BASH_ENV')}
env.update(FM_HOME=str(h),TMPDIR='/tmp')
log = (OUT/'before-fix-reproduction.log').open('w',buffering=1)
def run(tool,*args,success=True,fault=None):
    e=dict(env)
    if fault: e.update(BASH_ENV=str(OUT/'fault-env.sh'),VALIDATION_FAULT=fault)
    p=subprocess.run([str(tool),*map(str,args)],env=e,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=40)
    print('$ FM_HOME=<disposable-lab> '+tool.name+' '+' '.join(map(str,args)),file=log)
    print('exit='+str(p.returncode)+'\n'+p.stdout+p.stderr,file=log)
    assert (p.returncode==0) == success, p.stderr
    return p
try:
    run(ROOT/'bin/fm-lab-home.sh','create',h)
    shutil.copyfile(ROOT/'.tasks.toml',h/'.tasks.toml')
    (h/'data/backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
    for o in ['origin-a','origin-b']:
        run(ROOT/'bin/fm-tasks-axi.sh','add',o,'Review '+o,'--kind','scout','--repo','sample')
        (h/('state/'+o+'.meta')).write_text('kind=scout\nmode=scout\nspawn_gen=before-fix-'+o+'\n')
    (h/'answer.txt').write_text('Release the work for A.\n')
    run(script,'hold','call','--title','Decision call','--reason','Choose for A','--origin','origin-a')
    run(script,'answer','call','--release','--decision-file',h/'answer.txt')
    p=run(script,'hold','call','--reason','Choose for B','--origin','origin-b',success=False,fault='refuse')
    os.chmod(h/'data',0o755)
    os.chmod(h/'data/backlog.md',0o644)
    s=run(ROOT/'bin/fm-tasks-axi.sh','show','call','--full').stdout
    assert 'held: no' in s and 'Captain hold origin: origin-b' in s and 'Release the work for A.' in s
    run(script,'complete','origin-b','call')
    run(script,'verify','origin-b')
    print('REPRODUCED: base incorrectly certifies B using A\'s answer after the real backend hold and rollback both fail.',file=log)
    print('Before-fix false acceptance reproduced with the real backend.')
finally:
    os.chmod(h/'data',0o755)
    if (h/'data/backlog.md').exists(): os.chmod(h/'data/backlog.md',0o644)
    shutil.rmtree(h)
    print('Disposable baseline home removed.',file=log)
    log.close()
