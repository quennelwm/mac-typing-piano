# C-002T 代码组件交接

任务/角色：C-002T 代码；主对话负责 build.sh、README、IMPLEMENTATION、最终打包/验收与 HANDOFF。本轮没有 Git 写入，没有改 Design、contracts 或旧 C-001C 证据。运行环境 macOS 27.2 / arm64，Swift 6.4（最终环境与构建以主对话日志为准）。

## 持续试用

首次默认停止、无音频引擎输出、无监听；中文 440×220pt 启动卡显示版本和“开始打字钢琴”。只有用户点击开始，才先建立只观察全局监听、预加载已选音库、启用音画。缺权限时给出系统设置的手动路径，并展开错误卡；不调用申请权限 API。♪ 菜单最上方为开始/暂停，测试子菜单保留本窗口/全局60秒、局部候选和合成音。

`InputSessionDuration.continuous` 无60秒截止，仍每250ms检查安全输入和现有权限；事件tap失效/锁屏/睡眠/音频配置变化、暂停或退出都清理监听/按键/延迟释放/音符/声音，并关闭音频引擎。关闭测试控制台只结束60秒测试，不结束已主动开始的持续工作。监听失败或音频预加载失败都回到完全停止，不自动重试。

Fn/顶部排除/64键映射未改。普通浮动音符沿用700ms、减少动态200ms、标签可选且默认开启。菜单♪仍18pt原生模板图标。

## 音库与增益

按正式 docs/handoffs/A-002T.md 接收。运行时完整源为 `AudioTrial/trial-index.json` + `AudioTrial/vcsl-steinway-b/trial.sf2`；固定版本 a002t-steinway-mono.0.1、SHA-256 `2819d43506550ece98d80455388c913850acfcdd7ae45ee61908311a52997b5a`、大小22,744,220、恰好64音、program0/MSB121/LSB0。缺失/损坏/版本或选择器不合均报错，不自动换为合成音或局部音库。打包完整来源和许可证由 build.sh 负责。默认是 Steinway B 64音试用源；它不是最终听感批准。

读取本机 AVFAudio SDK 头文件确认 mixer.outputVolume 合法范围0...1，sampler.overallGain合法−90...+12dB。SF2 initialAttenuation=0、sustain attenuation=0，源统一处理增益−9.082dB，映射velocity全部64。旧链mix=.08时C4峰值=.0010227065；velocity32/64/100/127的实测分别=.000255676/.001022707/.002496836/.004027152，证明velocity响应也参与低电平。没有更改映射velocity或SF2素材。

新源独立profile：sampler+12dB，最大mix=.75，默认50%对应mix=.375；旧局部/合成测试仍使用原profile（max=.16/default=.08）。所有参数在准备阶段设置，不在按键回调读取资源。第一轮unity max（1）64音velocity127峰值=.9330222，因不满足测试余量阈值<.9而红灯，记录calibration-first.log；最终降低max至.75后重渲染通过。默认C4峰值=.019085（−34.386dBFS），比旧链+25.4dB，不等于已证明主观舒适度。

最终 `audio-calibration/calibration.json` 的90组真实离线渲染结果：
- 默认全64音均非零、有限；峰值范围.008718662—.030758396。
- 最大滑块64音velocity127，mono与实际双声道通道最大值同为.69976664（−3.10094dBFS，约3.1dB余量）；实际映射velocity64的和弦更低。
- 最大滑块120次异音/尾音叠加峰值.06140659；20Hz同音100次重击峰值.04128420。
- 10ms/100ms/1s/8s长短按、代表端点与跨区、尾音、panic、0音量、新击发抑制、调高不补播，以及关闭/重新启用静音均测试。
- zero/panic/no-replay渲染峰值严格0。代表文件 `audio-calibration/steinway-trial-float32.wav` 是采样器原始48kHz mono IEEE Float32，未后加增益/归一化。JSON给出片段帧位置、增益和文件hash。源bank为mono16不等于输出再次量化PCM16。
- 单独stereo离线接口记录两个实际输出通道；旧mono测试默认行为不变。

不证明任意无限重叠、其他设备/系统版本、硬件输出电平/声学延迟或听感。音效交接的MIDI94降混抵消约6.09dB及MIDI96约+14cents仍保留，没有逐音增益或调律改动。

## Dock可见性

系统适配器/恢复所有权未改；默认模拟，不写系统，仅显式手动系统入口会请求改变autohide。经主对话批准修复旧可见性策略：普通远离Dock的点击不再锁住隐藏；接近边缘/Dock前台隐藏；Dock区域拖动期间保持隐藏；释放鼠标、离开区域且Dock不在前台400ms后恢复。真实Dock键盘呼出、菜单、全屏/Space/屏幕变化仍未验证，不宣称精确观察到Dock可见性。隐藏画面不停止声音。

## 已运行的回归与限制

`session-red.log`→`session-green.log`、`gain-red.log`、`dock-red.log`→`feature-green.log`、`source-red.log`、`stereo-red.log`、`calibration-first.log`→`calibration-final.log`。最终音库/源选择/菜单/持续会话/增益聚焦11测试通过；`feature-green.log`另含Dock与旧策略11测试通过；最终`fault-cleanup.log`补权限和音频准备失败全清理。`test-compile.log`为仅编译/枚举，无真实输入。第一次修改初始化参数后曾触发增量链接旧符号，保留零参数初始化接口后重新构建通过。

所有输入和控制器测试使用注入mock；音库为AVAudioEngine manual offline。没有启动真实全局监听、硬件音频输出、改权限/系统音量/Dock或下载源文件。最终完整套件、candidate preflight绑定、App资源/签名/启动卡原生检查由主对话接续，必须使用 `TYPING_PIANO_EVIDENCE_DIR=.../docs/evidence/C-002T/candidate-regression`；不把本文件当最终完整通过结论。
