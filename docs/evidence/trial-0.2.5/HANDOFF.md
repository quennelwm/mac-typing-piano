# C-GH-025／0.2.5候选交接（CODE）

状态：代码与无窗口验证已完成，待主对话真实GUI验收。2026-10-28。候选包与签名现已冻结；不要在此目录继续重建或重签。

## 产物与范围

- App：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.5/打字钢琴试用.app`
- ZIP：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.5/打字钢琴试用.zip`
- Version0.2.5 / build8 / Bundle ID `local.typingpiano.trial` / arm64。
- Binary SHA-256：`5a5a2e384d1b10240f19cc5d3edd1ec404e0004cb80040fc78233c7990440fa0`
- ZIP SHA-256：`0b3033c1ee2d384c21dc163133c04f11acb7ec0eb9f91563bfebb17b010a2437`
- 机器可读记录：[delivery.json](delivery.json)。

本轮修改5个已有文件：`Code/Sources/PianoMac/ProbeMenu.swift`、`Code/Sources/PianoMac/ProbeController.swift`、`Code/Scripts/build.sh`、`Code/README.md`、`Code/IMPLEMENTATION.md`，另写本证据目录。源码/脚本/测试/资源快照见[source-hashes.json](source-hashes.json)，相对接手时的实际增量见[changes.diff](changes.diff)。接手时共享文件已包含16pt槽宽、16×16pt画布；本轮明确接收这部分改动。

♪继续由18pt medium系统字体绘制，按CoreText实际墨迹边界居中并仅按需缩小，16pt画布四周留0.5pt余量；拒绝空/无效边界，避免除零。模板图标及可访问名称不变。其余生产行为只更新未打包启动标题的版本fallback；构建脚本改为candidate-0.2.5、0.2.5/build8。没有新增测试、依赖或资源，没有修改输入、声音、Dock逻辑。

## 本轮验证

环境：macOS27.2 (26B123)、arm64、Apple Swift6.4。macOS14为编译目标，不等于经过macOS14兼容验收。

- [build.log](build.log)：release构建、资源manifest校验、ad-hoc签名及ZIP生成成功，独立输出目录。
- [tests.log](tests.log)：已定义无窗口组 **64项、0失败**；含菜单回调/集成、输入状态、Dock mock、宽度/淡变、重复启动等。未运行完整无过滤测试。只有现有SwiftPM native backend弃用提示。
- [self-check.json](self-check.json)：64键映射及资源/主题检查成功，无监听、权限请求、硬件声音或真实Dock写入。
- [menu-smoke.json](menu-smoke.json)：通过；requestedStatusItemWidthPt=16，连续音量滑块回调0.75/显示75%，模板图标true。没有安装真实NSStatusItem，不能把请求宽度当作实际按钮宽度或无裁切的现场验收。
- [signature-check.log](signature-check.log)：strict验证成功，arm64/ad-hoc，无Developer ID与公证。

复现：从仓库根按`Code/README.md`创建新的独立候选输出目录，再执行构建、自检、menu-smoke及其中完整64项过滤命令。请勿使用已冻结的candidate-0.2.5作为再次构建目标。

## 现有安装保护

任务开始时固定安装Info.plist为0.2.4/build7；实际读取的binary SHA-256为`81fb97253ca4cac9c9f59e42689d9e067743732dfae11f62bd8f598f1955c394`，与更早交接记录不同，因此本次保护比较使用任务开始时的实际快照，不推测其变化原因。[protected-install-before.json](protected-install-before.json)和[protected-install-after.json](protected-install-after.json)共42个包内文件逐一哈希相同。

没有覆盖、启动、退出或重签当前安装，没有启动候选GUI，没有改变权限、真实Dock或用户偏好，也没有执行Git操作。CLI preflight为true仅属于本次进程，不能据此承诺新签名GUI授权已延续。

## 未测与主对话后续

1. 主对话在准备好正常退出旧版后，独立执行真实16pt菜单宽度、图标完整显示、点击/菜单展开/滑块拖动验收；本轮未拍摄新GUI图或逐像素离屏图。
2. 安装升级、输入监控是否需移除旧条目后重新添加、真实全局实按/声音和Dock联动由主对话验证；保留用户偏好，不能在运行中覆盖旧包。
3. 主对话维护根README、下载指南及公开GitHub发布。其他macOS/Intel、多屏/全屏、完整物理键矩阵、长时稳定性仍未验收；原生Dock私有SPI的未来兼容性边界沿用0.2.4。
