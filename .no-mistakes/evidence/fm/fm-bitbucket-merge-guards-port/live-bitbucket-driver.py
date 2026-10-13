#!/usr/bin/env python3
"""Disposable HTTPS API fixture; runs the unmodified public Firstmate CLIs."""
import base64
import copy
import http.server
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import threading
import urllib.parse

ROOT = Path.cwd()
os.environ.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null')
SCRATCH = ROOT / '.bitbucket-test-tmp' / 'live'
EVIDENCE = Path('/home/node/.no-mistakes/evidence/01M4SV111DPBMGY82J84GZ53QX')
SCRATCH.mkdir(parents=True, exist_ok=True)
AUTH = 'Basic ' + base64.b64encode(b'lab@example.invalid:disposable-only').decode()
CA = SCRATCH / 'api.crt'
KEY = SCRATCH / 'api.key'
subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', str(KEY), '-out', str(CA), '-days', '1', '-subj', '/CN=api.bitbucket.org', '-addext', 'subjectAltName=DNS:api.bitbucket.org'], check=True, capture_output=True)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(CA, KEY)
cases = {}
requests = []


def git(repo, *args):
    return subprocess.run(['git', '-C', str(repo), *args], check=True, text=True, capture_output=True).stdout.strip()


def make_case(name, **options):
    home = SCRATCH / name / 'home'
    repo = SCRATCH / name / 'repo'
    for d in [home/'state', home/'data', home/'config', home/'projects', SCRATCH/name/'user-home', repo]:
        d.mkdir(parents=True)
    git(repo, 'init', '-q', '-b', 'main')
    git(repo, 'config', 'user.name', 'Disposable API Fixture')
    git(repo, 'config', 'user.email', 'lab@example.invalid')
    (repo/'README.md').write_text('baseline\n')
    git(repo, 'add', 'README.md')
    git(repo, 'commit', '-qm', 'baseline')
    baseline = git(repo, 'rev-parse', 'HEAD')
    git(repo, 'update-ref', 'refs/remotes/origin/main', baseline)
    git(repo, 'checkout', '-qb', 'fm/task-x1')
    (repo/'feature.txt').write_text('disposable feature\n')
    git(repo, 'add', 'feature.txt')
    git(repo, 'commit', '-qm', 'feature')
    head = git(repo, 'rev-parse', 'HEAD')
    (repo/'feature.txt').write_text('disposable feature advanced\n')
    git(repo, 'add', 'feature.txt')
    git(repo, 'commit', '-qm', 'advanced')
    moved = git(repo, 'rev-parse', 'HEAD')
    git(repo, 'reset', '--soft', head)
    git(repo, 'restore', '--staged', 'feature.txt')
    git(repo, 'restore', 'feature.txt')
    # Publish the disposable branch to a disposable origin so the real DoD
    # gate can prove reachability even when the separate API head read fails.
    origin = SCRATCH / name / 'origin.git'
    subprocess.run(['git', 'clone', '--quiet', '--bare', str(repo), str(origin)], check=True, capture_output=True)
    git(repo, 'remote', 'add', 'origin', str(origin))
    git(repo, 'fetch', '--quiet', 'origin')
    dest = options.get('dest', 'main')
    if dest != 'main':
        git(repo, 'branch', dest, baseline)
    shutil.copyfile(ROOT/'.tasks.toml', home/'.tasks.toml')
    (home/'data'/'backlog.md').write_text('## In flight\n\n## Queued\n\n## Done\n')
    (home/'state'/'task-x1.meta').write_text(f'window=fm-task-x1\nworktree={repo}\nproject={repo}\nkind=ship\nmode=no-mistakes\n')
    alice = {'user': {'uuid': '{alice}', 'nickname': 'alice'}, 'role': 'REVIEWER', 'approved': True, 'state': 'approved'}
    bob = {'user': {'uuid': '{bob}', 'nickname': 'bob'}, 'role': 'REVIEWER', 'approved': True, 'state': 'approved'}
    pr = {'type': 'pullrequest', 'id': 7, 'state': 'OPEN', 'draft': options.get('draft', False), 'source': {'branch': {'name': 'fm/task-x1'}, 'commit': {'hash': head[:12], 'type': 'commit'}}, 'destination': {'branch': {'name': dest}, 'commit': {'hash': baseline[:12]}}, 'participants': [alice, bob], 'close_source_branch': True}
    final = copy.deepcopy(pr)
    drift = options.get('drift')
    if drift == 'destination': final['destination']['branch']['name'] = 'release'
    if drift == 'withdrawn': final['participants'][0]['approved'] = False; final['participants'][0]['state'] = None
    if drift == 'replacement': final['participants'][0]['user'] = {'uuid': '{carol}', 'nickname': 'carol'}
    if drift == 'changes': final['participants'].append({'user': {'uuid': '{carol}', 'nickname': 'carol'}, 'role': 'REVIEWER', 'approved': False, 'state': 'changes_requested'})
    if drift == 'reorder': final['participants'].reverse()
    if drift == 'malformed': final['participants'] = 'unreadable'
    if drift == 'head': final['source']['commit']['hash'] = moved[:12]
    if drift == 'closed': final['state'] = 'DECLINED'
    if options.get('nickname'):
        for record in [pr, final]:
            for participant in record['participants']:
                participant['user'].pop('uuid', None)
    case = dict(name=name, home=home, repo=repo, baseline=baseline, head=head, moved=moved, pr=pr, final=final, reads=0, merged=False, posts=[], **options)
    cases[name] = case
    return case


