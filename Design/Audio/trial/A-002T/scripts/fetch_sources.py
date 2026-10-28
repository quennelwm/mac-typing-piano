#!/usr/bin/env python3
import concurrent.futures,hashlib,json,pathlib,shutil,threading,urllib.parse
import requests
ROOT=pathlib.Path(__file__).resolve().parents[1];AUDIO=ROOT.parents[1];PROJECT=AUDIO.parents[1]
E=PROJECT/'docs/evidence/A-002T';E.mkdir(parents=True,exist_ok=True)
PLAN=json.loads((AUDIO/'comparison/A-001C/full-layer-plan.json').read_text())['vcsl-steinway-b']
TREE={r['path']:r for r in json.loads((AUDIO/'source_evidence/vcsl-tree.json').read_text())['tree']}
OLD={r['sourcePath']:r for r in json.loads((AUDIO/'source_evidence/download-ledger.json').read_text())['files']}
BUDGET=110*1048576;LOCK=threading.Lock();COUNTER=E/'network-counter.json'
state=json.loads(COUNTER.read_text()) if COUNTER.exists() else {'receivedAudioBytes':0,'budgetBytes':BUDGET}
assert PLAN['additionalDownloadBytes']==96963856 and PLAN['sourceCommit']=='c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e'
def sha(b):return hashlib.sha256(b).hexdigest()
def validate(b,z):
 assert len(b)==z['sourceByteSize']
 assert hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==z['sourceGitBlob']
def fetch(z):
 meta=TREE[z['sourcePath']];assert meta['sha']==z['sourceGitBlob'] and meta['size']==z['sourceByteSize']
 p=ROOT/'vcsl-steinway-b/originals'/pathlib.Path(z['sourcePath']).name;p.parent.mkdir(parents=True,exist_ok=True)
 url='https://raw.githubusercontent.com/sgossner/VCSL/'+PLAN['sourceCommit']+'/'+urllib.parse.quote(z['sourcePath'],safe='/')
 if p.exists():b=p.read_bytes();origin='existing_A002T'
 elif z['alreadyDownloadedAndVerified']:
  old=AUDIO/OLD[z['sourcePath']]['localPath'];b=old.read_bytes();assert sha(b)==z['cachedSHA256'];validate(b,z);p.write_bytes(b);origin='copied_verified_A001'
 else:
  with requests.get(url,stream=True,timeout=60) as response:
   response.raise_for_status();buf=bytearray()
   for chunk in response.iter_content(65536):
    with LOCK:
     state['receivedAudioBytes']+=len(chunk);COUNTER.write_text(json.dumps(state,indent=2)+'\n')
     assert state['receivedAudioBytes']<=BUDGET,'download budget exceeded'
    buf.extend(chunk);assert len(buf)<=z['sourceByteSize']
   b=bytes(buf)
  validate(b,z);p.write_bytes(b);origin='downloaded_pinned_commit'
 validate(b,z)
 row={**z,'url':url,'localPath':str(p.relative_to(ROOT)),'sha256':sha(b),'actualBytes':len(b),'licenseID':'CC0-1.0','sourceCommit':PLAN['sourceCommit']}
 print(z['rootMIDI'],origin,len(b),'verified',flush=True);return row
if __name__=='__main__':
 frozen=E/'protected-files-before.json'
 if not frozen.exists():
  files=[p for p in AUDIO.rglob('*') if p.is_file() and ROOT not in p.parents]
  files += [p for task in ['A-001','A-001B','A-001C','C-001B'] for p in (PROJECT/f'docs/evidence/{task}').rglob('*') if p.is_file()]
  frozen.write_text(json.dumps({str(p.relative_to(PROJECT)):sha(p.read_bytes()) for p in files},indent=2)+'\n')
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(fetch,PLAN['zones']))
 for name in ['VCSL-CC0.txt','VCSL-README.md']:
  p=ROOT/'vcsl-steinway-b/licenses'/name;p.parent.mkdir(exist_ok=True);shutil.copyfile(AUDIO/'vcsl-steinway-b/licenses'/name,p)
 shutil.copyfile(AUDIO/'vcsl-steinway-b/originals/NORMALIZED.txt',ROOT/'vcsl-steinway-b/licenses/NORMALIZED.txt')
 doc={'task':'A-002T','sourceCommit':PLAN['sourceCommit'],'newAudioBudgetBytes':BUDGET,'approvedMissingSourceBytes':96963856,'totalOriginalAudioBytes':sum(r['actualBytes'] for r in rows),'networkReceiptEvidence':'docs/evidence/A-002T/network-counter.json','files':rows}
 (ROOT/'download-ledger.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
 print('COMPLETE',len(rows),'sources',state,flush=True)
