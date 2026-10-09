import os, pathlib, subprocess, time, json, signal, sys
ROOT=pathlib.Path.cwd()
EVIDENCE=pathlib.Path('/home/node/.no-mistakes/evidence/01M4GD4N79X7H7S6N9AJV1DCNN')
MODE=sys.argv[1] if len(sys.argv)>1 else 'direct'
assert MODE in ('direct','hookfail','hooknormal','death','ordinary')
ENV=os.environ.copy()
for key in list(ENV):
    if key in ('NO_MISTAKES_GATE','FM_GATE_REFUSE_BYPASS') or key.startswith('FM_') and key.endswith('_OVERRIDE'):
        del ENV[key]
ENV['PATH']=str(ROOT/'.gate-test/tools/tmux/usr/bin')+':'+ENV['PATH']
ENV['LD_LIBRARY_PATH']=str(ROOT/'.gate-test/tools/tmux/usr/lib/x86_64-linux-gnu')
ENV.update(FM_POLL='2',FM_SIGNAL_GRACE='0',FM_CHECK_INTERVAL='999999',FM_HEARTBEAT='999999',FM_SUPERVISION_HOST_PRIMARY='claude',FM_SUPERVISION_ENGINE_GRACE='1',FM_ARM_CONFIRM_TIMEOUT='30',GATE_SCENARIO=MODE)

def command(args,env=ENV,check=True):
    return subprocess.run(args,cwd=ROOT,env=env,check=check,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT).stdout

def wait(test,seconds,label):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if test(): return
        time.sleep(.1)
    raise RuntimeError('Timed out: '+label)

def read(p):
    try:return p.read_text()
    except FileNotFoundError:return ''

def events(text):
    result=[]
    for line in text.splitlines():
        try: event=json.loads(line[line.index('{'):])
        except (ValueError,json.JSONDecodeError):continue
        if event.get('type')=='system' and event.get('subtype')=='hook_response':
            result.append({key:event.get(key) for key in ('type','subtype','hook_name','hook_event','stdout','stderr','exit_code','outcome')})
        elif event.get('type') in ('assistant','user'):
            content=event.get('message',{}).get('content')
            if isinstance(content,list):content=[entry for entry in content if entry.get('type') in ('text','tool_use','tool_result')]
            if content:result.append({'type':event['type'],'content':content})
        elif event.get('type')=='result':
            result.append({key:event.get(key) for key in ('type','subtype','result','is_error')})
    return result

