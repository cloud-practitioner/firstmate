import os, pathlib, tempfile, shutil, subprocess, hashlib, time, json
root=pathlib.Path.cwd(); ev=pathlib.Path('/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C')
lab=pathlib.Path(tempfile.mkdtemp(prefix='delta-',dir=root/'.test-phase-tmp')); (lab/'state').mkdir(); log=lab/'state/replies.status'
env=dict(os.environ); env.update(FM_HOME=str(lab),TMPDIR=str(root/'.test-phase-tmp'),FM_REMOTE_DELTA_POLL_SECONDS='.1')
for k in ['FM_STATE_OVERRIDE','FM_ROOT_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE']: env.pop(k,None)
out=[]
def reader(prefix,wait=4,rel='state/replies.status'):
    args=[str(root/'bin/fm-remote-delta-read.sh'),rel,str(len(prefix)),hashlib.sha256(prefix).hexdigest(),str(wait)]
    return subprocess.Popen(args,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def collect(name,p,expected_rc):
    stdout,stderr=p.communicate(timeout=8); assert p.returncode==expected_rc,(p.returncode,stdout,stderr)
    text=stdout.decode(); out.append({'scenario':name,'exit':p.returncode,'response':text,'stderr':stderr.decode()});return text
try:
    log.write_bytes(b'')
    collect('unchanged log closes with no data',reader(b'',2),75)
    prefix=b'original\n';log.write_bytes(prefix);p=reader(prefix);time.sleep(.25);log.open('ab').write(b'partial');time.sleep(.25);assert p.poll() is None;log.open('ab').write(b'-completed\n')
    txt=collect('append waits for newline then returns whole line',p,0);assert 'status=delta\n' in txt and txt.endswith('partial-completed\n')
    prefix=b'alpha\nbeta\n'
    while time.time()%1>.2: time.sleep(.02)
    log.write_bytes(prefix)
    before=log.stat();p=reader(prefix);time.sleep(.18);log.write_bytes(b'OMEGA\nbeta\n');after=log.stat();txt=collect('same-size same-second in-place rewrite breaks continuity',p,0)
    assert before.st_ino==after.st_ino and before.st_size==after.st_size and int(before.st_mtime)==int(after.st_mtime)
    assert 'reason=prefix-changed\n' in txt
    out[-1]['filesystem']={'same_inode':True,'same_size':True,'same_epoch_second':True,'mtime_before_ns':before.st_mtime_ns,'mtime_after_ns':after.st_mtime_ns}
    log.write_bytes(prefix);p=reader(prefix);time.sleep(.2);log.write_bytes(b'x\n');txt=collect('truncation breaks continuity rather than rebasing cursor',p,0);assert 'reason=truncated\n' in txt
    p=reader(b'',1,'../outside.status');collect('reject relative path traversal',p,1)
    (ev/'remote-delta-live.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
finally: shutil.rmtree(lab)
