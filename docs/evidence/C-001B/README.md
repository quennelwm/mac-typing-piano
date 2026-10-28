# C-001B：真实钢琴小型 SF2 离线验证

本目录验证 A-001B 的 Kawai 与 Steinway B **候选** SF2。所有音频通过 AVAudioEngine manual offline 渲染；没有硬件播放、真实输入监听、权限请求、设备或系统音量变更、网络下载。候选银行及 Design/Audio 文件只读，默认占位 bank 与生产源码没有因本补测而变更。

最终代码对话独立复跑结果：36份输入/验证源码哈希核对通过，完整 XCTest **38/38通过**，证据绑定回归 **12/12通过**；两候选分别完成191／193项数值检查，WAV总大小3,628,888 bytes。见 `parent-verification.json` 与对应日志。

交付入口为 `results.json`。它聚合输入快照、两份逐音/生命周期结果、音高估计器校准及两个 WAV 的文件事实。只有本轮 `summarize` 成功且快照哈希匹配的结果可用；命令失败时，留存的旧 `results.json` 不能代表本轮通过。完整 XCTest 套件是否通过，以代码对话另存的全套测试日志为准，聚合 JSON 只证明本目录的候选检查。

## 复现

从仓库根目录顺序运行，期间不要改输入或验证源码：

```sh
python3 Code/Scripts/verify_candidate_banks.py preflight
python3 docs/evidence/C-001B/test_evidence_binding.py
swift test --build-system native --package-path Code --filter CandidateBankTests
python3 Code/Scripts/verify_candidate_banks.py summarize
python3 Code/Scripts/verify_candidate_banks.py unchanged
```

需要全套测试时，第三步去掉 `--filter CandidateBankTests`。本验证依赖当前仓库中的 A-001B 候选目录、既有 `jsonschema`、macOS Apple 音频框架；没有安装新依赖。`native` 是当前 SwiftPM 的已弃用兼容后端，本机默认后端的应用签名问题由代码总交接单独记录。

预检按冻结的 `contracts/audio.manifest.schema.json` 验证两个 manifest，并核对索引/参数/manifest 的 preset、program、bank、音区、格式及 candidate 状态。所有登记文件、源码 WAV、构建脚本和交接记录均验证或固定哈希；路径拒绝绝对路径、`..`、URL、跨目录符号链接。预检还绑定当前 `SamplerAudio.swift`、`CandidateBankTests.swift` 和验证器源码。没有运行音效目录中会重建候选的脚本。

XCTest 在渲染前后复核快照，并把快照 SHA-256、验证源码版本写进每份结果。汇总必须匹配候选 ID、bank SHA-256、覆盖/空缺表、加载参数及 WAV 文件名/哈希/帧数/大小。估计器校准也必须绑定同一快照及测试源码且自身成功。快照、源代码或结果不一致会退出失败，不会静默使用旧结果。

## 输入与测量概况

| 项目 | Kawai | Steinway B |
|---|---:|---:|
| Bank 字节数 | 2,668,204 | 2,649,954 |
| 逐音有输出 | 10 | 11 |
| 33–96 内未覆盖音位精确零 | 54 | 53 |
| velocity127、gain0.08 覆盖音位和弦峰值 | 0.0179284960 | 0.0230753720 |
| velocity127、gain0.16 覆盖音位和弦峰值 | 0.0277231596 | 0.0318169743 |
| 10 Hz、100 次 MIDI60 重击最大峰值 | 0.0010407867 | 0.0010227065 |
| 根音/邻音相对音程最大估计误差 | 0.2734 cents | 0.2215 cents |
| 渲染起音阈值帧范围 | 48–58 | 48 |

加载参数已在两包分别实载确认：program 0、bankMSB 121、bankLSB 0。初始增益 0.08，最大边界 0.16；和弦前额外渲染 100 ms 静音，让混音参数变化有时间稳定。此峰值结论只针对各自 10／11 个覆盖音位，不能延伸为完整 64 音或内部声部容量结论。

覆盖及空缺 MIDI 列表、每音峰值/RMS/起音帧、每组根音/邻音、每根音释放数据全部见 `vcsl-kawai-results.json`、`vcsl-steinway-b-results.json`。Kawai 根音为 33/42/60/96；Steinway 为 34/42/60/96。两包 MIDI45 都保持空缺。

