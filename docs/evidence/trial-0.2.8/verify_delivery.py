from pathlib import Path
import hashlib,json,subprocess,zipfile,plistlib,math,re
from PIL import Image
r=Path(__file__).resolve().parents[3];e=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((e/'source-hashes.json').read_text())
for item in manifest['files']:assert sha(r/item['path'])==item['sha256'],item['path']
protected=json.loads((e/'protected-before.json').read_text())
for path,digest in protected.items():assert Path(path).is_file() and sha(Path(path))==digest,path
report=json.loads((e/'native/report.json').read_text());assert report['passed'] and len(report['images'])==7 and len(list((e/'native').glob('*.png')))==7
assert len(report['layouts'])==9 and len(report['motion'])==72
for row in report['layouts']:
 assert row['keyCount']==64 and row['allLabelsInsideNoOverlapNoMissingGlyphs']
 assert row['canvasHeightPt']==144+112*row['heightScale']
 for sample in row['faceAlpha']:
  if sample['reducedTransparency']:assert sample['minAlpha']==sample['maxAlpha']==1
  else:
   # Labels remain enabled in this report; at 50% white-key sample points can intersect faint text.
   assert 0.75<sample['minAlpha']<=sample['maxAlpha']<1
   if sample['black']:assert sample['maxAlpha']<0.94
for frame in report['motion']:
 assert frame['allInkAndHaloInsideCanvas']
 if frame['timeMs']>=950 or (frame['reducedMotion'] and frame['timeMs']>=200):assert frame['instances']==0
for item in report['images']:
 image=Image.open(e/'native'/item['file']).convert('RGBA');assert image.size==(2528,math.ceil(item['canvasHeightPt']*2))
 if item['syntheticBackground']=='transparent':assert image.getextrema()[3][0]==0
b=Path.home()/'Library/Caches/local.typingpiano.trial/candidate-0.2.8';app=b/'打字钢琴试用.app';binary=app/'Contents/MacOS/TypingPianoProbe';archive=b/'打字钢琴试用.zip'
with (app/'Contents/Info.plist').open('rb') as f:info=plistlib.load(f)
assert info['CFBundleVersion']=='11' and info['CFBundleShortVersionString']=='0.2.8' and info['CFBundleIdentifier']=='local.typingpiano.trial'
subprocess.run(['codesign','--verify','--strict',str(app)],check=True,capture_output=True)
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 names=[n for n in z.namelist() if n.endswith('/Contents/MacOS/TypingPianoProbe')];assert len(names)==1
 assert hashlib.sha256(z.read(names[0])).hexdigest()==sha(binary)
selfcheck=json.loads((e/'self-check.json').read_text());assert selfcheck['mappingVersion']=='ansi64-playable.0.2'
assert not selfcheck['listenerStarted'] and not selfcheck['audioOutputStarted']
assert json.loads((e/'menu-smoke.json').read_text())['passed']
assert 'Executed 141 tests, with 3 tests skipped and 0 failures' in (e/'full-tests-release-source.log').read_text()
assert sha(app/'Contents/Resources/crystal-reference.json')==sha(r/'Design/UI/U-031/reference.json')
for p in (app/'Contents/Resources/AudioTrial').rglob('*'):
 if p.is_file():
  relative=p.relative_to(app/'Contents/Resources')
  old=Path.home()/'Library/Caches/local.typingpiano.trial/打字钢琴试用.app/Contents/Resources'/relative
  assert old.exists() and sha(p)==sha(old),str(relative)
result={'task':'C-031','version':'0.2.8','build':11,'app':str(app),'zip':str(archive),'binarySHA256':sha(binary),'zipSHA256':sha(archive),'sourceManifestSHA256':sha(e/'source-hashes.json'),'architecture':subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip(),'signing':'ad-hoc candidate, never GUI-started; final fixed identity signing belongs to PM','fullSuite':{'selected':141,'passed':138,'skipped':3,'failures':0},'conditionalAudioReplay':'3 explicitly skipped, not rerun in C-031','sourceFilesVerified':len(manifest['files']),'protectedFilesUnchanged':len(protected),'strictSignaturePassed':True,'zipIntegrityPassed':True,'nativeImages':7,'layouts':9,'motionSamples':72,'alphaAndBoundsPassed':True,'audioResourcesMatchInstalled027':True,'realDesktopAndSliderAcceptance':'NOT TESTED','hardwareInputAudio':'NOT TESTED','newTCCRetention':'NOT TESTED','systemSettingsWritten':False}
(e/'delivery.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False))
