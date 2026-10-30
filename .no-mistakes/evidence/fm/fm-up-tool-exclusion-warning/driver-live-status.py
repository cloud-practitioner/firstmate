import os, json, subprocess, time, shutil
from pathlib import Path
ROOT = Path.cwd()
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M65MFBQHY7METR56JHMH28BV')
BASE = ROOT / '.test-phase/status-lab'
HOME = BASE / 'home'
HELPER = ROOT / 'bin/fm-herdr-lab.sh'
BASE.mkdir(exist_ok=True)
env = dict(os.environ)
for key in ('FM_HOME','FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE','TMUX','HERDR_ENV','HERDR_PANE_ID','HERDR_TAB_ID','HERDR_WORKSPACE_ID','HERDR_SOCKET_PATH','FM_GATE_REFUSE_BYPASS','FM_TEST_SEAM'):
    env.pop(key, None)
env.update(FM_HERDR_LAB_STATE_DIR=str(BASE/'tripwire'), PI_CODING_AGENT_DIR=str(ROOT/'.test-phase/pi-home'))
transcript = []
def run(cmd, check=True, **kwargs):
    p = subprocess.run([str(x) for x in cmd], env=env, cwd=ROOT, capture_output=True, text=True, timeout=60, **kwargs)
    transcript.append({'command': [str(x) for x in cmd], 'exit': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr})
    if check and p.returncode: raise RuntimeError(transcript[-1])
    return p.stdout
session = run([HELPER,'name','exclusion']).strip()
provisioned = False
try:
    run([ROOT/'bin/fm-lab-home.sh','create',HOME])
    env.update(FM_HOME=str(HOME), FM_BACKEND='herdr', HERDR_SESSION=session,
               FM_CREW_STATE_NO_FORGE='1', FM_SUPERVISION_ACTOR='main')
    (HOME/'config/supervision-host-off').touch()
    run([HELPER,'provision',session])
    provisioned = True
    workspace = json.loads(run([HELPER,'run',session,'workspace','create','--label','tool-exclusion-status','--cwd',ROOT]))
    pane = workspace['result']['root_pane']['pane_id']
    run([HELPER,'viewer','start',session])
    command = f'env PI_CODING_AGENT_DIR={ROOT}/.test-phase/pi-home pi --provider lab --model exclusion-fixture --offline --no-session --no-context-files --no-extensions --no-skills --no-mcp --no-prompt-templates --no-themes'
    run([HELPER,'run',session,'pane','run',pane,command])
    time.sleep(2)
    capture = run([HELPER,'run',session,'pane','read',pane,'--source','visible','--format','text'])
    (EVIDENCE/'status-lab-pane.txt').write_text(capture)
    # A disposable real git repository is the worker worktree, not the gate repository.
    project = HOME/'projects/fixture'
    project.mkdir()
    run(['git','init','-q','-b','main',project])
    (project/'fixture.txt').write_text('Disposable status-reader fixture\n')
    run(['git','-C',project,'add','fixture.txt'])
    run(['git','-C',project,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','Fixture'])
    state = HOME/'state'
    (state/'worker.meta').write_text(f'kind=scout\nmode=scout\nharness=pi\nbackend=herdr\nbackend_target={session}:{pane}\nwindow={session}:{pane}\nworktree={project}\nproject=fixture\n')
    (HOME/'data/backlog.md').write_text('## In flight\n- [ ] worker - Live status fixture (kind: scout)\n')
    gen = run([ROOT/'bin/fm-busy-event.sh','arm',state,'worker']).strip()
    run([ROOT/'bin/fm-busy-event.sh','apply',state,'worker','idle','--gen',gen,'--source','pi-ext','--event','agent-settled'])
    warning = next(x for x in (EVIDENCE/'pi-late-status.log').read_text().splitlines() if x.startswith('note [state=none]'))+'\n'
    answers = []
    for name, declaration, expected in [
        ('done','done [at=1700000000]: completed fixture task\n','done'),
        ('failed','failed: stopped fixture task\n','failed'),
        ('working','working: continuing fixture task\n','working'),
        ('paused','paused [key=release]: waiting for release\n','paused'),
        ('blocked','blocked [key=access]: waiting for access\n','blocked'),
        ('decision','needs-decision [key=shape]: choose a shape\n','needs-decision'),
        ('held','captain-held [key=shape]: transferred\n','captain-held'),
        ('resolved','needs-decision [key=shape]: choose\nresolved [key=shape]: answered\n','resolved'),
        ('ordinary-note','done: complete\nnote: ordinary note\n','note'),
        ('warning-only','','no events yet'),
    ]:
        log = state/'worker.status'
        log.write_text(declaration)
        before = run([ROOT/'bin/fm-crew-state.sh','worker'])
        log.write_text(declaration+warning*210)
        after = run([ROOT/'bin/fm-crew-state.sh','worker'])
        assert before == after, (name,before,after)
        assert 'backend unreachable' not in after and 'backend target gone' not in after, after
        voice = json.loads(run(['python3',ROOT/'bin/fm_voice_records.py','status','--home',HOME,'--scope','full']))
        assert voice['worker_states'] == {expected:1}, (name,voice)
        fleet = json.loads(run([ROOT/'bin/fm-fleet-snapshot.sh','--json']))
        task = next(t for t in fleet['tasks'] if t['id']=='worker')
        raw = declaration.rstrip('\n').splitlines()[-1] if declaration else ''
        assert task['paths']['status_log']['last_event']['raw'] == raw, (name,task)
        inbox = run([ROOT/'bin/fm-inbox.sh','status'])
        assert 'exclusion not in effect' not in inbox, inbox
        assert raw in inbox if raw else '(no events yet)' in inbox
        bearing = json.loads(run([ROOT/'bin/fm-bearings-snapshot.sh','--json']))
        answers.append({'scenario':name, 'before':before.strip(), 'after':after.strip(),
                        'voice':voice, 'fleet':task, 'inbox':inbox, 'bearings':bearing})
        if name == 'done':
            assert 'state: done' in after, after
            # The backstop's documented snapshot cap is 64 KiB; the flood above
            # deliberately exceeded it for unbounded declaration readers.
            # Keep this distinct wake-presentation proof inside that contract.
            log.write_text(declaration + warning)
            (state/'.last-watcher-beat').touch()
            wake1 = run([ROOT/'bin/fm-wake-drain.sh'])
            assert 'STATUS OUTCOME BACKSTOP (' in wake1 and warning.strip() in wake1, wake1
            with log.open('a') as f: f.write(warning)
            wake2 = run([ROOT/'bin/fm-wake-drain.sh'])
            assert 'STATUS OUTCOME BACKSTOP (' not in wake2, wake2
            (EVIDENCE/'wake-first-drain.txt').write_text(wake1)
            (EVIDENCE/'wake-second-drain.txt').write_text(wake2)
    (EVIDENCE/'status-readers-live.json').write_text(json.dumps(answers,indent=2))
    print('Real Herdr/Pi endpoint status-reader cases completed:', [a['scenario'] for a in answers])
finally:
    if provisioned:
        try: run([HELPER,'teardown',session])
        except Exception as e: print('TEARDOWN FAILED',e); raise
    (EVIDENCE/'status-readers-commands.json').write_text(json.dumps(transcript,indent=2))
    if HOME.exists(): shutil.rmtree(HOME)
