from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
from io import BytesIO
import json,hashlib,zipfile
from PIL import Image,ImageChops,ImageStat
ROOT=Path(__file__).resolve().parents[4]; OUT=Path(__file__).resolve().parent; BASE=ROOT/'docs/evidence/C-001C'
archive=OUT/'reviewed-evidence.zip'
sha=lambda b:hashlib.sha256(b).hexdigest()
if archive.exists():
 with zipfile.ZipFile(archive) as z:data={name:z.read(name) for name in z.namelist()}
 prior=OUT/'comparison.json'
 start=json.loads(prior.read_text())['reviewTimeAsiaShanghai'] if prior.exists() else datetime.now(ZoneInfo('Asia/Shanghai')).isoformat()
else:
 paths=[BASE/'snapshot-ready.md',*sorted((BASE/'native-snapshots').glob('*')),*sorted((BASE/'animation-frames').glob('*'))]
 data={str(p.relative_to(ROOT)):p.read_bytes() for p in paths if p.is_file()}
 start=datetime.now(ZoneInfo('Asia/Shanghai')).isoformat()
 with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as z:
  for p,b in data.items():z.writestr(p,b)
def j(name):return json.loads(data['docs/evidence/C-001C/'+name])
c=j('native-snapshots/captures.json'); a=j('animation-frames/frames.json'); ref=json.loads((ROOT/'Design/UI/integration/reference.json').read_text())
issues=[];rows=[];measure=[]
for capture in c['captures']:
 w=capture['widthPt'];s=capture['backingScale'];scene=capture['scenario'];labels=capture['showLabels'];layout=next(l for l in ref['layouts'] if l['widthPt']==w);expected={k['midiNote']:k for k in layout['keys']};actual=capture['actualNativeMetrics'];pressed=set(capture['pressedPhysicalIDs'])
 if len(actual)!=64 or {m['midi'] for m in actual}!=set(range(33,97)):issues.append({'file':capture['file'],'error':'key count/set'})
 if pressed!=set(ref['scenarios'][scene]):issues.append({'file':capture['file'],'error':'scenario mismatch'})
 delta=0
 for m in actual:
  e=expected[m['midi']];down=e['physicalKeyID'] in pressed
  # Metrics are measured native drawing coordinates; compare held-state expectation too.
  er=e['heldRectPt' if down else 'restRectPt'];delta=max(delta,*[abs(x-y) for x,y in zip(m['rectBodyPt'],er)])
  for n,l in enumerate(m['labels']):
   el=e['labels'][n];ep=el['heldInkBoundsPt' if down else 'restInkBoundsPt'];delta=max(delta,*[abs(x-y) for x,y in zip(l['inkBodyPt'],ep)])
   if l['missingGlyphs']:issues.append({'file':capture['file'],'midi':m['midi'],'error':'missing glyph'})
 suffix='' if labels else '-labels-off'
 rp=ROOT/f'Design/UI/previews/piano-{w}-{scene}{suffix}@{s}x.png';ip='docs/evidence/C-001C/native-snapshots/'+capture['file']
 im=Image.open(BytesIO(data[ip])).convert('RGBA');ri=Image.open(rp).convert('RGBA')
 if im.size!=(w*s,104*s):issues.append({'file':capture['file'],'error':'canvas size'})
 diff=ImageChops.difference(im.crop((0,48*s,w*s,104*s)),ri); stats=ImageStat.Stat(diff)
 rows.append({'file':capture['file'],'sha256':sha(data[ip]),'width':w,'scale':s,'scenario':scene,'labels':labels,'bodyExactPixelMatch':diff.getbbox(alpha_only=False) is None,'bodyMeanAbsoluteErrorRGBA':stats.mean,'maximumMetricDifferencePt':delta,'metricCoordinateInterpretation':'base/rest local geometry; pressed transform is applied by rendering and is proven by exact PNG comparison','top48AlphaBBox':im.getchannel('A').crop((0,0,w*s,48*s)).getbbox()})
frames=a['frames'];regular=[f for f in frames if 'reducedMotion' in f and 'labels' in f and 'timeMs' in f and 'notes' in f]
maxRise=maxOpacity=0
for f in regular:
 duration=200 if f['reducedMotion'] else 700;t=f['timeMs'];n=f['instances']
 if t>=duration and n:issues.append({'error':'expired notes remain','timeMs':t,'reduced':f['reducedMotion']})
 for note in f['notes']:
  rise=0 if f['reducedMotion'] else 24*(1-(1-t/700)**3)
  opacity=max(0,1-t/200) if f['reducedMotion'] else min(1,t/60,(700-t)/400)
  maxRise=max(maxRise,abs(note['rise']-rise));maxOpacity=max(maxOpacity,abs(note['opacity']-opacity))
# Preserve live-update detection rather than treating changing output as one immutable build.
changed=[p for p,b in data.items() if not (ROOT/p).exists() or sha((ROOT/p).read_bytes())!=sha(b)]
result={'reviewTimeAsiaShanghai':start,'kind':c['kind'],'build':c['integrationBuild'],'executableSHA256':c['executableSHA256'],'themeSHA256':c['themeSHA256'],'mappingSHA256':c['mappingSHA256'],'capturesManifestSHA256':sha(data['docs/evidence/C-001C/native-snapshots/captures.json']),'animationManifestSHA256':sha(data['docs/evidence/C-001C/animation-frames/frames.json']),'reviewedArchiveSHA256':sha((OUT/'reviewed-evidence.zip').read_bytes()),'changedDuringReview':changed,'sourceFiles':[{'path':p,'sha256':sha(b),'byteSize':len(b)} for p,b in data.items()],'captures':rows,'animation':{'records':len(frames),'regularRecords':len(regular),'maxRiseDifferencePt':maxRise,'maxOpacityDifference':maxOpacity},'detectedIssues':issues,'scope':'Native offscreen render/diagnostic review only; no startup/hardware input/pointer/audio/Dock acceptance.'}
(OUT/'comparison.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'captures':len(rows),'exactBodyMatches':sum(r['bodyExactPixelMatch'] for r in rows),'maxMetricDelta':max(r['maximumMetricDifferencePt'] for r in rows),'animation':result['animation'],'issues':issues[:8],'changed':changed,'frameExtraShapes':[list(f) for f in frames if f not in regular][:3]},ensure_ascii=False))
