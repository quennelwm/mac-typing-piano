# C-001 音频格式早期反馈

- 执行角色：代码对话内部音频实现辅助；任务 C-001。不是 A-001 音效对话。
- 初始核查：2026-10-28，HEAD `41ca48f`，macOS 27.2（26B123）、arm64、Apple Swift 6.4。
- 建议沿用 `AVAudioEngine + AVAudioUnitSampler`，优先真实 RIFF `sfbk` 的 SF2；DLS 是后续候选，本探针只接受 SF2。SFZ、原始 WAV 集合和改扩展名文件均不是本探针支持格式。
- 最小占位计划：项目脚本原创合成谐波音、无外部采样或下载；仅用于验证引擎。音源不是钢琴定稿，不能算 A-001 试听/正式资源验收。
- 参数提案：program 0，bankMSB 121（melodic），bankLSB 0；MIDI 33–96；无永久 sustain、无 sample loop；SF2 release 目标 450 ms；主混音增益 0.08。
- 装载在 `prepare` 中完成；按键方法不读文件。同 MIDI 重击显式先 stopNote 后 startNote，旧 pressID 过滤由上层协调器负责；不宣称能任意寻址采样器内部声部。
- 离线渲染将覆盖 64 个音位非零输出、64 音和弦数值峰值、10 Hz 同音重击、10 秒长按、释放尾音、panic 清尾及重新准备、坏文件错误。
- 当前状态：此初稿只提出加载路线，尚未证明音源加载/离线渲染成功。完成后在本文件追加实际事实并保存日志。
- 未测边界：硬件出声、听感、端到端延迟、蓝牙、音频设备切换、64 个真实内部声部及长期工作。

本记录供代码对话汇总到 `format-feedback.md` 后由主对话转交；未联系其他聊天。

## 实际验证结果（2026-10-28）

加载路线已在上述 Mac 上通过 **Apple AVAudioUnitSampler 离线渲染** 验证。正式音源格式仍待 M0 审批；本结果仅证明这一个原创 SF2 占位可以加载和渲染。未播放到扬声器、未监听实际打字、未修改设备或权限。

- 最终占位文件：`Code/Assets/placeholder-original.sf2`，530,774 bytes。
- SHA-256：`ded7747105075d3b5ed95fed7a0453f638dd27882b80defd1fcc7062c4c700fb`。
- 六个根音及音区：36→33–41、48→42–53、60→54–65、72→66–77、84→78–89、96→90–96；每个原始样本 2 秒，22,050 Hz／16-bit／mono；无循环。
- Bank 参数确认为 program 0、bankMSB 121、bankLSB 0；这些参数不能自动推广到其他音源。
- 渲染格式：mono 48,000 Hz；音源节点 stereo 经引擎混音到离线 mono；mainMixer 增益 0.08。
- 设备记录：MacBookPro18,3／Apple M1 Pro；具体测试参数与环境见 `audio-results.json`。
- 原创来源与声明：`Code/Assets/source_inventory.md`、`PLACEHOLDER-LICENSE.txt`、`placeholder.manifest.json`；无第三方音频、无音频资源下载。

| 合成测试 | 实际数值／结果 |
|---|---|
| 64 音逐个触发，velocity 64，各渲染 120 ms | 全部非零且有限；最小／最大峰值 0.0024267696／0.0024737462 |
| 64 个不同 MIDI 同时发送 noteOn，velocity 127，渲染 1 秒 | mono 数字峰值 0.1382335；RMS 0.02630807394645784，无数值削波 |
| MIDI 60，10 Hz，100 次；每次按 50 ms、释放 50 ms | 最大峰值 0.0027894115，后 10 次未超过前 10 次最大峰值的 2 倍 |
| MIDI 60，按 100 ms 后 noteOff | 释放前 100 ms 峰值 0.0019017064；最后一个绝对值 > 1e-7 的样本在释放后 0.3595 秒；800 ms 后峰值 0 |
| MIDI 60 按住 10 秒 | 初段峰值 0.0024724924，末段峰值 0；由无循环样本自然结束，无按压超时规则 |
| 一个低音尾音和一个高音按下状态后 panic | 随后 500 ms 输出绝对值 < 1e-6；下一次击发非零，可直接继续离线渲染 |
| 缺失文件、SFZ 扩展名、无效内容、伪装 SF2 的 RIFF/WAVE、截断 bank | 全部抛出错误；失败后 render 报 notPrepared |
| shutdown 后重新 prepare | shutdown 后无法 render；重新加载为静音初态并可再次发音 |

