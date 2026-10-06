#!/usr/bin/env python3
"""Run an existing focused Herdr test with an isolated config/socket namespace."""
import os, subprocess, tempfile, pathlib, shutil, signal, json, sys, time
E = pathlib.Path('/home/node/.no-mistakes/evidence/01M47HX8Y8BQRSDDHWXNW190JH')
scratch = pathlib.Path(tempfile.mkdtemp(prefix='fm-task.', dir='/tmp'))
env = {k:v for k,v in os.environ.items() if not k.startswith(('FM_', 'HERDR_', 'TASKS_AXI_', 'NO_MISTAKES_'))}
env.update(FM_TASK_TMP=str(scratch), TMPDIR=str(scratch), XDG_CONFIG_HOME=str(scratch/'c'), FM_HERDR_LAB_STATE_DIR=str(scratch/'t'), TREEHOUSE_ROOT=str(scratch/'pools'))
(scratch/'c/herdr').mkdir(parents=True)
(scratch/'c/herdr/herdr.sock').symlink_to(os.environ['HERDR_SOCKET_PATH'])
log = E/sys.argv[2]
start = time.monotonic()
try:
    with log.open('w') as f:
        p = subprocess.Popen(['bash',sys.argv[1]], env=env, stdout=f, stderr=subprocess.STDOUT, start_new_session=True)
        try: code = p.wait(timeout=int(sys.argv[3]))
        except subprocess.TimeoutExpired:
            os.killpg(p.pid,signal.SIGTERM)
            try: p.wait(timeout=10)
            except subprocess.TimeoutExpired: pass
            try: os.killpg(p.pid,signal.SIGKILL)
            except ProcessLookupError: pass
            p.wait()
            code = 'timeout'
    print(json.dumps({'command':'bash '+sys.argv[1], 'exit':code, 'elapsed_seconds':round(time.monotonic()-start,1), 'artifact':str(log)}),flush=True)
    print('\n'.join(log.read_text().splitlines()[-15:]),flush=True)
finally:
    catalog = subprocess.run(['bin/fm-herdr-lab.sh','run','fm-lab-cleanup','session','list','--json'],env=env,text=True,capture_output=True,timeout=10)
    ok = True
    for session in json.loads(catalog.stdout).get('sessions',[]):
        if session['name'].startswith('fm-lab-'):
            cleanup = subprocess.run(['bin/fm-herdr-lab.sh','teardown',session['name']],env=env,text=True,capture_output=True,timeout=20)
            print('guarded teardown:',session['name'],'exit='+str(cleanup.returncode),cleanup.stderr,flush=True)
            ok = ok and cleanup.returncode == 0
    if ok:
        for directory, dirs, files in os.walk(scratch): os.chmod(directory,0o700)
        shutil.rmtree(scratch)
        print('Disposable task scratch removed; default-session tripwire unchanged.',flush=True)
    else: print('Cleanup requires attention: '+str(scratch),flush=True)
