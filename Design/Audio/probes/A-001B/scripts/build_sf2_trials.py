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
AUDIO = ROOT.parents[1]
VERSION = 'a001b-sf2-mono.0.1'
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
        low, high = max(33, root - 1), min(96, root + 1)
        ibag.extend(struct.pack('<HH', len(igen) // 4, 0))
        generators = [
            (43, low | high << 8), (44, 1 | 127 << 8),
            (8, 13500), (9, 0), (15, 0), (16, 0), (17, 0),
            (33, -12000), (34, -12000), (35, -12000), (36, -12000),
            (37, 0), (38, -1200), (48, 0), (54, 0), (56, 100),
            (58, root), (53, index),
        ]
        for op, amount in generators:
            igen.extend(gen(op, amount))
        zones.append({'sampleIndex': index, 'rootMIDI': root, 'lowMIDI': low,
                      'highMIDI': high, 'velocityMin': 1, 'velocityMax': 127,
                      'gainDB': 0, 'releaseMs': 500, 'loop': None,
                      'sampleRate': 48000, 'sampleChannels': 1, 'sampleBits': 16,
                      'sourceCandidatePath': f'Design/Audio/{candidate}/{rel}',
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
    inst = struct.pack('<20sH', name20('Four Root Piano'), 0)
    inst += struct.pack('<20sH', name20('EOI'), 4)
    info = chunk(b'ifil', struct.pack('<HH', 2, 1))
    info += info_string(b'isng', 'EMU8000')
    info += info_string(b'INAM', candidate + ' A-001B four-root mono trial')
    info += info_string(b'IENG', 'Versilian Studios LLC; A-001B resource processing')
    info += info_string(b'ICOP', 'CC0-1.0 samples; see included license and provenance')
    info += info_string(b'ICMT', 'CANDIDATE. Partial range. Mono downmix PCM16. No loops. Release 500ms encoded; sampler untested.')
    pdta = b''.join([
        chunk(b'phdr', phdr), chunk(b'pbag', struct.pack('<HHHH', 0, 0, 1, 0)),
        chunk(b'pmod', bytes(10)), chunk(b'pgen', gen(41, 0) + gen(0, 0)),
        chunk(b'inst', inst), chunk(b'ibag', bytes(ibag)), chunk(b'imod', bytes(10)),
        chunk(b'igen', bytes(igen)), chunk(b'shdr', b''.join(headers)),
    ])
    bank = chunk(b'RIFF', b'sfbk' + list_chunk(b'INFO', info)
                 + list_chunk(b'sdta', chunk(b'smpl', bytes(pcm))) + list_chunk(b'pdta', pdta))
    return bank, zones, stats


def main():
    trials = []
    for candidate, roots in CONFIG.items():
        folder = ROOT / candidate
        folder.mkdir(parents=True, exist_ok=True)
        manifest = json.loads((AUDIO / candidate / 'audio.manifest.json').read_text())
        assert manifest['coverageMIDI'] == roots and manifest['artifactState'] == 'candidate'
        bank, zones, stats = make_bank(candidate, roots, manifest)
        (folder / 'trial.sf2').write_bytes(bank)
        (folder / 'licenses').mkdir(exist_ok=True)
        for name in ['VCSL-CC0.txt', 'VCSL-README.md']:
            shutil.copyfile(AUDIO / candidate / 'licenses' / name, folder / 'licenses' / name)
        source = {
            'sourceManifestProjectPath': f'Design/Audio/{candidate}/audio.manifest.json',
            'sourceManifestSHA256': sha((AUDIO / candidate / 'audio.manifest.json').read_bytes()),
            'licenseRecords': manifest['licenseRecords'],
            'upstreamSourceRecords': json.loads((AUDIO / candidate / 'source_records.json').read_text()),
            'processedSources': [{'rootMIDI': z['rootMIDI'], 'projectPath': z['sourceCandidatePath'],
                                  'sha256': z['sourceSHA256']} for z in zones],
            'modifications': 'Existing A-001 stereo PCM24 -> (L+R)/2 mono, nearest-even PCM16; no dither, loop, new gain or pitch correction; SF2 zones +/-1 only and 500ms release timecents.'}
        dump(folder / 'source_records.json', source)
        params = {
            'formatVersion': 'SF2 2.01', 'artifactState': 'candidate', 'audioPackVersion': VERSION,
            'sf2Preset': 0, 'sf2Bank': 0, 'program': 0, 'bankMSB': 121, 'bankLSB': 0,
            'selectorStatus': 'PROPOSED_FOR_APPLE_LOAD_NOT_YET_TESTED_ON_THIS_BANK',
            'sampleRate': 48000, 'sampleChannels': 1, 'sampleBits': 16,
            'channelConversion': '(L+R)/2 arithmetic mono downmix; lossy stereo reduction',
            'bitDepthConversion': '24-bit to 16-bit round-to-nearest ties-to-even; no dither; lossy',
            'releaseTimecents': -1200, 'releaseSecondsEncoded': .5,
            'delayTimecents': -12000, 'attackTimecents': -12000,
            'holdTimecents': -12000, 'decayTimecents': -12000,
            'sustainAttenuationCentibels': 0, 'initialAttenuationCentibels': 0,
            'reverbSend': 0, 'chorusSend': 0, 'pan': 0,
            'sampleModes': 0, 'loop': None, 'pitchCorrectionCents': 0,
            'modulators': 'No explicit modulators; engine SF2 defaults may affect velocity/filter response.',
            'soundStatus': 'NO_RUNTIME_LOAD_RENDER_OR_LISTENING_TEST', 'zones': zones,
            'pcmConversionMetrics': stats}
        dump(folder / 'instrument-parameters.json', params)
        coverage = sorted(n for z in zones for n in range(z['lowMIDI'], z['highMIDI'] + 1))
        uncovered = sorted(set(range(33, 97)) - set(coverage))
        shutil.copyfile(ROOT / 'processing_recipe.md', folder / 'processing_recipe.md')
        qa = f'''# {candidate}／A-001B 候选 SF2 QA

状态 candidate，版本 {VERSION}。仅静态/字节校验，真实音源加载与听感未测试。

- bank: trial.sf2，{len(bank)} bytes；SHA-256 `{sha(bank)}`。
- 四根音 {roots}；覆盖 {coverage}，共{len(coverage)}个音位。
- 故意未覆盖 {uncovered}，不是完整64音包。
- 声道/位深：48kHz/mono/16-bit，由已交A-001立体声24-bit数学降混和量化，有损。
- SF2 preset/bank=0/0；Apple program/MSB/LSB=0/121/0待实载验证。
- 无循环，未校音；releaseVolEnv=-1200 timecents（编码500ms）。实际释放持续时间、默认modulator行为未测。
- 源PCM变换及峰值/误差详见 instrument-parameters.json；来源与原许可见 source_records.json、licenses/。
- 独立RIFF/SF2检查及源PCM比对：scripts/test_sf2_contract.py；证据在 docs/evidence/A-001B。
- 清单/哈希/源文件保护/重复生成：scripts/verify_delivery.py；本报告不是运行时通过凭证。

下一环节由代码对话加载本包，对覆盖音位和未覆盖音位分别测试，并测短按/1s/5s、释放、同音重击、panic与峰值。不能将C-001占位bank的成功结果迁移到本bank。未进行扬声器/耳机播放、系统设置改动或完整音源选择。
'''
        (folder / 'qa_audio.md').write_text(qa)
        file_records = []
        for p in sorted(folder.rglob('*')):
            if p.is_file() and p.name != 'audio.manifest.json':
                file_records.append({'path': str(p.relative_to(folder)), 'sha256': sha(p.read_bytes()),
                                     'byteSize': p.stat().st_size,
                                     'role': 'bank' if p.suffix == '.sf2' else ('license' if p.parent.name == 'licenses' else 'qa')})
        trial_manifest = {
            'schemaVersion': '1.0.0', 'audioPackVersion': VERSION, 'artifactState': 'candidate',
            'instrumentName': manifest['instrumentName'] + ' four-root mono SF2 trial',
            'runtimeFormat': 'sf2', 'targetEngine': 'AVAudioUnitSampler_candidate_UNTESTED',
            'noteNaming': 'C4=MIDI60', 'midiNoteRange': {'min': 33, 'max': 96},
            'coverageMIDI': coverage, 'files': file_records,
            'instrument': {'bankFile': 'trial.sf2', 'program': 0, 'bankMSB': 121, 'bankLSB': 0,
                           'sf2Preset': 0, 'sf2Bank': 0, 'selectorStatus': params['selectorStatus'],
                           'parametersFile': 'instrument-parameters.json'},
            'licenseRecords': [{**manifest['licenseRecords'][0],
                'modifications': source['modifications']}],
            'processingRecipePath': 'processing_recipe.md', 'qaReportPath': 'qa_audio.md',
            'readinessNote': 'EXPERIMENT ONLY. coverageMIDI is encoded zone coverage, NOT successful audio/engine verification. Four roots only. Mono PCM16 lossy conversion. SF2 preset0 bank0 encoded; Apple selectors proposed/unloaded. Full range, hardware, listening and sampler release NOT_TESTED.'}
        dump(folder / 'audio.manifest.json', trial_manifest)
        trials.append({
            'id': candidate, 'bankFile': candidate + '/trial.sf2',
            'manifestFile': candidate + '/audio.manifest.json',
            'parametersFile': candidate + '/instrument-parameters.json',
            'byteSize': len(bank), 'sha256': sha(bank), 'sf2Preset': 0, 'sf2Bank': 0,
            'program': 0, 'bankMSB': 121, 'bankLSB': 0,
            'selectorStatus': params['selectorStatus'], 'samplerLoadStatus': 'NOT_TESTED',
            'coverageMIDI': coverage, 'uncoveredMIDI': uncovered,
            'rootMIDI': roots, 'zones': [{k: z[k] for k in ['rootMIDI', 'lowMIDI', 'highMIDI']} for z in zones],
            'sampleChannels': 1, 'sampleBits': 16, 'sampleRate': 48000,
            'releaseTimecents': -1200, 'releaseSecondsEncoded': .5,
            'suggestedProbeVelocity': 64, 'suggestedInitialMixerGain': .08,
            'gainNote': '0.08 is a starting test gain from C-001, not verified safe or loudness matched for these banks.'})
    total = sum(t['byteSize'] for t in trials)
    assert total <= 20 * 1048576
    dump(ROOT / 'trial-index.json', {
        'taskID': 'A-001B', 'trialVersion': VERSION, 'artifactState': 'candidate',
        'pathBase': 'Directory containing this trial-index.json', 'format': 'SF2 2.01',
        'noteNaming': 'C4=MIDI60', 'midiTargetRange': {'min': 33, 'max': 96},
        'totalBankBytes': total, 'bankBudgetBytes': 20 * 1048576,
        'validationStatus': 'Run scripts/test_sf2_contract.py; evidence lives in docs/evidence/A-001B',
        'buildScript': 'scripts/build_sf2_trials.py',
        'buildScriptSHA256': sha(pathlib.Path(__file__).read_bytes()),
        'runtimeApproved': False, 'finalInstrumentSelected': False,
        'trials': trials})
    print(json.dumps({'totalBankBytes': total, 'trials': [{k: t[k] for k in ['id', 'bankFile', 'byteSize', 'sha256', 'coverageMIDI']} for t in trials]}, indent=2))


if __name__ == '__main__':
    main()
