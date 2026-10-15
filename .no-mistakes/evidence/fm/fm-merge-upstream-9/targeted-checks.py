#!/usr/bin/env python3
"""Select existing behavioral test functions, without running unrelated suites.
Copies the real bin tree unchanged so worktree-local fixture homes can be
siblings of, rather than forbidden descendants of, the product code root.
No static source assertions are used; all selected functions execute bin CLIs.
"""
import pathlib,os,re,shutil,subprocess,concurrent.futures
root=pathlib.Path.cwd(); work=root/'.test-validation'; code=work/'code-root'
ev=pathlib.Path('/home/node/.no-mistakes/evidence/01M4ZZGKP3RXD7YF8SFH2KDVQJ')
if code.exists():shutil.rmtree(code)
shutil.copytree(root/'bin',code/'bin');shutil.copytree(root/'tests',code/'tests')
selected={
 'fm-contributions': ['test_away_yolo_cross_home_is_fleet_work','test_expired_child_unsupported_forge_stays_unmeasured','test_home_summary_coverage','test_http_500_once_retries_without_waking','test_http_500_twice_records_the_failed_read','test_http_404_is_not_retried'],
 'fm-pr-merge': ['test_forgejo_url_resolves_and_merges','test_forgejo_combined_status_reads_every_page','test_forgejo_rejected_merge_is_never_trusted_by_exit_status','test_github_mergeable_unknown_retries_then_succeeds','test_allow_red_refused_on_forgejo','test_allow_missing_refused_on_forgejo'],
 'fm-watch-triage': ['test_wedge_threshold_defers_to_a_backlog_captain_hold','test_paused_bg_job_until_timeout_rechecks_after_the_job_ends','test_exit_picker_stale_names_the_dialog','test_quoted_exit_picker_stays_ordinary_stale']
}
env=os.environ.copy()
for k in list(env):
 if (k.startswith('FM_') and k.endswith('_OVERRIDE')) or k in ['FM_HOME','TASKS_AXI_FILE','TASKS_AXI_BACKEND']:env.pop(k)
env.update(HOME=str(work/'user-home'),TMPDIR=str(work/'tmp'),XDG_CONFIG_HOME=str(work/'config'),XDG_CACHE_HOME=str(work/'cache'))
for name,names in selected.items():
 p=code/'tests'/(name+'.test.sh'); src=p.read_text()
 if name=='fm-contributions':src=src.split('\nfailures=0\n',1)[0]
 else:src='\n'.join(line for line in src.splitlines() if not re.fullmatch(r'test_[A-Za-z0-9_]+',line))+'\n'
 src+='\n'+'\n'.join('echo "$ '+n+'"; '+n+' || exit 1' for n in names)+'\n'
 p.write_text(src)
def run(name):
 p=subprocess.run(['bash',str(code/'tests'/(name+'.test.sh'))],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=160)
 text='Selected existing behavioral tests: '+', '.join(selected[name])+'\nProduct bin copy: unchanged; fixture homes outside that code root, inside gate worktree.\n'+p.stdout+'\nexit='+str(p.returncode)+'\n'
 (ev/(name+'-targeted.log')).write_text(text)
 return name,p.returncode,p.stdout[-2400:]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for result in pool.map(run,selected):print(result,flush=True)