class API(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *args): pass

    def do_GET(self): self.dispatch()
    def do_POST(self): self.dispatch()

    def dispatch(self):
        u = urllib.parse.urlparse(self.path)
        parts = u.path.split('/')
        payload = None
        if self.command == 'POST':
            payload = json.loads(self.rfile.read(int(self.headers.get('Content-Length', '0'))))
        status = 200
        body = {'type': 'error', 'error': {'message': 'unexpected fixture route'}}
        name = parts[4] if len(parts) > 4 else ''
        case = cases.get(name)
        if self.headers.get('Authorization') != AUTH:
            status = 401
        elif case is None:
            status = 404
        elif '/pullrequests/7/merge' in u.path and self.command == 'POST':
            case['posts'].append(payload)
            strategy = payload.get('merge_strategy', 'merge_commit')
            repo = case['repo']
            dest = case['pr']['destination']['branch']['name']
            git(repo, 'checkout', '-q', dest)
            if strategy in ['squash', 'squash_fast_forward']:
                git(repo, 'merge', '--squash', 'fm/task-x1')
                git(repo, 'commit', '-qm', 'Squashed fixture PR 7')
            elif strategy == 'merge_commit' or strategy == 'rebase_merge':
                git(repo, 'merge', '--no-ff', 'fm/task-x1', '-m', 'Merged fixture PR 7')
            else:
                git(repo, 'merge', '--ff-only', 'fm/task-x1')
            case['merged'] = True
            body = {'type': 'pullrequest', 'id': 7, 'state': 'MERGED'}
        elif '/pullrequests/7' in u.path:
            if u.query != 'fields=id,state': case['reads'] += 1
            body = copy.deepcopy(case['final'] if case['reads'] >= 3 else case['pr'])
            if case['merged']: body = copy.deepcopy(case['pr']); body['state'] = 'MERGED'
        elif '/commit/' in u.path and u.path.endswith('/statuses'):
            body = {'values': [{'key': 'pipeline', 'name': 'Pipeline #1', 'state': 'SUCCESSFUL'}], 'page': 1, 'pagelen': 100}
        elif '/commit/' in u.path:
            status = case.get('commit_code', 200)
            reported = parts[-1]
            body = {'hash': case['moved'] if case['moved'].startswith(reported) else case['head']}
            if status != 200: body = {'type': 'error', 'error': {'message': 'commit lookup temporarily unavailable'}}
            if case.get('commit_malformed'): body = {'hash': 'not-a-commit'}
        elif '/refs/branches' in u.path:
            status = case.get('branch_code', 200)
            dest = case['pr']['destination']['branch']['name']
            body = {'values': [{'name': dest + '-other', 'default_merge_strategy': 'merge_commit'}, {'name': dest, 'default_merge_strategy': case.get('strategy', 'squash')}]}
            if case.get('missing_strategy'): body['values'][1].pop('default_merge_strategy')
            if case.get('wrong_branch'): body['values'] = body['values'][:1]
            if case.get('branch_malformed'): body = {'values': 'not-an-array'}
            if status != 200: body = {'type': 'error', 'error': {'message': 'branch default inaccessible'}}
        elif '/branch-restrictions' in u.path:
            body = {'values': [], 'page': 1, 'pagelen': 100}
        else: status = 404
        entry = {'scenario': name, 'method': self.command, 'path': self.path, 'request_body': payload, 'status': status, 'response': body}
        requests.append(entry)
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(data)
        self.close_connection = True


