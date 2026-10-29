from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[4];P=ROOT/'Design/UI/U-028';source=ROOT/'Design/UI/U-027/mapping.preview.json';m=json.loads(source.read_text());ks=m['keys'];byid={k['physicalKeyID']:k for k in ks};midi={k['midiNote']:k for k in ks};baseline={k['physicalKeyID']:k['midiNote'] for k in ks}
assert len(ks)==64 and set(baseline.values())==set(range(33,97))
labels={'commandLeft':'左 Command（⌘）','commandRight':'右 Command（⌘）','optionLeft':'左 Option（⌥）','optionRight':'右 Option（⌥）','shiftLeft':'左 Shift（⇧）','shiftRight':'右 Shift（⇧）','controlLeft':'左 Control（⌃）','fn':'Fn／地球键','space':'空格','tab':'Tab（⇥）','capsLock':'Caps Lock（⇪）','delete':'Delete（⌫）','return':'Return（↵）'}
name=lambda k:labels.get(k['physicalKeyID'],k['displayLabel'])
rows=[{'physicalKeyID':k['physicalKeyID'],'displayName':name(k),'physicalRow':k['physicalRow'],'positionInRow':k['positionInRow'],'defaultMIDI':k['midiNote'],'defaultPitch':k['noteName']} for k in ks]
rows.sort(key=lambda r:(r['physicalRow'],r['positionInRow']))
pitches=[{'midi':n,'displayPitch':midi[n]['noteName'].replace('#','♯'),'defaultOwnerPhysicalKeyID':midi[n]['physicalKeyID'],'isMiddleC':n==60} for n in range(33,97)]
examples=[]
for key,target in [('keyG',53),('fn',96),('keyG',60)]:
 other=next(i for i,v in baseline.items() if v==target);candidate=dict(baseline);candidate[key],candidate[other]=candidate[other],candidate[key]
 changes=[{'physicalKeyID':i,'fromMIDI':baseline[i],'toMIDI':v} for i,v in candidate.items() if v!=baseline[i]]
 assert len(changes)==(0 if key==other else 2) and set(candidate.values())==set(range(33,97)) and len(candidate)==64
 examples.append({'selectedKey':key,'targetMIDI':target,'changes':changes,'saveEnabled':bool(changes),'candidate':candidate})
swap=examples[0]['candidate'];restore=[{'physicalKeyID':i,'fromMIDI':swap[i],'toMIDI':n} for i,n in baseline.items() if swap[i]!=n]
obj={'version':'u028.2','artifactState':'design_proposal','sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'sourcePath':str(source.relative_to(ROOT)),'menuEntry':'自定义键位…','legacyPresetEntry':False,'windowSizePt':[560,440],'buttons':['恢复新表默认','取消','保存'],'physicalKeyOptions':rows,'pitchOptions':pitches,'swapExamples':examples,'restoreExample':{'changes':restore,'target':baseline},'semantics':{'selectionMutatesRuntime':False,'targetSelectionSwapsSingleDraftImmediately':True,'switchKeyPreservesAllDraftEdits':True,'saveCommitsEntireDraft':True,'runtimeStatusAndDraftStatusSeparate':True,'cancelMutatesRuntime':False,'resetRequiresSave':True,'occupiedPitchAction':'swap_two_assignments','saveMayEnableAudioOrInput':False,'needsKeyCaptureOrExtraPermission':False}}
(P/'reference.json').write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
# Exhaustive design-model check: every selection/target yields exactly0 or2 changed pairs.
count=0
for key in baseline:
 for target in range(33,97):
  other=next(i for i,v in baseline.items() if v==target);c=dict(baseline);c[key],c[other]=c[other],c[key]
  assert len(set(c.values()))==64 and set(c)==set(baseline) and sum(c[i]!=baseline[i] for i in c)==(0 if other==key else 2)
  count+=1
(P/'validation.json').write_text(json.dumps({'status':'pass','date':'2026-10-29 Asia/Shanghai','physicalKeyOptions':64,'pitchOptions':64,'swapModelCases':count,'restoreExampleChanges':len(restore),'scope':'Design options and exchange arithmetic only; native controls, focus, accessibility, persistence/audio reset not tested.'},ensure_ascii=False,indent=2)+'\n')
print('64 key options,64 pitches,4096 model swaps verified.')

# Sequence: G swaps with A, then A swaps with H; cancel preserves B, reset restores B.
draft=dict(baseline)
for key,target in [('keyG',53),('keyA',62)]:
 owner=next(i for i,v in draft.items() if v==target);draft[key],draft[owner]=draft[owner],draft[key]
assert draft['keyG']==53 and draft['keyA']==62 and draft['keyH']==60 and len(set(draft.values()))==64
assert baseline['keyG']==60 and baseline['keyA']==53 and baseline['keyH']==62
validation=json.loads((P/'validation.json').read_text());validation['multiEditExample']={'changes':[{'key':i,'from':baseline[i],'to':v} for i,v in draft.items() if v!=baseline[i]],'baselineUnchanged':True,'resetTargetMatchesNewDefault':True}
(P/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n')

r=json.loads((P/'reference.json').read_text())
r['states']=[{'id':'clean','runtimeLabel':'当前使用：新表默认／自定义键位','draftLabel':'草稿：未修改','saveEnabled':False},{'id':'dirty','draftLabel':'草稿：N项待保存','preview':'All differences between active mapping and single editable draft','saveEnabled':True},{'id':'restore','draftLabel':'草稿：恢复新表默认 · N项待保存','immediateRuntimeChange':False},{'id':'writeFailed','message':'保存失败，当前键位未更改。','retainEntireDraft':True,'retryAllowed':True},{'id':'staleSnapshot','message':'键位已在其他位置更新，请重新载入后调整。','saveEnabled':False,'reloadAction':'Explicitly discard draft and fetch active snapshot'},{'id':'loadFailed','message':'自定义配置无法载入，当前使用新表默认；原文件已保留。','runtimeLabel':'默认键位','preserveOriginalConfig':True}]
r['multiEditExample']=validation['multiEditExample'];r['decisionSources']=['docs/changes/CR-007-custom-keymap.md','docs/tasks/U-028.md','PM review: single draft, no continue/apply button']
(P/'reference.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
