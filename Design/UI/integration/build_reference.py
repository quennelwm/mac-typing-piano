"""Read frozen U-001 artifacts; write only U-001B references and evidence. No renderer."""
from pathlib import Path
import hashlib,json,math
ROOT=Path(__file__).resolve().parents[3]; UI=ROOT/'Design/UI'; OUT=UI/'integration'; E=ROOT/'docs/evidence/U-001B'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,o):p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
m=read(UI/'delivery-manifest.json'); records={r['path']:r for r in m['files']}
for r in m['files']:
 p=UI/r['path'];assert p.stat().st_size==r['byteSize'] and sha(p)==r['sha256'],r['path']
t=read(UI/'theme.candidate.json'); l=read(UI/'qa/layouts.json'); k=read(ROOT/'contracts/keymap.ansi64.v0.1.json')
assert sha(ROOT/'contracts/keymap.ansi64.v0.1.json')==t['sourceMapping']['sha256']
sources=[{'path':'Design/UI/'+name,'sha256':sha(UI/name),'byteSize':(UI/name).stat().st_size} for name in ['delivery-manifest.json','theme.candidate.json','qa/layouts.json','qa/floating-bounds.json']]
sources.append({'path':'contracts/keymap.ansi64.v0.1.json','sha256':sha(ROOT/'contracts/keymap.ansi64.v0.1.json')})
reference={'referenceVersion':'u001b.1','artifactState':'integration_reference','acceptedBaseline':'9270936286de49892881b0898c2f915558deb10e','themeVersion':t['themeVersion'],'mappingVersion':k['mappingVersion'],'sources':sources,'coordinateSystem':{'unit':'pt','origin':'body_top_left','yDirection':'down','bodyHeight':56,'effectHeadroom':48,'canvasHeight':104,'bodyOriginInCanvas':[0,48],'referenceBackingScales':[1,2]},'comparisonPolicy':{'geometryTolerancePt':0.25,'nativeTextPositionReviewTolerancePt':0.5,'colors':'exact sRGB tokens; antialias pixel equality not required','semanticDifferences':'zero tolerance; missing/extra keys, wrong label/side/visibility, clipping are failures','nativeReviewStatus':'awaiting_PM_forwarded_C-001C_snapshots'},'palette':t['candidateParameters']['palette'],'motion':t['motion'],'layouts':[],'scenarios':l['scenarios']}
checks=[]
for layout in l['layouts']:
 w=layout['widthPt'];keys=layout['keys'];assert len(keys)==64
 assert sum(x['color']=='white' for x in keys)==38
 assert sum(x['color']=='black' for x in keys)==26
 assert sorted(x['midiNote'] for x in keys)==list(range(33,97))
 assert len({x['physicalKeyID'] for x in keys})==64
 entries=[];whiteCount=0
 for key in keys:
  canonical=next(x for x in k['keys'] if x['physicalKeyID']==key['physicalKeyID'])
  assert key['labelParts']==canonical['labelParts'] and key['midiNote']==canonical['midiNote']
  black=key['color']=='black';assert black==(key['midiNote']%12 in [1,3,6,8,10])
  x,y,kw,kh=key['rectPt'];slot=(w-4)/38
  expected=[2+whiteCount*slot-slot*.59/2,2,slot*.59,32] if black else [2+whiteCount*slot+.35,2,slot-.7,50]
  assert all(abs(a-b)<1e-8 for a,b in zip(expected,key['rectPt']))
  if not black:whiteCount+=1
  dy=1.5 if black else 2
  entry={'physicalKeyID':key['physicalKeyID'],'midiNote':key['midiNote'],'color':key['color'],'labelParts':key['labelParts'],'accessibleName':key['accessibleName'],'restRectPt':key['rectPt'],'heldRectPt':[x,y+dy,kw,kh],'labelColorHex':t['labels']['blackColorHex' if black else 'whiteColorHex'],'labelGroupFollowsKey':True,'labelVisibilityDefault':True,'labelsOffKeepsKeyAndNote':True,'labels':[],'floatingAnchorPt':[x+kw/2,y-4]}
  for index,label in enumerate(key['labels']):
   b=label['inkBoundsPt'];entry['labels'].append({'part':'main' if index==0 else 'side','text':label['text'],'fontSizePt':label['fontSizePt'],'weight':'medium','restTextOriginPt':[label['x'],label['baselineY']],'heldTextOriginPt':[label['x'],label['baselineY']+dy],'restInkBoundsPt':b,'heldInkBoundsPt':[b[0],b[1]+dy,b[2],b[3]],'observedReferenceFonts':label['resolvedFonts'],'fontNamesAreRuntimeRequirement':False})
  entries.append(entry)
 reference['layouts'].append({'widthPt':w,'whiteSlotPt':slot,'keys':entries})
 checks.append({'widthPt':w,'keys':64,'white':38,'black':26,'mappingAndCoordinates':'pass'})
