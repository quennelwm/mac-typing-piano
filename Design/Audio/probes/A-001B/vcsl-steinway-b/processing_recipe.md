# A-001B SF2 最小试验配方

版本 `a001b-sf2-mono.0.1`，2026-10-28。仅格式试验，两个候选都未被选为正式音色；不进入 A-002。

## 复现

从 `/Users/wuming/Desktop/键盘钢琴` 执行：

```sh
python3 Design/Audio/probes/A-001B/scripts/build_sf2_trials.py
python3 Design/Audio/probes/A-001B/scripts/test_sf2_contract.py
python3 Design/Audio/probes/A-001B/scripts/verify_delivery.py
```

使用已有 Python3.12.2、NumPy1.26.4 和 jsonschema；没有安装依赖、下载音频、联网构建或改变系统设置。输入来自 A-001 四根音派生 WAV，读取前逐项匹配原 candidate manifest 的字节数及 SHA-256；输出仅写本试验目录和任务证据。

## 声音数据变换

每个输入是 48kHz/24-bit/stereo PCM。逐帧计算 `(L+R)/2`，随后按最近值、半值取偶数规则量化为16-bit PCM。没有附加增益、重采样、校音、EQ、混响或噪声整形；不加随机 dither，保证确定性复现。

**单声道降混及24→16位均有损**：立体声宽度会消失，反相成分可能相消，低电平量化细节减少。此选择只为最小单声道格式/加载试验，不能替代A-001立体声试听或作为正式音源声道方案。每个音的帧数、峰值、量化最大误差及PCM哈希在 instrument-parameters.json；全部波形与源录音的数学降混结果独立逐字节核对。

## SF2 文件内容

脚本实际写出 RIFF/sfbk：INFO、sdta/smpl 和 pdta 九个标准子区块。版本 ifil=(2,1)，含一个 preset、一个 instrument、四个 mono sample/zone。INFO 字符串的偶数长度和结尾零字节计入声明长度，避免 C-001 已发现的 Apple InvalidFile 问题；所有列表索引、终止记录和每样本46个零值保护点均显式写入。

没有立体声 sample link；sampleType=1、sampleLink=0。每样本 root 同时写入 sample header 和 overridingRootKey，pitchCorrection=0，保留原录音调律。sampleModes=0；SF2必需但未使用的 loop header 字段复制样本起止位置，不代表制作或验证了循环，外部元数据写 `loop:null`。

## 真实音区

| 候选 | 根音 → 启用的 MIDI 范围 |
|---|---|
| Kawai | 33→33–34；42→41–43；60→59–61；96→95–96 |
| Steinway B | 34→33–35；42→41–43；60→59–61；96→95–96 |

范围来自根音±1，裁到33–96；共10/11音位。完整未覆盖列表在 trial-index.json。特别是MIDI45（当前keyV）在两包中都没有zone；本轮不能直接回放A-001整段键序列后把缺音当作引擎故障。只测试明确覆盖的音位，另验证未覆盖音位预期静音。

音区仅一个力度层，接受velocity1–127；不同力度可能由采样器默认SF2调制器改变音量/滤波，不会切换真实录制的力度层。代码方应以64为起始试验力度，并另测48/127。

## 参数及测量边界

- SF2文件内：preset=0、bank=0。Apple API首次试载参数：program=0、bankMSB=121（melodic）、bankLSB=0。这是对本包的**试载参数提案**，虽与C-001已验证的另一个占位包一致，但这两份bank尚未实载。
- delay/attack/hold/decay 各−12000 timecents，约0.977ms；sustainVolEnv=0cB，保持原样本自然衰减；initialAttenuation=0cB、pan=0、reverbSend=0、chorusSend=0。
- releaseVolEnv=−1200 timecents，`2^(-1200/1200)=0.5s`。SF2按dB域定义释放，这与A-001离线余弦平方包络不同；编码值不能保证从noteOff到听不见恰好500ms。
- scaleTuning=100 cents/key，最大试验移调1半音。未增加显式modulator，采样器默认调制行为仍需实测。
- 建议代码先沿用0.08总线增益作为测试起点，实测峰值后再决定；该值不是这两个候选的防削波或听力安全结论。

## 来源与格式依据

音频许可沿用A-001固定版本VCSL CC0，随每包复制原LICENSE/README。各包source_records.json同时保留原始来源记录、A-001输入路径及SHA-256。原件保持不变。

格式实现依据 [SoundFont 2.01 原始技术规范](https://www.synthfont.com/SFSPEC21.PDF) 的RIFF/INFO、preset/instrument/sample结构和generator定义；只引用规范，不把规范PDF当作可随音源再分发的素材。Apple接口与本项目已验证占位路线见 `docs/evidence/C-001/audio-format-note.md`。本次借鉴其接口约定和INFO长度故障经验，没有复制占位合成声音或修改代码工程。

静态验证只能确认结构、源数据变换、索引、音区、清单、哈希及复现一致。AVAudioUnitSampler加载/离线渲染、实际noteOff、重击、负音区静音、64内部声部、设备和听感均待代码对话及用户后续验证。

CR-001/002/003均不改变本轮资源范围：不加触控板功能，菜单♪与音量滑块独立于bank；不写Dock、系统音量或设备偏好。
