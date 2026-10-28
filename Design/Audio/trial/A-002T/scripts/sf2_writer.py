#!/usr/bin/env python3
"""Build two minimal candidate SF2 banks from pinned A-001 PCM24 samples.

No network, third-party downloads, hardware playback or production-code writes.
SoundFont 2.01 binary layout: https://www.synthfont.com/SFSPEC21.PDF
"""
import hashlib
import json
import pathlib
import shutil
import struct
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
AUDIO = ROOT
VERSION = 'a002t-steinway-mono.0.1'
PLAN = json.loads((ROOT.parents[1] / 'comparison/A-001C/full-layer-plan.json').read_text())['vcsl-steinway-b']
RELEASE_TC = round(1200 * np.log2(.4))
CONFIG = {'vcsl-kawai': [33, 42, 60, 96], 'vcsl-steinway-b': [34, 42, 60, 96]}


def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def chunk(kind, data):
    assert len(kind) == 4 and len(data) % 2 == 0
    return kind + struct.pack('<I', len(data)) + data


def list_chunk(kind, data):
    return chunk(b'LIST', kind + data)


def info_string(kind, value):
    data = value.encode('ascii') + b'\0'
    if len(data) % 2:
        data += b'\0'
    return chunk(kind, data)


def name20(value):
    data = value.encode('ascii')
    assert len(data) <= 19
    return data.ljust(20, b'\0')


def gen(op, amount):
    return struct.pack('<HH', op, amount & 65535)


def read_mono16(path, source_record):
    raw_file = path.read_bytes()
    assert len(raw_file) == source_record['byteSize'] and sha(raw_file) == source_record['sha256']
    with wave.open(str(path), 'rb') as w:
        assert (w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getcomptype()) == (2, 3, 48000, 'NONE')
        frames = w.getnframes()
        b = np.frombuffer(w.readframes(frames), np.uint8).reshape(-1, 3).astype(np.int32)
    q = b[:, 0] | b[:, 1] << 8 | b[:, 2] << 16
    signed = np.where(q & 0x800000, q - 0x1000000, q).reshape(-1, 2)
    mono = signed.astype(np.float64).mean(axis=1) / 8388608
    # Divide PCM24 by 256 after an arithmetic stereo average. No normalization,
    # gain change, resampling, pitch correction, filtering or random dither.
    pcm16 = np.rint(mono * 32768).astype('<i2')
    assert np.abs(pcm16.astype(np.int32)).max() < 32767
    decoded = pcm16.astype(np.float64) / 32768
    stats = {'frames': frames, 'durationSeconds': frames / 48000,
             'monoPeakDBFS': float(20 * np.log10(np.abs(decoded).max())),
             'quantizationMaxAbsError': float(np.abs(decoded - mono).max()),
             'monoPCM16SHA256': sha(pcm16.tobytes()),
             'inputStereoPCM24SHA256': source_record['sha256']}
    return pcm16.tobytes(), stats


def make_bank(candidate, roots, source_manifest):
    source_files = {r['path']: r for r in source_manifest['files']}
    pcm = bytearray()
    headers = []
    zones = []
    stats = []
    ibag = bytearray()
    igen = bytearray()
    for index, root in enumerate(roots):
        rel = f'samples/piano_m{root:03d}_v064_rr01.wav'
        raw, measured = read_mono16(AUDIO / candidate / rel, source_files[rel])
        start = len(pcm) // 2
        pcm.extend(raw)
        end = len(pcm) // 2
        pcm.extend(bytes(46 * 2))
        # Required but unused loop-header fields mirror sample extent. No loop
        # has been designed: sampleModes=0 is authoritative for every zone.
        headers.append(struct.pack('<20sIIIIIBbHH', name20(f'Piano m{root:03d}'),
                                   start, end, start, end, 48000, root, 0, 0, 1))
        zone = next(z for z in PLAN['zones'] if z['rootMIDI'] == root)
        low, high = zone['lowMIDI'], zone['highMIDI']
        ibag.extend(struct.pack('<HH', len(igen) // 4, 0))
        generators = [
            (43, low | high << 8), (44, 1 | 127 << 8),
            (8, 13500), (9, 0), (15, 0), (16, 0), (17, 0),
            (33, -12000), (34, -12000), (35, -12000), (36, -12000),
            (37, 0), (38, RELEASE_TC), (48, 0), (54, 0), (56, 100),
            (58, root), (53, index),
        ]
        for op, amount in generators:
            igen.extend(gen(op, amount))
        zones.append({'sampleIndex': index, 'rootMIDI': root, 'lowMIDI': low,
                      'highMIDI': high, 'velocityMin': 1, 'velocityMax': 127,
                      'gainDB': 0, 'releaseMs': 400, 'loop': None,
                      'sampleRate': 48000, 'sampleChannels': 1, 'sampleBits': 16,
                      'sourceCandidatePath': f'Design/Audio/trial/A-002T/{candidate}/{rel}',
                      'sourceSHA256': source_files[rel]['sha256'],
                      'startSamplePoint': start, 'endSamplePointExclusive': end,
                      'guardSamplePoints': 46})
        stats.append({'rootMIDI': root, **measured})
    # Terminals are structural sentinels and never playable samples.
    headers.append(struct.pack('<20sIIIIIBbHH', name20('EOS'), 0, 0, 0, 0, 0, 0, 0, 0, 0))
    ibag.extend(struct.pack('<HH', len(igen) // 4, 0))
    igen.extend(gen(0, 0))
    phdr = struct.pack('<20sHHHIII', name20('Typing Piano Trial'), 0, 0, 0, 0, 0, 0)
    phdr += struct.pack('<20sHHHIII', name20('EOP'), 0, 0, 1, 0, 0, 0)
    inst = struct.pack('<20sH', name20('32 Root Piano'), 0)
    inst += struct.pack('<20sH', name20('EOI'), len(roots))
    info = chunk(b'ifil', struct.pack('<HH', 2, 1))
    info += info_string(b'isng', 'EMU8000')
    info += info_string(b'INAM', candidate + ' A-002T full-range mono trial')
    info += info_string(b'IENG', 'Versilian Studios LLC; A-002T resource processing')
    info += info_string(b'ICOP', 'CC0-1.0 samples; see included license and provenance')
    info += info_string(b'ICMT', 'CANDIDATE. MIDI33-96. Mono PCM16. No loops. Release approx400ms. Engine validation pending.')
    pdta = b''.join([
        chunk(b'phdr', phdr), chunk(b'pbag', struct.pack('<HHHH', 0, 0, 1, 0)),
        chunk(b'pmod', bytes(10)), chunk(b'pgen', gen(41, 0) + gen(0, 0)),
        chunk(b'inst', inst), chunk(b'ibag', bytes(ibag)), chunk(b'imod', bytes(10)),
        chunk(b'igen', bytes(igen)), chunk(b'shdr', b''.join(headers)),
    ])
    bank = chunk(b'RIFF', b'sfbk' + list_chunk(b'INFO', info)
                 + list_chunk(b'sdta', chunk(b'smpl', bytes(pcm))) + list_chunk(b'pdta', pdta))
    return bank, zones, stats

