from pathlib import Path
import json,math,hashlib,platform
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[4];OUT=ROOT/'Design/UI/U-027';UI=ROOT/'Design/UI'
read=lambda p:json.loads(p.read_text()); sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
mapdata=read(OUT/'mapping.preview.json');byid={k['physicalKeyID']:k for k in mapdata['keys']};source=read(ROOT/'docs/inputs/playable-v0.2/Mac_Typing_Piano_Playable_Keymap_v0.2_DRAFT.json');sourcebyid={k['physicalKeyID']:k for k in source['mapping']};layout=read(OUT/'qa/layouts.json');checks=[];contrasts=[]
def check(n,c):
 checks.append({'name':n,'pass':bool(c)})
def lum(rgb):
 x=[v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb[:3]]
 return sum(v*w for v,w in zip(x,[.2126,.7152,.0722]))
def contrast(a,b):
 x,y=sorted([lum(a),lum(b)]);return (y+.05)/(x+.05)
def intersects(a,b):return a[0]<b[0]+b[2] and a[0]+a[2]>b[0] and a[1]<b[1]+b[3] and a[1]+a[3]>b[1]
check('64 IDs and contiguous MIDI',len(byid)==64 and sorted(k['midiNote'] for k in byid.values())==list(range(33,97)))
check('source MIDI imported exactly',all(k['midiNote']==sourcebyid[k['sourceDOMPhysicalKeyID']]['midi'] for k in byid.values()))
check('new core G=C4 A=F3 Return=C5',byid['keyG']['midiNote']==60 and byid['keyA']['midiNote']==53 and byid['return']['midiNote']==72)
check('Fn preserved and moved by approved new mapping',byid['fn']['midiNote']==33)
old=read(ROOT/'contracts/keymap.ansi64.v0.1.json');oldbyid={k['physicalKeyID']:k for k in old['keys']}
check('physical metadata and labels retained',all(all(k[field]==oldbyid[k['physicalKeyID']][field] for field in ['sdkConstantCandidate','physicalRow','positionInRow','captureStatus','labelParts']) for k in byid.values()))
for l in layout['layouts']:
 w=l['widthPt'];ks=l['keys'];check(f'{w} true doubled body',l['heightPt']==112 and all(k['rectPt'][1]==4 and k['rectPt'][3]==(64 if k['color']=='black' else 100) for k in ks));check(f'{w} 38 white/26 black',sum(k['color']=='white' for k in ks)==38 and len(ks)==64)
 check(f'{w} all labels match ID mapping',all(k['labelParts']==byid[k['physicalKeyID']]['labelParts'] for k in ks))
 for wd in [0,1]:
  for bd in [0,1]:
   for scale in [1,2]:
    im=Image.open(OUT/f'qa/surface-{w}-{wd}-{bd}@{scale}x.png').convert('RGBA')
    for k in ks:
     black=k['color']=='black';dy=(bd*1.5) if black else (wd*2);fg=(205,205,205) if black else (89,89,89)
     for label in k['labels']:
      x,y,b,h=label['inkBoundsPt'];y+=dy
      ratios=[contrast(fg,im.getpixel((px,py))) for px in range(math.floor(x*scale),math.ceil((x+b)*scale)) for py in range(math.floor(y*scale),math.ceil((y+h)*scale))]
      contrasts.append({'width':w,'physicalKeyID':k['physicalKeyID'],'label':label['text'],'whiteHeld':wd,'blackHeld':bd,'scale':scale,'minimumContrast':min(ratios)})
      if not black:
       for other in ks:
        if other['color']=='black':
         r=other['rectPt'].copy();r[1]+=bd*1.5
         check(f'{w}:{wd}:{bd}:{scale}:{k["physicalKeyID"]}/{other["physicalKeyID"]} label not covered',not intersects([x,y,b,h],r))
 for state in ['rest','single','multi']:
  for scale in [1,2]:
   for labels in [True,False]:
    im=Image.open(OUT/f'previews/piano-{w}-{state}{"" if labels else "-labels-off"}@{scale}x.png')
    check(f'{w}/{state}/{scale}/{labels} canvas',im.size==(w*scale,112*scale) and im.mode=='RGBA')
 for mode,end in [('normal',900),('reduced',200)]:
  for scale in [1,2]:
   im=Image.open(OUT/f'previews/floating-{w}-{mode}-{end}ms@{scale}x.png').convert('RGBA');rest=Image.open(OUT/f'previews/piano-{w}-rest@{scale}x.png').convert('RGBA')
   check(f'{w}/{mode}/{scale} effect gone at deadline',im.getchannel('A').crop((0,0,w*scale,96*scale)).getbbox() is None and ImageChops.difference(im.crop((0,96*scale,w*scale,208*scale)),rest).getbbox(alpha_only=False) is None)
