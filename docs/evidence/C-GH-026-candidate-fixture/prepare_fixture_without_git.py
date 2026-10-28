#!/usr/bin/env python3
"""Run the unchanged preflight checks in an empty directory, without querying Git metadata."""
import importlib.util
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[3]
output = Path(sys.argv[1]).resolve()
assert output.is_relative_to(root), 'summarize requires project-relative artifact paths'
assert not output.exists() or not any(output.iterdir()), 'use a new, empty output directory'
os.environ['TYPING_PIANO_EVIDENCE_DIR'] = str(output)
spec = importlib.util.spec_from_file_location('candidate_verifier', root / 'Code/Scripts/verify_candidate_banks.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
def metadata_only(args, **kwargs):
    assert args == ['git', 'rev-parse', 'HEAD']
    return 'NOT_QUERIED_no_Git_operations'
# Only the informational headAtPreflight field is replaced; all original schema,
# path, source/asset hash, format, selector and budget checks execute unchanged.
module.subprocess = SimpleNamespace(check_output=metadata_only)
module.preflight()
(output / 'preflight-invocation.json').write_text(json.dumps({
    'mode': 'original preflight with only Git metadata query suppressed',
    'gitExecuted': False, 'integrityChecksModified': False,
    'helper': str(Path(__file__).relative_to(root))}, indent=2) + '\n')
