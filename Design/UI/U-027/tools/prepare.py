from pathlib import Path
import json,copy,hashlib
ROOT=Path(__file__).resolve().parents[4];OUT=ROOT/'Design/UI/U-027'
oldp=ROOT/'contracts/keymap.ansi64.v0.1.json';newp=ROOT/'docs/inputs/playable-v0.2/Mac_Typing_Piano_Playable_Keymap_v0.2_DRAFT.json'
old=json.loads(oldp.read_text());new=json.loads(newp.read_text());oldByID={k['physicalKeyID']:k for k in old['keys']}
ids={**{'Key'+c:'key'+c for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'},**{'Digit'+str(i):'digit'+str(i) for i in range(10)},'Backquote':'grave','Minus':'minus','Equal':'equal','Backspace':'delete','Tab':'tab','BracketLeft':'bracketLeft','BracketRight':'bracketRight','Backslash':'backslash','CapsLock':'capsLock','Semicolon':'semicolon','Quote':'quote','Return':'return','ShiftLeft':'shiftLeft','ShiftRight':'shiftRight','Comma':'comma','Period':'period','Slash':'slash','Fn':'fn','ControlLeft':'controlLeft','AltLeft':'optionLeft','AltRight':'optionRight','MetaLeft':'commandLeft','MetaRight':'commandRight','Space':'space','ArrowLeft':'arrowLeft','ArrowDown':'arrowDown','ArrowUp':'arrowUp','ArrowRight':'arrowRight'}
assert set(ids)=={k['physicalKeyID'] for k in new['mapping']} and set(ids.values())==set(oldByID)
keys=[]
for r in new['mapping']:
 k=copy.deepcopy(oldByID[ids[r['physicalKeyID']]])
 k.update(midiNote=r['midi'],noteName=r['note'],pianoKeyColor=r['pianoKeyType'])
 k['sourceDOMPhysicalKeyID']=r['physicalKeyID'];keys.append(k)
assert sorted(k['midiNote'] for k in keys)==list(range(33,97))
assert all((k['midiNote']%12 in [1,3,6,8,10])==(k['pianoKeyColor']=='black') for k in keys)
def save(n,o):(OUT/n).write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
save('id-translation.json',{'purpose':'Explicit source DOM ID to existing physicalKeyID, UI preview only','pairs':[{'source':a,'target':b} for a,b in ids.items()]})
save('mapping.preview.json',{'mappingVersion':'performance-piano-v0.2-ui-preview','artifactState':'design_proposal','defaultSelection':'new_profile_provisional_PM_assumption_2026-10-29','keys':keys})
save('parameters.json',{'version':'u027.1','artifactState':'design_proposal','bodyHeightPt':112,'headroomPt':96,'canvasHeightPt':208,'screenSideMarginPt':8,'screenWidthsPt':[1280,1512,1920],'pianoWidthsPt':[1264,1496,1904],'whiteFaceHeightPt':100,'blackFaceHeightPt':64,'keyTopPt':4,'whiteTravelPt':2,'blackTravelPt':1.5,'labels':{'whiteSizePt':10,'blackSizePt':9.5,'sideSizePt':6.5,'followKeyTransform':True,'visibleByDefault':True,'bakedIntoTexture':False},'floating':{'glyph':'♪','fontSizePt':24,'durationMs':900,'risePt':48,'driftXPt':4,'ease':'1-(1-t)^3','fadeInMs':80,'fadeOutMs':500,'haloBlurPt':1.25,'conservativeBoundsPaddingPt':4,'reducedDurationMs':200,'reducedRisePt':0,'reducedDriftXPt':0},'panel':{'nonactivating':True,'entireCanvasMousePassThrough':True,'ordinaryPauseMayShowStaticKeys':True,'showDoesNotEnableAudioOrInput':True},'sourceSHA256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [oldp,newp,ROOT/'Design/UI/tools/native_render.swift']}})
# Reuse only the native vector drawing functions; old source is never edited.
s=(ROOT/'Design/UI/tools/native_render.swift').read_text().split('var allLayouts:')[0]
s=s.replace('Design/UI")','Design/UI/U-027")').replace('contracts/keymap.ansi64.v0.1.json','Design/UI/U-027/mapping.preview.json')
s=s.replace('[900, 1000, 1100]','[1264, 1496, 1904]').replace('height: 32)','height: 64)').replace('height: 50)','height: 100)').replace('y: 2, width:','y: 4, width:')
s=s.replace('height:56)','height:112)').replace('x:1,y:1,width:width-2,height:53','x:1,y:2,width:width-2,height:106')
s=s.replace('// U-001 design renderer only.','// U-027 design renderer, derived from frozen U-001 native vector functions only.')
(OUT/'tools/drawing.swift.inc').write_text(s)
print('Explicit mapping conversion, parameters and reusable drawing functions prepared.')