class Proxy(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_CONNECT(self):
        if self.path != 'api.bitbucket.org:443':
            self.send_error(403)
            return
        self.send_response(200, 'Connection established')
        self.end_headers()
        self.wfile.flush()
        tls = context.wrap_socket(self.connection, server_side=True)
        try: API(tls, self.client_address, self.server)
        finally: tls.close(); self.close_connection = True


server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
results = []


def run_case(name, *, check=False, args=(), expected=0, message='', product=ROOT, **options):
    case = make_case(name, **options)
    env = {k: v for k,v in os.environ.items() if not (k.startswith('FM_') or k.startswith('TASKS_AXI_') or k.startswith('NO_MISTAKES_BITBUCKET_') or k.lower() in ['http_proxy', 'https_proxy', 'all_proxy', 'no_proxy'])}
    env.update(FM_HOME=str(case['home']), HOME=str(SCRATCH/name/'user-home'), TMPDIR=str(SCRATCH), GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null', NO_MISTAKES_BITBUCKET_EMAIL='lab@example.invalid', NO_MISTAKES_BITBUCKET_API_TOKEN='disposable-only', HTTPS_PROXY=f'http://127.0.0.1:{server.server_port}', NO_PROXY='', CURL_CA_BUNDLE=str(CA), FM_PR_BITBUCKET_CONFIRM_ATTEMPTS='2', FM_PR_BITBUCKET_CONFIRM_INTERVAL='0')
    cli = 'fm-pr-check.sh' if check else 'fm-pr-merge.sh'
    url = f'https://bitbucket.org/fm-lab/{name}/pull-requests/7'
    command = [str(product/'bin'/cli), 'task-x1', url, *args]
    completed = subprocess.run(command, env=env, cwd=ROOT, text=True, capture_output=True, timeout=45)
    meta_text = (case['home']/'state'/'task-x1.meta').read_text()
    meta = dict(line.split('=',1) for line in meta_text.splitlines() if '=' in line)
    armed = (case['home']/'state'/'task-x1.check.sh').exists()
    history = git(case['repo'], 'log', '--format=%h %s', case['pr']['destination']['branch']['name'])
    tree = git(case['repo'], 'ls-tree', '--name-only', case['pr']['destination']['branch']['name'])
    errs = []
    if completed.returncode != expected: errs.append(f'exit {completed.returncode}, expected {expected}')
    if message and message not in completed.stderr: errs.append(f'refusal did not name {message!r}')
    if not check:
        if expected == 0:
            desired = options.get('strategy', 'squash')
            if args:
                desired = {'--squash':'squash','--merge':'merge_commit','--rebase':'rebase_fast_forward'}.get(args[-1], args[-1])
            if case['posts'] != [{'type':'pullrequest','close_source_branch':False,'merge_strategy':desired}]: errs.append(f'wrong merge request body: {case["posts"]}')
            if not case['merged'] or 'feature.txt' not in tree: errs.append('fixture destination did not land feature')
            if 'is merged at the verified head' not in completed.stdout: errs.append('no landed-state readback')
        else:
            if case['posts'] or case['merged']: errs.append('refused case still requested a merge')
            if git(case['repo'], 'rev-parse', case['pr']['destination']['branch']['name']) != case['baseline']: errs.append('destination changed despite refusal')
            if options.get('drift') and case['reads'] != 3: errs.append('drift did not reach final pre-merge read')
    elif options.get('draft'):
        if armed or 'pr' in meta: errs.append('draft was armed or recorded')
    else:
        if not armed or meta.get('pr') != url: errs.append('ready PR was not armed')
        if (options.get('commit_code', 200) != 200 or options.get('commit_malformed')) and 'pr_head' in meta: errs.append('unresolved head recorded')
    record = {'name':name, 'command':command, 'product':'target' if product == ROOT else 'base', 'exit_code':completed.returncode,'stdout':completed.stdout,'stderr':completed.stderr,'metadata':meta,'poll_armed':armed,'full_pr_reads':case['reads'],'merge_requests':case['posts'],'api_merged':case['merged'],'destination_history':history,'destination_tree':tree,'errors':errs,'result':'fail' if errs else 'pass'}
    results.append(record)
    print(f'{name}: {record["result"]} (exit={completed.returncode}, PR reads={case["reads"]}, merge POSTs={len(case["posts"])})', flush=True)
    return record


try:
    for strategy in ['squash', 'merge_commit', 'fast_forward', 'squash_fast_forward', 'rebase_fast_forward', 'rebase_merge']:
        run_case('default-'+strategy.replace('_','-'), strategy=strategy)
    run_case('slash-destination', dest='release/2026.06', strategy='squash')
    for name, options in [('http500',{'branch_code':500}),('http403',{'branch_code':403}),('unknown',{'strategy':'octopus'}),('missing',{'missing_strategy':True}),('wrong-branch',{'wrong_branch':True}),('malformed',{'branch_malformed':True})]:
        run_case('default-'+name, expected=1, message='merge strategy', **options)
    for flag in ['--squash','--merge','--rebase']:
        record = run_case('explicit-'+flag[2:], args=('--',flag), branch_code=503)
        if any('/refs/branches' in r['path'] for r in requests if r['scenario'] == record['name']): record['errors'].append('explicit strategy attempted default lookup'); record['result']='fail'
    run_case('explicit-method', args=('--','--method','rebase_merge'), strategy='rebase_merge', branch_code=503)
    for drift, message in [('destination','now targets release'),('withdrawn','approval withdrawn by {alice}'),('replacement','approval withdrawn by {alice}'),('changes','changes requested by {carol}'),('malformed','reviews of the pull request could not be interpreted'),('head','changed after verification'),('closed','changed after verification')]:
        run_case('final-'+drift, drift=drift, expected=1, message=message)
    run_case('final-nickname-withdrawn', drift='withdrawn', nickname=True, expected=1, message='approval withdrawn by alice')
    run_case('final-reordered-reviews', drift='reorder')
    for code in [503,404]:
        run_case('draft-lookup-'+str(code), check=True, draft=True, commit_code=code, expected=1, message='is a draft pull request')
    run_case('draft-lookup-malformed', check=True, draft=True, commit_malformed=True, expected=1, message='is a draft pull request')
    run_case('ready-lookup-503', check=True, commit_code=503)
    run_case('ready-lookup-malformed', check=True, commit_malformed=True)
    base = SCRATCH/'base'
    base.mkdir()
    with subprocess.Popen(['git','archive','3ed72cc39094de5501b60d3ac269e2291127ca89','bin','.tasks.toml'], stdout=subprocess.PIPE) as archive:
        subprocess.run(['tar','-x','-C',str(base)], stdin=archive.stdout, check=True)
        archive.stdout.close()
        if archive.wait(): raise RuntimeError('base extraction failed')
    # Deliberately retain the target expectations: these reproductions must fail.
    run_case('base-default-squash', product=base)
    run_case('base-default-unreadable', product=base, branch_code=503, expected=1, message='merge strategy')
    run_case('base-final-destination', product=base, drift='destination', expected=1, message='now targets release')
    run_case('base-final-withdrawn', product=base, drift='withdrawn', expected=1, message='approval withdrawn')
    run_case('base-final-changes', product=base, drift='changes', expected=1, message='changes requested')
    run_case('base-draft-lookup-503', product=base, check=True, draft=True, commit_code=503, expected=1, message='is a draft pull request')
finally:
    server.shutdown()
    server.server_close()
    thread.join()
    (EVIDENCE/'live-bitbucket-results.json').write_text(json.dumps(results, indent=2)+'\n')
    (EVIDENCE/'live-bitbucket-api-requests.json').write_text(json.dumps(requests, indent=2)+'\n')
    with (EVIDENCE/'live-bitbucket-transcript.md').open('w') as f:
        f.write('# Live Bitbucket CLI validation\n\nThe real public Firstmate shell scripts, real curl, real jq, real Git, and local TLS/HTTP transport were used. A disposable API fixture accepted only synthetic credentials and applied merges to disposable Git repositories. No shared Bitbucket service was accessed. Target expectations were intentionally also applied to the base commit to reproduce regressions.\n\n')
        for r in results:
            f.write(f'## {r["name"]} ({r["product"]})\n\nCommand: `{" ".join(r["command"])}`\n\nExit: {r["exit_code"]}; full PR reads: {r["full_pr_reads"]}; merge POSTs: {len(r["merge_requests"])}; poll armed: {r["poll_armed"]}.\n\n```text\n{r["stdout"]}{r["stderr"]}```\n\nMerge request body:\n```json\n{json.dumps(r["merge_requests"],indent=2)}\n```\n\nPersisted task metadata:\n```json\n{json.dumps(r["metadata"],indent=2)}\n```\n\nDestination Git history:\n```text\n{r["destination_history"]}\n```\n\nDestination tree:\n```text\n{r["destination_tree"]}\n```\n\n')
    shutil.rmtree(SCRATCH)

failed = [r['name'] for r in results if r['product']=='target' and r['result']!='pass']
base_reproduced = [r['name'] for r in results if r['product']=='base' and r['result']=='fail']
print('TARGET FAILURES:', failed)
print('BASE REGRESSIONS REPRODUCED:', base_reproduced)
if failed: raise SystemExit(1)
if len(base_reproduced) != 6: raise SystemExit(2)
