#!/usr/bin/env python3
"""Independent RIFF/SF2 artifact tests. Does not import the bank writer."""
import hashlib
import json
import pathlib
import struct
import unittest
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
AUDIO = ROOT.parents[1]
ROOTS = {'vcsl-kawai': [33, 42, 60, 96], 'vcsl-steinway-b': [34, 42, 60, 96]}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def chunks(data):
    result = []
    pos = 0
    while pos < len(data):
        require(pos + 8 <= len(data), 'truncated chunk header')
        kind, size = struct.unpack_from('<4sI', data, pos)
        require(pos + 8 + size <= len(data), 'chunk overrun')
        result.append((kind, data[pos + 8:pos + 8 + size]))
        pos += 8 + size + size % 2
    require(pos == len(data), 'bad chunk padding')
    return result


def records(data, fmt):
    size = struct.calcsize(fmt)
    require(len(data) % size == 0, 'record width')
    return list(struct.iter_unpack(fmt, data))


def inspect_bank(data):
    require(data[:4] == b'RIFF' and data[8:12] == b'sfbk', 'RIFF/sfbk identity')
    require(struct.unpack_from('<I', data, 4)[0] == len(data) - 8, 'RIFF length')
    outer = chunks(data[12:])
    require([k for k, _ in outer] == [b'LIST'] * 3, 'three LIST chunks')
    require([body[:4] for _, body in outer] == [b'INFO', b'sdta', b'pdta'], 'LIST order')
    info = dict(chunks(outer[0][1][4:]))
    require(info[b'ifil'] == struct.pack('<HH', 2, 1), 'SF2 2.01 version')
    for k, body in info.items():
        if k != b'ifil':
            require(len(body) % 2 == 0 and body.endswith(b'\0'), 'INFO string even declared length')
    sdta = chunks(outer[1][1][4:])
    require(len(sdta) == 1 and sdta[0][0] == b'smpl', 'PCM16 smpl only')
    pcm = sdta[0][1]
    require(len(pcm) % 2 == 0, 'PCM16 aligned')
    ordered = chunks(outer[2][1][4:])
    require([k for k, _ in ordered] == [b'phdr', b'pbag', b'pmod', b'pgen', b'inst', b'ibag', b'imod', b'igen', b'shdr'], 'pdta order')
    pdta = dict(ordered)
    phdr = records(pdta[b'phdr'], '<20sHHHIII')
    pbag = records(pdta[b'pbag'], '<HH')
    pgen = records(pdta[b'pgen'], '<HH')
    inst = records(pdta[b'inst'], '<20sH')
    ibag = records(pdta[b'ibag'], '<HH')
    igen = records(pdta[b'igen'], '<HH')
    shdr = records(pdta[b'shdr'], '<20sIIIIIBbHH')
    require(len(phdr) == 2 and phdr[0][1:4] == (0, 0, 0), 'one preset 0 bank 0')
    require(phdr[1][0].rstrip(b'\0') == b'EOP' and phdr[1][3] == 1, 'preset terminal')
    require(pbag == [(0, 0), (1, 0)] and pgen == [(41, 0), (0, 0)], 'preset links')
    require(pdta[b'pmod'] == bytes(10) and pdta[b'imod'] == bytes(10), 'terminal-only explicit modulators')
    require(len(inst) == 2 and inst[0][1] == 0 and inst[1][1] == 4, 'four instrument zones')
    require(inst[1][0].rstrip(b'\0') == b'EOI', 'instrument terminal')
    require(len(ibag) == 5 and len(shdr) == 5, 'zone/sample count')
    require(ibag[0][0] == 0 and ibag[-1][0] == len(igen) - 1, 'generator endpoints')
    require(igen[-1] == (0, 0) and all(m == 0 for _, m in ibag), 'generator/modulator terminals')
    require(shdr[-1][0].rstrip(b'\0') == b'EOS', 'sample terminal')
    require(all(v == 0 for v in shdr[-1][1:]), 'sample terminal zeros')
    zones = []
    samples = []
    previous_end = 0
    for i, sample in enumerate(shdr[:-1]):
        name, start, end, loop_start, loop_end, sr, pitch, correction, link, sample_type = sample
        require(start >= previous_end and end > start + 48 and end + 46 <= len(pcm) // 2, 'sample bounds and guards')
        require(pcm[end * 2:(end + 46) * 2] == bytes(92), 'zero guard sample points')
        require((loop_start, loop_end) == (start, end), 'unused loop fields copy sample extent')
        require(sr == 48000 and sample_type == 1 and link == 0 and correction == 0, 'mono sample metadata')
        require(0 <= pitch <= 127, 'root range')
        samples.append({'root': pitch, 'pcm': pcm[start * 2:end * 2], 'frames': end - start})
        previous_end = end + 46
        begin, finish = ibag[i][0], ibag[i + 1][0]
        require(begin < finish, 'monotonic generator indexes')
        gens = igen[begin:finish]
        require(gens[0][0] == 43 and gens[1][0] == 44 and gens[-1] == (53, i), 'range first sampleID last')
        require(len(dict(gens)) == len(gens), 'unique zone generators')
        g = dict(gens)
        lo, hi = g[43] & 255, g[43] >> 8
        require((lo, hi) == (max(33, pitch - 1), min(96, pitch + 1)), 'root plus/minus one only')
        require(g[44] == 1 | (127 << 8), 'velocity range 1..127')
        require(g[58] == pitch and g[54] == 0 and g[56] == 100, 'root/no-loop/semitone scaling')
        require(struct.unpack('<h', struct.pack('<H', g[38]))[0] == -1200, '500ms release timecents')
        require(g[37] == 0 and g[48] == 0 and g[15] == 0 and g[16] == 0 and g[17] == 0, 'sustain/gain/FX/pan')
        require(g[34] == (-12000 & 65535), 'approximately 1ms attack')
        zones.append({'rootMIDI': pitch, 'lowMIDI': lo, 'highMIDI': hi})
    require(previous_end == len(pcm) // 2, 'sample data exact extent')
    return {'zones': zones, 'samples': samples}


class TrialBankContract(unittest.TestCase):
    def check_candidate(self, candidate):
        p = ROOT / candidate / 'trial.sf2'
        self.assertTrue(p.is_file(), f'missing required trial bank: {candidate}')
        decoded = inspect_bank(p.read_bytes())
        self.assertEqual([z['rootMIDI'] for z in decoded['zones']], ROOTS[candidate])
        coverage = [n for z in decoded['zones'] for n in range(z['lowMIDI'], z['highMIDI'] + 1)]
        self.assertEqual(len(coverage), len(set(coverage)))
        self.assertLess(len(coverage), 64)
        for sample in decoded['samples']:
            src = AUDIO / candidate / 'samples' / f"piano_m{sample['root']:03d}_v064_rr01.wav"
            with wave.open(str(src), 'rb') as w:
                self.assertEqual((w.getframerate(), w.getnchannels(), w.getsampwidth()), (48000, 2, 3))
                count = w.getnframes()
                raw = w.readframes(count)
            # Decode independently and verify the output is the declared (L+R)/2 mix.
            raw3 = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int64)
            vals = raw3 @ np.array([1, 256, 65536], dtype=np.int64)
            vals[vals >= 8388608] -= 16777216
            expected = np.rint(vals.reshape(-1, 2).sum(axis=1) / 512).astype('<i2')
            self.assertEqual(sample['frames'], count)
            self.assertEqual(sample['pcm'], expected.tobytes())
            self.assertLess(int(np.abs(expected.astype(np.int32)).max()), 32767)

    def test_kawai_binary_and_source_contract(self):
        self.check_candidate('vcsl-kawai')

    def test_steinway_binary_and_source_contract(self):
        self.check_candidate('vcsl-steinway-b')

    def test_trial_index_never_claims_runtime_or_full_coverage(self):
        p = ROOT / 'trial-index.json'
        self.assertTrue(p.is_file(), 'missing trial-index')
        index = json.loads(p.read_text())
        self.assertEqual(index['artifactState'], 'candidate')
        self.assertEqual(len(index['trials']), 2)
        total = 0
        for trial in index['trials']:
            bank = ROOT / trial['bankFile']
            self.assertEqual(hashlib.sha256(bank.read_bytes()).hexdigest(), trial['sha256'])
            self.assertEqual(bank.stat().st_size, trial['byteSize'])
            total += trial['byteSize']
            self.assertEqual((trial['program'], trial['bankMSB'], trial['bankLSB']), (0, 121, 0))
            self.assertEqual(trial['samplerLoadStatus'], 'NOT_TESTED')
            self.assertEqual(sorted(trial['coverageMIDI'] + trial['uncoveredMIDI']), list(range(33, 97)))
            self.assertEqual(len(set(trial['coverageMIDI'] + trial['uncoveredMIDI'])), 64)
        self.assertLess(total, 20 * 1048576)


if __name__ == '__main__':
    unittest.main(verbosity=2)
