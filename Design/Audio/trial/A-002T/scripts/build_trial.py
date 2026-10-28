#!/usr/bin/env python3
import hashlib,json,pathlib,platform,sys,wave
import numpy as np
ROOT=pathlib.Path(__file__).resolve().parents[1];AUDIO=ROOT.parents[1];PROJECT=AUDIO.parents[1]
E=PROJECT/'docs/evidence/A-002T';C='vcsl-steinway-b';F=ROOT/C

def load_code(p):
 namespace={'__file__':str(p),'__name__':'resource_helpers'};exec(compile(p.read_text(),str(p),'exec'),namespace);return namespace
P=load_code(AUDIO/'scripts/build_candidates.py');W=load_code(ROOT/'scripts/sf2_writer.py')
def sha(b):return hashlib.sha256(b).hexdigest()
def dump(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def build():
 ledger=json.loads((ROOT/'download-ledger.json').read_text());plan=W['PLAN'];assert len(ledger['files'])==32
 oldqa=json.loads((AUDIO/C/'qa_metrics.json').read_text());gain_db=oldqa['candidateWideGainDB'];gain=10**(gain_db/20)
 reports=[];source_files=[]
 for row in ledger['files']:
  original=ROOT/row['localPath'];raw=original.read_bytes();assert sha(raw)==row['sha256']
  x,sr,width=P['read_wav'](original);assert sr==44100 and width==3 and np.isfinite(x).all()
  source_metrics=P['metrics'](x,sr);assert source_metrics['samplesAtOrAboveFullScale']==0 and abs(x).max()>0
  threshold=max(abs(x).max()*.001,2/2**(width*8-1));hits=np.flatnonzero(abs(x).max(axis=1)>=threshold);assert len(hits)>0
  onset=int(hits[0]);trim=max(0,onset-round(.002*sr));y=P['resample'](x[trim:trim+8*sr],sr/48000)
  tail=min(3840,len(y));y[-tail:]*=np.cos(np.linspace(0,np.pi/2,tail))[:,None]**2;y*=gain
  assert abs(y).max()<1
  root=row['rootMIDI'];rel=f'samples/piano_m{root:03d}_v064_rr01.wav';out=F/rel;P['write_wav'](out,y)
  decoded,_,_=P['read_wav'](out);mono=decoded.mean(axis=1);side=(decoded[:,0]-decoded[:,1])/2
  front=mono[:36000];assert np.sqrt(np.mean(front**2))>1e-5 and len(mono)>4800
  measured=P['metrics'](decoded);pitch=P['pitch_evidence'](x[trim:],sr,root)
  report={'rootMIDI':root,'originalPath':row['localPath'],'originalSHA256':row['sha256'],'sourceSampleRate':sr,'sourceBits':width*8,'sourceChannels':2,'sourceMetrics':source_metrics,'thresholdDBFS':P['db'](threshold),'firstThresholdCrossingMs':onset/sr*1000,'trimmedLeadingMs':trim/sr*1000,'processedMetrics':measured,'monoFirst750msRMSdBFS':P['db'](np.sqrt(np.mean(front**2))),'monoToStereoRMSdB':P['db'](np.sqrt(np.mean(mono**2))/np.sqrt(np.mean(decoded**2))),'dcMean':float(mono.mean()),'pitchEvidence':pitch,'pitchReviewFlag':abs(pitch['estimatedCentsFromEqualTemperament'])>20,'monoReviewFlag':bool(np.sqrt(np.mean(mono**2))/np.sqrt(np.mean(decoded**2))<.5)}
  reports.append(report);source_files.append({'path':rel,'byteSize':out.stat().st_size,'sha256':sha(out.read_bytes())})
  print('processed',root,'peak',round(measured['peakDBFS'],2),'cents',round(pitch['estimatedCentsFromEqualTemperament'],2),flush=True)
 bank,zones,pcm_metrics=W['make_bank'](C,plan['rootMIDI'],{'files':source_files})
 assert [n for z in zones for n in range(z['lowMIDI'],z['highMIDI']+1)]==list(range(33,97))
 target=F/'trial.sf2';tmp=F/'trial.sf2.tmp';tmp.write_bytes(bank);tmp.replace(target)
 # Keep parameter keys compatible with the tested A-001B integration index.
 params=json.loads((AUDIO/'probes/A-001B'/C/'instrument-parameters.json').read_text())
 params.update({'audioPackVersion':W['VERSION'],'releaseTimecents':W['RELEASE_TC'],'releaseSecondsEncoded':float(2**(W['RELEASE_TC']/1200)),'requestedReleaseMs':400,'selectorStatus':'SAME_SELECTOR_AS_C001B_NEW_BANK_RUNTIME_PENDING','soundStatus':'NEW_BANK_RUNTIME_AND_LISTENING_PENDING','zones':zones,'pcmConversionMetrics':pcm_metrics})
 dump(F/'instrument-parameters.json',params)
 dump(F/'processing-metrics.json',{'task':'A-002T','candidateWideGainDB':gain_db,'gainPolicy':'Reuse A001 Steinway common gain for all32 roots; no per-note normalization','sampleFormat':'48kHz stereo PCM24 intermediates -> arithmetic mono PCM16 SF2','sourceSamples':reports,'subjectiveListening':'NOT_TESTED','engineLoad':'NOT_TESTED'})
 dump(F/'source_records.json',{'sourceCommit':plan['sourceCommit'],'licenseID':'CC0-1.0','upstreamSources':ledger['files'],'processedSources':source_files,'licenseNote':'VCSL license and README copied unchanged, plus upstream NORMALIZED.txt','modifications':'Same candidate-wide A001 gain, onset threshold trim with2ms pre-roll, max8s,64tap sinc48kHz,last80ms cosine-squared fade,stereo24 rounding,arithmetic(L+R)/2,nearest-even PCM16,no dither/no pitch correction/no loops,no FX,approx400ms encoded release.'})
 manifest=json.loads((AUDIO/'probes/A-001B'/C/'audio.manifest.json').read_text())
 manifest.update({'audioPackVersion':W['VERSION'],'instrumentName':'VCSL Steinway B 64-note mono trial','coverageMIDI':list(range(33,97)),'files':[],'readinessNote':'CANDIDATE. Full64-note encoded coverage from32 roots; not final tone selection. New bank engine/hardware/listening validation pending. Mono16 lossy reduction; inherited recorded tuning kept; trial release approx400ms.'})
 manifest['instrument']['selectorStatus']=params['selectorStatus'];manifest['licenseRecords'][0]['modifications']=json.loads((F/'source_records.json').read_text())['modifications']
 for p in sorted(F.rglob('*')):
  if p.is_file() and p.name!='audio.manifest.json':
   manifest['files'].append({'path':str(p.relative_to(F)),'sha256':sha(p.read_bytes()),'byteSize':p.stat().st_size,'role':'bank' if p.suffix=='.sf2' else 'license' if p.parent.name=='licenses' else 'sample' if p.suffix=='.wav' else 'qa'})
 dump(F/'audio.manifest.json',manifest)
 t=json.loads((AUDIO/'probes/A-001B/trial-index.json').read_text())['trials'][1]
 assert t['id']==C
 t.update({'byteSize':len(bank),'sha256':sha(bank),'coverageMIDI':list(range(33,97)),'uncoveredMIDI':[],'rootMIDI':plan['rootMIDI'],'zones':[{k:z[k] for k in ['rootMIDI','lowMIDI','highMIDI']} for z in zones],'releaseTimecents':W['RELEASE_TC'],'releaseSecondsEncoded':params['releaseSecondsEncoded'],'selectorStatus':params['selectorStatus'],'gainNote':'.08 legacy probe starting point only, NOT calibrated. Save Float32 or adequately scaled renders; do not amplify low-level PCM16 by48dB as quality evidence.'})
 index={'taskID':'A-002T','trialVersion':W['VERSION'],'artifactState':'candidate','pathBase':'Directory containing this trial-index.json','format':'SF2 2.01','noteNaming':'C4=MIDI60','midiTargetRange':{'min':33,'max':96},'totalBankBytes':len(bank),'validationStatus':'Static source/build complete; run scripts/verify_trial.py. Code role owns actual sampler verification and mixer calibration.','buildScript':'scripts/build_trial.py','buildScriptSHA256':sha(pathlib.Path(__file__).read_bytes()),'runtimeApproved':False,'finalInstrumentSelected':False,'trialDefaultCandidate':C,'trials':[t]}
 tmp=ROOT/'trial-index.json.tmp';dump(tmp,index);tmp.replace(ROOT/'trial-index.json')
 dump(E/'environment.json',{'python':sys.version,'platform':platform.platform(),'numpy':np.__version__,'newDependenciesInstalled':False})
 print('INTEGRATION_READY',str(ROOT/'trial-index.json'),len(bank),sha(bank),flush=True)
if __name__=='__main__':build()
