# A-001 可复现处理配方

版本 a001-candidates.0.1，2026-10-28。只生成候选 WAV 和离线试听，未制作生产音色库。

## 环境与复现

在项目根目录执行：

```sh
python3 Design/Audio/scripts/fetch_candidates.py
OPENBLAS_NUM_THREADS=1 python3 Design/Audio/scripts/build_candidates.py
python3 Design/Audio/scripts/package_candidates.py
python3 Design/Audio/scripts/validate_candidates.py
```

Python 3.12.2、NumPy 1.26.4、requests、jsonschema 使用现有环境；没有安装系统依赖。实际 Python 版本以 `docs/evidence/A-001/environment.json` 为准。首次获取脚本依赖随包保存的固定提交树；不追随 master、不克隆全库。已存在的原始文件先核对长度与 Git blob SHA-1；新下载按预检大小限制流量并核对 SHA-1，随后写 SHA-256。HTTP 压缩传输的 Content-Length 不是解压后文件长度，最终验证以解压后字节数及哈希为准。

## 原始材料与音高

- Kawai：`A0 / F#1 / C3 / C6` 的 v2/rr1/Player 样本，用作 MIDI `33 / 42 / 60 / 96`。本次频谱及低音谐波间隔支持“上游音名比 C4=60 低一组八度”。原 WAV 无 smpl 根音元数据，不能用文件名直接建立本项目映射。
- Steinway B：NoSus/Close/vl2/rr1 的 `A#1 / F#2 / C4 / C7`，用作 MIDI `34 / 42 / 60 / 96`。低音 A1 试听由根音 34 下移 1 半音。
- Kawai 的 A1/C4/C7/C1 是本轮八度诊断材料，只保留在 originals，不进入处理后采样集。所有文件路径、Git blob 和 SHA-256 在下载账本。低音的最强谱峰可能是第二谐波，必须结合第三谐波间隔判断根音。
- 原录音的调律偏差保留；没有静默自动校音。FFT 数字是粗估，不能代替听音、专业调律或跨音域验证。

## 确定性处理

1. 读取 PCM16/24 双声道原 WAV。起音阈值取 `max(原峰值×0.001, 2个原量化单位)`，在第一越阈样点前保留 2 ms；本次八个有效样本的前裁切均为 0 ms。
2. 最多保留 8 s。64 抽头 Hann 窗 sinc 离线重采样到 48 kHz；向低采样率转换时收窄截止频率，零延拓边界。没有新增第三方音频库。
3. 在文件最后 80 ms 使用余弦平方淡出。无循环点、无去噪、无 EQ、无混响，不声称进行了听感修复。
4. 每候选四根音前 0.75 s RMS 的中位数对齐到 −28 dBFS，并限制该候选最响根音不高于 −12 dBFS。得到**每候选一个公共增益**，不逐音最大化。Kawai 约 +12.597 dB；Steinway B 约 −9.082 dB。上游 Steinway 已归一化的层间关系不另行改写；仅取一个层，不宣称恢复了全层力度曲线。
5. 写 48 kHz/24-bit/stereo PCM WAV；舍入量化，无随机抖动，保证本环境复现一致。Kawai 原始为 16-bit，升为 24-bit 不增加原始录音信息。

## 试听事件与动态

`audition-events.json` 是手写合成事件，实际物理键标签和 MIDI 来自只读 `ansi64-draft.0.1` 映射。没有监听、保存用户输入。

| 时间 | 内容 |
|---|---|
| 0 / 2.5 / 5 s | MIDI 33 / 60 / 96，各保持 1 s |
| 7 / 8 / 10 s | 中音保持 50 ms / 1 s / 5 s |
| 16 s | 四音同时触发 |
| 18 s | 中音每 100 ms 重击，共八次 |
| 20 s | 合成 Command+C/V/C，Command 只触发一次 |
| 23 s | 16 个合成快打事件 |

音高转换最大 3 半音，使用同一 sinc 方法；移调会改变采样时长及频谱，不能视作原音录制。释放是明确的 500 ms 余弦平方包络，叠加原样本自然衰减；源样本提前结束时随之结束。预设力度 64/48 仅按振幅比例变化，不模拟不同击弦力度音色。

试听公共总线增益 −9 dB，无限制器/压缩器。重复音在离线工具里允许尾音重叠，**不代表 AVAudioUnitSampler 的同音生命周期**。声音开关、panic、Dock 让位以及 CR-001 的标签/Dock 设置不在这个资源脚本里实现。

## 压力文件

`stress-preview.wav` 是四个音各叠 16 次、同时起音的 64 个离线声部（不是 64 个不同音高）。同相叠加故意暴露极端峰值。未保护的浮点混合峰值记入 QA；输出试听前另加公共衰减使其峰值为 −6 dBFS，衰减量明确记录。文件无削波不等于真实引擎已防削波，更不等于实际 64 声部验收通过。

## 未做

没有完整 64 音包、SF2/DLS、正式 release sample、循环点或运行时包；没有实际扬声器/耳机试听、录回、设备延迟测量及长时间打字测试。所有脚本仅用于候选资源加工，不可代替代码对话的生产引擎。
