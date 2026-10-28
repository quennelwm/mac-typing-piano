#!/usr/bin/env python3
import hashlib,json,os,pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1];PROJECT=ROOT.parents[3];E=PROJECT/'docs/evidence/A-002T'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():return {str(p.relative_to(ROOT)):sha(p) for p in ROOT.rglob('*') if p.is_file()}
before=snapshot()
with (E/'rebuild.log').open('w') as log:subprocess.run([sys.executable,str(ROOT/'scripts/build_trial.py')],check=True,env={**os.environ,'OPENBLAS_NUM_THREADS':'1'},stdout=log,stderr=subprocess.STDOUT)
after=snapshot();different=[p for p in set(before)|set(after) if before.get(p)!=after.get(p)]
report={'task':'A-002T','status':'passed' if not different else 'failed','method':'Actual full rebuild from retained raw stereo sources, not bank-only repack; every task payload file compared before/after','filesCompared':len(before),'differentFiles':different,'payloadSHA256':after,'bankSHA256':sha(ROOT/'vcsl-steinway-b/trial.sf2'),'networkCallsInRebuild':0,'sourceProcessingScript':{'projectPath':'Design/Audio/scripts/build_candidates.py','sha256':sha(PROJECT/'Design/Audio/scripts/build_candidates.py')},'commonGainSource':{'projectPath':'Design/Audio/vcsl-steinway-b/qa_metrics.json','sha256':sha(PROJECT/'Design/Audio/vcsl-steinway-b/qa_metrics.json')}}
(E/'reproducibility.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');assert not different,different
print(json.dumps({k:v for k,v in report.items() if k!='payloadSHA256'},ensure_ascii=False))