minimum=min(contrasts,key=lambda x:x['minimumContrast']);check('4.5 contrast every label/all held combinations',minimum['minimumContrast']>=4.5)
check('192 native labels measured',read(OUT/'qa/native-labels.json')['status']=='pass')
check('1536 note bounds plus conservative4pt pad fit',read(OUT/'qa/floating-bounds.json')['status']=='pass' and read(OUT/'qa/floating-bounds.json')['missingGlyphs']==0)
# Continuous-time proof: e=1-(1-t)^3 is monotone over t in[0,1].
# Both x and y extrema therefore occur at the endpoints; include the t=1 limit
# even though the instance is removed at900ms. Reduced motion is stationary.
fb=read(OUT/'qa/floating-bounds.json');ink=fb['glyphInkBoundsPt'];envelopes=[]
for l in layout['layouts']:
 for k in l['keys']:
  x,y,w,h=k['rectPt'];center=x+w/2
  for reduced in [False,True]:
   rise=0 if reduced else 48;dx=0 if reduced else 4
   box=[center-ink[2]/2-4,y-4-rise-ink[3]-4,ink[2]+8+dx,ink[3]+8+rise]
   margins={'left':box[0],'right':l['widthPt']-box[0]-box[2],'top':96+box[1],'bottom':112-box[1]-box[3]}
   good=min(margins.values())>=0
   check(f'{l["widthPt"]}/{k["midiNote"]}/{reduced} continuous full-life envelope',good)
   envelopes.append({'widthPt':l['widthPt'],'midiNote':k['midiNote'],'physicalKeyID':k['physicalKeyID'],'reduced':reduced,'fullLifetimeBoundsBodyPt':box,'canvasMarginsPt':margins,'pass':good})
continuous={'status':'pass' if all(r['pass'] for r in envelopes) else 'fail','proof':'For t in[0,1], e=1-(1-t)^3 monotonically spans[0,1]. Whole-life glyph+4pt halo envelope covers every time, not only sampled keyframes; includes900ms limit. Reduced mode stationary200ms. Based on current native CoreText ink metrics.','records':envelopes,'edgeKeyRecords':[r for r in envelopes if r['midiNote'] in [33,96]],'minimumCanvasMarginsPt':{side:min(r['canvasMarginsPt'][side] for r in envelopes) for side in ['left','right','top','bottom']},'scope':'Geometric containment; not wall-clock/runtime integration or other font versions.'}
(OUT/'qa/continuous-lifecycle.json').write_text(json.dumps(continuous,ensure_ascii=False,indent=2)+'\n')
for path in (OUT/'previews').glob('floating-*.png'):
 im=Image.open(path).convert('RGBA');scale=2 if '@2x' in path.name else 1
 box=im.getchannel('A').crop((0,0,im.width,96*scale)).getbbox()
 check(path.name+' headroom raster does not touch outer top or sides',box is None or (box[0]>0 and box[1]>0 and box[2]<im.width))
original=read(UI/'delivery-manifest.json');check('182 frozen originals unchanged',all(sha(UI/e['path'])==e['sha256'] for e in original['files']))
frames=[Image.open(OUT/f'qa/frames/normal-{t}.png').convert('RGB') for t in range(0,901,20)]
frames[0].save(OUT/'previews/floating-1496-once.gif',save_all=True,append_images=frames[1:],duration=20,optimize=False,disposal=2)
gif=Image.open(OUT/'previews/floating-1496-once.gif');dur=0
for i in range(gif.n_frames):gif.seek(i);dur+=gif.info['duration']
check('one-shot GIF900ms effect +20ms blank end',dur==920 and 'loop' not in gif.info)
result={'status':'pass' if all(c['pass'] for c in checks) else 'fail','date':'2026-10-29 Asia/Shanghai','environment':platform.platform(),'checksTotal':len(checks),'failed':[c for c in checks if not c['pass']],'nativeLabelCount':192,'floatingBoundsCount':1536,'continuousLifetimeEnvelopes':len(envelopes),'minimumEnvelopeMarginsPt':continuous['minimumCanvasMarginsPt'],'contrastCombinations':len(contrasts),'minimumContrast':minimum,'frozenOriginalsVerified':len(original['files']),'gifContainerMs':dur,'scope':'Native offscreen vector/CoreText design only; no product window, live focus/pointer/input/audio/900ms wall-clock scheduling tested.'}
(OUT/'qa/validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(OUT/'qa/contrast.json').write_text(json.dumps({'minimum':minimum,'records':contrasts},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False));assert result['status']=='pass'
