#!/usr/bin/env python3
"""Write candidate-only manifests and reports from measured files."""
import hashlib
import json
import pathlib
import re
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[1]
COMMIT = json.loads((ROOT / 'source_evidence/vcsl-commit.json').read_text())['sha']
TREE = json.loads((ROOT / 'source_evidence/vcsl-tree.json').read_text())['tree']
LEDGER = json.loads((ROOT / 'source_evidence/download-ledger.json').read_text())
NAMES = {'vcsl-kawai': 'VCSL Kawai', 'vcsl-steinway-b': 'VCSL Steinway B'}


def dump(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')


def record(path, root, role):
    return {'path': str(path.relative_to(root)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'byteSize': path.stat().st_size, 'role': role}


def make_proposals():
    result = {}
    note_values = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
                   'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
    for candidate, prefix, offset in [
        ('vcsl-kawai', 'Chordophones/Zithers/Grand Piano, Kawai/Sustains/', 12),
        ('vcsl-steinway-b', 'Chordophones/Zithers/Grand Piano, Steinway B/NoSus/', 0),
    ]:
        roots = {}
        for e in TREE:
            if not e['path'].startswith(prefix):
                continue
            m = re.search(r'_([A-G]#?)(-?\d)_(?:v2|vl2)_rr1', e['path'])
            if m:
                midi = 12 * (int(m[2]) + 1) + note_values[m[1]] + offset
                if 33 <= midi <= 96:
                    roots[midi] = e
        zones = []
        for root, entry in sorted(roots.items()):
            covered = [n for n in range(33, 97) if min(roots, key=lambda r: (abs(r-n), r)) == root]
            zones.append({'rootMIDI': root, 'lowMIDI': min(covered), 'highMIDI': max(covered),
                          'velocityMin': 1, 'velocityMax': 127, 'gainDB': 0,
                          'releaseMs': 500, 'loop': None, 'sourcePath': entry['path'],
                          'sourceByteSize': entry['size'], 'sourceGitBlob': entry['sha'],
                          'status': 'PROPOSAL_ONLY_NOT_DOWNLOADED_OR_AUDITIONED_AS_A_FULL_SET'})
        result[candidate] = {
            'artifactState': 'proposal', 'sourceCommit': COMMIT, 'runtimeApproved': False,
            'noteNaming': 'C4=MIDI60', 'sourceOctaveOffset': offset,
            'fullLayerSourceBytes': sum(e['size'] for e in roots.values()),
            'estimatedPCM24Stereo8SecondsUpperBytes': len(roots) * 48000 * 6 * 8,
            'maxProposedTransposeSemitones': max(abs(n-z['rootMIDI']) for z in zones for n in range(z['lowMIDI'], z['highMIDI']+1)),
            'zones': zones,
            'warning': 'Only a mathematical inventory proposal. Gain, pitch, root metadata, sample duration and SF2 release behavior require A-002/engine testing. No full coverage is claimed.'}
    dump(ROOT / 'proposed-zones.json', result)


def package():
    make_proposals()
    rows = []
    for candidate, name in NAMES.items():
        folder = ROOT / candidate
        q = json.loads((folder / 'qa_metrics.json').read_text())
        shutil.copyfile(ROOT / 'processing_recipe.md', folder / 'processing_recipe.md')
        selected = [e for e in LEDGER['files'] if e['candidate'] == candidate]
        dump(folder / 'source_records.json', {'sourceCommit': COMMIT, 'files': selected,
              'author': 'Versilian Studios LLC; repository maintained by Sam Gossner',
              'note': 'localPath in this evidence file is relative to Design/Audio; original URL is pinned. Runtime manifest paths are relative to this candidate directory.'})
        sample_table = []
        for r in q['sourceSamples']:
            p = r['pitchEvidence']
            sample_table.append(f"| {r['rootMIDI']} | {p['estimatedFundamentalHz']:.4f} | {p['estimatedCentsFromEqualTemperament']:+.2f} | {r['sourceMetrics']['durationSeconds']:.3f} | {r['trimmedLeadingMs']:.3f} | {r['processedMetrics']['peakDBFS']:.2f} |")
        text = f'''# {name} 候选阶段 QA

2026-10-28，a001-candidates.0.1；状态 candidate，待 PM-002。没有用户/人工听感通过结论。

## 实测数值

有效根音：{q['rootMIDI']}；四个派生 WAV 均为 48 kHz/24-bit/stereo。
每候选公共增益 {q['candidateWideGainDB']:+.3f} dB，试听公共总线增益 −9 dB。

| MIDI 根音 | 粗估基频 Hz | 偏移 cents | 原始时长 s | 前裁 ms | 派生峰值 dBFS |
|---|---:|---:|---:|---:|---:|
{chr(10).join(sample_table)}

FFT 取原始音频起音后 0.08—0.58 s，Hann 窗，0.125 Hz 网格；低音使用第二谐波除二，结合第三谐波检查。钢琴不谐性、噪声与录音调律会影响数值；这些不是精密音高校准结果。原始文件没有 smpl 根音元数据；项目 MIDI 来自此次资源核查。

28 s `audition.wav`：峰值 **{q['audition']['peakDBFS']:.3f} dBFS**；整段 RMS {q['audition']['rmsDBFS']:.3f} dBFS（包含静音，非 LUFS）；满幅/削波样点 {q['audition']['samplesAtOrAboveFullScale']}。末帧为零；派生样本末尾 80 ms 已淡出。起音数值检查不能证明没有听感点击。

`stress-preview.wav`：64 个同步离线声部，四种音各重复 16 次。未保护混合峰值 **{q['stress']['unprotectedMix']['peakDBFS']:+.3f} dBFS**，存在过载风险；为便于试听，输出前额外衰减 **{q['stress']['protectiveGainDB']:.3f} dB**，保存后峰值 −6 dBFS。没有将这个离线增益应用到生产引擎；需要代码探针验证真实音源的总线余量、防削波和声部策略。

## 验收状态

| ID/项目 | 状态 | 证据与边界 |
|---|---|---|
| L-01 候选来源 | 静态核查完成，待主接收 | 原 LICENSE/README、固定提交、逐文件 Git blob/字节数/SHA-256、修改配方 |
| A-01 小样 | 数值核查完成，听感未测 | 四根音与试听中小范围移调；不是连续 MIDI33—96，通过集合仅指这些候选根音 |
| A-01 完整64音 | 未测试 | 完整层/正式音色库未制作；proposed-zones 只有数学音区提案 |
| A-02 起音/尾音 | 离线数据检查完成，听感/引擎未测 | 合成50ms/1s/5s事件；500ms离线释放包络；裁切和峰值记录 |
| A-03 64声部 | 真实验收未测试 | 离线极端叠加暴露过载，保护后的预览不证明运行时通过 |
| Apple 文件识别/PCM 解码 | 验证记录见 evidence | 只证明 WAV 格式可读，不能证明 soundbank 加载 |
| AVAudioUnitSampler、SF2/DLS | 未测试 | 未提供 bank，不注册 ready |
| 内置/有线/蓝牙、延迟、1小时体验 | 未测试 | 没有播放/录回或设备设置变更 |

## 试听和复现

在聊天中点开 `audition.wav`，或由用户在 Mac 执行 `afplay "{folder / 'audition.wav'}"`。本轮只提供可播放文件，未自动外放或修改系统音量。处理命令见 processing_recipe.md；精确数值和算法参数见 qa_metrics.json。

## 来源差异与限制

{('Kawai目录标注Legacy。源音名比本项目约定低一组八度；原16-bit录音转成24-bit不增加原始信息。A1/C4/C7/C1仅作诊断存档；当前有效根音来自A0/F#1/C3/C6。不能依据四音推定所有上游根音都正确。' if candidate == 'vcsl-kawai' else 'Steinway B已由上游逐层归一化，本轮只用NoSus/vl2一层，未恢复完整力度响应。C7粗估偏高约14 cents，需听音核验和决定是否校音；本轮未自动修音。')}

八个有效样本均未发现数值满幅削波，但“柔和、不刺耳、自然、不糊”均待人工试听。不同原录制/踏板条件未统一，不能凭响度对齐称作受控盲听。没有 release sample、循环点或多力度层；长按按原采样自然衰减。

已采纳 CR-001：标签与系统 Dock 自动隐藏设置不改变音频事件、尾音或音量，本轮不触及系统 Dock 设置。
'''
        (folder / 'qa_audio.md').write_text(text)
        files = []
        for p in sorted(folder.rglob('*')):
            if not p.is_file() or p.name == 'audio.manifest.json':
                continue
            role = 'license' if p.parent.name == 'licenses' else ('sample' if p.suffix == '.wav' and p.parent.name in ['samples', 'originals'] else 'qa')
            files.append(record(p, folder, role))
        manifest = {
            'schemaVersion': '1.0.0', 'audioPackVersion': 'a001-candidates.0.1',
            'artifactState': 'candidate', 'instrumentName': name,
            'runtimeFormat': None, 'targetEngine': 'AVAudioUnitSampler_candidate_UNTESTED',
            'noteNaming': 'C4=MIDI60', 'midiNoteRange': {'min': 33, 'max': 96},
            'coverageMIDI': q['rootMIDI'], 'files': files, 'instrument': None,
            'licenseRecords': [{'sourceURL': 'https://github.com/sgossner/VCSL/tree/' + COMMIT,
                'author': 'Versilian Studios LLC', 'sourceVersion': COMMIT,
                'licenseID': 'CC0-1.0', 'licenseFile': 'licenses/VCSL-CC0.txt',
                'modifications': 'Original WAV unchanged; selected roots resampled to 48kHz PCM24, max8s, 80ms tail fade, one common gain per candidate. Offline audition with <=3-semitone shifts, synthetic events and 500ms release. See recipe.'}],
            'processingRecipePath': 'processing_recipe.md', 'qaReportPath': 'qa_audio.md',
            'readinessNote': 'Candidate only. coverageMIDI lists four prepared sample roots, not validated engine/64-note coverage. Extra originals are diagnostic evidence. No SF2/DLS bank or runtime instrument configured. Subjective listening and engine QA NOT_TESTED. Proposed future zones are outside this manifest.'}
        dump(folder / 'audio.manifest.json', manifest)
        rows.append(f"| {name} | {sum(e['actualBytes'] for e in selected)/1048576:.3f} MiB | {sum(p.stat().st_size for p in (folder/'samples').glob('*.wav'))/1048576:.3f} MiB | {q['audition']['peakDBFS']:.2f} | {q['candidateWideGainDB']:+.2f} |")
    comparison = f'''# A-001 两种钢琴候选比较

状态：候选资料与试听已产出，静态验证证据见 docs/evidence/A-001/validation.json，待 PM-002 接收；最终音色和格式未选定。

两者均来自固定版本 VCSL CC0 声音素材。各交四个有效根音、28秒相同合成事件试听、压力预览及原始录音。完整来源见 source_inventory.md；不是商业音源抽样，也没有把SFZ改名为SF2。

| 候选 | 本轮原文件及说明（含诊断） | 四个处理后小样 | 试听峰值 dBFS | 公共候选增益 dB |
|---|---:|---:|---:|---:|
{chr(10).join(rows)}

两段试听均 8,064,044 bytes（48 kHz/24-bit/stereo，28 s）。RMS近似匹配但未做人工等响确认；响度和声学数字不能证明柔和/自然。

## 取舍

- **Kawai**：源录音为16-bit，Legacy目录；有可核实的低中高根音和真实自然衰减。需处理音名八度差异，来源名中的C3对应本项目C4。现测C7粗估接近十二平均律；不能因此宣称整体调律更好。后续单层上游候选约86.05 MiB。
- **Steinway B**：源录音为24-bit，NoSus单层，音名在本次样本中符合C4=60；原始音量明显更高，上游已归一化。C7粗估约+14 cents，需试听决定是否修正。后续单层上游候选约106.09 MiB。
- 两者完整层均超过本轮剩余下载预算，本轮未下载。按每根音最长8秒的PCM24立体声估算，后续28/32根音分别不超过约61.52/70.31 MiB（不含bank开销）；16-bit/更短自然尾音可能减小体积，须在A-002验证。
- 目前只推荐**先比较这两段试听，再决定音色**。若主对话仅为工程试载需要优先级，Steinway B现有根音命名较直接，可先做最小SF2探针；这不是听感胜出或正式音色选择。

## 集成结论

优先提案为AVAudioUnitSampler + 真实制作且实载验证的SF2，备选为经批准的明确WAV zones。详见 format-proposal.md。上游声学录音、自制离线包络与Apple采样器运行结果必须区分。本轮没有创建bank、没有完整64音覆盖、没有播放硬件测试，也未修改生产代码。

64个同步离线声部的未保护混合峰值约+8.58/+9.28 dBFS，说明极端叠加需要额外余量或限制策略。提供的stress-preview.wav已单独衰减到−6 dBFS，不能作为生产防削波完成证据。

## 试听入口

- Kawai：`vcsl-kawai/audition.wav`
- Steinway B：`vcsl-steinway-b/audition.wav`
- 0—6.5秒比较低中高；7—15.5秒检查短按/长按；16秒多音；18秒重击；20秒快捷键；23秒快打。

人工听感、真实设备延迟、正式64声部均未测试。CR-001已采纳，标签开关或系统Dock设置不改变声音策略。所有文件等待PM-002，不自行进入A-002或发布。
'''
    (ROOT / 'candidate_comparison.md').write_text(comparison)


if __name__ == '__main__':
    package()