reference['floatingFrames']=[{'elapsedMs':ms,'present':ms<700,'opacity':min(1,ms/60,(700-ms)/400) if ms<700 else 0,'risePt':24*(1-(1-ms/700)**3),'reducedPresent':ms<200,'reducedRisePt':0,'reducedOpacity':max(0,1-ms/200)} for ms in [0,100,350,700]]
reference['referenceImages']=[{'widthPt':w,'state':s,'scale':scale,'path':f'Design/UI/previews/piano-{w}-{s}@{scale}x.png','sha256':records[f'previews/piano-{w}-{s}@{scale}x.png']['sha256']} for w in [900,1000,1100] for s in ['rest','single','multi'] for scale in [1,2]]
write(OUT/'reference.json',reference)
# Leaf-by-leaf field classification: exhaustive for the frozen candidate, not a new theme schema.
def leaves(obj,p=''):
 if isinstance(obj,dict):
  for key,value in obj.items():yield from leaves(value,p+'/'+key)
 elif isinstance(obj,list):
  for i,value in enumerate(obj):yield from leaves(value,p+'/'+str(i))
 else:yield p,obj
policies=[]
for p,value in leaves(t):
 mode='runtime_parameter';note='Read from accepted candidate; preserve units and user preferences.'
 if p.startswith(('/sourceMapping','/schemaVersion','/themeVersion','/artifactState')):mode='load_validation';note='Validate identity/status/hash; PM acceptance authorizes prototype loading, not ready/public release.'
 elif p.startswith('/assets/'):
  mode='resource_manifest';note='Integrity and optional component loading; native equivalent drawing may avoid SVG runtime dependency.'
 elif p in ['/readinessNote','/geometry/heightScope','/labels/fontStrategy','/candidateParameters/schemaNote','/candidateParameters/labelsOff','/candidateParameters/mainEntry'] or p.endswith(('/runtimeImplemented','/controls','/target','/timeDomain')):mode='design_metadata';note='Explanation/candidate history only; not a runtime success state or executable expression.'
 elif p.startswith('/candidateParameters/dockAutoHide'):mode='product_adapter';note='Code-owned system adapter and user confirmation; never apply setting while loading theme.'
 elif p.startswith(('/candidateParameters/menuIcon','/candidateParameters/volumeControl')):mode='product_adapter';note='Menu preferences/controls, separate from piano renderer. No global gestures or system volume.'
 elif p in ['/motion/residualGlowMs']:mode='inactive_parameter';note='Residual glow is disabled; floating note remains enabled independently.'
 elif p in ['/geometry/blackHeightRatio','/geometry/restKeyBottomPt','/geometry/depressedKeyBottomPt']:mode='derived_consistency';note='Check against explicit 50/32pt faces and 2pt white travel; do not apply to 56pt body height.'
 elif p in ['/labels/contrastTarget','/labels/minMainFontSizePt']:mode='validation_constraint';note='Acceptance guard; do not silently shrink text to fit.'
 elif p in ['/motion/floatingNote/easingFormula']:mode='design_metadata';note='Implement declared cubic function; never evaluate a theme expression as code.'
 policies.append({'jsonPointer':p,'value':value,'classification':mode,'handling':note})
write(OUT/'theme-field-policy.json',{'themeSha256':sha(UI/'theme.candidate.json'),'fieldCount':len(policies),'fields':policies})
write(E/'reference-validation.json',{'status':'pass','frozenFilesVerified':len(records),'sourceManifestSha256':sha(UI/'delivery-manifest.json'),'referenceSha256':sha(OUT/'reference.json'),'themeFieldCount':len(policies),'layouts':checks,'fn':{'midiNote':34,'label':'fn','captureStatus':'unverified'},'topRowIncluded':False,'nativeScreenshotReview':'awaiting','scope':'Read-only provenance, coordinate and expectation validation, not native runtime acceptance.'})
print(json.dumps({'frozenFilesVerified':len(records),'layouts':checks,'themeFields':len(policies),'nativeReview':'awaiting'},ensure_ascii=False))
