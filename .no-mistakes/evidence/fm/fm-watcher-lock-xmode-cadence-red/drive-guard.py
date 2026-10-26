import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path.cwd()
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M5TSGD98SD2PXA6384PVCDD6')
LAB = ROOT / '.fm-validation/live-guard-home'
AMBIENT = ROOT / '.fm-validation/ambient'
BASE = dict(os.environ)
for key in list(BASE):
    if key.startswith('FM_'):
        BASE.pop(key)
BASE.update(HOME=str(ROOT / '.fm-validation/user-home'), TMPDIR=str(ROOT / '.fm-validation/tmp'), PI_CODING_AGENT='true')


def snapshot(path):
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in path.rglob('*') if p.is_file()}


with (EVIDENCE / 'live-guard-transcript.log').open('w') as log:
    def run(args, env, title):
        log.write(f'\n## {title}\n$ {" ".join(map(str, args))}\n')
        result = subprocess.run(list(map(str, args)), env=env, capture_output=True, text=True, timeout=30)
        log.write(result.stdout)
        log.write(result.stderr)
        log.write(f'exit={result.returncode}; stdout_bytes={len(result.stdout.encode())}; stderr_bytes={len(result.stderr.encode())}\n')
        log.flush()
        assert result.returncode == 0, (title, result.stderr)
        return result.stdout, result.stderr

    # Use the supported marked-home constructor, never an operator home.
    run(['bin/fm-lab-home.sh', 'create', LAB], BASE, 'Create disposable, marked worktree-local home')
    env = dict(BASE, FM_HOME=str(LAB), FM_ROOT_OVERRIDE=str(LAB), FM_GUARD_GRACE='300')
    watcher = None
    watcher_log = None
    try:
        ambient_config = AMBIENT / 'config/x-mode.env'
        ambient_config.write_text('FM_POLL=971\n')
        before = snapshot(AMBIENT)
        config = LAB / 'config/x-mode.env'
        config.write_text('FM_POLL=17\n')
        (LAB / 'state/task.meta').write_text('project=disposable-local-example\n')

        # The shell starts with conflicting ambient FM_HOME, then the same
        # per-command fixture pin as the fix overrides it. No ps/backend shims.
        shell_env = dict(env, FM_HOME=str(AMBIENT), CASE_HOME=str(LAB))
        _, err = run(['bash', '-c', 'FM_HOME="$CASE_HOME" bin/fm-guard.sh'], shell_env,
                     'Conflicting ambient home: real guard uses the explicit local cadence config')
        expected = f"source '{config}' first"
        assert 'WATCHER DOWN - SUPERVISION IS OFF' in err
        assert expected in err, err
        assert str(ambient_config) not in err
        assert '1 task(s) in flight' in err
        (EVIDENCE / 'guard-local-cadence.stderr.txt').write_text(err)

        # Contradict the first case: only the ambient home retains a config.
        # A fresh episode must not leak its source command into the local home.
        config.unlink()
        (LAB / 'state/.guard-watcher-stale-banner').unlink(missing_ok=True)
        _, err = run(['bash', '-c', 'FM_HOME="$CASE_HOME" bin/fm-guard.sh'], shell_env,
                     'Adversarial inverse: ambient config exists, local config absent')
        assert 'WATCHER DOWN - SUPERVISION IS OFF' in err
        assert 'x-mode.env' not in err, err
        assert before == snapshot(AMBIENT), 'ambient home changed'
        log.write('Ambient home content hashes and file set unchanged.\n')

        # Append through the production durable-queue owner, then check the
        # actual emitted operator warning ordering and repair-after-drain.
        run(['bash', '-c', '. bin/fm-wake-lib.sh; fm_wake_append heartbeat heartbeat heartbeat'], env,
            'Append a heartbeat using the production wake queue')
        (LAB / 'state/task2.meta').write_text('project=another-disposable-local-example\n')
        (LAB / 'state/.guard-watcher-stale-banner').unlink(missing_ok=True)
        _, err = run(['bin/fm-guard.sh'], env, 'Watcher down with queued wake: banner leads, drain precedes repair')
        assert '2 task(s) in flight' in err
        assert err.index('WATCHER DOWN - SUPERVISION IS OFF') < err.index('queued wakes pending - drain them')
        assert 'After draining queued wakes, ' in err
        assert 'guarded operation WILL still run' in err
        (EVIDENCE / 'guard-down-queued.stderr.txt').write_text(err)

        # Clear only this scenario's disposable records. Start the actual daemon
        # with no task endpoints or checks, then introduce one local meta record
        # after it has published its verified identity and beacon. No backend,
        # fake watcher PID, credentials, primary CLI, or shared service involved.
        for p in (LAB / 'state').iterdir():
            if p.is_file():
                p.unlink()
        daemon_env = dict(BASE, FM_HOME=str(LAB), FM_POLL='30', FM_CHECK_INTERVAL='999999', FM_HEARTBEAT='999999')
        watcher_log = (EVIDENCE / 'live-watcher.log').open('w')
        log.write('\n## Healthy watcher\n$ FM_HOME=<marked-local-lab> FM_POLL=30 bin/fm-watch.sh\n')
        watcher = subprocess.Popen(['bin/fm-watch.sh'], env=daemon_env, stdout=watcher_log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 15
        lock = LAB / 'state/.watch.lock/pid'
        beat = LAB / 'state/.last-watcher-beat'
        identity = LAB / 'state/.watch.lock/pid-identity'
        while time.monotonic() < deadline:
            if watcher.poll() is not None:
                raise AssertionError(f'watcher exited {watcher.returncode} before health publication')
            if lock.exists() and lock.read_text().strip() == str(watcher.pid) and beat.exists() and identity.exists():
                break
            time.sleep(0.05)
        else:
            raise AssertionError('watcher did not publish health within 15 seconds')
        log.write(f'Actual daemon pid={watcher.pid}; lock pid={lock.read_text().strip()}; identity={identity.read_text().strip()}; beacon_mtime={beat.stat().st_mtime}\n')
        (LAB / 'state/task.meta').write_text('project=disposable-local-example\n')
        out, err = run(['bin/fm-guard.sh'], env, 'Live identity-matched watcher and fresh beacon: guard emits nothing')
        assert out == '' and err == '', (out, err)
        assert watcher.poll() is None
        assert before == snapshot(AMBIENT), 'ambient home changed'
        log.write('Real watcher remains alive; guard is silent with one in-flight record.\n')
    finally:
        if watcher is not None:
            watcher.terminate()
            try:
                rc = watcher.wait(timeout=12)
            except subprocess.TimeoutExpired:
                watcher.kill()
                watcher.wait()
                raise
            log.write(f'Owned watcher stopped with exit={rc}.\n')
        if watcher_log is not None:
            watcher_log.close()
        shutil.rmtree(LAB)
        log.write('Disposable lab removed; no shared session or operator home accessed.\n')
