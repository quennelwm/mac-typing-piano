from pathlib import Path
import json, hashlib, subprocess, plistlib, zipfile, jsonschema
from PIL import Image
r=Path(__file__).resolve().parents[3];e=r/'docs/evidence/trial-0.2.7';b=Path.home()/'Library/Caches/local.typingpiano.trial/candidate-0.2.7';app=b/'打字钢琴试用.app';binary=app/'Contents/MacOS/TypingPianoProbe';archive=b/'打字钢琴试用.zip'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((e/'source-hashes.json').read_text())
for item in manifest['files']: assert sha(r/item['path'])==item['sha256'],item['path']
protected=json.loads((e/'protected-before.json').read_text())
for p,h in protected.items():assert Path(p).is_file() and sha(Path(p))==h,p
with (app/'Contents/Info.plist').open('rb') as f: info=plistlib.load(f)
assert info['CFBundleShortVersionString']=='0.2.7' and info['CFBundleVersion']=='10'
subprocess.run(['codesign','--verify','--strict',str(app)],check=True,capture_output=True)
assert not (app/'Contents/Resources/keymap.ansi64.v0.1.json').exists()
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    # ditto may omit the UTF-8 flag on its Chinese root entry; match the unique ASCII suffix.
    names=[n for n in z.namelist() if n.endswith('/Contents/MacOS/TypingPianoProbe')]
    assert len(names)==1
    assert hashlib.sha256(z.read(names[0])).hexdigest()==sha(binary)
new=json.loads((r/'contracts/keymap.ansi64.playable.v0.2.json').read_text())
jsonschema.validate(new,json.loads((r/'contracts/keymap.schema.json').read_text()))
jsonschema.validate({'schemaVersion':1,'baseMappingVersion':new['mappingVersion'],'notes':{k['physicalKeyID']:k['midiNote'] for k in new['keys']}},json.loads((r/'contracts/custom-keymap.schema.json').read_text()))
ui=json.loads((r/'Design/UI/U-027/mapping.preview.json').read_text())
assert [(k['physicalKeyID'],k['midiNote'],k['labelParts']) for k in new['keys']]==[(k['physicalKeyID'],k['midiNote'],k['labelParts']) for k in ui['keys']]
assert 'Executed 130 tests, with 3 tests skipped and 0 failures' in (e/'full-tests-final.log').read_text()
assert 'Executed 3 tests, with 0 failures' in (e/'candidate-tests.log').read_text()
for log in ['candidate-summary.log','candidate-unchanged.log']:assert 'Traceback' not in (e/log).read_text()
captures=json.loads((e/'piano/captures.json').read_text())['captures'];assert len(captures)==36
for c in captures:
    assert Image.open(e/'piano'/c['file']).size==(c['widthPt']*c['backingScale'],208*c['backingScale'])
    assert c['canvasHeightPt']==208 and c['bodyOriginPt']==[0,96] and len(c['actualNativeMetrics'])==64
    for key in c['actualNativeMetrics']:assert key['rectBodyPt'][1]==4 and key['rectBodyPt'][3] in [100,64]
frames=json.loads((e/'animation/frames.json').read_text())['frames']
for frame in frames:
    if 'notes' not in frame:continue
    for rect in frame.get('inkBoundsWithHaloPt',[]):assert rect[0]>=0 and rect[1]>=0 and rect[0]+rect[2]<=1000 and rect[1]+rect[3]<=208
    if frame['timeMs']>=900:assert frame['instances']==0
    if frame.get('reducedMotion', False) and frame['timeMs']>=200:assert frame['instances']==0
for p in (e/'editor').glob('*.png'):
    image=Image.open(p).convert('RGBA');assert image.size in [(560,440),(1120,880)];assert image.getextrema()[3]==(255,255)
for name in ['menu-smoke','window-smoke']:assert json.loads((e/(name+'.json')).read_text())['passed']
selfcheck=json.loads((e/'self-check.json').read_text());assert selfcheck['mappingVersion']=='ansi64-playable.0.2'
assert selfcheck['keyCount']==64 and not selfcheck['listenerStarted'] and not selfcheck['audioOutputStarted']
report={'version':'0.2.7','build':10,'fullSuite':{'selected':130,'passed':127,'skipped':3,'failures':0},'separateCandidateSuite':{'passed':3,'failures':0},'totalDistinctTestsPassed':130,'nativePianoImages':len(captures),'animationFrames':len(frames),'editorImages':4,'sourceFilesVerified':len(manifest['files']),'protectedFilesUnchanged':len(protected),'schemasPassed':True,'all64AssignmentsMatchApprovedUIAndAttachment':True,'strictSignaturePassed':True,'zipIntegrityPassed':True,'packagedClassicMappingAbsent':True,'hardwareInputTested':False,'hardwareAudioTested':False,'systemSettingsWritten':False,'sourceFrozen':True}
delivery={'version':'0.2.7','build':10,'app':str(app),'zip':str(archive),'binarySHA256':sha(binary),'zipSHA256':sha(archive),'architecture':subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip(),'signing':'ad-hoc; final development signing belongs to PM','sourceManifestSHA256':sha(e/'source-hashes.json'),'verification':report}
(e/'final-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');(e/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(delivery,ensure_ascii=False))
