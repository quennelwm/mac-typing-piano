# 交接：C-029／普通工作窗口遮挡修复

## 结论
状态：已完成待主对话验收，最终生产源码已重新冻结。本次只解冻窗口层级和必要诊断/回归。仍为0.2.7/build10，未发布；旧C-027/C-028候选哈希被本次新候选取代，历史证据保留。

## 根因与修复
ProbePanel使用.normal，真实WindowServer layer0。其isVisible=true仅表示已order in，普通窗口前置后仍为true，不能保证未遮挡。red.log以两个真实重叠普通NSWindow依次A→B→A前置复现：panel rank9，普通窗口rank7/8，三个步骤均失败。

生产改动仅将ProbePanel.level改为.floating（本机layer3）。不增加激活、反复orderFront、监听、计时器或权限；保留hidesOnDeactivate=false、鼠标穿透、不可key/main、fullScreenNone，以及原会话隐藏和Dock淡出逻辑。

--window-smoke复用新增真实窗口顺序诊断；CLI和XCTest均显式使用生产相同.accessory策略，不调用activate。先等待WindowServer登记（最多1秒），每次切换普通窗口仅前置普通窗口，钢琴不再次orderFront。记录真实ID/rank/layer及前台PID；最后前置真实.modalPanel代理窗口验证钢琴低于该窗口。rank数字越小越靠前。

## 变更范围
- Code/Sources/PianoMac/PianoView.swift：普通层改浮动层。
- Code/Sources/PianoMac/OverlayWindowEvidence.swift：显式诊断，临时重叠窗口、CGWindow顺序和焦点证据。
- Code/Sources/PianoProbe/main.swift：已有--window-smoke升级，使用.accessory。
- Code/Tests/PianoMacTests/OverlayWindowStackTests.swift：复用生产ProbePanel和诊断，验证真实排序。
- 本目录新增证据。未改契约、UI/音频资产、PM签名/安装包或TCC；未执行Git操作。

## 复现方法
在项目根目录：
```sh
swift test --build-system native --package-path Code --scratch-path "$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.7/swiftpm" --filter OverlayWindowStackTests
TYPING_PIANO_SIGN_IDENTITY=- TYPING_PIANO_BUILD_ROOT="$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.7" bash Code/Scripts/build.sh
"$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.7/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe" --window-smoke
```
诊断直接运行候选可执行文件并自行结束，不通过open启动第二个生产会话，不启用输入、音频或系统设置。临时窗口短暂出现后只关闭自身窗口。

## 测试证据
- environment.json：实际macOS、架构、Swift环境；源基线来自任务卡8cf809a加C-027/C-028冻结，不查询Git。
- red.log：原.normal真实遮挡失败，非常量断言。
- green.log：最初固定80ms采样时floating不在onscreen，失败保留，不计通过；其原因未确定，不能宣称一定由activationPolicy或外部窗口操作导致。
- stack-diagnostic.log/full-tests-final.log：后续真实排序通过，尚未明确统一activationPolicy，只作中间证据。
- full-tests-accessory.log及window-smoke-accessory.json：最终以生产.accessory策略复核，以这里结果为准。
- source-hashes.json、changes.diff、delivery.json：本次最终源码、最小差异与重建哈希。

## 现有自定义编辑器入口核查
真正运行时编辑器只由♪菜单“自定义键位…”调用ProbeController.showKeymapEditor，保存连接现有customStore和正在运行的映射。测试控制台没有相应按钮，也没有可远程打开此窗口的现成启动参数或命令接口。

现有--keymap-editor-snapshot <目录>可以生成4张真实AppKit控件离屏图，但使用独立内存保存回调，不会操作当前运行App或真实用户自定义配置，不可当作运行时保存验收。未为测试增加用户主界面。主对话应通过现有♪菜单验收运行时编辑器。

## 已知限制
本次“普通工作窗口切换”等效回归使用本进程真实NSWindow和WindowServer顺序，不冒称已安装App的跨应用实机验收。modal代理level8高于floating3，Dock和系统菜单SDK层级分别20/24；未打开实际TCC弹窗，不能外推所有权限窗口。occlusionVisible字段在最后modal覆盖钢琴后采样，false符合预期。

保留fullScreenNone并回归原会话阻断、锁屏/睡眠独立原因和Dock逻辑；本轮未切换真实全屏Space、锁屏、睡眠或操作Dock/系统权限。全屏/多屏/真实系统对话框需主对话后续实机验证。

## 请求主对话处理
候选只做ad-hoc签名。最终开发签名、安装/替换、已安装layer与跨应用前景检查仍由主对话执行；本对话没有停止或替换当前运行的已签名0.2.7。

## 最终结果与候选哈希

- 完整回归131项：128通过、3项候选音库测试按设计跳过、0失败。本轮未重复3项音库离线重放；此前C-027/C-028已单独执行，其历史证据未改。
- 最终候选实际--window-smoke：accessory=1，layer3，A→B→A排序通过，低于modal代理，前台PID不变；self-check/menu-smoke通过。
- 82个最终源文件哈希复核，438个受保护文件字节未变。主对话同时重命名final-signature/installed为pre-c029并更新REVIEW，已单列，未误报其字节未变；主已签名App和已安装App完整性检查通过。
- arm64、0.2.7/build10，strict ad-hoc签名、ZIP CRC及内含二进制一致性通过。
- binary SHA256：`1c4ed52c7d12a22382a96bcba205e70f45284c7d2a5c8dba3d12ee13e43ed4dd`
- ZIP SHA256：`e608ba1b97a5aa56397b8fb3db3ec23108409e7766d351161ca8fd2fb97e489a`
- source-hashes.json SHA256：`10d4d0733429809e6f3c6fcb4834f71a6042dfb0937876faf66f0ebc48e04bc1`

交付路径与机器可读结果见delivery.json。当前源码没有进一步修改；主可据本目录清单重新签名并验收。
