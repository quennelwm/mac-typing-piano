#!/usr/bin/env python3
"""Independent binary/PCM/source contracts; does not import the bank writer."""
import hashlib,json,pathlib,struct,sys,wave
import numpy as np
import jsonschema
ROOT=pathlib.Path(__file__).resolve().parents[1];AUDIO=ROOT.parents[1];PROJECT=AUDIO.parents[1];E=PROJECT/'docs/evidence/A-002T';C='vcsl-steinway-b';F=ROOT/C
checks=[]
def check(label,ok):
 if not ok:raise AssertionError(label)
 checks.append({'check':label,'status':'passed'})
def sha(b):return hashlib.sha256(b).hexdigest()
def doc(p):return json.loads(p.read_text())
def decode24(p):
 with wave.open(str(p),'rb') as w:
  assert (w.getframerate(),w.getnchannels(),w.getsampwidth())==(48000,2,3)
  b=np.frombuffer(w.readframes(w.getnframes()),np.uint8).reshape(-1,3).astype(np.int64)
 v=b@np.array([1,256,65536]);v[v>=8388608]-=16777216;return v.reshape(-1,2)
def verify():
 index=doc(ROOT/'trial-index.json');t=index['trials'][0];bank=(ROOT/t['bankFile']).read_bytes()
 check('Candidate and replaceable trial state',index['artifactState']=='candidate' and index['finalInstrumentSelected'] is False and index['runtimeApproved'] is False)
 check('Index single bank binding',len(index['trials'])==1 and len(bank)==t['byteSize'] and sha(bank)==t['sha256'] and (t['program'],t['bankMSB'],t['bankLSB'])==(0,121,0))
 namespace={'__file__':str(ROOT/'scripts/inspect_sf2.py'),'__name__':'independent_parser'}
 exec(compile((ROOT/'scripts/inspect_sf2.py').read_text(),str(ROOT/'scripts/inspect_sf2.py'),'exec'),namespace)
 decoded=namespace['inspect_bank'](bank)
 check('Independent binary RIFF/SF2 structure, guards, selectors, no loops or FX, release -1586',True)
 zones=decoded['zones'];coverage=[n for z in zones for n in range(z['lowMIDI'],z['highMIDI']+1)]
 check('All64 notes exactly once; no out-of-range zones',sorted(coverage)==list(range(33,97)) and len(set(coverage))==64)
 check('32 roots and <=1-semitone map',len(zones)==32 and [z['rootMIDI'] for z in zones]==list(range(34,97,2)) and zones==t['zones'])
 check('Index complete coverage',t['coverageMIDI']==list(range(33,97)) and t['uncoveredMIDI']==[])
 m=doc(F/'audio.manifest.json');jsonschema.validate(m,doc(PROJECT/'contracts/audio.manifest.schema.json'));check('Manifest schema',True)
 records=m['files'];check('Manifest no duplicate paths',len({r['path'] for r in records})==len(records))
 for r in records:
  p=pathlib.Path(r['path']);check('Manifest '+r['path'],not p.is_absolute() and '..' not in p.parts and (F/p).is_file() and len((F/p).read_bytes())==r['byteSize'] and sha((F/p).read_bytes())==r['sha256'])
 check('All three source license/notice files present',all(any(r['path']=='licenses/'+name for r in records) for name in ['VCSL-CC0.txt','VCSL-README.md','NORMALIZED.txt']))
 ledger=doc(ROOT/'download-ledger.json');plan=doc(AUDIO/'comparison/A-001C/full-layer-plan.json')[C];tree={r['path']:r for r in doc(AUDIO/'source_evidence/vcsl-tree.json')['tree']}
 check('Pinned source commit and32 records',ledger['sourceCommit']==plan['sourceCommit'] and len(ledger['files'])==32)
 check('Approved28 files and exact bytes',len(plan['missingRootMIDI'])==28 and sum(r['sourceByteSize'] for r in ledger['files'] if not r['alreadyDownloadedAndVerified'])==96963856)
 check('Actual received audio within110MiB',doc(E/'network-counter.json')['receivedAudioBytes']<=110*1048576 and doc(E/'network-counter.json')['receivedAudioBytes']>=96963856)
 for r in ledger['files']:
  b=(ROOT/r['localPath']).read_bytes();blob=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest();tree_row=tree[r['sourcePath']]
  check('Original root '+str(r['rootMIDI']),sha(b)==r['sha256'] and blob==r['sourceGitBlob']==tree_row['sha'] and len(b)==r['sourceByteSize']==tree_row['size'] and r['licenseID']=='CC0-1.0')
 params=doc(F/'instrument-parameters.json');reports=doc(F/'processing-metrics.json');metrics={r['rootMIDI']:r for r in params['pcmConversionMetrics']};qa={r['rootMIDI']:r for r in reports['sourceSamples']}
 check('Same candidate-wide gain as A001',reports['candidateWideGainDB']==doc(AUDIO/C/'qa_metrics.json')['candidateWideGainDB'])
 check('Encoded400ms within0.2ms and requested parameters',params['releaseTimecents']==-1586 and abs(params['releaseSecondsEncoded']-.4)<.0002 and params['requestedReleaseMs']==400)
 for s in decoded['samples']:
  n=s['root'];x=decode24(F/f'samples/piano_m{n:03d}_v064_rr01.wav');want=np.rint(x.sum(axis=1)/512).astype('<i2');actual=np.frombuffer(s['pcm'],'<i2');st=qa[n]
  check('Root '+str(n)+' PCM byte match, frames <=8s',want.tobytes()==s['pcm'] and s['frames']==len(want) and 4800<len(want)<=384000 and sha(s['pcm'])==metrics[n]['monoPCM16SHA256'])
  check('Root '+str(n)+' finite/nonempty/unclipped and bounded quantization',0<int(abs(actual.astype(np.int32)).max())<32767 and np.isfinite(actual).all() and metrics[n]['quantizationMaxAbsError']<=.5/32768+1e-12 and st['processedMetrics']['samplesAtOrAboveFullScale']==0 and st['monoFirst750msRMSdBFS']>-100)
  check('Root '+str(n)+' terminal fade and source format',actual[-1]==0 and st['sourceChannels']==2 and st['sourceBits']==24 and st['sourceSampleRate']==44100)
  if n in [34,42,60,96]:check('Legacy root '+str(n)+' processed WAV unchanged',sha((F/f'samples/piano_m{n:03d}_v064_rr01.wav').read_bytes())==sha((AUDIO/C/f'samples/piano_m{n:03d}_v064_rr01.wav').read_bytes()))
 protected=doc(E/'protected-files-before.json');changed=[p for p,h in protected.items() if not (PROJECT/p).exists() or sha((PROJECT/p).read_bytes())!=h]
 check('Frozen prior artifacts unchanged',not changed)
 # Verify parser rejects actual malformed binary cases, not only valid bank.
 bad=bytearray(bank);bad[4:8]=struct.pack('<I',len(bank));cases={'wrong RIFF extent':bytes(bad),'truncated sample table':bank[:-12],'wrong form':bank[:8]+b'WAVE'+bank[12:]}
 for label,b in cases.items():
  rejected=False
  try:namespace['inspect_bank'](b)
  except ValueError:rejected=True
  check('Reject '+label,rejected)
 result={'task':'A-002T','status':'passed','checkCount':len(checks),'checks':checks,'bankSHA256':sha(bank),'bankBytes':len(bank),'frozenInputFileCount':len(protected),'pitchReviewRoots':[n for n,r in qa.items() if r['pitchReviewFlag']],'monoReviewRoots':[n for n,r in qa.items() if r['monoReviewFlag']],'sourcePrecision':'Originalstereo24->stereo24processed->mono16bank, not amplified C001B render','engineLoad':'NOT_TESTED_BY_AUDIO_ROLE','hardwareListening':'NOT_TESTED','reproducibilityEvidence':'reproducibility.json (separate actual rebuild evidence)'}
 (E/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({k:v for k,v in result.items() if k!='checks'},ensure_ascii=False,indent=2))
if __name__=='__main__':verify()
