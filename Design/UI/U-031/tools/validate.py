from pathlib import Path
import json,math,hashlib,platform,os
from collections import defaultdict
from PIL import Image,ImageChops
P=Path(__file__).resolve().parents[1];ROOT=P.parents[2];read=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
CACHE=Path(os.environ.get('TYPING_PIANO_UI_QA_CACHE',str(Path.home()/'Library/Caches/local.typingpiano.ui/U-031')))
def image_path(rel):return P/rel if (P/rel).exists() else CACHE/rel
l=read(P/'qa/layouts.json')['layouts'];ref=read(P/'reference.json');checks=[];alpha=[];contrasts=[];diffs=[]
def check(n,v):checks.append({'name':n,'pass':bool(v)})
def luminance(rgb):
 c=[(v/255)/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb[:3]]
 return sum(x*y for x,y in zip(c,[.2126,.7152,.0722]))
def ratio(a,b):
 a,b=sorted([luminance(a),luminance(b)]);return (b+.05)/(a+.05)
def blend(f,b,a):return tuple(f[i]*a+b[i]*(1-a) for i in range(3))
def intersects(a,b):return a[0]<b[0]+b[2] and a[0]+a[2]>b[0] and a[1]<b[1]+b[3] and a[1]+a[3]>b[1]
def bg_at(mode,x,y,w,h):
 if mode=='light':return (244,245,247)
 if mode=='dark':return (24,33,46)
 cols=[(162,118,136),(127,162,184),(168,173,126)];v=cols[min(5,int(x/(w/6)))%3]
 return blend((255,255,255),v,.15) if .30*h<=y<.48*h else v
for a in l:
 w=a['widthPt'];pct=a['heightPercent'];h=pct/100;body=112*h;keys=a['keys']
 check(f'{w}/{pct}: real body scaling',a['bodyHeightPt']==body and all(abs(k['rectPt'][3]-(64 if k['color']=='black' else 100)*h)<1e-8 for k in keys))
 check(f'{w}/{pct}: bijection',len(keys)==64 and len({k['physicalKeyID'] for k in keys})==64 and sorted(k['midiNote'] for k in keys)==list(range(33,97)))
 check(f'{w}/{pct}: white/black count',sum(k['color']=='white' for k in keys)==38)
 for wd in [0,1]:
  for bd in [0,1]:
   im=Image.open(CACHE/f'qa/surface-{w}-h{pct}-{wd}-{bd}.png').convert('RGBA')
   check(f'{w}/{pct}/{wd}/{bd}: no fully opaque backing/surface pixels',im.getchannel('A').getextrema()[1]<255)
   for k in keys:
    black=k['color']=='black';dy=((1.5*bd) if black else (2*wd))*h;x,y,kw,kh=k['rectPt'];py=y+dy+kh*.45;px=x+kw*.5;rgba=im.getpixel((int(px),int(py)))
    alpha.append({'widthPt':w,'heightPercent':pct,'whiteDown':wd,'blackDown':bd,'midi':k['midiNote'],'color':k['color'],'alpha8':rgba[3]})
    check(f'{w}/{pct}/{wd}/{bd}/{k["midiNote"]} translucent face center',0<rgba[3]<255)
    for label in k['labels']:
     bx,by,bw,bh=label['inkBoundsPt'];by+=dy
     if not black:
      for other in keys:
       if other['color']=='black':
        r=other['rectPt'].copy();r[1]+=1.5*bd*h
        check(f'{w}/{pct}/{wd}/{bd}/{k["midiNote"]}:{label["text"]}/{other["midiNote"]} label visible region',not intersects([bx,by,bw,bh],r))
     fg=(65,75,85) if black else (150,159,169);fa=.84 if black else .86
     for mode in ['light','dark','color']:
      rr=[]
      for iy in range(math.floor(by),math.ceil(by+bh)):
       for ix in range(math.floor(bx),math.ceil(bx+bw)):
        pix=im.getpixel((ix,iy));back=blend(pix[:3],bg_at(mode,ix,iy,w,body),pix[3]/255);front=blend(fg,back,fa);rr.append(ratio(front,back))
      contrasts.append({'widthPt':w,'heightPercent':pct,'whiteDown':wd,'blackDown':bd,'midi':k['midiNote'],'color':k['color'],'label':label['text'],'background':mode,'nominalCompositedContrast':min(rr)})
 for state in ['rest','multi']:
  im=Image.open(image_path(f'previews/piano-{w}-h{pct}-{state}@1x.png'));check(f'{w}/{pct}/{state} dimensions',im.size==(w,math.ceil(body)))
