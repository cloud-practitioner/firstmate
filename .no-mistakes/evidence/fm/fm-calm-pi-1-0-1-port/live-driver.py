import os, sys, json, time, shutil, struct, fcntl, termios, select, subprocess, hashlib
from pathlib import Path

ROOT = Path.cwd()
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M4255Z93913VQ2VRJNN7CD28')
version = sys.argv[1]
pkg = ROOT / f'.test-calm-validation/pi-{version}-global/lib/node_modules/@earendil-works/pi-coding-agent'
lab = ROOT / f'.test-calm-validation/live-{version}'
project = lab / 'project'
config = lab / 'pi-config'
home = lab / 'home'
for p in [project, config, home / 'config', lab / 'tmp']:
    p.mkdir(parents=True, exist_ok=True)
shutil.copytree(ROOT / '.pi/extensions/lib', project / '.pi/extensions/lib', dirs_exist_ok=True)
for name in ['fm-calm.ts', 'fm-primary-pi-watch.ts']:
    shutil.copy2(ROOT / '.pi/extensions' / name, project / '.pi/extensions' / name)
(project / 'node_modules/@earendil-works').mkdir(parents=True, exist_ok=True)
for name, source in [('pi-coding-agent', pkg), ('pi-tui', pkg / 'node_modules/@earendil-works/pi-tui')]:
    dest = project / 'node_modules/@earendil-works' / name
    if not dest.exists(): dest.symlink_to(source, target_is_directory=True)
if not (project / 'node_modules/typebox').exists():
    (project / 'node_modules/typebox').symlink_to(pkg / 'node_modules/typebox', target_is_directory=True)
(home / 'config/calm').write_text('on\n')
(config / 'settings.json').write_text(json.dumps({'hideThinkingBlock': True, 'tuiMode': 'regular', 'telemetryEnabled': False, 'quietStartup': True}))
(config / 'keybindings.json').write_text(json.dumps({'tui.input.submit': 'alt+s'}))
(project / 'sample.txt').write_text('CALM_LIVE_GREP\n')
(project / 'CALM_LIVE_FIND.txt').write_text('live export fixture\n')

# Input data is a disposable Pi v3 session, not a replacement for the product.
now = '2026-10-04T00:00:00.000Z'
records = [{'type': 'session', 'version': 3, 'id': '11111111-1111-4111-8111-111111111111', 'timestamp': now, 'cwd': str(project)}]
parent = None
counter = 0
usage = {'input': 1, 'output': 1, 'cacheRead': 0, 'cacheWrite': 0, 'totalTokens': 2, 'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0, 'total': 0}}
def append(message):
    global parent, counter
    counter += 1
    ident = f'a{counter:07d}'
    records.append({'type': 'message', 'id': ident, 'parentId': parent, 'timestamp': now, 'message': {**message, 'timestamp': counter}})
    parent = ident
append({'role': 'user', 'content': [{'type': 'text', 'text': 'Show the saved grep, find and watcher examples.'}]})
for name, args, output, details in [
    ('grep', {'pattern': 'CALM_LIVE_GREP', 'path': '.'}, 'sample.txt:1:CALM_LIVE_GREP', {}),
    ('find', {'pattern': 'CALM_LIVE_FIND*', 'path': '.'}, 'CALM_LIVE_FIND.txt', {}),
    ('fm_watch_arm_pi', {}, 'watcher: saved fixture arm result', {'ok': True, 'message': 'watcher: saved fixture arm result'}),
]:
    append({'role': 'assistant', 'content': [{'type': 'thinking', 'thinking': 'SAVED_INTERNAL_REASONING'}, {'type': 'toolCall', 'id': f'call_{name}', 'name': name, 'arguments': args}], 'api': 'anthropic-messages', 'provider': 'anthropic', 'model': 'claude-sonnet-4-5', 'usage': usage, 'stopReason': 'toolUse'})
    append({'role': 'toolResult', 'toolCallId': f'call_{name}', 'toolName': name, 'content': [{'type': 'text', 'text': output}], 'details': details, 'isError': False})
append({'role': 'assistant', 'content': [{'type': 'text', 'text': 'The saved tool examples are complete.'}], 'api': 'anthropic-messages', 'provider': 'anthropic', 'model': 'claude-sonnet-4-5', 'usage': usage, 'stopReason': 'stop'})
session = lab / 'session.jsonl'
session.write_text(''.join(json.dumps(r) + '\n' for r in records))
before = hashlib.sha256(session.read_bytes()).hexdigest()
export = EVIDENCE / f'pi-{version}-calm-export.html'
if export.exists(): export.unlink()
# No auth stores, account pins, operator settings, or shared fleet paths are used.
env = dict(os.environ)
for name in list(env):
    if name.startswith(('FM_', 'PI_', 'NO_MISTAKES', 'CHROME_', 'TASKS_AXI')) or 'TOKEN' in name or 'API_KEY' in name or name in ['TMUX', 'AWS_PROFILE', 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']:
        env.pop(name, None)
env.update({'HOME': str(home), 'FM_HOME': str(home), 'PI_CODING_AGENT_DIR': str(config), 'PI_CODING_AGENT_SESSION_DIR': str(lab / 'sessions'), 'PI_OFFLINE': '1', 'PI_TELEMETRY': '0', 'TMPDIR': str(lab / 'tmp'), 'XDG_CONFIG_HOME': str(home / '.config'), 'XDG_CACHE_HOME': str(home / '.cache'), 'XDG_DATA_HOME': str(home / '.local/share'), 'TERM': 'xterm-256color', 'COLORTERM': 'truecolor'})
cli = ['node', str(pkg / 'dist/cli.js'), '--offline', '--tui-mode', 'regular', '--no-context-files', '--no-skills', '--no-prompt-templates', '--no-themes', '--no-extensions', '--approve', '-e', str(project / '.pi/extensions/fm-calm.ts'), '-e', str(project / '.pi/extensions/fm-primary-pi-watch.ts'), '--session', str(session)]
master, slave = os.openpty()
# Size is set on the slave before the real CLI starts, and the master is drained.
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 44, 160, 0, 0))
process = subprocess.Popen(cli, stdin=slave, stdout=slave, stderr=slave, cwd=project, env=env, start_new_session=True)
os.close(slave)
output = bytearray()
steps = []
def drain(seconds):
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        if select.select([master], [], [], min(.05, max(0, until-time.monotonic())))[0]:
            try:
                chunk = os.read(master, 65536)
                if not chunk: break
                output.extend(chunk)
            except OSError: break

