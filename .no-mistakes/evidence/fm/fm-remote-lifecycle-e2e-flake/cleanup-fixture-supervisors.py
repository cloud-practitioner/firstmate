#!/usr/bin/env python3
"""Reclaim only this turn's idle, orphaned duplicate fixture supervisors.
Keep the published serving worker and its parent. Never name operator processes.
"""
import os
import signal
import subprocess
from pathlib import Path
root = Path('/home/node/.no-mistakes/worktrees/450411b3e67c/01M40012HAGF4C4Q91QNT4Q373')
fixture = root/'.no-mistakes/test-phase/tmp/fm-remote-secondmate-e2e.adMqhq'
worker = str(fixture/'remote-root/bin/fm-remote-job-worker.sh')
published = int((fixture/'remote-jobs/worker.pid').read_text())
parent = int(Path(f'/proc/{published}/stat').read_text().split(') ', 1)[1].split()[1])
keep = {published, parent}
stopped = []
for line in subprocess.check_output(['ps', '-u', str(os.getuid()), '-o', 'pid=,ppid=,args='], text=True).splitlines():
    pid_text, ppid_text, args = line.strip().split(None, 2)
    pid = int(pid_text)
    if int(ppid_text) != 1 or pid in keep or args != f'/bin/bash {worker}':
        continue
    try:
        cmd = Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
        if cmd[:2] != [b'/bin/bash', worker.encode()] or any(cmd[2:]):
            continue
        os.kill(pid, signal.SIGTERM)
        stopped.append(pid)
    except (FileNotFoundError, ProcessLookupError):
        pass
print(f'Retained serving worker {published} and its supervisor {parent}; reclaimed duplicate fixture supervisors {stopped}.')
