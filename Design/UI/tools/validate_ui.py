#!/usr/bin/env python3
"""Meaningful artifact checks: mapping, geometry, fonts, contrast, alpha, lifecycle evidence and hashes."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import math
import xml.etree.ElementTree as ET
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
UI=ROOT/'Design/UI'
layout_data=json.loads((UI/'qa/layouts.json').read_text())
keymap=json.loads((ROOT/'contracts/keymap.ansi64.v0.1.json').read_text())
theme=json.loads((UI/'theme.candidate.json').read_text())
checks=[]
def check(name,condition,detail=None):
    checks.append({'name':name,'status':'pass' if condition else 'fail','detail':detail})

def lum(rgb):
    linear=[v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb[:3]]
    return sum(a*b for a,b in zip(linear,[.2126,.7152,.0722]))
def ratio(a,b):
    x,y=sorted([lum(a),lum(b)])
    return (y+.05)/(x+.05)

def intersects(a,b):
    return a[0]<b[0]+b[2] and a[0]+a[2]>b[0] and a[1]<b[1]+b[3] and a[1]+a[3]>b[1]

check('canonical MIDI sequence', sorted(k['midiNote'] for k in keymap['keys'])==list(range(33,97)))
check('mapping source hash',theme['sourceMapping']['sha256']==hashlib.sha256((ROOT/'contracts/keymap.ansi64.v0.1.json').read_bytes()).hexdigest())
expected={k['physicalKeyID']:k for k in keymap['keys']}
contrast_records=[]
occlusions=[]
for layout in layout_data['layouts']:
    width=layout['widthPt'];keys=layout['keys'];slot=(width-4)/38
    check(f'{width}: 38 white, 26 black, 64 unique keys',Counter(k['color'] for k in keys)=={'white':38,'black':26} and len({k['physicalKeyID'] for k in keys})==64)
    runs=[];run=0;white_count=0
    for k in keys:
        midi=k['midiNote'];is_black=midi%12 in {1,3,6,8,10}
        check(f'{width}/{midi}: mapping/color/label',k['color']==('black' if is_black else 'white') and k['labelParts']==expected[k['physicalKeyID']]['labelParts'])
        if is_black:
            check(f'{width}/{midi}: black centered over neighboring white boundary',abs(k['rectPt'][0]+k['rectPt'][2]/2-(2+white_count*slot))<1e-7)
        else:white_count+=1
    black_midis=[k['midiNote'] for k in keys if k['color']=='black']
    for midi in black_midis:
        if run and midi-last!=2:runs.append(run);run=0
        run+=1;last=midi
    runs.append(run)
    check(f'{width}: real black grouping',runs==[1,2,3,2,3,2,3,2,3,2,3],runs)
    for state in ['rest','single','multi']:
        for scale in [1,2]:
            p=UI/f'previews/piano-{width}-{state}@{scale}x.png'
            im=Image.open(p)
            check(f'{p.name}: size/alpha',im.size==(width*scale,56*scale) and 'A' in im.getbands() and im.getchannel('A').getextrema()[0]<255)
    for wd in [0,1]:
        for bd in [0,1]:
            for scale in [1,2]:
                surface=Image.open(UI/f'qa/surface-{width}-{wd}-{bd}@{scale}x.png').convert('RGBA')
                for k in keys:
                    down=bd if k['color']=='black' else wd
                    dy=down*(1.5 if k['color']=='black' else 2)
                    for label in k['labels']:
                        x,y,w,h=label['inkBoundsPt']; y+=dy
                        fg=tuple(int(theme['labels'][('black' if k['color']=='black' else 'white')+'ColorHex'][i:i+2],16) for i in [1,3,5])
                        pixels=[surface.getpixel((px,py)) for py in range(math.floor(y*scale),math.ceil((y+h)*scale)) for px in range(math.floor(x*scale),math.ceil((x+w)*scale))]
                        r=min(ratio(fg,p) for p in pixels)
                        contrast_records.append({'widthPt':width,'whiteDown':bool(wd),'blackDown':bool(bd),'scale':scale,'physicalKeyID':k['physicalKeyID'],'label':label['text'],'ratio':r})
                    if k['color']=='white':
                        for label in k['labels']:
                            box=list(label['inkBoundsPt']);box[1]+=dy
                            for other in keys:
                                if other['color']!='black':continue
                                r=list(other['rectPt']);r[1]+=bd*1.5
                                if intersects(box,r):occlusions.append({'width':width,'whiteDown':wd,'blackDown':bd,'label':k['physicalKeyID'],'black':other['physicalKeyID']})
minimum=min(contrast_records,key=lambda r:r['ratio'])
check('actual background pixels under every native glyph ink box: 4.5 target',minimum['ratio']>=4.5,minimum)
check('no white label covered by neighboring black face in all held combinations',not occlusions,occlusions)
check('native font/glyph/bounds checks',json.loads((UI/'qa/native-labels.json').read_text())['status']=='pass')
check('floating note bounds including halo in headroom',json.loads((UI/'qa/floating-bounds.json').read_text())['status']=='pass')
check('floating glyph exists',json.loads((UI/'qa/floating-bounds.json').read_text())['missingGlyphs']==0)
check('preview event logic',json.loads((UI/'qa/preview-logic.json').read_text())['status']=='pass')
check('timeline cases and real monotonic duration',json.loads((UI/'qa/timeline.json').read_text())['status']=='pass')
for asset in theme['assets']:
    p=UI/asset['path']; tree=ET.fromstring(p.read_text()) if asset['format']=='svg' else []
    check(f'{asset["id"]}: file size/hash/no baked text',p.stat().st_size==asset['byteSize'] and hashlib.sha256(p.read_bytes()).hexdigest()==asset['sha256'] and not any(e.tag.rsplit('}',1)[-1]=='text' for e in (tree.iter() if asset['format']=='svg' else [])))
    check(f'{asset["id"]}: provenance exists',(UI/asset['licenseRef'].split('#')[0]).is_file())
for name in ['single','multi','labels-off','reduced']:
    im=Image.open(UI/f'previews/floating-{name}.gif');total=0
    for frame in range(im.n_frames):im.seek(frame);total+=im.info.get('duration',0)
    check(f'floating-{name}.gif: one-shot under 1s',total==720 and 'loop' not in im.info,{'durationMs':total,'frames':im.n_frames})
check('label toggle/default retained',theme['labels']['visibleByDefault'] and theme['labels']['userToggleAllowed'] and not theme['labels']['bakeIntoTexture'])
check('menu icon glyphs in all size/scale/appearance specimens',json.loads((UI/'qa/menu-icons.json').read_text())['status']=='pass')
for p in (UI/'components/icons').glob('*.png'):
    im=Image.open(p).convert('RGBA');check(p.name+': transparent margin',im.getpixel((0,0))[3]==0 and im.getchannel('A').getextrema()[1]>0)
check('candidate not registered as ready',theme['artifactState']=='design_proposal')
report={'status':'pass' if all(c['status']=='pass' for c in checks) else 'fail','checks':checks,'contrastSampleCount':len(contrast_records),'minimumContrast':minimum,'scope':'Native rendering pixels + geometric/manifest/timeline evidence; no browser, production UI or human target-screen acceptance.'}
(UI/'qa/validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
(UI/'qa/contrast.json').write_text(json.dumps({'minimum':minimum,'method':'sRGB foreground vs actual unlabeled native key pixels at glyph ink bounds; includes press-state combinations, shadows and 1x/2x. Antialiased edge pixels are not treated as the intended text color.','records':contrast_records},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':report['status'],'checks':len(checks),'minimumContrast':minimum,'failures':[c for c in checks if c['status']=='fail']},ensure_ascii=False,indent=2))
if report['status']!='pass':raise SystemExit(1)
