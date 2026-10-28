#!/usr/bin/env python3
import pathlib,json,hashlib,wave,subprocess,sys,math
import numpy as np
ROOT=pathlib.Path(__file__).resolve().parents[1];PROJECT=ROOT.parents[3];E=PROJECT/'docs/evidence/A-001C'
checks=[]
def check(label,truth):
 assert truth,label
 checks.append({'check':label,'status':'passed'})
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def payload():return {str(p.relative_to(ROOT)):sha(p) for p in ROOT.rglob('*') if p.is_file()}
before=payload()
subprocess.run([sys.executable,str(ROOT/'scripts/build_comparison.py')],check=True,stdout=subprocess.DEVNULL)
check('Rebuild all payload files byte-identical',before==payload())
r=json.loads((ROOT/'processing-record.json').read_text())
check('All bound inputs remain unchanged',all(sha(PROJECT/p)==v['sha256'] and (PROJECT/p).stat().st_size==v['byteSize'] for p,v in r['inputs'].items()))
levels=[]
for out in r['outputs']:
 c=out['candidateID'];p=ROOT/out['file']
 check(c+' file hash and size',sha(p)==out['sha256'] and p.stat().st_size==out['byteSize'])
 with wave.open(str(p),'rb') as w:
  check(c+' format and frame count',(w.getframerate(),w.getnchannels(),w.getsampwidth(),w.getnframes())==(48000,1,3,741600))
  b=np.frombuffer(w.readframes(w.getnframes()),np.uint8).reshape(-1,3).astype(np.int32);q=b[:,0]+(b[:,1]<<8)+(b[:,2]<<16);q[q>=8388608]-=16777216;x=q.astype(float)/8388608
 rms=20*math.log10(float(np.sqrt(np.mean(x*x))));peak=20*math.log10(float(abs(x).max()));levels.append(rms)
 check(c+' no clipping and peak <= -6dBFS',bool(abs(x).max()<1 and peak<=-6))
 check(c+' independently measured levels agree',abs(rms-out['measured']['rmsDBFS'])<1e-9 and abs(peak-out['measured']['peakDBFS'])<1e-9)
 source=PROJECT/r['sources'][c]['path'];meta=json.loads((PROJECT/f'docs/evidence/C-001B/{c}-results.json').read_text())
 with wave.open(str(source),'rb') as w:raw=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32768
 expected=[]
 for i,s in enumerate(r['segments'],1):
  original=meta['representativeWAV']['segments'][i]
  check(c+' shared event '+str(i),original['label']==s['label'] and original['startFrame']==s['sourceStartFrame'] and original['frameCount']==s['frameCount'] and original['velocity']==64 and abs(original['gain']-.08)<1e-6)
  y=raw[s['sourceStartFrame']:s['sourceStartFrame']+s['frameCount']].copy()
  if s['endFadeFrames']:y[-240:]*=(np.arange(239,-1,-1)/239)
  expected.extend([y,np.zeros(2400)])
 expected=np.concatenate(expected)*10**(out['gainDB']/20)
 check(c+' output matches documented extraction and constant gain',bool(np.max(abs(x-expected))<=.501/8388608))
 check(c+' last gap silent',bool(np.all(x[-2400:]==0)))
check('Two RMS levels match within 0.001dB',max(levels)-min(levels)<.001)
plan=json.loads((ROOT/'full-layer-plan.json').read_text())
for c,p in plan.items():
 ranges=[n for z in p['zones'] for n in range(z['lowMIDI'],z['highMIDI']+1)]
 check(c+' complete planned range and <=1 semitone shift',sorted(ranges)==list(range(33,97)) and all(abs(n-z['rootMIDI'])<=1 for z in p['zones'] for n in range(z['lowMIDI'],z['highMIDI']+1)))
 check(c+' exact planned download sums',p['fullRawLayerBytes']==sum(z['sourceByteSize'] for z in p['zones']) and p['additionalDownloadBytes']==sum(z['sourceByteSize'] for z in p['zones'] if not z['alreadyDownloadedAndVerified']))
files=[p for d in [ROOT,E] for p in d.rglob('*') if p.is_file()]+[PROJECT/'docs/handoffs/A-001C.md']
size=sum(p.stat().st_size for p in files if p.exists())
check('Delivery under 20MiB with 64KiB evidence headroom',size+65536<=20*2**20)
result={'task':'A-001C','status':'passed','checks':checks,'checkCount':len(checks),'deliveryBytesBeforeThisReport':size,'inputFileCount':len(r['inputs']),'humanListening':'NOT_TESTED','hardwarePlayback':False,'finalToneSelection':False,'limitation':'Very low-level PCM16 source rendering quantization amplified by approximately 48dB. Not final comfort/noise-floor validation.'}
(E/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':'passed','checkCount':len(checks),'deliveryBytes':size,'inputFileCount':len(r['inputs'])}))
