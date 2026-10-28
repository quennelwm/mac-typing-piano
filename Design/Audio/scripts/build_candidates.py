#!/usr/bin/env python3
"""A-001 deterministic offline resource audition, not a production sampler."""
import hashlib
import json
import math
import pathlib
import shutil
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[1]
SR = 48000
CONFIG = {
    'vcsl-kawai': [(33, 'GPiano_sus_A0_v2_rr1_Player.wav'),
                   (42, 'GPiano_sus_F#1_v2_rr1_Player.wav'),
                   (60, 'GPiano_sus_C3_v2_rr1_Player.wav'),
                   (96, 'GPiano_sus_C6_v2_rr1_Player.wav')],
    'vcsl-steinway-b': [(34, 'JHPiano_NoSus_Close_A#1_vl2_rr1.wav'),
                        (42, 'JHPiano_NoSus_Close_F#2_vl2_rr1.wav'),
                        (60, 'JHPiano_NoSus_Close_C4_vl2_rr1.wav'),
                        (96, 'JHPiano_NoSus_Close_C7_vl2_rr1.wav')],
}


def dump(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2, allow_nan=False) + '\n')


def db(value):
    return float(20 * np.log10(max(float(value), 1e-12)))


def read_wav(path):
    with wave.open(str(path), 'rb') as w:
        sr, ch, width = w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(w.getnframes())
        assert w.getcomptype() == 'NONE' and ch == 2
    if width == 2:
        x = np.frombuffer(raw, '<i2').astype(np.float64) / 32768
    elif width == 3:
        b = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        x = np.where(v & 0x800000, v - 0x1000000, v) / 8388608
    else:
        raise ValueError('Only PCM16/24 supported')
    return x.reshape(-1, ch), sr, width


def write_wav(path, x):
    assert np.isfinite(x).all() and np.max(np.abs(x)) < 1
    q = np.rint(x * 8388607).astype(np.int32).reshape(-1)
    b = np.stack([q & 255, (q >> 8) & 255, (q >> 16) & 255], axis=1).astype(np.uint8)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(3)
        w.setframerate(SR)
        w.writeframes(b.tobytes())


def resample(x, input_step):
    """64-tap windowed sinc, zero extension, antialias cutoff on downsampling."""
    count = int(np.floor(len(x) / input_step))
    out = np.zeros((count, 2), dtype=np.float64)
    offsets = np.arange(-31, 33)
    cutoff = min(1.0, 1.0 / input_step) * 0.94
    for start in range(0, count, 4096):
        pos = np.arange(start, min(start + 4096, count)) * input_step
        idx = np.floor(pos).astype(np.int64)[:, None] + offsets
        delta = pos[:, None] - idx
        weights = cutoff * np.sinc(cutoff * delta) * np.where(
            np.abs(delta) < 32, 0.5 + 0.5 * np.cos(np.pi * delta / 32), 0)
        weights /= weights.sum(axis=1, keepdims=True)
        valid = (idx >= 0) & (idx < len(x))
        values = x[np.clip(idx, 0, len(x) - 1)] * valid[:, :, None]
        out[start:start + len(pos)] = np.einsum('ij,ijk->ik', weights, values)
    return out


def metrics(x, sr=SR):
    peak = np.max(np.abs(x))
    return {
        'durationSeconds': len(x) / sr, 'peakDBFS': db(peak),
        'rmsDBFS': db(np.sqrt(np.mean(x * x))),
        'samplesAtOrAboveFullScale': int(np.sum(np.abs(x) >= 1)),
        'firstFrameAbsMax': float(np.max(np.abs(x[0]))),
        'lastFrameAbsMax': float(np.max(np.abs(x[-1]))),
        'last50msRMSDBFS': db(np.sqrt(np.mean(x[-int(sr * .05):] ** 2))),
        'maxAdjacentStep': float(np.max(np.abs(np.diff(x, axis=0)))),
        'finite': bool(np.isfinite(x).all()),
    }


