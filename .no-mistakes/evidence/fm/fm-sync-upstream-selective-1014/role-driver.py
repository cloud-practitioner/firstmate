import os, pathlib, subprocess, json, shutil
root=pathlib.Path.cwd(); out=pathlib.Path('/home/node/.no-mistakes/evidence/01M4WAKYZW6KFBK2B9EM3WJZX5/role-cli-transcript.log')
home=root/'.validation/role-home'; subprocess.run(['bin/fm-lab-home.sh','create',str(home)],check=True)
env=os.environ.copy()
for k in list(env):
    if k.startswith('FM_') or k.startswith('HERDR_') or k in ['TMUX','TASKS_AXI_FILE','TASKS_AXI_BACKEND']: env.pop(k,None)
env.update(FM_HOME=str(home),TMPDIR=str(root/'.validation/tmp'),FM_BACKEND='tmux',FM_SPAWN_NO_GUARD='1')
lines=[]
def run(args, rc, contains=None):
    p=subprocess.run([str(root/'bin'/args[0]),*args[1:]],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    lines.extend(['$ '+' '.join(args),p.stdout.rstrip(),f'exit={p.returncode}'])
    out.write_text('\n'.join(lines)+'\n')
    assert p.returncode==rc,(args,p.stdout,p.returncode,rc)
    if contains: assert contains in p.stdout,(args,p.stdout,contains)
    return p.stdout
scope='github.com/cloud-practitioner/firstmate'
try:
    run(['fm-role.sh','report'],0,'user (default)')
    run(['fm-role.sh','check',str(root)],1,'no publication authority')
    run(['fm-brief.sh','denied','firstmate','--mode','direct-PR','--project',str(root)],1,'no publication authority')
    assert not (home/'data/denied/brief.md').exists()
    run(['fm-brief.sh','consent','firstmate','--mode','direct-PR','--project',str(root),'--upstream-consent','GitHub.COM/Cloud-Practitioner/FirstMate'],0)
    contract=next(x for x in (home/'data/consent/brief.md').read_text().splitlines() if x.startswith('Delivery contract:'))
    assert 'upstream-consent='+scope in contract; lines+=['Persisted consent brief: '+contract]
    run(['fm-role.sh','check',str(root),'upstream-consent',scope],0,'authorized: task consent')
    run(['fm-role.sh','check',str(root)],1,'no publication authority')
    (home/'config/firstmate-role').write_text('maintainer github.com/not/this-repo\n')
    run(['fm-role.sh','check',str(root)],1,'no publication authority')
    (home/'config/firstmate-role').write_text('maintainer '+scope+'\n')
    run(['fm-role.sh','report'],0,'maintainer '+scope)
    run(['fm-role.sh','check',str(root)],0,'authorized: maintainer')
    run(['fm-brief.sh','maintainer','firstmate','--mode','direct-PR','--project',str(root)],0)
    (home/'config/firstmate-role').unlink()
    (home/'config/firstmate-role').symlink_to(home/'data/non-authoritative-role')
    (home/'data/non-authoritative-role').write_text('maintainer '+scope+'\n')
    run(['fm-role.sh','check',str(root)],1,'no publication authority')
    (home/'config/firstmate-role').unlink()
    for kind in ['--scout','--secondmate']:
        run(['fm-spawn.sh','nonship',str(root),kind,'--upstream-consent',scope],1,'--upstream-consent applies only to ship spawns')
    run(['fm-brief.sh','local','firstmate','--mode','local-only','--project',str(root)],0)
    run(['fm-brief.sh','local-bad','firstmate','--mode','local-only','--upstream-consent',scope],1,'local-only')
    # A fully populated generated brief drives the real dispatch gate, not a fake backend.
    run(['fm-brief.sh','spawn-denied','firstmate','--mode','direct-PR','--project',str(root)],1,'no publication authority')
    d=home/'data/spawn-denied';d.mkdir(parents=True,exist_ok=True)
    (d/'brief.md').write_text("You are a crewmate.\n# Task\n## Captain's intent\nVerify authority.\n## Firstmate spec\nNo publication.\n# Definition of done\nDelivery contract: mode=direct-PR\nShip branch: fm/spawn-denied\n")
    run(['fm-spawn.sh','spawn-denied',str(root),'pi','--mode','direct-PR','--yolo','off'],1,'spawn refused for spawn-denied')
    assert not (home/'state/spawn-denied.meta').exists()
    consent_brief=home/'data/consent/brief.md'
    consent_brief.write_text(consent_brief.read_text().replace('{TASK}','Verify consent agreement.').replace('{FIRSTMATE_SPEC}','Do not publish.'))
    run(['fm-spawn.sh','consent',str(root),'pi','--mode','direct-PR','--yolo','off'],1,'upstream-consent mismatch')
    # Scout promotion must fail without authority, then persist a bounded consent.
    task='promote';(home/'data'/task).mkdir();(home/'data'/task/'brief.md').write_text("You are a crewmate.\n# Task\n## Captain's intent\nInvestigate.\n## Firstmate spec\nReport.\n")
    meta=home/'state'/f'{task}.meta';meta.write_text(f'window=fm-{task}\nkind=scout\nproject={root}\nworktree={home}/projects/scout\n')
    before=meta.read_bytes()
    run(['fm-promote.sh',task,'--mode','direct-PR','--yolo','off'],1,'promotion refused')
    assert meta.read_bytes()==before and not (home/'data'/task/'ship-instructions.md').exists()
    run(['fm-promote.sh',task,'--mode','direct-PR','--yolo','off','--upstream-consent',scope],0)
    data=dict(line.split('=',1) for line in meta.read_text().splitlines() if '=' in line)
    assert data['kind']=='ship' and data['upstream_consent']==scope
    lines+=['Promoted persisted metadata: '+json.dumps({k:data[k] for k in ['kind','mode','upstream_consent']},sort_keys=True)]
    lines+=['No remote publication was attempted. All checks used disposable FM_HOME.']
finally:
    out.write_text('\n'.join(lines)+'\n')
    shutil.rmtree(home)
