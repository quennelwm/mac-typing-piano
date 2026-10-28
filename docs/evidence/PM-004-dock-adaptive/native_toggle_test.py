import subprocess,json,time
from pathlib import Path
root=Path('/Users/wuming/Desktop/键盘钢琴')
def read(): return subprocess.check_output(['/usr/bin/defaults','read','com.apple.dock','autohide'],text=True).strip()
def snap(label):
 r=json.loads(subprocess.check_output(['/usr/bin/swift',str(root/'docs/evidence/PM-004-dock-adaptive/dock_windows.swift')],text=True))
 return {'label':label,'preference':read(),'snapshot':r}
original=read()
assert original=='1', 'Do not run when user preference has changed'
rows=[snap('before-enabled')]
try:
 subprocess.run(['/usr/bin/defaults','write','com.apple.dock','autohide','-bool','false'],check=True)
 time.sleep(1)
 rows.append(snap('disabled-after-one-second'))
finally:
 subprocess.run(['/usr/bin/defaults','write','com.apple.dock','autohide','-bool','true'],check=True)
 time.sleep(1)
 rows.append(snap('restored-enabled-after-one-second'))
 (root/'docs/evidence/PM-004-dock-adaptive/native-toggle-test.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(rows,ensure_ascii=False,indent=2))
