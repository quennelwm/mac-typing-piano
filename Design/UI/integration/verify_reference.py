"""Validate derived expectations independently against the frozen delivery; no native-pass claims."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]; UI=ROOT/'Design/UI'; I=UI/'integration'; E=ROOT/'docs/evidence/U-001B'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def close(a,b):return abs(a-b)<1e-8
r=read(I/'reference.json');t=read(UI/'theme.candidate.json'); original=read(UI/'qa/layouts.json');m=read(UI/'delivery-manifest.json')
for f in m['files']:
 p=UI/f['path'];assert sha(p)==f['sha256'] and p.stat().st_size==f['byteSize']
for source in r['sources']:assert sha(ROOT/source['path'])==source['sha256']
count=0
for layout,old in zip(r['layouts'],original['layouts']):
 assert layout['widthPt']==old['widthPt'];assert len(layout['keys'])==64
 assert sum(k['color']=='white' for k in layout['keys'])==38
 for k,o in zip(layout['keys'],old['keys']):
  assert k['physicalKeyID']==o['physicalKeyID'] and k['midiNote']==o['midiNote']
  assert k['restRectPt']==o['rectPt'] and k['labelParts']==o['labelParts']
  black=k['color']=='black';dy=1.5 if black else 2
  assert k['heldRectPt']==[o['rectPt'][0],o['rectPt'][1]+dy,*o['rectPt'][2:]]
  assert k['labelColorHex']==t['labels']['blackColorHex' if black else 'whiteColorHex']
  assert len(k['labels'])==len(o['labels'])
  for a,b in zip(k['labels'],o['labels']):
   assert a['text']==b['text'] and a['restInkBoundsPt']==b['inkBoundsPt']
   assert a['restTextOriginPt']==[b['x'],b['baselineY']]
   assert a['heldTextOriginPt']==[b['x'],b['baselineY']+dy]
   assert a['fontSizePt']==b['fontSizePt'] and not a['fontNamesAreRuntimeRequirement']
  x,y,w,h=k['restRectPt'];assert k['floatingAnchorPt']==[x+w/2,y-4]
  main=k['labels'][0]['restInkBoundsPt'];assert close(y+h-main[1]-main[3],3 if black else 4)
  if len(k['labels'])==2:
   side=k['labels'][1]['restInkBoundsPt'];assert close(side[1]+side[3],main[1]+(-.6 if black else 2))
  count+=1
 assert next(k for k in layout['keys'] if k['physicalKeyID']=='fn')['midiNote']==34
assert r['floatingFrames'][2]['risePt']==21 and r['floatingFrames'][2]['opacity']==.875
assert not r['floatingFrames'][-1]['present'] and not r['floatingFrames'][2]['reducedPresent']
assert r['coordinateSystem']['canvasHeight']==104
for img in r['referenceImages']:assert sha(ROOT/img['path'])==img['sha256']
p=read(I/'theme-field-policy.json')
def leaves(o,path=''):
 if isinstance(o,dict):
  for k,v in o.items():yield from leaves(v,path+'/'+k)
 elif isinstance(o,list):
  for i,v in enumerate(o):yield from leaves(v,path+'/'+str(i))
 else:yield path,o
expected=dict(leaves(t));actual={f['jsonPointer']:f['value'] for f in p['fields']}
assert expected==actual and len(actual)==len(p['fields'])==372
assert all(f['classification'] and f['handling'] for f in p['fields'])
accept=read(I/'visual-acceptance.json');request=read(I/'capture-request.json')
assert all(c['status']=='awaiting' and c['actualEvidence'] is None for c in accept['criteria'])
assert len(request['scenes'])==18 and request['status']=='awaiting'
files=[{'path':str(f.relative_to(ROOT)),'sha256':sha(f),'byteSize':f.stat().st_size} for f in sorted(I.iterdir()) if f.is_file()]
report={'status':'pass','verifiedFrozenFiles':len(m['files']),'keysCompared':count,'widths':[900,1000,1100],'themeLeafFieldsCompared':len(actual),'referenceImageHashes':18,'visualCriteria':len(accept['criteria']),'nativeReviewStatus':'awaiting_PM_forwarded_C-001C_snapshots','scope':'Reference derivation/provenance verified; no native runtime measurement performed.','integrationFiles':files}
(E/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='integrationFiles'},ensure_ascii=False))
