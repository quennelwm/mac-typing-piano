# 交接：C-034／程序实现对话
## 结论
代码完成待主验收及实机交互验证。0.2.11/build14，接续任务给定b74f560加未提交C-033；本对话未作Git操作。97项源码/依赖冻结，唯一最终manifest SHA256：`873388910a57dc99eb302b8e2d28bcb04e95b6b6d7cc914db5aaeb8608c920a0`。最终158项，155通过、3既有条件skip、0失败。

旧0.2.10两种菜单关闭现场FAIL保留。C-034不将popover构造、hitTest或单测冒充现场关闭通过。确切旧失败机制仍UNKNOWN，见CLOSE-INVESTIGATION.md。

## 实际产物
- 候选：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.11/打字钢琴试用.app`
- ZIP：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.11/打字钢琴试用.zip`
- 二进制SHA256：`cff5298a4b7fb4e33c19a6e5e7280ca41e1ae926098a9a35d153e3a1260d1125`
- ZIP SHA256：`b4810a31157030cb3416d63789218ad563fb6e7fee4c3144f43c839bc9b9cdd1`
- 最终构建日志：**build-frozen.log**；最终完整回归：**full-test-frozen.log**。
- verification.json、delivery.json、source-hashes.json、environment.json。
- 两张最终离屏图：previews/control-panel.png（270×370pt普通原生控件），previews/binding-draft.png（760×390pt，完整64键、等待目标蓝边和草稿）。均已查看。previews/report.json记录方式；无真实菜单截图，未启动候选正常GUI。
- 性能唯一最终结果：**benchmark-frozen.json**。其他render-before/after/paired及debug/build-delivery日志为中途诊断，不能替代最终源/包。旧42bc…及155b…manifest已被撤回，最终仅上述873388…有效。

## 变更范围
仅Code及本目录。相对C-033冻结源的变化：
- Code/IMPLEMENTATION.md
- Code/README.md
- Code/Scripts/build.sh
- Code/Sources/PianoCore/AppPreferences.swift
- Code/Sources/PianoMac/AlertVolume.swift
- Code/Sources/PianoMac/ControlPanel.swift
- Code/Sources/PianoMac/ControlPanelEvidence.swift
- Code/Sources/PianoMac/KeymapEditor.swift
- Code/Sources/PianoMac/PianoView.swift
- Code/Sources/PianoMac/ProbeController.swift
- Code/Sources/PianoMac/ProbeMenu.swift
- Code/Sources/PianoMac/QuietIvoryProvenance.swift
- Code/Sources/PianoMac/RenderBenchmark.swift
- Code/Sources/PianoMac/TransparencyEvidence.swift
- Code/Sources/PianoProbe/main.swift
- Code/Tests/PianoMacTests/ControlPanelTests.swift
- Code/Tests/PianoMacTests/ControllerIntegrationTests.swift
- Code/Tests/PianoMacTests/OverlayVisibilityTests.swift
- Code/Tests/PianoMacTests/TransparencyTests.swift

CR-012实现：
- 状态项16pt ♪保持，根承载改瞬态NSPopover普通控件；按钮leftMouseDown切换，同一鼠标事件编号去重自动dismiss/action，移除0.6秒时间窗。Esc仅App局部处理；关闭补存但不暂停。外部关闭依赖瞬态宿主，真实点击仍须实测。
- 运行勾选控制整体会话；独立浮音默认开并保存。按键声音左状态/右switch同步。暂停时调控只保存，不恢复输入/引擎/画面。原静态“暂停仍显示钢琴”测试按新需求改为隐藏；Dock隐藏声音继续的规则保持。
- 四条单行slider：归一化高度0—1映射0.5—1.8，旧1.32保留约63%；透明度0—1；App音量；系统alert volume。App音量实时改gain，250ms合并偏好保存。提醒音量拖动只更新UI/待写末值，250ms后写一次，关闭异步补写，退出先补写再按会话所有权恢复。
- 展开不请求权限/写系统，也不在展开/关闭同步读NSAppleScript；提醒音量启动后异步读取一次，显式提交时重新读取核验。首个original保留，lastVerified泛化为任意0—100，外部变化放弃恢复。调音量→旧静音入口→正常恢复仍保留最初original，失败和未核验状态不假报成功。
- 自定义主界面仅模拟琴键→实按→保存；旧下拉/表格仍保留测试兼容对象但不在主界面。等待目标有蓝边与文字，重复绑定交换保持双射，标签按草稿更新。保存原子管线保持，取消/关闭不应用，恢复默认仅草稿。
- 本地捕获仅编辑聚焦且等待；Esc/失焦取消。Command单按延后释放，⌘S/⌘W优先；绑定普通键后消费其repeat/keyUp直到释放，避免按住Return误保存。编辑打开先安全暂停，编辑窗口可见时拒绝重新启动，避免丢释放事件残留held。没有其他App事件吞取/逐键记录。
- top/bottom互斥偏好默认top。top仍floating，bottom为desktopIconWindow+1，屏幕变化不重置；切换不改变held/audio，不增加抢焦点循环。
- 黑键文字改#68717A/.90，白键#969FA9/.86保持；纯黑主体、独立透明度/浮音和实时按压几何保持。