def pitch_evidence(x, sr, midi):
    # Piano fundamentals may be weak. For bass, inspect harmonics 1/2/3 separately.
    z = x[int(.08 * sr):int(.58 * sr)].mean(axis=1)
    n = sr * 8
    spectrum = np.abs(np.fft.rfft(z * np.hanning(len(z)), n))
    expected = 440 * 2 ** ((midi - 69) / 12)
    partials = []
    for harmonic in [1, 2, 3]:
        hz = expected * harmonic
        lo, hi = int(hz * .97 * 8), int(hz * 1.03 * 8)
        k = lo + int(np.argmax(spectrum[lo:hi]))
        partials.append({'harmonic': harmonic, 'peakHz': k / 8,
                         'relativeMagnitude': float(spectrum[k] / spectrum.max())})
    harmonic = 2 if midi < 48 else 1
    f0 = partials[harmonic - 1]['peakHz'] / harmonic
    return {'assignedMIDI': midi, 'expectedHz': expected, 'partials': partials,
            'estimatorHarmonic': harmonic, 'estimatedFundamentalHz': f0,
            'estimatedCentsFromEqualTemperament': 1200 * math.log2(f0 / expected),
            'method': '0.08–0.58 s stereo mean, Hann FFT, 0.125 Hz grid; bass uses harmonic 2. Approximate; not a tuning certification.'}


def make_events():
    mapping = json.loads((PROJECT / 'contracts/keymap.ansi64.v0.1.json').read_text())
    by_id = {k['physicalKeyID']: k for k in mapping['keys']}
    by_midi = {k['midiNote']: k for k in mapping['keys']}
    events = []

    def add(t, midi, hold, section, velocity=64):
        events.append({'timeSeconds': t, 'midiNote': midi, 'holdSeconds': hold,
                       'releaseSeconds': .5, 'velocity': velocity, 'section': section,
                       'physicalKeyID': by_midi[midi]['physicalKeyID']})

    for t, midi in [(0, 33), (2.5, 60), (5, 96)]:
        add(t, midi, 1, 'low-mid-high')
    for t, hold in [(7, .05), (8, 1), (10, 5)]:
        add(t, 60, hold, 'short-1s-5s')
    for midi in [33, 42, 60, 96]:
        add(16, midi, .2, 'four-note-chord')
    for i in range(8):
        add(18 + i * .10, 60, .04, 'rapid-retrigger-overlapping-tails')
    # Actual fixed mapping for the simulated shortcut, no observed user input.
    for key, t, hold in [('commandLeft', 20, 1.2), ('keyC', 20.1, .1),
                         ('keyV', 20.45, .1), ('keyC', 20.8, .1)]:
        k = by_id[key]
        add(t, k['midiNote'], hold, 'synthetic-command-c-v-c', k['velocity'])
    for i, midi in enumerate([33, 35, 60, 62, 94, 96, 59, 60] * 2):
        add(23 + i * .10, midi, .045, 'synthetic-fast-typing')
    return {'origin': 'hand-authored synthetic events; no keyboard collection',
            'mappingVersion': mapping['mappingVersion'], 'durationSeconds': 28,
            'events': events}


def render(samples, events, seconds, allow_large_shift=False):
    out = np.zeros((int(seconds * SR), 2), dtype=np.float64)
    cache = {}
    for e in events:
        midi = e['midiNote']
        root = min(samples, key=lambda n: abs(n - midi))
        shift = midi - root
        assert allow_large_shift or abs(shift) <= 3
        key = (root, midi)
        if key not in cache:
            cache[key] = samples[root] if not shift else resample(samples[root], 2 ** (shift / 12))
        hold, release = e['holdSeconds'], e['releaseSeconds']
        x = cache[key][:round((hold + release) * SR)].copy()
        t = np.arange(len(x)) / SR
        phase = np.clip((t - hold) / release, 0, 1)
        envelope = np.cos(phase * np.pi / 2) ** 2
        # A preset amplitude response; not keyboard velocity sensing or SF2 behavior.
        x *= (envelope * (e['velocity'] / 64))[:, None]
        start = round(e['timeSeconds'] * SR)
        end = min(start + len(x), len(out))
        out[start:end] += x[:end - start]
    return out


