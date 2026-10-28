# C-001C 原生组件集成与验证记录

角色：代码实现子任务；不代替主对话HANDOFF/验收。环境为本机 macOS 27.2（26B123）、arm64，2026-10-28。未运行真实键盘监听、硬件音频播放或系统 Dock 写入；未修改 Design、contracts 或 Git。

## 实现

- `Code/Sources/PianoMac/PianoView.swift` 使用独立键面路径、渐变、底沿、黑键阴影与 CoreText 标签；逐项转写已批准的 `Design/UI/tools/native_render.swift`、`UI_SPEC.md`、`MOTION_SPEC.md` 和新增 `integration/NATIVE_ADAPTER.md`。运行时标签只来自统一 keymap。原测试用布局 API 保留，Quiet Ivory 新布局独立放在 `PianoGeometry.quietIvory`。默认1000pt，菜单可选900/1100pt，104pt窗口包含48pt透明上方空间和56pt主体。
- `QuietIvoryProvenance` 将当前编译样式绑定到已批准主题 SHA-256 `1cd6ec885ff33d3cb071300c63b753604d29c5b4b28fbcdccf69812fff0220fb` 及映射 SHA-256 `147ad9041aa7514e70e80c94a476149f47944d36f74367825ae95bd69edf245b`。这是固定候选的编译样式，不是新动态主题接口。缺失或变更会给出路径诊断；不执行主题里的字符串。
- 按键45ms下沉、100ms回弹、短按至少45ms按下过程；短up继续当前下沉曲线，随后回弹，不突然跳到全按下。重击从当前呈现位置转向按下；每键最多一个分段状态。减少动态时即时明暗、无位移。
- 每个有效新pressID一枚700ms的♪，12pt，24pt上升；减少动态为200ms原位淡出。与声音和标签独立；up不会截断音符。隐藏/总暂停/安全阻断清空并停动画Timer，恢复不补播。真实自动Timer测试确认0.8秒后释放；空闲/长按停止动画刷新。系统减少动态通知已接入，实际系统设置切换尚未现场验收。
- 原生菜单18pt♪使用与批准图标相同的CoreText墨迹居中/15pt内框拟合，并设置模板图像。日常菜单无任务编号/M1；测试入口、三种音源、系统Dock试验/恢复集中在测试子菜单。滑块只改本App增益和已保存音量。
- `AudioSource` 在初始化时读取A-001B trial-index.json中的音域，不复制第二份MIDI表。合成原64音仍可选，两真实候选分别标注10/64与11/64键有声；缺音不替补。`AuditionSession` 默认关闭，只有明确启用调用prepare；按键路径不加载文件。切库先暂停输入（推进InputMonitor epoch使旧队列失效）、清理协调器/延迟任务/图形，再shutdown，保持停止，必须重新开启测试和声音。
- `DockAdapter` 注入读写存储和恢复票据存储，复用既有DockOwnership。默认仅内存模拟。实际系统入口先显示说明，由用户主动选择；真实适配器仅固定`/usr/bin/defaults read/write com.apple.dock autohide`，无shell、killall或其他键。关闭提醒及取消按钮沿用批准原文；取消不改期望或任何存储。
- Dock写前原子保存票据，写后读回与视觉生效严格分离。外部不同值不覆盖；退出仅恢复自己仍持有的已验证值，失败留票据。写后读回nil/抛错阻止后续事务覆盖原始值，进入明确恢复流程；启动不自动恢复崩溃票据。相同布尔值无法识别外部同值写入，这个限制已在恢复提示说明。所有系统行为仍未现场实测。

## 包资源要求

不需要整条钢琴位图、SVG解码依赖或字体文件。必须包含：

- `Resources/keymap.ansi64.v0.1.json`
- `Resources/theme.candidate.json`
- `Resources/placeholder-original.sf2`及原占位许可
- `Resources/AudioCandidates/trial-index.json`
- `Resources/AudioCandidates/vcsl-kawai/trial.sf2`
- `Resources/AudioCandidates/vcsl-steinway-b/trial.sf2`
- A-001B候选目录中配套manifest、parameters、来源记录、制作说明、许可与UI来源许可由主对话构建脚本完整保留。

源目录CLI仍从Design/Audio/probes/A-001B读取候选；打包App只使用bundle内路径。没有资源加载失败时的静默音源回退。应用偏好与票据仍使用联调路径，不代表正式偏好迁移已完成。

## CLI/证据

- `--self-check`：映射、主题指纹、三个音源路径/覆盖与存在状态，保留监听/硬件音频/Dock均未启动标志。
- `--snapshot DIR`：36张rest/single/multi×3宽度×标签开关×1x/2x图，`captures.json`含实际矩形、墨迹范围、基线、回退字体、主题/映射/可执行文件hash、OS、倍率和场景。第一批仅rest的12张旧命名图保留供追溯；以最新captures.json为新批次索引。
- `--animation-snapshot DIR`：180张生产绘制逐帧图（四组普通/减少动态×标签开关，含350ms；另含短按/回弹中重击各14帧）与frames.json。是确定性离屏逐帧证据，不是屏幕录制或真实输入延迟。
- `--menu-smoke`：原生菜单/连续滑块程序化烟测，不触发真实菜单系统操作。
- `--window-smoke`：104pt非激活/鼠标穿透窗口程序化烟测，实际鼠标点击、Dock和屏幕可读性仍待验。

## 测试与边界

测试先行引入API与行为断言；API缺失RED日志以及后续GREEN均保存在本目录。针对短按跳变、Dock不确定读回和首次击发，另执行了临时移除修复的行为RED，finally恢复源码后再次GREEN。无测试期间遗留的代码回退。

- `swift-tests.log`：54项XCTest零失败，包括原38项及新增16项；执行环境/命令为 `TYPING_PIANO_EVIDENCE_DIR=<项目>/docs/evidence/C-001C/candidate-regression swift test --build-system native --scratch-path ~/Library/Caches/local.typingpiano.probe/swift-build --package-path Code`。
- `candidate-preflight.log`、`candidate-summarize.log`：旧回归按preflight→完整Swift测试→summarize执行，输入36文件绑定、两真实SF2离线191/193检查通过、来源未变。原C-001B目录未被覆盖。
- `final-targeted-tests.log`：加强首次击发断言后，最终16项新增定向测试零失败。控制器测试注入输入源与音频引擎，仅合成事件；没有真正监听键盘或启动硬件输出。测试展示非激活浮层/非激活控制窗口后清理。
- `behavior-regression-red.log`与`first-strike-red.log`：证明旧短按模型、旧不确定Dock恢复门槛和移除start后refresh会分别失败。
- 候选离线响度/峰值/释放验证不等于声学延迟/真实声部上限/目标扬声器听感；64实体键、Fn/Caps/左右修饰/中文/快捷键、菜单拖动、系统Dock读写视觉效果和恢复需用户实机继续验收。

未修改或提交生产发布设置，未安装依赖。最终构建/签名/打包路径及完整交接由主对话提供。
