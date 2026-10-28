# A-001 音效格式提案（待 PM-002 批准）

2026-10-28，音效对话；任务基线 6c25ab0。此文件只提出方案，不批准正式音色、运行时格式或 A-002。

本轮先取得两种以内 CC0 钢琴的低、中、高音原始 WAV，制作固定合成事件的离线试听。目标 MIDI 33—96，C4=60；实际小样覆盖单独记载，不能用三根音大幅移调充作最终 64 音通过。优先核查 VCSL 的 Kawai 与 Steinway B 两种钢琴；若足够，不另下载 Salamander。

## 推荐：AVAudioUnitSampler + 经验证的 SF2

批准后制作小型 SF2 验证包，再制作正式包。原始 WAV 留在 Design/Audio；正式 bank 及 manifest 在 A-002 获批后制作。SF2 必须由真实样本、根音、音区、包络及声道配置生成，不能改 SFZ 扩展名。先验证单音端点、低中高音、连续半音、release、同音重击和多音；程序号、bankMSB/LSB 实载后确定，当前为未定。

固定预设力度：普通键 64、修饰键 48，不代表真实力度测量。建议先只保留一个经试听合适的柔和采样层，根音尽量间隔不超过 3 半音；无循环、无额外混响，release 从 500 ms 候选起步。低音自然衰减与高音尾部需分别核验。SF2 的立体声样本、velocity 响应及包络转换须由代码探针验证，不能假定与离线 WAV 一致。

## 备选：明确配置的 WAV zones

若 SF2 探针不可靠，再由主对话批准 WAV zones 加对应引擎能力；不能把 WAV 文件夹直接称作完成的乐器。需要 sampleFile/rootMIDI/lowMIDI/highMIDI/velocityMin/velocityMax/gainDB/releaseMs/loop，及声部、释放、重击、panic 的实测。不得因此由音效对话修改生产引擎。

SFZ 仅可用于理解上游映射；本轮不新增 SFZ 引擎或转换依赖，不把它作为 Apple soundbank 可加载证据。离线试听脚本仅是资源处理工具，不是生产播放实现。

## 待评审与责任

- 主对话：音色候选、正式格式、完整包体预算与 A-002 范围。
- 代码对话：实际 SF2/DLS 载入、音频生命周期、同音重击、64 声部/尾音、设备延迟；可先用其占位探针。
- 音效对话：来源许可、资源加工、根音/音区提案、离线试听/数值 QA。

当前无 bank，无正式 manifest，无引擎加载通过声明；不改 Resources、contracts 或用户音频设置。

## 本轮取得的具体输入与 SDK 证据

- `vcsl-kawai/samples/`：MIDI 33、42、60、96；`vcsl-steinway-b/samples/`：34、42、60、96。候选 manifest 的 `runtimeFormat=null`、`instrument=null`、`artifactState=candidate`，只记四个实际处理根音，不注册为正式 wav_set。
- 两组均为 48 kHz/24-bit/stereo；处理后 WAV 没有 smpl/根音元数据。根音记录在 JSON 中，不能把文件夹直接喂给默认采样器后假定映射已经正确。
- 本机 SDK 的 `AVFAudio.framework/Headers/AVAudioUnitSampler.h` 第25—41行列出 soundbank API 的 DLS/SF2 输入；第61—74行说明 loadAudioFiles 会为文件建 zone，并利用音频文件的放置元数据。这是 API 文档证据，未运行具体音源加载；[Apple 官方方法文档](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler/loadsoundbankinstrument(at:program:bankmsb:banklsb:))对应相同入口。
- `proposed-zones.json`：Kawai 28 根音、Steinway B 32 根音的未来单层提案；数学覆盖 MIDI33—96、最近根音移调最大1半音。全部根音的音高/采样质量和 SF2 区域参数尚未验证，不能据此宣布64音通过。
- 上游单层原始 WAV 预检约86.05/106.09 MiB，均需 A-002 新预算；本轮不下载。若选择原生SF2路线，应先只用已下载四根音做最小验证包，明确实验覆盖和每个根音/区间后再全量制作。
- 两种离线试听峰值约−15.50/−14.80 dBFS；极端64声部未保护混合会超满幅。500ms包络仅在离线脚本中实现，不能推导 AVAudioUnitSampler 的 release、同音重击或 panic 行为。

CR-001 已读取并采纳：标签开关、系统 Dock 自动隐藏偏好与声音/尾音独立；本轮没有改变当前 Mac 的 Dock 或音频设置。