这里的 64 和弦记录只证明发送了 64 条不同音高的命令并得到有限、未削波的混合输出，**不证明采样器保留了 64 个独立内部声部**。0.138 数字峰值也不是听力安全保证。探针只使用保守固定增益，没有额外限制器，其他音源需要重新校准与验证。释放阈值是本占位音的一个测量结果，不代表其他音源的精确 450 ms 包络。

### 复现与证据

从仓库根目录运行：

```sh
python3 Code/Scripts/generate_placeholder.py
python3 docs/evidence/C-001/audio-structure-check.py
swift test --build-system native --package-path Code --filter PianoAudioTests
```

- `audio-red.log`：先写测试及 API 空桩，8 项中 7 项因 `notImplemented` 失败。
- `audio-green-attempt-1.log`：首次实际实现能编译，但 Apple 以 -10871（InvalidFile）拒绝生成 bank。
- `audio-structure-red.log`：新增结构回归检查定位 INFO 字符串奇数字节声明。
- `audio-green-attempt-2.log`：只修复 bank 元数据长度后，对同一已编译引擎执行 `--skip-build`，8/8 通过。
- `audio-green.log`：加强错误类型、伪装与截断文件检查后重新构建，8/8 通过。
- `audio-generation.json`：Python 环境、文件哈希、区块尺寸、同运行时逐字节重现。
- `audio-results.json`：上述最终测试数值及边界，可供主对话汇总。

native 构建器在当前 SwiftPM 发出弃用警告；这是本机工程构建绕过默认构建器签名阻塞的临时路径，详见代码主交接。音频测试没有引入依赖或改变平台支持承诺。

### API 与接入注意

`SamplerAudio` 需由调用方在同一串行上下文调用。`init()` 不创建音频硬件连接；`prepare(bankURL:offline:)` 验证并加载一次。`noteOn(midi:velocity:)` 在 33–96 内先 stopNote 再 startNote；velocity 0 不击发、大于 127 钳制为 127；`noteOff(midi:)` 由调用方先验证 pressID。

`panic()` 发送 sustain off、all sound off、all notes off，然后 `engine.reset()` 清尾；离线时间轴归零，已加载 bank 保持可用，不读盘或重新加载。`shutdown()` 清尾并停止、释放引擎。`render(seconds:)` 只接受已准备的 offline 模式，返回 mono `[Float]`，`sampleRate=48000`，单次时长范围 0–60 秒。辅助状态有 `isPrepared`、`isOffline` 和固定 `gain=0.08`。

prepare、render 的失败向上传递；note 方法在未准备或引擎未运行时不发音。设备变更通知及恢复由上层决定何时清状态并重新 prepare，本轮只测主动 shutdown/reprepare，**没有实测物理设备断开或切换**。

### 格式修正与依据

初版普通 RIFF padding 没有计入 INFO 字符串的声明长度；SF2 文本字段要求自身以一或两个零字节终止并达到偶数字节长度。只改这一点后，Apple 从 InvalidFile 变为成功加载，构成故障定位证据。格式依据为 [SoundFont 原始技术规范](https://www.synthfont.com/SFSPEC21.PDF) 的 INFO 字符串章节；没有复制第三方采样。

本机 SDK `AVAudioUnitSampler.h` 明确说明 SF2／DLS 加载会读文件和分配内存；`AVAudioEngine.h` 要求尽早进入 manual 模式，并说明 reset 清除节点尾音。实现遵循这些说明：先 enableManualRenderingMode，再访问 mainMixer，离线测试不接触 inputNode 或输出设备。

未测试仍包括：真实扬声器／耳机与蓝牙、用户听感、真实输入到声学出声延迟、真实设备恢复、64 内部声部、正式音源和 60 分钟工作。音频辅助工作已交给代码对话集成，M0 接收由主对话决定。

## CR-003后续增量（最终C-001代码）

SamplerAudio新增setGain(Float)，本App总线范围0—0.16，默认0.08。菜单50%→0.08，100%→0.16，后者合成64-note chord离线峰值0.276467。原有0.08数值继续有效。最终音频测试增加为9项，总套件35项，见all-tests.log。

实测单独写mainMixer.outputVolume=0时，offline4096-frame quantum存在过渡，volume-transition-diagnostic.log保留原失败。为保证0%输出零，setGain(0)还调用已验证panic并抑制新的采样器noteOn，视觉/输入状态不变；调高不补播旧音。非零调整仍使用采样器主混音器。该变化不是系统音量控制，也没有新增引擎或依赖。最大增益仍只对本占位数字试验有证据，正式候选须重新测量。
