#!/usr/bin/env python3
"""Independent candidate integrity, contract and PCM checks; no hardware pass claims."""
import hashlib
import json
import pathlib
import subprocess
import wave

import jsonschema
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[1]
EVIDENCE = PROJECT / 'docs/evidence/A-001'
checks = []


def check(name, value):
    checks.append({'check': name, 'passed': bool(value)})


def within(root, value):
    p = pathlib.PurePosixPath(value)
    return not p.is_absolute() and '..' not in p.parts and '://' not in value and (root / p).resolve().is_relative_to(root.resolve())


def validate():
    schema = json.loads((PROJECT / 'contracts/audio.manifest.schema.json').read_text())
    ledger = json.loads((ROOT / 'source_evidence/download-ledger.json').read_text())
    check('download preflight below 80 MiB', ledger['sampleAndNoteBytes'] < 80 * 1048576)
    check('download accounting exact', sum(f['actualBytes'] for f in ledger['files']) == ledger['sampleAndNoteBytes'])
    for f in ledger['files']:
        b = (ROOT / f['localPath']).read_bytes()
        check(f"original SHA256 {f['localPath']}", hashlib.sha256(b).hexdigest() == f['sha256'])
        check(f"original Git blob {f['localPath']}", hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest() == f['gitBlobSHA1'])
        check(f"original length {f['localPath']}", len(b) == f['expectedBytes'] == f['actualBytes'])
    native_logs = []
    for candidate in ['vcsl-kawai', 'vcsl-steinway-b']:
        folder = ROOT / candidate
        m = json.loads((folder / 'audio.manifest.json').read_text())
        errors = list(jsonschema.Draft202012Validator(schema).iter_errors(m))
        check(candidate + ' schema', not errors)
        check(candidate + ' not ready', m['artifactState'] == 'candidate' and m['runtimeFormat'] is None and m['instrument'] is None)
        check(candidate + ' partial coverage', len(m['coverageMIDI']) == 4 and len(m['coverageMIDI']) < 64)
        for f in m['files']:
            check(candidate + ' path ' + f['path'], within(folder, f['path']))
            p = folder / f['path']
            check(candidate + ' file ' + f['path'], p.is_file())
            check(candidate + ' hash ' + f['path'], hashlib.sha256(p.read_bytes()).hexdigest() == f['sha256'])
            check(candidate + ' size ' + f['path'], p.stat().st_size == f['byteSize'])
        for key in ['qaReportPath', 'processingRecipePath']:
            check(candidate + ' ' + key, within(folder, m[key]) and (folder / m[key]).is_file())
        check(candidate + ' license matches original', (folder / 'licenses/VCSL-CC0.txt').read_bytes() == (ROOT / 'source_evidence/LICENSE').read_bytes())
        metrics = json.loads((folder / 'qa_metrics.json').read_text())
        for r in metrics['sourceSamples']:
            check(candidate + f" estimated pitch MIDI{r['rootMIDI']}", abs(r['pitchEvidence']['estimatedCentsFromEqualTemperament']) < 35)
        wav_paths = sorted((folder / 'samples').glob('*.wav')) + [folder/'audition.wav', folder/'stress-preview.wav']
        check(candidate + ' four prepared samples', len(wav_paths) == 6)
        for p in wav_paths:
            with wave.open(str(p), 'rb') as w:
                check(str(p.relative_to(ROOT)) + ' PCM format', (w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getcomptype()) == (48000, 2, 3, 'NONE'))
                frames = w.getnframes()
                raw = w.readframes(frames)
                check(str(p.relative_to(ROOT)) + ' complete PCM', len(raw) == frames * 6 and frames > 0)
            b = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int32)
            q = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
            q = np.where(q & 0x800000, q - 0x1000000, q)
            check(str(p.relative_to(ROOT)) + ' not clipped', np.max(np.abs(q)) < 8388607)
            check(str(p.relative_to(ROOT)) + ' nonempty signal', np.max(np.abs(q)) > 100)
            check(str(p.relative_to(ROOT)) + ' zero final frame', np.max(np.abs(q[-2:])) == 0)
            if p.name == 'audition.wav':
                check(candidate + ' audition 28 sec', frames == 28 * 48000)
                peak = 20 * np.log10(np.max(np.abs(q)) / 8388608)
                check(candidate + ' independently measured preview peak', abs(peak - metrics['audition']['peakDBFS']) < .001)
            run = subprocess.run(['/usr/bin/afinfo', str(p)], text=True, capture_output=True)
            check(str(p.relative_to(ROOT)) + ' afinfo recognized', run.returncode == 0 and '48000' in run.stdout)
            native_logs.append(str(p.relative_to(ROOT)) + '\n' + run.stdout + run.stderr)
    by_key = {k['physicalKeyID']: k for k in json.loads((PROJECT / 'contracts/keymap.ansi64.v0.1.json').read_text())['keys']}
    events = json.loads((ROOT / 'audition-events.json').read_text())
    for e in events['events']:
        check('synthetic mapping ' + str(e['timeSeconds']), by_key[e['physicalKeyID']]['midiNote'] == e['midiNote'])
        for candidate in ['vcsl-kawai', 'vcsl-steinway-b']:
            roots = json.loads((ROOT / candidate / 'audio.manifest.json').read_text())['coverageMIDI']
            check(candidate + ' transpose within 3', min(abs(r - e['midiNote']) for r in roots) <= 3)
    proposals = json.loads((ROOT / 'proposed-zones.json').read_text())
    for candidate, proposal in proposals.items():
        covered = [n for z in proposal['zones'] for n in range(z['lowMIDI'], z['highMIDI'] + 1)]
        check(candidate + ' mathematical proposal covers each target once', sorted(covered) == list(range(33, 97)))
        check(candidate + ' proposal not approved', proposal['runtimeApproved'] is False)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / 'native-format-check.txt').write_text('\n'.join(native_logs))
    failures = [c for c in checks if not c['passed']]
    report = {'task': 'A-001', 'status': 'PASS' if not failures else 'FAIL',
              'checkCount': len(checks), 'failureCount': len(failures),
              'checks': checks, 'failures': failures,
              'limitations': ['Static/numeric/file decoding checks only', 'No subjective listening',
                             'No SF2/DLS load', 'No full 64-note audio', 'No real sampler polyphony or latency']}
    (EVIDENCE / 'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'checks': len(checks), 'failures': failures}, ensure_ascii=False, indent=2))
    raise SystemExit(bool(failures))


if __name__ == '__main__':
    validate()
