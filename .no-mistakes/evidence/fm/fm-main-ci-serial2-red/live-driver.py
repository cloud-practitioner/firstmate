import os, pathlib, subprocess, time, json, sys

ROOT=pathlib.Path.cwd()
EVIDENCE=pathlib.Path('/home/node/.no-mistakes/evidence/01M4FP5CTQHWWJANYTGJWVB08N')
TMUX=ROOT/'.validation/tools/installed/bin/tmux'
NODE=subprocess.check_output(['bash','-c','command -v node'],text=True).strip()
MKTEMP=subprocess.check_output(['bash','-c','command -v mktemp'],text=True).strip()

# No substituted harness, host, watcher, or dispatcher: the only shims serialize
# the real offer calculation with the operator's status append and inject one
# dependency failure when requested.
def run_scenario(name, fault, early=False):
    lab=pathlib.Path(subprocess.check_output(['mktemp','-d',str(ROOT/'.l.XXXXXX')],text=True).strip())
    out=EVIDENCE/name; out.mkdir(exist_ok=True)
    subprocess.run(['bin/fm-lab-home.sh','create',str(lab)],check=True)
    (lab/'tmux').mkdir()
    (lab/'config/supervision-host').touch()
    (lab/'faultbin').mkdir()
    node=lab/'faultbin/node'
    node.write_text('''#!/usr/bin/env bash
case "$*" in
  *fm-branch-dispatch.mjs\\ offer*)
    count=$(cat "$FM_HOME/offer-count" 2>/dev/null || echo 0)
    count=$((count + 1))
    printf '%s\\n' "$count" > "$FM_HOME/offer-count"
    if [ "$count" -eq 2 ]; then
      : > "$FM_HOME/second-offer-ready"
      for i in $(seq 1 500); do
        [ ! -e "$FM_HOME/second-offer-release" ] || break
        sleep 0.1
      done
    fi ;;
esac
exec "'''+NODE+'''" "$@"
''')
    node.chmod(0o755)
    mktemp=lab/'faultbin/mktemp'
    mktemp.write_text('''#!/usr/bin/env bash
case "$*" in
  *'/state/.watcher-down.tmp.'*)
    if [ -e "$FM_HOME/inject-write-failure" ] && [ "$(cat "$FM_HOME/offer-count" 2>/dev/null)" = 2 ]; then
      printf '%s\\n' 'injected mktemp failure: watcher downtime publication' >> "$FM_HOME/fault-events"
      exit 1
    fi ;;
esac
exec "'''+MKTEMP+'''" "$@"
''')
    mktemp.chmod(0o755)
    if early:
        real_od=subprocess.check_output(['bash','-c','command -v od'],text=True).strip()
        od=lab/'faultbin/od'
        od.write_text('''#!/usr/bin/env bash
parent=$(tr '\\0' ' ' < "/proc/$PPID/cmdline" 2>/dev/null)
last=${!#}
target=$(tr '\\0' ' ' < "$last" 2>/dev/null)
case "$parent|$target" in
  *fm-supervision-host.sh*'|'*fm-watch-arm.sh*)
    if mkdir "$FM_HOME/early-read-once" 2>/dev/null; then
      # Return the real identity bytes unchanged, only later. This models a
      # slow scheduled host while its already-started arm closes normally.
      result=$("'''+real_od+'''" "$@")
      rc=$?
      : > "$FM_HOME/early-read-held"
      sleep 3
      printf '%s\\n' "$result"
      exit "$rc"
    fi ;;
esac
exec "'''+real_od+'''" "$@"
''')
        od.chmod(0o755)
    env=dict(os.environ)
    for k in ['NO_MISTAKES_GATE','FM_GATE_REFUSE_BYPASS','FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE','PI_CODING_AGENT','FM_SUPERVISION_ENGINE_CLAUDE_BIN','TMUX','FM_TASK_ID']:
        env.pop(k,None)
    env.update(TMUX_TMPDIR=str(lab/'tmux'),FM_HOME=str(lab),FM_BACKEND='tmux',FM_POLL='1',FM_SIGNAL_GRACE='0',FM_CHECK_INTERVAL='999999',FM_HEARTBEAT='999999',FM_SUPERVISION_ENGINE_GRACE='1',PATH=str(lab/'faultbin')+':'+str(TMUX.parent)+':'+env['PATH'])
    def tmux(*args,check=True):
        return subprocess.run([str(TMUX),'-L','fm-lab',*args],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=check).stdout
    def wait_for(fn, seconds=45):
        end=time.monotonic()+seconds
        while time.monotonic()<end:
            if fn(): return
            time.sleep(.1)
        raise RuntimeError('timed out waiting for '+getattr(fn,'__name__','condition'))
    def contents(file):
        try:return (lab/file).read_text()
        except FileNotFoundError:return ''
    checks={}
    started=time.monotonic()
    try:
        tmux('new-session','-d','-s','primary','-x','120','-y','40','-c',str(ROOT),'-e','FM_HOME='+str(lab),'claude')
        wait_for(lambda: 'auto mode on' in tmux('capture-pane','-p','-t','primary'),20)
        time.sleep(2)
        tmux('new-window','-d','-t','primary','-n','fm-demo','-c',str(ROOT),'sleep 300')
        (lab/'state/demo.meta').write_text('project=lab\nwindow=fm-demo\nbackend=tmux\nkind=scout\nharness=claude\n')
        prompt='Captain-approved disposable lab validation: use only the existing FM_HOME lab, never another home. Do not spawn, sync, merge, fetch, initialize, or invoke no-mistakes. Run `bin/fm-lock.sh`, then reply exactly "LAB READY" without any other tool calls. If a lab Stop-hook notification appears later, do not run commands or acknowledge the wake; only quote the notification. I will inject the lab status events.'
        tmux('send-keys','-t','primary','-l',prompt)
        time.sleep(1)
        tmux('send-keys','-t','primary','Enter')
        wait_for(lambda: (lab/'state/.watch.lock/pid').exists(),65)
        time.sleep(.15)
        with (lab/'state/demo.status').open('a') as f:
            f.write('working [at=%d]: step one\n'%time.time())
        wait_for(lambda: (lab/'second-offer-ready').exists(),40)
        checks['first_offer_accepted_and_real_second_offer_reached']=True
        if early:
            checks['early_close_schedule_injected']=(lab/'early-read-held').exists()
            assert checks['early_close_schedule_injected'], 'host scheduling hold was not reached'
        # Transition the real decision-owned wake contract. In the failure
        # case, enqueue through its real owner without another status append,
        # so the already-started successor remains healthy and quiet.
        if fault:
            subprocess.run(['bash','-c','. "$1"; fm_wake_append signal demo.status "needs-decision: which export format?"','_',str(ROOT/'bin/fm-wake-lib.sh')],env=env,check=True)
            (lab/'inject-write-failure').touch()
        else:
            with (lab/'state/demo.status').open('a') as f:
                f.write('needs-decision [at=%d]: which export format?\n'%time.time())
        checks['marker_before_handback']=contents('state/.watcher-down').strip()
        (lab/'second-offer-release').touch()
        needle='outcome=failed ' if fault else 'outcome=rewake '
        wait_for(lambda: needle in contents('state/.claude-autoarm-epoch'),40)
        checks['stop_owner_outcome']='failed' if fault else 'rewake'
        checks['host_log']=contents('state/.supervision-host.log')
        checks['wake_remains_durable']='demo.status' in contents('state/.wake-queue')
        checks['marker']=contents('state/.watcher-down').strip()
        if fault:
            checks['fault_injected']='injected mktemp failure' in contents('fault-events')
            checks['downtime_unrestored']='downtime-unrestored' in checks['host_log']
            healthy=subprocess.run(['bash','-c','. "$1"; fm_watcher_healthy "$FM_HOME/state" "$2" 20 "$FM_HOME"','_',str(ROOT/'bin/fm-wake-lib.sh'),str(ROOT/'bin/fm-watch.sh')],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            checks['successor_still_healthy_at_failed_handback']=healthy.returncode==0
            # The owner has consumed and removed its output file. Its public
            # failure feedback is captured from Claude's real terminal below.
        else:
            checks['pass_through_main_only']='main-only' in checks['host_log']
        # Capture actual asynchronous feedback without permitting model fleet
        # mutation. A generated banner reaches the real primary conversation.
        terminal_needle='auto-arm FAILED' if fault else 'watcher wake'
        wait_for(lambda: terminal_needle in tmux('capture-pane','-p','-S','-300','-t','primary'),35)
        time.sleep(6)
        terminal=tmux('capture-pane','-p','-S','-300','-t','primary')
        (out/'claude-terminal.txt').write_text(terminal)
        checks['feedback_visible_in_real_claude']=terminal_needle in terminal
        if early:
            checks['no_initial_readiness_in_feedback']='watcher: started pid=' not in terminal
            assert checks['no_initial_readiness_in_feedback'], 'readiness was already emitted; early-close schedule not exercised'
            assert 'supervision-host hand-back failed:' in terminal, 'failed host diagnostic not visible'
        checks['elapsed_seconds']=round(time.monotonic()-started,2)
        required=['first_offer_accepted_and_real_second_offer_reached','wake_remains_durable','feedback_visible_in_real_claude']+(['fault_injected','downtime_unrestored','successor_still_healthy_at_failed_handback'] if fault else ['pass_through_main_only'])
        assert all(checks[k] for k in required), checks
        checks['result']='pass'
    except Exception as exc:
        checks['result']='fail'; checks['error']=str(exc)
        (out/'claude-terminal.txt').write_text(tmux('capture-pane','-p','-S','-300','-t','primary',check=False))
    finally:
        for file in ['state/.supervision-host.log','state/.claude-autoarm-epoch','state/.claude-autoarm-failure-notified','state/.watcher-down','state/.wake-queue','fault-events','offer-count']:
            if (lab/file).is_file(): (out/pathlib.Path(file).name).write_bytes((lab/file).read_bytes())
        subprocess.run(['bin/fm-watch-arm.sh','--stop'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        tmux('kill-server',check=False)
        # A recorded host is a real process under this lab only.
        host_record=contents('state/.supervision-host')
        for row in host_record.splitlines():
            pieces=row.split('\t')
            if len(pieces)>1 and pieces[0] in ['host','arm']:
                try: os.kill(int(pieces[1]),15)
                except (ProcessLookupError,ValueError): pass
        subprocess.run(['rm','-rf',str(lab)],check=True)
        checks['lab_removed']=not lab.exists()
        (out/'result.json').write_text(json.dumps(checks,indent=2)+'\n')
    print(json.dumps(checks,indent=2))
    return checks['result']=='pass'

ok=run_scenario(sys.argv[1],sys.argv[2]=='fault',len(sys.argv)>3 and sys.argv[3]=='early')
sys.exit(0 if ok else 1)
