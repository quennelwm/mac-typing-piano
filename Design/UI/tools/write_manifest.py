#!/usr/bin/env python3
"""Inventory final UI deliverables; intermediate GIF frames are reproducible scratch output."""
from pathlib import Path
import hashlib,json
ui=Path(__file__).resolve().parents[1]
records=[]
for p in sorted(ui.rglob('*')):
    if not p.is_file():continue
    rel=p.relative_to(ui).as_posix()
    if rel=='delivery-manifest.json' or rel.startswith('qa/frames/') or '__pycache__' in rel:continue
    records.append({'path':rel,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'byteSize':p.stat().st_size})
manifest={'artifactState':'design_proposal','version':'quiet-ivory-u001.0.3','excludes':['delivery-manifest.json (self)','qa/frames/** (reproducible intermediate frames)','**/__pycache__/**'],'files':records,'totalBytes':sum(r['byteSize']for r in records)}
(ui/'delivery-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
for r in records:
    p=ui/r['path'];assert p.stat().st_size==r['byteSize'] and hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256']
print(f"Manifest: {len(records)} deliverables, {manifest['totalBytes']} bytes, all hashes rechecked.")
