import os, pathlib, subprocess, shutil, tempfile, time
R=pathlib.Path.cwd(); E=pathlib.Path('/home/node/.no-mistakes/evidence/01M64ZPT5AJ4390HHRPB92ZDZC'); W=R/'.test-validation'
lab=pathlib.Path(tempfile.mkdtemp(prefix='remote-live.',dir=W/'tmp')); log=[]; ssh=None
base={k:v for k,v in os.environ.items() if not (k.startswith('FM_') or k.startswith('GIT_') or k.startswith('TASKS_AXI'))}
base.update(TMPDIR=str(lab/'tmp'),GIT_CONFIG_GLOBAL=str(R/'tests/git-fixture.gitconfig'),GIT_CONFIG_NOSYSTEM='1')
def run(args,env=None,ok=None,timeout=90):
 e=base.copy();e.update(env or {});p=subprocess.run([str(x) for x in args],env=e,cwd=R,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout)
 log.append('$ '+' '.join(str(x) for x in args)+'\nexit='+str(p.returncode)+'\n'+p.stdout.decode(errors='replace')+p.stderr.decode(errors='replace'))
 if ok is not None:assert p.returncode==ok,log[-1]
 return p
try:
 for d in ['tmp','user','parent/data','parent/state','remote/state','remote/data']: (lab/d).mkdir(parents=True,exist_ok=True)
 (lab/'gitconfig').write_text('[user]\n name = Validation\n email = validation@example.invalid\n[commit]\n gpgsign = false\n')
 shutil.copytree(R/'bin',lab/'remote-root/bin');shutil.copy2(R/'AGENTS.md',lab/'remote-root/AGENTS.md')
 run(['git','init','-q','-b','main',lab/'remote-root'],ok=0);run(['git','-C',lab/'remote-root','add','bin','AGENTS.md'],ok=0)
 (lab/'parent/data/secondmates.md').write_text(f'- isolated - disposable remote (host: fm-ssh-local; root: {lab}/remote-root; home: {lab}/remote; scope: validation; projects: sample; added 2026-10-30)\n')
 (lab/'remote/state/parent-replies.status').write_text('note: real SSH loopback reply\n')
 run(['ssh-keygen','-q','-t','rsa','-b','2048','-m','PEM','-N','','-f',lab/'host-key'],ok=0)
 ssh=subprocess.Popen(['node',str(W/'ssh-server.cjs'),str(lab)],env=base,stdout=subprocess.DEVNULL,stderr=open(E/'remote-ssh-server.log','w'))
 for _ in range(100):
  if (lab/'port').exists():break
  time.sleep(.1)
 port=(lab/'port').read_text()
 (lab/'ssh-config').write_text(f'Host fm-ssh-local\n HostName 127.0.0.1\n Port {port}\n User disposable\n StrictHostKeyChecking no\n UserKnownHostsFile {lab}/known_hosts\n GlobalKnownHostsFile /dev/null\n IdentityAgent none\n PubkeyAuthentication no\n PreferredAuthentications none\n LogLevel ERROR\n')
 wrapper=lab/'ssh-client';wrapper.write_text(f'#!/bin/sh\nexec /usr/bin/ssh -F "{lab}/ssh-config" "$@"\n');wrapper.chmod(0o755)
 env={'FM_HOME':str(lab/'parent'),'FM_SSH_BIN':str(wrapper),'FM_REMOTE_REPLY_WAIT_SECONDS':'1'}
 capture=lab/'capture';p=run(['bin/fm-procevent-remote-reply.sh','source','isolated'],env,0);capture.write_bytes(p.stdout)
 assert b'schema=fm-remote-delta.v1' in p.stdout and b'note: real SSH loopback reply' in p.stdout
 run(['bin/fm-procevent-remote-reply.sh','ingest','isolated',capture],env,0)
 status=lab/'parent/state/isolated.status';before=status.read_bytes();assert b'real SSH loopback reply' in before
 cursor=lab/'parent/state/remote-replies/isolated.cursor'; saved=cursor.read_bytes()
 run(['bin/fm-procevent-remote-reply.sh','ingest','isolated',capture],env,0);assert status.read_bytes()==before
 log.append('Observed: real OpenSSH -> disposable SSH server -> tracked fm-remote-entrypoint -> real remote-job worker -> real delta reader -> parent ingestion. Replay did not duplicate the status stream.')
 for flag,code in [('transport-failure',255),('invalid-success',1)]:
  (lab/flag).touch();p=run(['bin/fm-procevent-remote-reply.sh','source','isolated'],env,code)
  assert p.stdout==b'' and cursor.read_bytes()==saved and status.read_bytes()==before
  log.append(f'Observed: {flag}: stdout has zero bytes; cursor and mirrored status unchanged.')
  (lab/flag).unlink()
 (E/'remote-reply-capture.txt').write_bytes(capture.read_bytes());(E/'remote-reply-status.txt').write_bytes(status.read_bytes())
 print('real SSH reply, idempotent ingestion, failed transport and non-schema success rejection passed')
except Exception:
 (E/'remote-live-error.log').write_text('\n'.join(log));raise
finally:
 if ssh: ssh.terminate();ssh.wait(timeout=10)
 pidfile=lab/'jobs/worker.pid'
 if pidfile.exists():
  pid=pidfile.read_text().strip();run(['bash','-c','. "$1/bin/fm-remote-job-lib.sh"; fm_remote_job_stop_worker_tree "$2"','_',R,pid],timeout=20)
 (E/'remote-reply-live.log').write_text('\n'.join(log))
 shutil.rmtree(lab)
