import os, pathlib, subprocess, json, shutil
ROOT = pathlib.Path.cwd()
EVIDENCE = pathlib.Path('/home/node/.no-mistakes/evidence/01M5NDSRSC3QSFVJQR0FE670EK')
env = dict(os.environ)
for key in list(env):
    if key.startswith(('HERDR_', 'FM_', 'TASKS_AXI_', 'REX_', 'GH_', 'GITHUB_', 'BITBUCKET_', 'BB_', 'NO_MISTAKES_BITBUCKET_')) or key == 'TMUX': env.pop(key, None)
env['TMPDIR'] = str(ROOT / '.test-phase/tmp')
env['GIT_CONFIG_NOSYSTEM']='1'; env['GIT_CONFIG_GLOBAL']='/dev/null'
log = (EVIDENCE/'retained-artifacts-cli.log').open('w')
results=[]
def run(args, expected=0, cwd=ROOT, e=None):
    log.write('$ '+' '.join(map(str,args))+'\n'); log.flush()
    r=subprocess.run(list(map(str,args)), cwd=cwd, env=e or env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write(r.stdout+f'[exit {r.returncode}]\n'); log.flush()
    if r.returncode != expected: raise RuntimeError(f'{args}: expected {expected}, got {r.returncode}')
    return r.stdout
before=ROOT/'.test-phase/before-bin'; before.mkdir()
for p in (ROOT/'bin').iterdir():
    if p.name!='fm-captain-hold.sh': (before/p.name).symlink_to(p)
(before/'fm-captain-hold.sh').write_bytes(subprocess.check_output(['git','show','6ed8354606febe990a522245fe49ed7e6fb10b86^:bin/fm-captain-hold.sh']))
for variant, flag, value, old, corrupt in [
    ('github-before','--pr','https://github.com/o/r/pull/7',True,False),
    ('github','--pr','https://github.com/o/r/pull/7',False,False),
    ('forgejo','--pr','https://forgejo.example.com/o/r/pulls/7',False,False),
    ('report','--report','data/task/report.md',False,False),
    ('bitbucket','--pr','https://bitbucket.org/ws/repo/pull-requests/7',False,False),
    ('gerrit','--pr','https://gerrit.example.com/c/project/+/12345',False,False),
    ('malformed','--pr','https://github.com/o/r/pull/7',False,True),
]:
    home=ROOT/'.test-phase'/('retention-'+variant)
    run(['bash','bin/fm-lab-home.sh','create',home])
    shutil.copyfile(ROOT/'.tasks.toml',home/'.tasks.toml')
    (home/'data/backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
    e=dict(env,FM_HOME=str(home),FM_ROOT_OVERRIDE=str(ROOT),HOME=str(home/'user-home'))
    (home/'user-home').mkdir()
    run(['tasks-axi','add','task','Retained delivery follow-up','--kind','ship','--repo','sample','--start'],cwd=home,e=e)
    captain=before/'fm-captain-hold.sh' if old else ROOT/'bin/fm-captain-hold.sh'
    run(['bash',captain,'hold','task','--reason','Choose the follow-up after interrupted cleanup'],e=e)
    run(['bash','-c','. "$1"; fm_backlog_close_marker_mark_cleanup_incomplete "$2/state" "$2/state/task.backlog-close" task "$2/data" live-gen --retain "$3" "$4"', '_',ROOT/'bin/fm-backlog-transition-lib.sh',home,flag,value],e=e)
    log.write('Persisted pending retention contract:\n'+(home/'state/task.backlog-close').read_text())
    if corrupt:
        with (home/'state/task.backlog-close').open('a') as f: f.write('mode=close\n')
    (home/'answer.txt').write_text('Proceed with the delivered result.\n')
    run(['bash',captain,'answer','task','--decision-file',home/'answer.txt'],expected=1 if corrupt else 0,e=e)
    shown=run(['tasks-axi','show','task','--full'],cwd=home,e=e)
    if corrupt:
        assert 'hold_kind: captain' in shown and 'state: in_flight' in shown
    else:
        assert 'state: done' in shown
        if old: assert 'pr:'+value not in shown and 'PR '+value in shown
        elif variant in ('github','forgejo'): assert 'pr:'+value in shown
        elif variant=='report': assert 'report:'+value in shown
        else: assert value in shown
    results.append({'variant':variant,'expected_result_observed':True})
    shutil.rmtree(home)
log.close()
(EVIDENCE/'retained-artifacts-results.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
