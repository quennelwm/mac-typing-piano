#!/usr/bin/env python3
"""Download only pinned, pre-sized A-001 evidence/samples; never clone a library."""
import datetime, hashlib, json, pathlib, urllib.parse, requests
ROOT=pathlib.Path(__file__).resolve().parents[1]
EVIDENCE=ROOT/'source_evidence'
BUDGET=80*1024*1024
commit=json.loads((EVIDENCE/'vcsl-commit.json').read_text())['sha']
tree={e['path']:e for e in json.loads((EVIDENCE/'vcsl-tree.json').read_text())['tree']}
choices={
 'vcsl-kawai': ['Chordophones/Zithers/Grand Piano, Kawai/Legacy.txt']+[f'Chordophones/Zithers/Grand Piano, Kawai/Sustains/GPiano_sus_{n}_v2_rr1_Player.wav' for n in ['A1','C4','C7','A0','C3','C6','C1','F#1']],
 'vcsl-steinway-b':['Chordophones/Zithers/Grand Piano, Steinway B/NORMALIZED.txt']+[f'Chordophones/Zithers/Grand Piano, Steinway B/NoSus/JHPiano_NoSus_Close_{n}_vl2_rr1.wav' for n in ['A#1','C4','C7','F#2']]
}
size=sum(tree[p]['size'] for paths in choices.values() for p in paths)
assert size < BUDGET
print('Preflight selected bytes:',size,flush=True)
ledger=[]
s=requests.Session(); s.headers['User-Agent']='TypingPiano-A001-candidate-download'
for candidate,paths in choices.items():
    for path in paths:
        meta=tree[path]; out=ROOT/candidate/'originals'/pathlib.Path(path).name
        url=f'https://raw.githubusercontent.com/sgossner/VCSL/{commit}/'+urllib.parse.quote(path,safe='/')
        if not out.exists():
            r=s.get(url,stream=True,timeout=45); r.raise_for_status()
            if 'content-length' in r.headers and not r.headers.get('content-encoding'):
                assert int(r.headers['content-length'])==meta['size']
            data=bytearray()
            for chunk in r.iter_content(65536):
                data.extend(chunk)
                if len(data)>meta['size']: raise RuntimeError('Size exceeded preflight')
            assert len(data)==meta['size']
            assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==meta['sha']
            out.parent.mkdir(parents=True,exist_ok=True); out.write_bytes(data)
        data=out.read_bytes()
        assert len(data)==meta['size']
        assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==meta['sha']
        ledger.append({'candidate':candidate,'sourcePath':path,'url':url,'localPath':str(out.relative_to(ROOT)),'expectedBytes':meta['size'],'actualBytes':len(data),'gitBlobSHA1':meta['sha'],'sha256':hashlib.sha256(data).hexdigest()})
        print(candidate,out.name,len(data),'verified',flush=True)
(EVIDENCE/'download-ledger.json').write_text(json.dumps({'date':'2026-10-28','retrievedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sourceCommit':commit,'budgetBytes':BUDGET,'sampleAndNoteBytes':size,'files':ledger},indent=2)+'\n')
