from pathlib import Path
import hashlib,json,subprocess,zipfile,plistlib
r=Path(__file__).resolve().parents[4];e=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((e/'source-hashes.json').read_text())
for f in m['files']:assert sha(r/f['path'])==f['sha256'],f['path']
old=json.loads((e/'protected-before.json').read_text());unchanged=0;pm_changes=[]
for path,digest in old.items():
 p=Path(path)
 if p.is_file() and sha(p)==digest:unchanged+=1
 elif '/docs/evidence/PM-027/' in path:pm_changes.append(path)
 else:raise AssertionError('Protected file changed: '+path)
# PM independently renamed/superseded its evidence during this task. Its actual signed App must remain intact.
pm=json.loads((r/'docs/evidence/PM-027/pre-c029-final-signature.json').read_text())
assert sha(Path(pm['app'])/'Contents/MacOS/TypingPianoProbe')==pm['binarySHA256']
b=Path.home()/'Library/Caches/local.typingpiano.trial/candidate-0.2.7';app=b/'打字钢琴试用.app';binary=app/'Contents/MacOS/TypingPianoProbe';zpath=b/'打字钢琴试用.zip'
subprocess.run(['codesign','--verify','--strict',str(app)],check=True,capture_output=True)
with (app/'Contents/Info.plist').open('rb') as f:info=plistlib.load(f)
assert info['CFBundleVersion']=='10' and info['CFBundleShortVersionString']=='0.2.7'
with zipfile.ZipFile(zpath) as z:
 assert z.testzip() is None
 names=[s for s in z.namelist() if s.endswith('/Contents/MacOS/TypingPianoProbe')];assert len(names)==1
 assert hashlib.sha256(z.read(names[0])).hexdigest()==sha(binary)
window=json.loads((e/'window-smoke-accessory.json').read_text());assert window['passed'] and window['activationPolicy']==1
assert window['windowLevel']==3 and window['frontmostPIDUnchanged'] and window['belowModalWindow']
assert len(window['samples'])==3 and all(x['passed'] for x in window['samples'])
assert window['samples'][0]['frontNormalWindowID']==window['samples'][1]['backNormalWindowID']==window['samples'][2]['frontNormalWindowID']
assert 'Executed 131 tests, with 3 tests skipped and 0 failures' in (e/'full-tests-accessory.log').read_text()
assert json.loads((e/'menu-smoke.json').read_text())['passed']
assert json.loads((e/'self-check.json').read_text())['mappingVersion']=='ansi64-playable.0.2'
d={'task':'C-029','version':'0.2.7','build':10,'app':str(app),'zip':str(zpath),'binarySHA256':sha(binary),'zipSHA256':sha(zpath),'sourceManifestSHA256':sha(e/'source-hashes.json'),'architecture':subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip(),'signing':'ad-hoc; final development signing and installation belong to PM','fullSuite':{'selected':131,'passed':128,'skipped':3,'failures':0},'candidateBankTestsRerunThisTask':False,'sourceFilesVerified':len(m['files']),'strictSignaturePassed':True,'zipCRCAndBinaryPassed':True,'windowStackPassed':True,'activationPolicy':'accessory','protectedFilesUnchanged':unchanged,'pmEvidenceIndependentlyUpdatedOrRenamed':pm_changes,'installedAppUntouched':True,'pmSignedAppUnchanged':True,'realTCCDialogTested':False,'installedCrossApplicationTested':False}
(e/'delivery.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(json.dumps(d,ensure_ascii=False))
