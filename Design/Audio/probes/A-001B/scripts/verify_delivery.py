#!/usr/bin/env python3
"""Run the static delivery audit and deterministic rebuild; no sampler load."""
import hashlib
import json
import pathlib
import platform
import struct
import subprocess
import sys

import jsonschema

sys.dont_write_bytecode = True
from test_sf2_contract import inspect_bank

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[3]
EVIDENCE = PROJECT / 'docs/evidence/A-001B'
checks = []


def check(label, condition):
    checks.append({'check': label, 'passed': bool(condition)})


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_path(base, name):
    p = pathlib.PurePosixPath(name)
    return not p.is_absolute() and '..' not in p.parts and '://' not in name and (base / p).resolve().is_relative_to(base.resolve())


def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    schema = json.loads((PROJECT / 'contracts/audio.manifest.schema.json').read_text())
    index = json.loads((ROOT / 'trial-index.json').read_text())
    check('two experimental candidates', len(index['trials']) == 2 and not index['finalInstrumentSelected'])
    check('not runtime approved', index['artifactState'] == 'candidate' and not index['runtimeApproved'])
    check('bank total under20MiB', index['totalBankBytes'] < 20 * 1048576)
    check('builder hash', sha(ROOT / index['buildScript']) == index['buildScriptSHA256'])
    bank_results = []
    mutations = []
    for trial in index['trials']:
        ident = trial['id']
        folder = ROOT / ident
        manifest = json.loads((folder / 'audio.manifest.json').read_text())
        errors = list(jsonschema.Draft202012Validator(schema).iter_errors(manifest))
        check(ident + ' contract schema', not errors)
        check(ident + ' candidate sf2', manifest['artifactState'] == 'candidate' and manifest['runtimeFormat'] == 'sf2')
        for record in manifest['files']:
            name = record['path']
            p = folder / name
            check(ident + ' safe path ' + name, safe_path(folder, name))
            check(ident + ' file/hash/size ' + name, p.is_file() and p.stat().st_size == record['byteSize'] and sha(p) == record['sha256'])
        for name in [manifest['processingRecipePath'], manifest['qaReportPath'], manifest['instrument']['parametersFile'], manifest['instrument']['bankFile']]:
            check(ident + ' reference ' + name, safe_path(folder, name) and (folder / name).is_file())
        check(ident + ' copied license matches A001', (folder / 'licenses/VCSL-CC0.txt').read_bytes() == (PROJECT / f'Design/Audio/{ident}/licenses/VCSL-CC0.txt').read_bytes())
        bank = ROOT / trial['bankFile']
        data = bank.read_bytes()
        parsed = inspect_bank(data)
        coverage = sorted(n for z in parsed['zones'] for n in range(z['lowMIDI'], z['highMIDI'] + 1))
        check(ident + ' binary coverage equals index and manifest', coverage == trial['coverageMIDI'] == manifest['coverageMIDI'])
        check(ident + ' actual hash/size equals index', sha(bank) == trial['sha256'] and len(data) == trial['byteSize'])
        params = json.loads((folder / 'instrument-parameters.json').read_text())
        check(ident + ' encoded 500ms', params['releaseTimecents'] == -1200 and params['releaseSecondsEncoded'] == 2 ** (-1200/1200))
        check(ident + ' explicitly lossy mono16', params['sampleChannels'] == 1 and params['sampleBits'] == 16 and 'lossy' in params['channelConversion'] and 'lossy' in params['bitDepthConversion'])
        check(ident + ' quantization bounded half LSB16', all(s['quantizationMaxAbsError'] <= 1/65536 for s in params['pcmConversionMetrics']))
        # Exercise malformed real-bank fixtures in memory; do not change on-disk artifacts.
        cases = []
        bad = bytearray(data); bad[8:12] = b'WAVE'; cases.append(('wrong RIFF form', bad))
        cases.append(('truncated bank', data[:-2]))
        bad = bytearray(data); pos = data.find(b'INAM')
        struct.pack_into('<I', bad, pos + 4, struct.unpack_from('<I', data, pos + 4)[0] - 1)
        cases.append(('odd INFO declared string length', bad))
        igen = data.rfind(b'igen') + 8
        bad = bytearray(data); struct.pack_into('<H', bad, igen + 2, 33 | (96 << 8))
        cases.append(('unauthorized full-range zone', bad))
        size = struct.unpack_from('<I', data, igen - 4)[0]
        generator_records = list(struct.iter_unpack('<HH', data[igen:igen + size]))
        sample_op = next(i for i, (op, value) in enumerate(generator_records) if op == 53)
        bad = bytearray(data); struct.pack_into('<H', bad, igen + sample_op * 4 + 2, 4)
        cases.append(('sampleID points at EOS', bad))
        shdr = data.rfind(b'shdr') + 8
        end = struct.unpack_from('<I', data, shdr + 24)[0]
        smpl = data.find(b'smpl') + 8
        bad = bytearray(data); bad[smpl + end * 2] = 1
        cases.append(('nonzero guard point', bad))
        for label, broken in cases:
            error = None
            try:
                inspect_bank(bytes(broken))
            except ValueError as exc:
                error = str(exc)
            check(ident + ' rejects ' + label, error is not None)
            mutations.append({'candidate': ident, 'fixture': label, 'rejected': error is not None, 'error': error})
        bank_results.append({'id': ident, 'byteSize': len(data), 'sha256': sha(bank),
                             'zones': parsed['zones'], 'coverageMIDI': coverage,
                             'uncoveredMIDI': trial['uncoveredMIDI'],
                             'samplePCM16SHA256': [hashlib.sha256(s['pcm']).hexdigest() for s in parsed['samples']]})
    before_inputs = json.loads((EVIDENCE / 'a001-before.json').read_text())
    changed = [name for name, digest in before_inputs['files'].items() if not (PROJECT / name).is_file() or sha(PROJECT / name) != digest]
    check('all A001 originals unchanged', not changed)
    # Preserve content digests of the entire self-contained candidate payload and index.
    stable_files = [ROOT / 'trial-index.json'] + sorted(p for t in index['trials'] for p in (ROOT / t['id']).rglob('*') if p.is_file())
    before = {str(p.relative_to(ROOT)): sha(p) for p in stable_files}
    run = subprocess.run([sys.executable, str(ROOT / 'scripts/build_sf2_trials.py')], text=True, capture_output=True)
    (EVIDENCE / 'rebuild.log').write_text(run.stdout + run.stderr)
    check('rebuild exit zero', run.returncode == 0)
    changed_outputs = [name for name, digest in before.items() if sha(ROOT / name) != digest]
    check('rebuilt banks and metadata byte identical', not changed_outputs)
    tests = subprocess.run([sys.executable, str(ROOT / 'scripts/test_sf2_contract.py')], text=True, capture_output=True)
    (EVIDENCE / 'contract-green.log').write_text(tests.stdout + tests.stderr)
    check('independent binary and source PCM tests pass', tests.returncode == 0)
    failures = [c for c in checks if not c['passed']]
    report = {'task': 'A-001B', 'date': '2026-10-28', 'status': 'PASS' if not failures else 'FAIL',
              'python': platform.python_version(), 'numpy': __import__('numpy').__version__,
              'checkCount': len(checks), 'failureCount': len(failures), 'failures': failures,
              'checks': checks, 'banks': bank_results, 'mutationChecks': mutations,
              'inputProtection': {'fileCount': len(before_inputs['files']), 'changedFiles': changed},
              'reproducibility': {'fileCount': len(before), 'byteIdentical': not changed_outputs,
                                  'changedFiles': changed_outputs, 'sha256': before},
              'samplerLoadStatus': 'NOT_TESTED', 'hardwareAndListening': 'NOT_TESTED',
              'full64NoteCoverage': False, 'newAudioDownloads': 0}
    (EVIDENCE / 'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'checks': len(checks), 'failures': failures,
                      'originalFilesUnchanged': len(before_inputs['files']) - len(changed),
                      'rebuiltFilesByteIdentical': len(before) - len(changed_outputs)}, ensure_ascii=False, indent=2))
    raise SystemExit(bool(failures))


if __name__ == '__main__':
    main()
