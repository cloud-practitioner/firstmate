import pathlib, shutil, subprocess
root=pathlib.Path.cwd(); base=root/'.test-rearm/base-root'
shutil.copytree(root/'bin',base/'bin',dirs_exist_ok=True)
shutil.copytree(root/'.pi/extensions',base/'.pi/extensions',dirs_exist_ok=True)
for name in ['bin/fm-procevent.sh','.pi/extensions/fm-primary-pi-watch.ts']:
 (base/name).write_bytes(subprocess.check_output(['git','show','bcfc00fea6ef9c88d4695816738555fecc0d757d:'+name]))
s=(root/'.test-rearm/live.py').read_text()
s=s.replace("EV=pathlib.Path('/home/node/.no-mistakes/evidence/01M5XNA6EXS99GEKKQTBA3Q4G9')", "EV=pathlib.Path('/home/node/.no-mistakes/evidence/01M5XNA6EXS99GEKKQTBA3Q4G9/baseline'); EV.mkdir(exist_ok=True)")
s=s.replace("ROOT/'bin/fm-procevent.sh'", "ROOT/'.test-rearm/base-root/bin/fm-procevent.sh'")
s=s.replace("ROOT/'.pi/extensions/fm-primary-pi-watch.ts'", "ROOT/'.test-rearm/base-root/.pi/extensions/fm-primary-pi-watch.ts'")
s=s.replace("ROOT/'bin/fm-watch-arm.sh'", "ROOT/'.test-rearm/base-root/bin/fm-watch-arm.sh'")
(root/'.test-rearm/live-baseline.py').write_text(s)
p=subprocess.run(['python3',str(root/'.test-rearm/live-baseline.py')])
assert p.returncode!=0,'expected baseline to reproduce queued copy failure'
print('Baseline live reproducer failed as expected; inspect baseline/error-queue.tsv, pi-error.txt, and live-transcript.log.')
# Execute exactly the new coalescing regression with the old extension.
s=(root/'tests/.rearm-pi-focused.test.sh').read_text(); s=s.split('\ntest_pi_identical_unconsumed_wakes_are_coalesced\n')[0]
s+='\nEXT="$ROOT/.test-rearm/base-root/.pi/extensions/fm-primary-pi-watch.ts"\ntest_pi_identical_unconsumed_wakes_are_coalesced\n'
(root/'tests/.rearm-pi-baseline.test.sh').write_text(s)