## 数值方法与边界

- 渲染为 mono 48 kHz，原始浮点数据用于测量。逐音各渲染 750 ms；起音及尾音结束使用绝对幅度 `1e-7` 阈值。未覆盖音、panic 后、gain0 和静音后调高但未新击发，采用**所有样本精确为 0** 的检查。
- 起音的 48 帧等于本次离线时间轴 1 ms；这包括音源包络/样本的行为，**不是键盘输入到扬声器的延迟**。
- 音高估计截取渲染后的 80–650 ms，按音高选择 1–8 个样本分组平均降采样、去均值，计算归一化自相关；在标称周期的 0.85–1.18 倍范围搜索内部峰，以三点抛物线细化周期。置信门槛为相关系数≥0.6，实际最低约 Kawai0.995／Steinway0.923。
- 邻音相对于同一区根音的音程按 `1200*log2(f邻/f根)` 计算，与 ±100 cents 比较，预设容差 25 cents。相同估计器对 MIDI33–96 的已知正弦校准最大误差约 0.0752 cents。纯正弦校准不证明真实钢琴的非谐波/噪声估计没有偏差。
- 绝对频率与相对 A440 的偏移只作为未认证估计记录，不按标签宣称完美调音。当前估计范围 Kawai约−4.02至+0.08 cents，Steinway约+0.15至+10.80 cents；尤其 Steinway 高音的偏移需要音效方/后续试听评估，不能据此自行调音或淘汰候选。
- 每个根音分别按 50 ms、1秒、5秒后释放，再渲染 800 ms。非零尾音阈值结束约为 Kawai0.172–0.398秒、Steinway0.215–0.402秒；两包在600–800ms窗口均为零。编码500ms不是“实际可听尾音必须500ms”的承诺。MIDI96样本在5秒前已自然结束，因此该长按释放没有新尾音，结果显式记录为样本已静音。
- 同音重击按50ms开/50ms释放，连续100次；最后10次最大值未超过最初10次的2倍。panic 同时覆盖仍按下声及已释放尾音，再次击发有效。gain0清尾并阻止新音，升回0.16不会重放静音期间的按压；shutdown/reprepare初态静音且新击发有效。

## 代表文件

仅保存两段、各18.9秒，合计3,628,888 bytes（约3.46 MiB），低于20 MiB：

- `vcsl-kawai-offline-representative.wav`
- `vcsl-steinway-b-offline-representative.wav`

每段依次包含四根音、MIDI60的50ms/1秒/5秒保持与释放、10Hz前20次重击、最大gain0.16的覆盖音和弦。段落起止帧、增益和力度在各结果的 `representativeWAV.segments` 中。文件为48kHz/mono/PCM16，保持测试增益，未归一化；PCM16量化会舍去极弱尾音，数值结论使用量化前浮点数据。文件仅写出，未自动播放。

WAV 来源是对应已验证 bank 的离线渲染，来源版本/许可沿用各候选 `source_records.json` 与 `licenses/VCSL-CC0.txt`（VCSL固定提交、CC0-1.0），不是新采集声音。WAV自身哈希在结果与总汇中双向核对。

## 证据与未测项

`input-verification.json` 保存最终36文件快照；`parent-preflight.log`、`parent-all-tests.log`、`parent-binding-tests.log`、`parent-summary.log` 保存最终绑定版本的独立复现，`parent-verification.json` 保存重新计算输入/WAV哈希及既有C-001文件保护核查。`preflight.log`、`offline-first-run.log`、`offline-final.log` 是绑定修正前的历史记录。`binding-red.log` 证明旧的“status=passed”接受条件未拒绝11种错配，`binding-green.log` 为修正后12/12通过；反例只修改内存副本，未动候选或现有证据文件。

两个候选初次实载及当前离线检查未发现失败；这不把 `candidate` 改成 `ready`，也不选择正式音色。未测仍包括听感、硬件输出/蓝牙、实际输入到声学输出延迟、真实音频设备切换、完整64音覆盖、内部64声部、完整力度层、60分钟使用与最终资源验收。