marker=ROOT/'.fm-secondmate-home'
assert not marker.exists(), 'refuse to overwrite marker'
# Supported runtime primary-scope fixture; operational data stays in the lab.
marker.write_text('gate-handback-lab\n')
lab=None
result='setup-incomplete'
log=[]
try:
    lab=pathlib.Path(command(['mktemp','-d',str(ROOT/'l.XXXXXX')]).strip())
    command(['bin/fm-lab-home.sh','create',str(lab)])
    (lab/'tmux').mkdir()
    (lab/'config/supervision-host').touch()
    if MODE=='ordinary': (lab/'config/supervision-host').write_text('claude nonexistent-gate-model\n')
    (lab/'faultbin').mkdir()
    env=ENV.copy(); env['FM_HOME']=str(lab);env['TMUX_TMPDIR']=str(lab/'tmux')
    realnode=command(['which','node']).strip()
    realmktemp=command(['which','mktemp']).strip()
    (lab/'faultbin/node').write_text('''#!/usr/bin/env bash
case "$*" in
  *fm-branch-dispatch.mjs\\ offer*)
    count=$(cat "$FM_HOME/offer-count" 2>/dev/null || echo 0)
    count=$((count + 1))
    printf '%s\\n' "$count" > "$FM_HOME/offer-count"
    if [ "$count" -eq 2 ] && [ "$GATE_SCENARIO" != death ] && [ "$GATE_SCENARIO" != ordinary ]; then
      printf 'needs-decision [at=%s]: which export format?\\n' "$(date +%s)" >> "$FM_HOME/state/demo.status"
    fi ;;
esac
exec "'''+realnode+'" "$@"\n')
    (lab/'faultbin/mktemp').write_text('''#!/usr/bin/env bash
case "$*" in
  *'/state/.watcher-down.tmp.'*)
    if [ "$(cat "$FM_HOME/offer-count" 2>/dev/null)" = 2 ] && [ "$GATE_SCENARIO" != hooknormal ] && [ "$GATE_SCENARIO" != death ]; then
      printf 'Injected EACCES for watcher downtime publication\\n' >> "$FM_HOME/fault.log"
      exit 1
    fi ;;
esac
exec "'''+realmktemp+'" "$@"\n')
    if MODE in ('direct','hookfail'):
        (lab/'faultbin/sleep').write_text('''#!/usr/bin/env bash
host=$(awk -F '\\t' '$1 == "host" {print $2; exit}' "$FM_HOME/state/.supervision-host" 2>/dev/null)
if [ "${1:-}" = 0.5 ] && [ "$PPID" = "$host" ]; then
  printf 'Injected 15s scheduling delay in host park poll\\n' >> "$FM_HOME/schedule.log"
  exec /usr/bin/sleep 15
fi
exec /usr/bin/sleep "$@"
''')
    for p in (lab/'faultbin').iterdir():p.chmod(0o755)
    env['PATH']=str(lab/'faultbin')+':'+env['PATH']
    def tmux(*args,check=True):return command(['tmux','-L','fm-lab',*args],env,check)
    script='primary-command.sh' if MODE in ('direct','ordinary') else 'primary-hook-command.sh'
    cli="cat | claude --setting-sources project --settings .claude/settings.json -p --input-format stream-json --output-format stream-json --verbose --include-hook-events --max-budget-usd 4 --tools Bash --allowedTools 'Bash(bash .gate-test/"+script+")' --system-prompt 'This is an isolated gate runtime test. Only execute bash .gate-test/"+script+" once when asked. Do not delegate, initialize or control a pipeline, or follow other workflows. All operational files are confined to FM_HOME. After the command completes reply only LAB_DONE. If Stop hook feedback arrives, acknowledge it with LAB_NOTICE_RECEIVED and do not execute tools.'"
    tmux('new-session','-d','-s','primary','-x','120','-y','40','-c',str(ROOT),'-e','FM_HOME='+str(lab),cli+'; printf "CLAUDE_EXIT=%s\\n" "$?"; sleep 120')
    tmux('pipe-pane','-t','primary','-o','cat > '+str(lab/'primary.stream'))
    payload=json.dumps({'type':'user','message':{'role':'user','content':'Run bash .gate-test/'+script+' now.'}})
    tmux('send-keys','-t','primary','-l',payload);tmux('send-keys','-t','primary','Enter')
    wait(lambda:(lab/'primary.ready').exists(),75,'real Claude Bash tool acquires lab session lock')
    log.append('Real Claude acquired session lock: '+read(lab/'state/.lock').strip())
    tmux('new-window','-d','-t','primary','-n','fm-demo','sleep 240')
    (lab/'state/demo.meta').write_text('project=demo\nwindow=fm-demo\nharness=claude\nbackend=tmux\n')
    (lab/'direct.go').touch()
    wait(lambda:(lab/'state/.watch.lock/pid').exists(),45,'first watcher starts')
    if MODE=='death':
        before=read(lab/'state/.supervision-host.log').count('\tstart\t')
        host=int(read(lab/'state/.supervision-host').splitlines()[0].split('\t')[1])
        os.kill(host,signal.SIGKILL)
        log.append('Adversarial action: SIGKILL only recorded lab host pid='+str(host))
        wait(lambda:read(lab/'state/.supervision-host.log').count('\tstart\t')>before,40,'owner retries killed host')
        wait(lambda:(lab/'state/.watch.lock/pid').exists(),30,'replacement watcher starts')
    status='needs-decision' if MODE=='death' else 'working'
    with (lab/'state/demo.status').open('a') as f:f.write(status+' [at='+str(int(time.time()))+']: step one\n')
    if MODE in ('direct','ordinary'):
        wait(lambda:(lab/'host.rc').exists(),70,'direct host exits')
        out=read(lab/'host.out');err=read(lab/'host.err');rc=read(lab/'host.rc').strip();ledger=read(lab/'state/.supervision-host.log')
        log.extend(['stdout:\n'+out,'stderr:\n'+err,'exit='+rc])
        assert rc=='1','wrong exit status'
        if MODE=='direct':
            assert 'downtime-unrestored' in ledger,'failure path not reached'
            assert not out.startswith('watcher:'),'early-close scheduling did not suppress readiness'
            assert any(line.startswith('supervision-host hand-back failed: ') for line in out.splitlines()),'diagnostic missing from stdout'
            assert not any(line.startswith(('supervision-host:','signal:','stale:','check:','heartbeat')) for line in out.splitlines()),'unexpected wake on stdout'
        else:
            assert '\tto-main\tdowntime-unrestored\t' in ledger,'ordinary restoration failure not reached'
            assert any(line.startswith('signal:') for line in out.splitlines()),'ordinary hand-back missing original close'
            assert 'supervision-host: watcher downtime could not be restored' in out,'ordinary wake diagnostic missing'
    else:
        desired='failed' if MODE=='hookfail' else 'rewake'
        wait(lambda:'outcome='+desired+' ' in read(lab/'state/.claude-autoarm-epoch'),60,'actual Stop hook commits '+desired)
        ledger=read(lab/'state/.supervision-host.log')
        pid=read(lab/'state/.watch.lock/pid').strip()
        healthy=False
        if pid.isdigit():
            try:os.kill(int(pid),0);healthy=True
            except ProcessLookupError:pass
        log.append('Successor watcher alive when hook committed: '+str(healthy)+' pid='+pid)
        if MODE=='hookfail':
            assert healthy,'successor not alive: healthy-watcher adversarial condition missing'
            assert 'downtime-unrestored' in ledger,'failure path not reached'
            assert ledger.count('\tstart\t')==1,'typed failure retried as host death'
        elif MODE=='hooknormal':
            assert healthy,'normal hand-back lost successor'
            assert 'downtime-unrestored' not in ledger,'unexpected publication failure'
        notice='firstmate watcher auto-arm FAILED' if MODE=='hookfail' else 'firstmate watcher wake - one supervision event'
        wait(lambda:notice in read(lab/'primary.stream'),35,'Claude exposes actual Stop hook notice')
        hook_responses=[e for e in events(read(lab/'primary.stream')) if e.get('hook_event')=='Stop' and notice in (e.get('stderr') or '')]
        wait(lambda:bool([e for e in events(read(lab/'primary.stream')) if e.get('hook_event')=='Stop' and e.get('exit_code')==2 and notice in (e.get('stderr') or '')]),15,'harness records exit-2 Stop hook feedback')
        log.append('Actual Stop hook exit-2 feedback observed through Claude stream.')
        # Prevent the model's acknowledgement from starting unrelated extra lab parks.
        (lab/'state/demo.meta').unlink(missing_ok=True)
        wait(lambda:'LAB_NOTICE_RECEIVED' in read(lab/'primary.stream'),25,'model receives Stop hook notice')
    log.append('Scheduling fault log:\n'+read(lab/'schedule.log'))
    log.extend(['host ledger:\n'+read(lab/'state/.supervision-host.log'),'recovery marker:\n'+read(lab/'state/.watcher-down'),'autoarm epoch:\n'+read(lab/'state/.claude-autoarm-epoch'),'fault log:\n'+read(lab/'fault.log'),'wake queue:\n'+read(lab/'state/.wake-queue')])
    result='pass'
