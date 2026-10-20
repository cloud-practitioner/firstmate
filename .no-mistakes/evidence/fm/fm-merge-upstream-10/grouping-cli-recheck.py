#!/usr/bin/env python3
import pathlib,os,subprocess,json,shutil,tomllib,tempfile
r=pathlib.Path.cwd();ev=pathlib.Path('/home/node/.no-mistakes/evidence/01M5CS8Z14AJ6WRYGCEP0JMSHD');lab=pathlib.Path(tempfile.mkdtemp(prefix='fm-groups-check-'));home=lab/'home'
env={k:v for k,v in os.environ.items() if not k.startswith(('FM_','HERDR_','TASKS_AXI_'))};env['FM_HOME']=str(home)
log=(ev/'grouping-cli-recheck.log').open('w')
def run(args,expect=0):
 p=subprocess.run([str(a) for a in args],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
 log.write('$ '+' '.join(map(str,args))+'\n'+p.stdout+f'[exit {p.returncode}]\n');log.flush();assert p.returncode==expect,p.stdout;return p.stdout
try:
 run(['bin/fm-lab-home.sh','create',home])
 for i,project,state in [('urgent-1','alpha','needs-decision'),('build-1','alpha','blocked'),('other-1','beta','done')]:
  (home/'state'/f'{i}.meta').write_text(f'kind=ship\nbackend=herdr\nproject={lab/project}\nherdr_session=fm-lab-offline-plan-only\nherdr_workspace_id=workspace-{i}\nherdr_pane_id=pane-{i}\n')
  (home/'state'/f'{i}.status').write_text(state+': disposable task input\n')
 assert run(['bin/fm-herdr-groups.sh','plan'])==''
 (home/'config/herdr-project-groups').write_text('fallback *\nalpha-group repo:alpha\nurgent task:urgent\n')
 plan=run(['bin/fm-herdr-groups.sh','plan'])
 rows={row.split('\t')[0]:row.split('\t') for row in plan.splitlines()}
 assert rows['urgent-1'][1:3]==['urgent','needs-captain'],rows
 assert rows['build-1'][1:3]==['alpha-group','problem'],rows
 assert rows['other-1'][1:3]==['fallback','done'],rows
 assert run(['bin/fm-herdr-groups.sh','order-key','urgent-1',lab/'alpha']).strip()=='003.urgent'
 sidebar=lab/'herdr.toml';sidebar.write_text('[ui]\ntheme = "dark"\n')
 before=sidebar.read_bytes();run(['bin/fm-herdr-groups.sh','sidebar-config','--apply',sidebar])
 config=tomllib.loads(sidebar.read_text());assert config['ui']['theme']=='dark'
 assert config['ui']['sidebar']['spaces']['rows'][1]==[{'token':'$fm_group','bold':True},'$fm_state']
 assert config['ui']['sidebar']['agents']['rows'][0]==['state_icon',{'token':'$fm_group','bold':True},'$fm_state','$fm_task']
 backups=list(lab.glob('herdr.toml.bak-*'));assert len(backups)==1 and backups[0].read_bytes()==before
 saved=sidebar.read_bytes();run(['bin/fm-herdr-groups.sh','sidebar-config','--apply',sidebar],1);assert sidebar.read_bytes()==saved
 (ev/'generated-sidebar-recheck.toml').write_bytes(saved)
 (ev/'grouping-plan-recheck.tsv').write_text(plan)
 log.write('Effective TOML fields parsed successfully; original theme preserved; second apply refused without mutation. This is the public offline planning/configuration surface, NOT proof of Herdr rendering or live sync.\n')
finally:
 log.close();shutil.rmtree(lab)
