# C-001 音源格式早期反馈

2026-10-28；当前为实现提案，最终冻结由 PM-002 决定。

继续采用已批准的 AVAudioEngine + AVAudioUnitSampler 优先路线。优先交 SF2/DLS 与实际 program、bankMSB、bankLSB；WAV 可为制作中间格式，SFZ 不能直接加载或改后缀。代码探针将生成小型原创合成 SF2，并用离线 manual rendering 实际验证加载和释放。它只是链路占位，不能代替音效角色的钢琴候选或用户试听。

主文档的 350–700ms release 应在音色包络里实现；Swift 的延迟 noteOff 不能替代 release。采样器没有 pressID 寻址能力，探针会对同 MIDI 新击发先发送 stopNote，再 startNote；旧的应用级 release 由代次拦截。此策略不保证旧尾音独立控制，需离线和听感验证。

后续实际结果写 audio-format-note.md 与音频测试日志。正式资源范围、采样位深和包体仍待音效提案及 PM-002 接收，不修改契约。
