#!/usr/bin/env python3
"""Retry the one unresolved targeted check with a disposable nested SDK layout.
No SDK or source changes; all links target the supplied installed SDK.
"""
import json, os, pathlib, subprocess, tempfile
root = pathlib.Path.cwd()
evidence = pathlib.Path('/home/node/.no-mistakes/evidence/01M5CS8Z14AJ6WRYGCEP0JMSHD')
package = pathlib.Path('/workspaces/wp/.pi/install/releases/1.3.0/node_modules/@earendil-works/pi-coding-agent')
env = {k:v for k,v in os.environ.items() if not k.startswith(('FM_', 'HERDR', 'GH_', 'GITHUB_', 'BITBUCKET_', 'NO_MISTAKES_BITBUCKET_', 'GIT_CONFIG_')) and k not in ('TMUX', 'TMUX_PANE')}
env.update(TMPDIR='/tmp', GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null')
with tempfile.TemporaryDirectory(prefix='fm-sdk-check-') as temp:
    wrapper = pathlib.Path(temp) / 'pi-coding-agent'
    wrapper.mkdir()
    for child in package.iterdir():
        (wrapper / child.name).symlink_to(child, target_is_directory=child.is_dir())
    if not (wrapper / 'node_modules').exists():
        (wrapper / 'node_modules').symlink_to(package.parent.parent, target_is_directory=True)
    env['FM_PI_PACKAGE_DIR'] = str(wrapper)
    cmd = ['bin/fm-test-run.sh', '--jobs', '1', '--per-script-timeout-secs', '420', '--json', str(evidence / 'pi-sdk-layout-timing.json'), 'tests/fm-pi-branch-extension.test.sh']
    (evidence / 'pi-sdk-layout-command.json').write_text(json.dumps({'command':cmd, 'sdk_source':str(package), 'layout':'temporary symlinks expose hoisted dependencies under the test-expected node_modules', 'tmp_cleanup':'TemporaryDirectory'}, indent=2) + '\n')
    with (evidence / 'pi-sdk-layout-recheck.log').open('w') as log:
        result = subprocess.run(cmd, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=460)
    print('Pi targeted retry exit:', result.returncode)
    print((evidence / 'pi-sdk-layout-recheck.log').read_text()[-7000:])
    raise SystemExit(result.returncode)