def build():
    event_doc = make_events()
    dump(ROOT / 'audition-events.json', event_doc)
    summaries = {}
    for candidate, roots in CONFIG.items():
        folder = ROOT / candidate
        (folder / 'samples').mkdir(exist_ok=True)
        (folder / 'licenses').mkdir(exist_ok=True)
        for source, dest in [('LICENSE', 'VCSL-CC0.txt'), ('README.md', 'VCSL-README.md')]:
            shutil.copyfile(ROOT / 'source_evidence' / source, folder / 'licenses' / dest)
        processed, reports = {}, []
        rms_values = []
        for midi, name in roots:
            original = folder / 'originals' / name
            x, sr, width = read_wav(original)
            original_metrics = metrics(x, sr)
            threshold = max(np.max(np.abs(x)) * .001, 2 / 2 ** (width * 8 - 1))
            hits = np.flatnonzero(np.max(np.abs(x), axis=1) >= threshold)
            onset = int(hits[0]) if len(hits) else 0
            trim = max(0, onset - round(.002 * sr))
            clipped = x[trim:trim + round(8 * sr)]
            y = resample(clipped, sr / SR)
            tail = min(round(.08 * SR), len(y))
            y[-tail:] *= np.cos(np.linspace(0, np.pi / 2, tail))[:, None] ** 2
            processed[midi] = y
            rms_values.append(float(np.sqrt(np.mean(y[:round(.75 * SR)] ** 2))))
            reports.append({'sourceFile': 'originals/' + name, 'rootMIDI': midi,
                            'sourceSampleRate': sr, 'sourceBitDepth': width * 8,
                            'sourceMetrics': original_metrics,
                            'thresholdDBFS': db(threshold),
                            'firstThresholdCrossingMs': onset / sr * 1000,
                            'trimmedLeadingMs': trim / sr * 1000,
                            'pitchEvidence': pitch_evidence(x[trim:], sr, midi)})
        # One candidate-wide gain based on all roots, never normalize notes independently.
        gain = 10 ** (-28 / 20) / float(np.median(rms_values))
        largest = max(np.max(np.abs(y)) for y in processed.values())
        gain = min(gain, 10 ** (-12 / 20) / largest)
        for report in reports:
            midi = report['rootMIDI']
            processed[midi] *= gain
            name = f'piano_m{midi:03d}_v064_rr01.wav'
            write_wav(folder / 'samples' / name, processed[midi])
            decoded, _, _ = read_wav(folder / 'samples' / name)
            report['sampleFile'] = 'samples/' + name
            report['processedMetrics'] = metrics(decoded)
        audition = render(processed, event_doc['events'], event_doc['durationSeconds'])
        # Conservative offline preview mix gain; no limiter, compressor or reverb.
        mix_gain = 10 ** (-9 / 20)
        audition *= mix_gain
        write_wav(folder / 'audition.wav', audition)
        stress_events = [{'timeSeconds': 0, 'midiNote': midi, 'holdSeconds': .2,
                          'releaseSeconds': .5, 'velocity': 64}
                         for midi in [33, 42, 60, 96] for _ in range(16)]
        stress = render(processed, stress_events, 2) * mix_gain
        raw_stress = metrics(stress)
        protective_gain = min(1., 10 ** (-6 / 20) / np.max(np.abs(stress)))
        stress *= protective_gain
        write_wav(folder / 'stress-preview.wav', stress)
        qa = {'candidate': candidate, 'artifactState': 'candidate',
              'sampleFormat': 'WAV PCM24 48000 Hz stereo', 'rootMIDI': sorted(processed),
              'candidateWideGainDB': db(gain), 'auditionMixGainDB': -9,
              'sourceSamples': reports, 'audition': metrics(audition),
              'stress': {'description': '64 coincident offline voices: 16 copies of four notes; not 64 MIDI coverage, not sampler capacity',
                         'unprotectedMix': raw_stress, 'protectiveGainDB': db(protective_gain),
                         'writtenPreview': metrics(stress)},
              'subjectiveListening': 'NOT_TESTED', 'engineLoad': 'NOT_TESTED',
              'full64NoteCoverage': 'NOT_TESTED', 'audioDeviceLatency': 'NOT_TESTED'}
        dump(folder / 'qa_metrics.json', qa)
        summaries[candidate] = qa
    dump(PROJECT / 'docs/evidence/A-001/offline-metrics.json', summaries)
    print(json.dumps({k: {'gainDB': v['candidateWideGainDB'], 'auditionPeakDBFS': v['audition']['peakDBFS'],
                         'stressRawPeakDBFS': v['stress']['unprotectedMix']['peakDBFS']}
                      for k, v in summaries.items()}, indent=2))


if __name__ == '__main__':
    build()
