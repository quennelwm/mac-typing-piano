#!/usr/bin/env python3
"""Read-only C-001B evidence -> matched-level A/B excerpts and budget plan."""
import hashlib,json,pathlib,wave,math
import numpy as np
ROOT=pathlib.Path(__file__).resolve().parents[1]
PROJECT=ROOT.parents[3]
EVIDENCE=PROJECT/'docs/evidence/A-001C'
CBASE=PROJECT/'docs/evidence/C-001B'
AUDIO=PROJECT/'Design/Audio'
IDS=['vcsl-kawai','vcsl-steinway-b']
# Fixed neutral labels, not randomized on rebuild. Reveal is separate.
LABELS={'vcsl-kawai':'B','vcsl-steinway-b':'A'}
inputs={}
def read(p):
 b=p.read_bytes();inputs[str(p.relative_to(PROJECT))]={'sha256':hashlib.sha256(b).hexdigest(),'byteSize':len(b)};return b
def obj(p):return json.loads(read(p))
def save(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def db(x):return float(20*np.log10(max(float(x),1e-15)))
def stats(x):return {'frames':len(x),'durationSeconds':len(x)/48000,'rmsDBFS':db(np.sqrt(np.mean(x*x))),'peakDBFS':db(abs(x).max()),'clippedSamples':int(np.sum(abs(x)>=1))}
def write24(p,x):
 q=np.rint(x*8388608).astype(np.int32);assert abs(q).max()<8388607
 b=np.stack([q&255,(q>>8)&255,(q>>16)&255],axis=1).astype(np.uint8)
 with wave.open(str(p),'wb') as w:w.setnchannels(1);w.setsampwidth(3);w.setframerate(48000);w.writeframes(b.tobytes())
 return q.astype(float)/8388608

def build():
 EVIDENCE.mkdir(parents=True,exist_ok=True)
 trials=obj(AUDIO/'probes/A-001B/trial-index.json')
 signals={};segments={};sources={}
 for c in IDS:
  report=obj(CBASE/f'{c}-results.json');assert report['status']=='passed' and report['loadStatus']=='passed'
  trial=next(t for t in trials['trials'] if t['id']==c)
  assert report['bankSHA256']==trial['sha256']
  bank=read(AUDIO/'probes/A-001B'/trial['bankFile']);assert hashlib.sha256(bank).hexdigest()==trial['sha256']
  meta=report['representativeWAV'];path=CBASE/meta['filename'];b=read(path)
  assert len(b)==meta['byteSize'] and hashlib.sha256(b).hexdigest()==meta['sha256']
  with wave.open(str(path),'rb') as w:
   assert (w.getframerate(),w.getnchannels(),w.getsampwidth())==(48000,1,2)
   assert w.getnframes()==meta['frames'];x=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32768
  pieces=[];timeline=[];pos=0
  for i in range(1,8):
   s=meta['segments'][i];start=s['startFrame'];n=s['frameCount'];y=x[start:start+n].copy()
   assert s['velocity']==64 and abs(s['gain']-.08)<1e-6
   if i==7:y[-240:]*=np.linspace(1,0,240) # only final 5ms of an already truncated repeat excerpt
   timeline.append({'label':s['label'],'sourceStartFrame':start,'frameCount':n,'outputStartFrame':pos,'trailingSilenceFrames':2400,'endFadeFrames':240 if i==7 else 0,'velocity':64,'engineGain':.08})
   pieces.extend([y,np.zeros(2400)]);pos+=n+2400
  signals[c]=np.concatenate(pieces);segments[c]=timeline
  sources[c]={'path':str(path.relative_to(PROJECT)),'sha256':meta['sha256'],'bankSHA256':report['bankSHA256'],'format':'48kHz mono PCM16 render from mono PCM16 SF2','original':stats(x),'extracted':stats(signals[c])}
 assert segments[IDS[0]]==segments[IDS[1]]
 # Same integrated RMS over identical duration, with a shared peak-constrained target.
 rms={c:np.sqrt(np.mean(x*x)) for c,x in signals.items()}
 target=min(10**(-26/20),*(rms[c]*10**(-6.1/20)/abs(signals[c]).max() for c in IDS))
 outputs=[]
 for c in IDS:
  label=LABELS[c];gain=target/rms[c];p=ROOT/f'{label}.wav';y=write24(p,signals[c]*gain)
  outputs.append({'label':label,'candidateID':c,'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'byteSize':p.stat().st_size,'gainDB':db(gain),'measured':stats(y)})
 report={'task':'A-001C','algorithm':'identical segments; final repeat excerpt 5ms linear endpoint fade; whole-excerpt constant gain to shared RMS target; peak ceiling -6.1dBFS; PCM24 nearest-even output','rmsTargetDBFS':db(target),'notLUFS':True,'inputs':inputs,'sources':sources,'segments':segments[IDS[0]],'outputs':outputs,'sourcePrecisionCaveat':'Common excerpts RMS approximately -74.3dBFS in PCM16. Approximately +48.3dB gain also amplifies existing quantization; PCM24 output cannot recover source detail. Do not use for final long-session comfort/noise-floor judgment.','subjectiveListening':'NOT_TESTED','hardwareOutput':False}
 # Future minimal available-root layer, under maximum +/-1 semitone constraint.
 proposal=obj(AUDIO/'proposed-zones.json');ledger=obj(AUDIO/'source_evidence/download-ledger.json')
 tree={r['path']:r for r in obj(AUDIO/'source_evidence/vcsl-tree.json')['tree']}
 cached={r['sourcePath']:r for r in ledger['files']};plans={}
 for c in IDS:
  p=proposal[c];rows=[]
  for z in p['zones']:
   path=z['sourcePath'];known=cached.get(path);present=False
   assert tree[path]['sha']==z['sourceGitBlob'] and tree[path]['size']==z['sourceByteSize']
   if known:
    data=read(AUDIO/known['localPath']);assert hashlib.sha256(data).hexdigest()==known['sha256'];present=True
    assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==z['sourceGitBlob']
   rows.append({'rootMIDI':z['rootMIDI'],'lowMIDI':z['lowMIDI'],'highMIDI':z['highMIDI'],'sourcePath':path,'sourceGitBlob':z['sourceGitBlob'],'sourceByteSize':z['sourceByteSize'],'alreadyDownloadedAndVerified':present,'cachedSHA256':known['sha256'] if present else None})
  covered=[n for z in rows for n in range(z['lowMIDI'],z['highMIDI']+1)];assert sorted(covered)==list(range(33,97))
  roots=[r['rootMIDI'] for r in rows]
  assert all(any(min(abs(n-q) for q in roots if q!=r)>1 for n in range(33,97)) for r in roots)
  plans[c]={'sourceCommit':p['sourceCommit'],'license':'CC0-1.0','layer':'Kawai v2 Player / Steinway NoSus vl2 Close, rr1; one existing recorded layer','rootCount':len(rows),'rootMIDI':roots,'maximumTransposeSemitones':1,'mathematicalCoverageMIDI':covered,'coverageAudioValidated':False,'fullRawLayerBytes':sum(r['sourceByteSize'] for r in rows),'additionalDownloadBytes':sum(r['sourceByteSize'] for r in rows if not r['alreadyDownloadedAndVerified']),'missingRootMIDI':[r['rootMIDI'] for r in rows if not r['alreadyDownloadedAndVerified']],'payloadSizeUpperEstimatesAt8Seconds':{'mono16Bytes':len(rows)*48000*8*2,'stereo16Bytes':len(rows)*48000*8*4,'stereo24Bytes':len(rows)*48000*8*6},'sizeEstimateNote':'PCM payload estimates, not finished bank sizes; up to 8s/root at 48kHz; add guards/metadata; duration and all original file formats still need validation. Download sizes are pinned Git tree bytes, excluding HTTP overhead and future release samples.','zones':rows}
 save(ROOT/'full-layer-plan.json',plans)
 # refresh after plan input reads so every used file is bound
 report['inputs']=inputs
 save(ROOT/'processing-record.json',report)
 save(ROOT/'reveal.json',{'purpose':'Open only after blind preference noted; fixed labels, not randomized trial','mapping':{LABELS[c]:c for c in IDS}})
 save(ROOT/'blind-index.json',{'task':'A-001C','state':'comparison_only_not_final_selection','format':'48kHz mono PCM24 derived from mono PCM16 engine renders; no recovered precision','sequence':segments[IDS[0]],'options':[{'label':o['label'],'file':o['file'],'sha256':o['sha256'],'byteSize':o['byteSize']} for o in sorted(outputs,key=lambda o:o['label'])],'revealFile':'reveal.json','instructions':'Keep playback volume/device fixed. Listen to A and B before opening reveal. Scores: softness, high-note comfort, rapid-strike clarity. No formal perceptual equality or double-blind claim.'})
 save(EVIDENCE/'inputs.json',inputs)
 print(json.dumps({'outputs':outputs,'targetRMSdB':db(target),'plans':{c:{k:p[k] for k in ['rootCount','additionalDownloadBytes','fullRawLayerBytes','missingRootMIDI']} for c,p in plans.items()}},ensure_ascii=False,indent=2))
if __name__=='__main__':build()