def command(text, submit=b'\x1bs'):
    os.write(master, text.encode())
    drain(.3)
    os.write(master, submit)
    drain(1)

try:
    drain(5)
    assert process.poll() is None, f'Pi exited on startup: {process.returncode}'
    assert b'The saved tool examples are complete.' in output, 'saved transcript did not load'
    # Pi adds a native thinking-level entry on startup. Compare from the loaded,
    # idle state so the export invariant does not reject normal initialization.
    before = hashlib.sha256(session.read_bytes()).hexdigest()
    command('/calm')
    assert (home / 'config/calm').read_text() == 'off\n', '/calm did not persist off'
    command('/calm')
    assert (home / 'config/calm').read_text() == 'on\n', '/calm did not persist on'
    steps.append('Real /calm command toggled off then on and persisted each choice.')
    command('/export ' + str(export), b'\r')
    assert not export.exists(), 'Enter unexpectedly submitted with Alt+s binding'
    assert (home / 'config/calm').read_text() == 'on\n'
    steps.append('Enter with submit remapped to Alt+s did not create the HTML export.')
    os.write(master, b'\x1bs')
    drain(3)
    assert export.exists(), 'Alt+s did not create the HTML export'
    assert b'Session exported to:' in output, 'real Pi export confirmation missing'
    steps.append('Alt+s executed /export and real Pi confirmed its output path.')
    assert (home / 'config/calm').read_text() == 'on\n'
    # No model turn or tool execution is needed to inspect a saved transcript.
    command('/quit')
    if process.poll() is None:
        process.wait(timeout=5)
    after = hashlib.sha256(session.read_bytes()).hexdigest()
    assert before == after, 'export changed original session data'
    steps.append('Original session bytes remained unchanged through toggles and export.')
    report = {'version': version, 'command': cli, 'pty': {'rows': 44, 'columns': 160}, 'steps': steps, 'export': str(export), 'sessionSha256Before': before, 'sessionSha256After': after, 'exit': process.returncode}
    (EVIDENCE / f'pi-{version}-live-result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
finally:
    if process.poll() is None:
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()
    drain(.2)
    (EVIDENCE / f'pi-{version}-terminal.ansi').write_bytes(output)
    os.close(master)
