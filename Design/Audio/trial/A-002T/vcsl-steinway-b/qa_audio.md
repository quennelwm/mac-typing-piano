# A-002T 候选音库 QA

Steinway B 单层32根映射MIDI33–96全部64音，每音最多±1半音，无重叠。候选mono16试用库，不是正式立体声音色定稿。

逐源hash、原始/处理后峰值、前裁切、近似FFT音高、降混能量比例、PCM量化误差、分区和release参数分别见download-ledger.json、processing-metrics.json、instrument-parameters.json。旧四根应与A-001处理中间件一致。异常静音/削波/不完整区域会阻断构建；FFT偏移超过20cents或降混能量比例低于.5标人工复核，不自动校音。FFT局部搜索不能独立排除错误八度，且高音钢琴弦不谐和度可能影响读数。

静态独立RIFF/SF2解析、32根PCM字节比对、完整64音无洞无重叠、schema/路径/许可/hash、下载预算、旧文件不变与复现证据见docs/evidence/A-002T/verification.json。请以该证据的实际状态为准。

尚未由音效角色运行新bank的AVAudioUnitSampler、扬声器/耳机播放、设备延迟、长时听感、多音峰值、持续按键与panic。代码角色负责真实全音实载和音量校准；旧四根bank成功不代表新bank已经通过。400ms为编码包络起点，不是每个音实际尾音持续时间。