性能：Dock仍100ms观察，状态未变不走全套refresh；暂停不采Dock，面板关闭不逐击更新菜单或做启动权限预检。已有activeMIDI旧值guard未被冒充新修复；新增同尺寸setFrameSize和浮音设置guard。阴影改窄矢量边缘层次以消除逐键高斯模糊；白键只扣相邻黑键且裁剪区域限对应键；透明材质中间层排除144pt留白。有限每键材质tile不含标签/浮音/背景，白键仍按实时黑键轮廓裁剪；静止键层运行时缓存随几何/映射/标签/透明度/按压/辅助设置失效，运动期间仍独立实时绘制。非预制整条贴图。bitmap+tiles总保留每view≤4MiB（分配前含旧bitmap，生成后再核），生产三view≤12MiB；tile≤1MiB，颜色/渐变缓存≤64/8对象。这个上限不含CoreGraphics临时工作区/窗口后备或音源，不能替代实际RSS结论。

## 复现方法
1. 分段回归见stage及targeted日志；8个ControlPanelTests覆盖偏好、提醒音量所有权、直接绑键草稿、暂停/声音/层级隔离、4轨道hitTest、⌘S/单按Command/Return repeat、失焦、静止缓存复用及预算。
2. 最终完整命令：`swift test --build-system native --package-path Code --scratch-path /Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.11/swiftpm`，结果full-test-frozen.log。过程中因新边界修复及主要求UI文案共运行4次完整套件，旧结果不覆盖新源；交付只认最后一次。
3. 最终构建显式TYPING_PIANO_SIGN_IDENTITY=-，TYPING_PIANO_BUILD_ROOT指向上述candidate-0.2.11，运行Code/Scripts/build.sh：build-frozen.log。不要覆盖已冻结候选。
4. 候选二进制直接CLI：--self-check、--menu-smoke（旧诊断适配器，不能代替新面板验证）、--control-panel-evidence <本目录>/previews、--render-benchmark。对应JSON/stderr已保存。无open/lsregister/候选GUI/系统写入。
5. strict codesign、ZIP CRC和内部二进制匹配、版本14、97项源hash及153项保护hash比对见verification.json。保护快照在候选构建前采集，不是任务开头全状态快照；截至验证时当前安装仍0.2.10且保护字节未变。

## 测试证据
环境：macOS27.2 arm64 / Swift6.4，environment.json；macOS14为编译目标，不是跨系统认证。
PASS：最终158项155通过/3 CandidateBankTests按既有opt-in条件skip/0失败。覆盖0/50/100%材质、26黑键主体、标签/浮音独立、动态轮廓命中/高度、Dock规则、映射原子保存与held状态、离线音频等原回归。
PASS（程序化/模拟）：四轨道10/50/90%位置命中真实NSSlider及连续target-action路径；不等同实际鼠标拖动。CGEvent/NSEvent构造后直接调用本地编辑路由，验证命令键和repeat，不注入OS/不代表实按。
PASS：2图离屏、strict ad-hoc、ZIP CRC/内部二进制、源冻结与保护字节。

最终同进程配对基准（1496×256pt、2×、预热4帧后60帧，计入状态advance/渲染/CGContext+makeImage，无PNG IO；进程CPU含其他线程，wall为单帧同步耗时）：

| 场景 | 缓存关 P95 CPU ms | 缓存开 P95 CPU ms | 缓存开 P95 wall ms | 键层绘制次数 off→on |
| static | 16.418 | 0.724 | 0.742 | 64→1 |
| floating-only | 15.852 | 1.408 | 1.111 | 64→1 |
| press-plus-floating | 15.956 | 14.746 | 15.272 | 64→54 |

浮音组实际每8帧strike一次，末次advance后均清零；press组每8帧切换约21音/释放前组并击发浮音，是和弦压力组，非普通人打字或每帧全键切换。冷帧CPU/wall、浮音绘制次数、精确缓存字节也在benchmark-frozen.json。当前暖缓存保留约2.8—2.9MB/view。最初未优化中途全量场景P95约50ms仅为追溯，最终配对表才是同口径cache对比。没有把进程CPU毫秒换算为实际fps，也没有据离屏数值声称实机流畅。

## 已知限制
NOT RUN：真实♪短点/长按重复关闭、外部点击、Esc后立即点、四滑条点击定位/连续拖动/跨子菜单跟踪；候选正常GUI完全未启动。
NOT RUN：真实实体键矩阵/Fn、真实系统提醒音量写/读回/外部修改/退出恢复、权限返回/取消/TCC升级、真实top/bottom多屏全屏。
NOT RUN：安装后的实际动画帧间隔/长尾、同口径常驻CPU/RSS/长时泄漏。旧0.2.10主采样为非受控空闲，不能与离屏基准直接比较，参考主PM-034/performance-baseline。真实低CPU/内存与流畅仍须现场验证。
确切旧菜单失败触发机制未证实，已记录而非臆称根因。现有--build-system native弃用提示未扩散处理。未修改用户偏好、运行App、TCC或Git。

## 请求主对话处理
以最终873388…manifest、full-test-frozen.log、build-frozen.log和本候选接收。按固定身份签名并比较0.2.10 DR，封存ad-hoc候选后安装。主开始替换后代码侧不再重建/重查旧安装保护。

## 下一步建议
1. 主/UI/R最终核对冻结源及2图，固定签名/旧DR比较。
2. 同路径安装，逐项实点关闭、四滑条及最终保存、绑键与层级、提醒音量，保留用户原偏好。
3. 同口径现场动画/CPU/RSS验证后再决定发布，不能把代码通过提前写成现场通过。
