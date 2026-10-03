import os, subprocess, tempfile, pathlib, json, pty, fcntl, termios, struct, select, time, re, signal, shutil
root=pathlib.Path.cwd()
ev=pathlib.Path('/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C')
lab=pathlib.Path(tempfile.mkdtemp(prefix='pi-trust-',dir=root/'.test-phase-tmp'))
pi=shutil.which('pi')
agent=lab/'agent'; agent.mkdir(); trust=agent/'trust.json'; trust.write_text('{}\n')
results=[]
try:
    for name,approve,seeded in [('unseeded-stall',False,False)]:
        cwd=lab/name; (cwd/'.pi/extensions').mkdir(parents=True)
        (cwd/'.pi/extensions'/('fm-primary-pi-watch.ts' if seeded else 'dummy.ts')).write_text('export default function () {}\n')
        if seeded:
            (cwd/'.fm-secondmate-home').write_text('lab-sm\n')
            for d in ['state','config','data']: (cwd/d).mkdir()
            (cwd/'data/charter.md').write_text('# Lab charter\n')
        env=dict(os.environ)
        for k in list(env):
            if k.startswith('FM_') or k in ['TMUX','TMUX_PANE']: env.pop(k,None)
        env.update(HOME=str(lab/'home'),PI_CODING_AGENT_DIR=str(agent),PI_OFFLINE='1',TERM='xterm-256color',COLORTERM='truecolor')
        master,slave=pty.openpty()
        fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',40,120,0,0))
        args=[pi,'--no-session','--no-skills','--no-prompt-templates']+(['--approve'] if approve else [])
        p=subprocess.Popen(args,cwd=cwd,env=env,stdin=slave,stdout=slave,stderr=slave,start_new_session=True)
        os.close(slave); data=bytearray(); deadline=time.monotonic()+18
        try:
            while time.monotonic()<deadline:
                if select.select([master],[],[],.15)[0]:
                    try: chunk=os.read(master,65536)
                    except OSError: break
                    if not chunk: break
                    data.extend(chunk)
                text=data.decode('utf8','replace')
                plain=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',text)
                if (not approve and 'Trust project folder' in plain) or (approve and any(s in plain for s in ['escape interrupt','No models available','No API key','try '])):
                    time.sleep(.4)
                    while select.select([master],[],[],0)[0]:
                        try: data.extend(os.read(master,65536))
                        except OSError: break
                    break
            (ev/f'pi-{name}.ansi').write_bytes(data)
            plain=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',data.decode('utf8','replace'))
            if approve:
                assert 'Trust project folder' not in plain,plain
                assert any(s in plain for s in ['escape interrupt','No models available','No API key','try ']),plain
            else: assert 'Trust project folder' in plain,plain
            assert trust.read_text()=='{}\n'
            results.append({'scenario':name,'argv':args,'grid':'120x40','trust_dialog':not approve,'trust_store':trust.read_text().strip(),'result':'pass'})
        finally:
            if p.poll() is None: os.killpg(p.pid,signal.SIGTERM)
            try: p.wait(timeout=6)
            except subprocess.TimeoutExpired: os.killpg(p.pid,signal.SIGKILL);p.wait()
            os.close(master)
    (ev/'pi-trust.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results,indent=2))
finally: shutil.rmtree(lab)
