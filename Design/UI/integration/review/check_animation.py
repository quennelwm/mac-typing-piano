from pathlib import Path
from io import BytesIO
import json,zipfile,hashlib
from PIL import Image,ImageChops
P=Path(__file__).resolve().parent; z=zipfile.ZipFile(P/'reviewed-evidence.zip');base='docs/evidence/C-001C/animation-frames/'
a=json.loads(z.read(base+'frames.json')); tests=[]
def im(name):return Image.open(BytesIO(z.read(base+name))).convert('RGBA')
regular=[f for f in a['frames'] if 'reducedMotion' in f]; edges=[];pairs=0
for f in regular:
 name=f"native-reduced-{str(f['reducedMotion']).lower()}-labels-{str(f['labels']).lower()}-{f['timeMs']}ms.png"
 image=im(name);alpha=image.getchannel('A');head=alpha.crop((0,0,2000,96));box=head.getbbox()
 assert image.size==(2000,208)
 if box:
  assert box[0]>0 and box[1]>0 and box[2]<2000 and box[3]<96
 if f['timeMs']>=(200 if f['reducedMotion'] else 700):assert box is None and f['instances']==0
 edges.append({'file':name,'headroomAlphaBoundsPx':box})
 if f['labels']:
  other=im(name.replace('labels-true','labels-false'))
  assert ImageChops.difference(image.crop((0,0,2000,96)),other.crop((0,0,2000,96))).getbbox(alpha_only=False) is None
  pairs+=1
for reduced in [False,True]:
 for labels in [False,True]:
  records=[f for f in regular if f['reducedMotion']==reduced and f['labels']==labels]
  for f in records:assert f['instances']==(5 if f['timeMs']<(200 if reduced else 700) else 0)
extra=[f for f in a['frames'] if 'scenario'in f]
for scenario in ['short-tap','restrike']:
 rows={f['timeMs']:f for f in extra if f['scenario']==scenario}
 if scenario=='short-tap':assert rows[20]['depression']>0 and rows[45]['depression']==1 and rows[180]['depression']==0 and rows[700]['instances']==0
 else:assert rows[80]['instances']==2 and rows[100]['depression']>rows[80]['depression'] and rows[700]['instances']==1 and rows[780]['instances']==0
 # Files exist and dimensions agree; actual pointer/real timer not tested.
 for f in rows.values():assert im(f['file']).size==(2000,208)
result={'status':'pass','regularFrames':len(regular),'labelOnOffEffectPairs':pairs,'extraShortTapRestrikeFrames':len(extra),'headroomBounds':edges,'scope':'Synthetic production-render frames and diagnostics. Does not verify wall-clock paint scheduling, startup first event, hidden-event cleanup or hardware input.'}
(P/'animation-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in result.items() if k!='headroomBounds'})
