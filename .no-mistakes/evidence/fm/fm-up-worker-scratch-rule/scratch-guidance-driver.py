import json, os, pathlib, shutil, subprocess, sys, time, shlex

ROOT = pathlib.Path('/home/node/.no-mistakes/worktrees/c98b859efde5/01M46G0PDZ4VFSXNWTR9GE0QEG')
FIX = ROOT / '.scratch-validation'
EVIDENCE = pathlib.Path('/home/node/.no-mistakes/evidence/01M46G0PDZ4VFSXNWTR9GE0QEG')
EVIDENCE.mkdir(parents=True, exist_ok=True)
ENV = os.environ.copy()
for key in ('FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE','FM_GATE_REFUSE_BYPASS','HERDR_ENV','HERDR_PANE_ID','HERDR_TAB_ID','HERDR_WORKSPACE_ID','HERDR_SOCKET_PATH','HERDR_SESSION','TMUX','TMUX_PANE'):
    ENV.pop(key, None)
ENV['FM_HERDR_LAB_STATE_DIR'] = str(FIX / 'herdr-state')
LOG = []
def run(args, env=None, timeout=30, input=None):
    result = subprocess.run(args, cwd=ROOT, env=env or ENV, text=True, input=input, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    LOG.append('$ ' + shlex.join(map(str,args)) + '\n' + result.stdout)
    if result.returncode:
        raise RuntimeError(f'command exited {result.returncode}: {result.stdout}')
    return result.stdout

def home(name):
    p = FIX / name
    run(['bash','bin/fm-lab-home.sh','create',str(p)])
    return p

def scaffold(h, id, mode):
    env=ENV | {'FM_HOME': str(h)}
    args=['bash','bin/fm-brief.sh',id,'scratch-demo']
    args += ['--scout'] if mode == 'scout' else ['--mode', mode]
    args += ['--herdr-lab']
    run(args,env)
    path=h / 'data' / id / 'brief.md'
    text=path.read_text()
    expected=f'your task temp root (the `tasktmp=` directory recorded in `{h}/state/{id}.meta`)'
    assert expected in text, f'{mode} missing current-home task metadata lookup'
    assert 'never write scratch to a fixed path in shared /tmp' in text
    if mode == 'no-mistakes':
        assert 'If you pass `--intent` through a file, write it under your task temp root' in text
    shutil.copyfile(path,EVIDENCE / f'scaffold-{mode}.md')
    LOG.append(f'Emitted {mode} Rules:\n'+text.split('# Rules\n',1)[1].split('# Definition of done',1)[0])
    return path

RESULTS={}
try:
    h=home('contract home')
    for mode in ('scout','no-mistakes','direct-PR','local-only'):
        scaffold(h,'contract-'+mode.lower(),mode)
    RESULTS['scaffolds']='pass'
    for mode in ('no-mistakes','direct-PR','local-only'):
        id='promotion-'+mode.lower()
        path=scaffold(h,id,'scout')
        text=path.read_text().replace('{TASK}','Prepare a distinct task intent handoff.').replace('{FIRSTMATE_SPEC}','Preparation only; do not publish or run a validation pipeline.')
        path.write_text(text)
        scratch=h/'state'/'relocated scratch'/id
        scratch.mkdir(parents=True)
        meta=h/'state'/f'{id}.meta'
        meta.write_text(f'window=fixture-{id}\nkind=scout\nworktree={FIX}/project\ntasktmp={scratch}\n')
        run(['bash','bin/fm-promote.sh',id,'--mode',mode,'--yolo','off'],ENV|{'FM_HOME':str(h)})
        instructions=h/'data'/id/'ship-instructions.md'
        emitted=instructions.read_text()
        persisted=path.read_text()
        contract=emitted.split('# Current delivery mode contract',1)[1]
        assert contract in persisted, f'{mode} relaunch brief lost superseding delivery contract'
        assert f'Delivery contract: mode={mode}' in emitted
        assert f'the `tasktmp=` directory recorded in `{meta}`' in emitted
        assert 'never write scratch to a fixed path in shared /tmp' in emitted
        if mode == 'no-mistakes':
            assert 'If you pass `--intent` through a file, write it under your task temp root' in emitted
        assert 'kind=ship\n' in meta.read_text()
        assert f'tasktmp={scratch}\n' in meta.read_text()
        shutil.copyfile(instructions,EVIDENCE/f'promoted-{mode}.md')
    RESULTS['promotions']='pass'

    # Real Claude processes consume the CLI's final generated instructions.
    # Temp roots are disposable persisted task records, not mocked scripts.
    project=FIX/'project'
    project.mkdir()
    run(['git','init','-q','-b','main',str(project)])
    (project/'README.md').write_text('Disposable scratch-instruction validation project.\n')
    run(['git','-C',str(project),'-c','user.name=Lab','-c','user.email=lab@example.invalid','add','README.md'])
    run(['git','-C',str(project),'-c','user.name=Lab','-c','user.email=lab@example.invalid','commit','-qm','Initialize disposable project'])
    workers=[]
    for label,mode,goal in (
        ('alpha','no-mistakes','Provide the alpha-only goal: display temperature in Celsius.'),
        ('beta','no-mistakes','Provide the beta-only goal: display distance in kilometres.'),
        ('scout','scout','Prepare the scout-only investigation note.'),
        ('promoted','no-mistakes','Provide the promoted-only goal: show dates in ISO format.'),
    ):
        h=home('worker-'+label)
        id='same-task'
        path=scaffold(h,id,'scout' if label=='promoted' else mode)
        spec="This is a preparation-only live lab check. Do not run no-mistakes, any pipeline, lifecycle, Git branch/commit operations, or remote/PR commands. Do not edit project files. Prepare one scratch file named intent.txt whose content is exactly the Captain's intent subsection, with a trailing newline. Keep that basename unchanged: other concurrent workers also use intent.txt. Do not include this Firstmate spec in the file. Inspect the task records needed to choose its location using your normal Rules. Return the absolute file path and stop."
        path.write_text(path.read_text().replace('{TASK}',goal).replace('{FIRSTMATE_SPEC}',spec))
        # One path is deliberately not state/<id>.tasktmp to prove lookup.
        scratch=h/('relocated scratch' if label=='promoted' else 'state')/(id+'.tasktmp')
        scratch.mkdir(parents=True)
        (h/'state'/f'{id}.meta').write_text(f'window=lab-{label}\nkind={"scout" if label in ("scout","promoted") else "ship"}\nworktree={project}\ntasktmp={scratch}\n')
        if label=='promoted':
            run(['bash','bin/fm-promote.sh',id,'--mode','no-mistakes','--yolo','off'],ENV|{'FM_HOME':str(h)})
        role=run(['bash','-c','. bin/fm-dod-lib.sh; fm_brief_worker_role "$1" "$2"','bash',str(h/'state'),id])
        prompt=FIX/f'prompt-{label}.md'
        prompt.write_text('FIRSTMATE_OP: v1 launch-brief\n'+role+'\n'+path.read_text())
        shutil.copyfile(prompt,EVIDENCE/f'live-input-{label}.md')
        worker_script=FIX/f'worker-{label}.sh'
        output=FIX/f'worker-{label}.json'
        rcfile=FIX/f'worker-{label}.rc'
        cmd=['env','-u','CLAUDECODE','-u','NO_MISTAKES_GATE','-u','FM_GATE_REFUSE_BYPASS','-u','FM_ROOT_OVERRIDE','-u','FM_STATE_OVERRIDE','-u','FM_DATA_OVERRIDE','-u','FM_CONFIG_OVERRIDE','-u','FM_PROJECTS_OVERRIDE',f'FM_HOME={h}',
             'claude','-p','--safe-mode','--restricted','--append-system-prompt','This live lab turn is preparation only. Follow the generated task Rules to choose the scratch location, and write intent.txt from the original Captain intent subsection. Do not execute promotion setup or delivery steps, start a pipeline, change Git, or contact any remote. You may read and write only disposable test fixtures beneath '+str(FIX)+'.','--no-session-persistence','--strict-mcp-config','--setting-sources','','--model','sonnet','--effort','low','--permission-mode','dontAsk','--allowedTools','Read','Write','--tools','Read,Write','--add-dir',str(FIX),'--output-format','json']
        worker_script.write_text('#!/usr/bin/env bash\ncd '+shlex.quote(str(project))+' || exit\n'+shlex.join(cmd)+' < '+shlex.quote(str(prompt))+' > '+shlex.quote(str(output))+' 2>&1\nprintf "%s\\n" "$?" > '+shlex.quote(str(rcfile))+'\n')
        workers.append((label,h,scratch,goal,worker_script,output,rcfile))

    session=run(['bash','bin/fm-herdr-lab.sh','name','scratch-guidance']).strip()
    provisioned=False
    try:
        # provision owns prepare for a fresh named session.
        run(['bash','bin/fm-herdr-lab.sh','provision',session],timeout=80)
        provisioned=True
        for label,h,scratch,goal,script,output,rcfile in workers:
            result=json.loads(run(['bash','bin/fm-herdr-lab.sh','run',session,'workspace','create','--cwd',str(project),'--label','scratch-'+label,'--no-focus']))
            (EVIDENCE/f'herdr-workspace-{label}.json').write_text(json.dumps(result,indent=2)+'\n')
            def find_pane(obj):
                if isinstance(obj,dict):
                    for key in ('pane_id','paneId'):
                        if isinstance(obj.get(key),str): return obj[key]
                    for value in obj.values():
                        found=find_pane(value)
                        if found:return found
                elif isinstance(obj,list):
                    for value in obj:
                        found=find_pane(value)
                        if found:return found
            pane=find_pane(result)
            if not pane:
                raise RuntimeError('workspace create did not expose pane id: '+json.dumps(result))
            run(['bash','bin/fm-herdr-lab.sh','run',session,'pane','run',pane,'bash '+shlex.quote(str(script))])
        deadline=time.monotonic()+180
        while time.monotonic()<deadline and not all(w[-1].exists() for w in workers):
            time.sleep(1)
        for label,h,scratch,goal,script,output,rcfile in workers:
            if output.exists():shutil.copyfile(output,EVIDENCE/f'live-claude-{label}.json')
            if not rcfile.exists():
                RESULTS['live-'+label]='untested: Claude did not complete within 180 seconds'
                continue
            code=rcfile.read_text().strip()
            if code!='0':
                RESULTS['live-'+label]='untested: Claude exited '+code+'; see transcript'
                continue
            generated=scratch/'intent.txt'
            if not generated.exists():
                RESULTS['live-'+label]='fail: no intent.txt under recorded tasktmp'
                continue
            content=generated.read_text()
            assert content==goal+'\n',f'{label} intent content contaminated: {content!r}'
            shutil.copyfile(generated,EVIDENCE/f'live-intent-{label}.txt')
            RESULTS['live-'+label]='pass'
            LOG.append(f'Real worker {label}: recorded tasktmp={scratch}; persisted {generated}; content={content!r}')
        intent_paths=list(FIX.rglob('intent.txt'))
        LOG.append('All intent.txt files created in disposable setup:\n'+'\n'.join(str(p) for p in intent_paths))
        expected={str(w[2]/'intent.txt') for w in workers if RESULTS.get('live-'+w[0])=='pass'}
        assert set(map(str,intent_paths))==expected,'a worker wrote an intent file outside its recorded task root'
        assert run(['git','-C',str(project),'status','--porcelain']).strip()=='','workers modified the project'
    finally:
        run(['bash','bin/fm-herdr-lab.sh','teardown',session],timeout=30)
        LOG.append('Named Herdr lab removed; default-session tripwire verified by helper.')
except Exception as exc:
    RESULTS['driver-error']=str(exc)
    LOG.append('ERROR: '+repr(exc))
finally:
    (EVIDENCE/'scratch-guidance-cli.log').write_text('\n'.join(LOG)+'\n')
    (EVIDENCE/'scratch-guidance-results.json').write_text(json.dumps(RESULTS,indent=2)+'\n')
    print(json.dumps(RESULTS,indent=2))