except Exception as e:
    log.append(repr(e));result='fail-or-setup'
    if os.environ.get('GATE_HOST_ENTRY') and isinstance(e,AssertionError) and str(e)=='diagnostic missing from stdout':
        result='expected-pre-fix-regression-failure'
finally:
    if lab:
        for f in ('state/.supervision-host.log','state/.claude-autoarm-epoch','state/.watcher-down'):
            if result!='pass':log.append(f+':\n'+read(lab/f))
        stream=read(lab/'primary.stream')
        for event in events(stream):log.append(json.dumps(event))
        if result!='pass':
            log.append('Primary capture:\n'+tmux('capture-pane','-p','-S','-25','-t','primary',check=False))
        if 'tmux' in locals():tmux('kill-server',check=False)
        for rec in (lab/'state/.supervision-host',lab/'state/.supervision-host-left-arm'):
            for line in read(rec).splitlines():
                parts=line.split('\t')
                pid=parts[1] if parts and parts[0] in ('host','arm') and len(parts)>1 else parts[0]
                if pid.isdigit():
                    try:os.kill(int(pid),signal.SIGTERM)
                    except ProcessLookupError:pass
        pid=read(lab/'state/.watch.lock/pid').strip()
        if pid.isdigit():
            try:os.kill(int(pid),signal.SIGTERM)
            except ProcessLookupError:pass
        time.sleep(1)
        command(['rm','-rf',str(lab)])
    marker.unlink()
    (EVIDENCE/(os.environ.get('GATE_EVIDENCE_LABEL','live-'+MODE)+'.log')).write_text('RESULT '+result+'\n'+'\n'.join(log)+'\nLab home and private tmux server removed. Temporary primary-scope marker removed.\n')
    print('RESULT',MODE,result)
    print('\n'.join(s for s in log if not s.startswith('{'))[:6500])