check('white light / black dark label direction',ref['material']['white']['labelHex']=='#969FA9' and ref['material']['black']['labelHex']=='#414B55')
check('native labels all fit/no missing/no overlaps',read(P/'qa/labels.json')['status']=='pass')
life=read(P/'qa/note-lifetime.json');check('all1152 continuous note envelopes',len(life['records'])==1152 and life['status']=='pass')
for mode,end in [('normal',950),('reduced',200)]:
 im=Image.open(P/f'previews/notes-{mode}-{end}ms.png').convert('RGBA');rest=Image.open(P/'previews/piano-1496-h100-rest@1x.png').convert('RGBA')
 check(mode+' deadline no notes',im.getchannel('A').crop((0,0,1496,144)).getbbox() is None and ImageChops.difference(im.crop((0,144,1496,256)),rest).getbbox(alpha_only=False) is None)
for f in (P/'previews').glob('notes-*.png'):
 im=Image.open(f).convert('RGBA');b=im.getchannel('A').crop((0,0,1496,144)).getbbox();check(f.name+' no headroom outer-edge alpha',b is None or (b[0]>0 and b[1]>0 and b[2]<1496))
opaque=Image.open(CACHE/'qa/reduced-transparency-alpha.png').convert('RGBA');layout=next(a for a in l if a['widthPt']==1496 and a['heightPercent']==100)
check('reduced transparency opaque face centers',all(opaque.getpixel((int(k['rectPt'][0]+k['rectPt'][2]/2),int(k['rectPt'][1]+k['rectPt'][3]*.45)))[3]==255 for k in layout['keys']))
# Explicit composite-background proof: at same face points, RGB varies when backdrop changes.
trans=Image.open(CACHE/'qa/surface-1496-h100-0-0.png').convert('RGBA')
for k in layout['keys']:
 x,y,w,h=k['rectPt'];rgba=trans.getpixel((int(x+w/2),int(y+h*.45)))
 light=blend(rgba[:3],(244,245,247),rgba[3]/255);dark=blend(rgba[:3],(24,33,46),rgba[3]/255)
 diffs.append(max(abs(a-b) for a,b in zip(light,dark)))
check('all64 faces respond to backdrop',min(diffs)>0)
# Product had changed sinceU001; verify original frozen asset files, not other role work.
old=read(ROOT/'Design/UI/delivery-manifest.json');check('182 original UI files unchanged',all(sha(ROOT/'Design/UI'/f['path'])==f['sha256'] for f in old['files']))
mins={typ:min(c['nominalCompositedContrast'] for c in contrasts if c['color']==typ) for typ in ['white','black']}
# Visibility floor is an internal check for fully lost text, not a WCAG claim.
check('subtle labels remain numerically distinguishable on test backgrounds',min(mins.values())>1.05)
result={'status':'pass' if all(c['pass'] for c in checks) else 'fail','date':'2026-10-29 Asia/Shanghai','environment':platform.platform(),'checkCount':len(checks),'failed':[c for c in checks if not c['pass']],'layouts':9,'nativeLabels':576,'continuousNoteEnvelopes':1152,'faceCenterSamples':len(alpha),'centerAlphaRange8bit':{t:[min(a['alpha8'] for a in alpha if a['color']==t),max(a['alpha8'] for a in alpha if a['color']==t)] for t in ['white','black']},'labelContrastSamples':len(contrasts),'minimumNominalContrast':mins,'contrastMeaning':'Configured label color/alpha composited on actual surface pixels plus three synthetic backgrounds; not antialias edge contrast or WCAG pass. Subtle labels explicitly requested.','minimumBackdropRGBDelta':min(diffs),'minimumNoteMarginsPt':[min(a['marginsPt'][i] for a in life['records']) for i in range(4)],'frozenOriginalsVerified':len(old['files']),'scope':'Offscreen native vector/CoreText and synthetic compositing only. No real desktop backdrop, native Liquid Glass API, live slider/preferences/input/audio/Dock/OS accessibility tested.'}
alphaGroups=defaultdict(list);contrastGroups=defaultdict(list)
for x in alpha:alphaGroups[(x['widthPt'],x['heightPercent'],x['whiteDown'],x['blackDown'],x['color'])].append(x)
for x in contrasts:contrastGroups[(x['widthPt'],x['heightPercent'],x['whiteDown'],x['blackDown'],x['color'],x['background'])].append(x)
aSummary=[{'widthPt':k[0],'heightPercent':k[1],'whiteDown':k[2],'blackDown':k[3],'color':k[4],'samples':len(v),'alphaRange8bit':[min(x['alpha8'] for x in v),max(x['alpha8'] for x in v)]} for k,v in alphaGroups.items()]
cSummary=[{'group':list(k),'samples':len(v),'minimum':min(v,key=lambda x:x['nominalCompositedContrast']),'maximum':max(x['nominalCompositedContrast'] for x in v)} for k,v in contrastGroups.items()]
result['intermediateImages']='Regenerable external cache via TYPING_PIANO_UI_QA_CACHE; not deliverables.'
(P/'qa/validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(P/'qa/alpha.json').write_text(json.dumps({'sampleCount':len(alpha),'groups':aSummary},indent=2)+'\n')
(P/'qa/contrast.json').write_text(json.dumps({'sampleCount':len(contrasts),'groups':cSummary},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False));assert result['status']=='pass'
