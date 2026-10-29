# 交接：C-032／程序实现对话
## 结论
已完成待主验收。0.2.9 / build12，基线由任务给定fe4c65d。90项源码/依赖文件已冻结，完整测试仅运行一次：146项，143通过、3条件跳过、0失败。独立ad-hoc候选已生成，仅运行CLI/离屏入口；已安装0.2.8及既有发布产物未改。

## 实际产物
- 候选App：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.9/打字钢琴试用.app`
- ZIP：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.9/打字钢琴试用.zip`
- 二进制SHA256：`72a7f947cbb0d73300e57c41880714e273feae8eebe4b8ef394b7fa4884e34cc`
- ZIP SHA256：`86a8bff441df46345ece852bccebc2ef2139949edf5aee4f2996abd33e52db71`
- source-hashes.json SHA256：`6767f535bfc3ef1c1a11b6672f75be885ac727bed0acaaa07f560fec805fb8cc`
- 交付机器记录：delivery.json、verification.json、source-hashes.json。
- 仅3张图：previews/transparency-0.png、transparency-50.png、transparency-100.png；previews/report.json覆盖0/15/50/100及系统覆盖，均来自生产PianoView的2528×512离屏渲染。未复制before源码树，未提交Git。

## 变更范围
仅Code及本目录。改变文件（与0.2.8冻结清单比较）：
- Code/IMPLEMENTATION.md
- Code/README.md
- Code/Scripts/build.sh
- Code/Sources/PianoCore/AppPreferences.swift
- Code/Sources/PianoMac/PianoView.swift
- Code/Sources/PianoMac/ProbeController.swift
- Code/Sources/PianoMac/ProbeMenu.swift
- Code/Sources/PianoMac/QuietIvoryProvenance.swift
- Code/Sources/PianoMac/TransparencyEvidence.swift
- Code/Sources/PianoProbe/main.swift
- Code/Tests/PianoMacTests/TransparencyTests.swift

新增偏好transparency默认0.15，缺失/null/非数字回落，有限越界钳制，整数百分比保存。菜单标签82pt避免裁字；0—100滑块沿用高度的250ms保存定时器、关闭菜单补存和退出dirty/重试/取消路径。未重写保存架构。

材质内部按U-031配色画实色键面，在单独透明层以1-transparency统一合成；底座/边缘/投影/高光同层衰减，白键扣除按压后的黑键轮廓。标签保持白键#969FA9/.86、黑键#414B55/.84；浮音与标签在该层外独立绘制。Dock的窗口alpha、音画事件、held/custom mapping、音源和权限均不改。系统Reduce Transparency开启时只覆盖有效材质opacity并禁用滑块/显示原因，保存值不改，关闭后恢复。

## 复现方法
已执行以下流程，完整日志在本目录；无须为接收再重复代码侧完整测试。
1. `swift test --package-path Code --scratch-path /Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.9/swiftpm --filter TransparencyTests`：targeted-final.log。
2. `swift test --build-system native --package-path Code --scratch-path /Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.9/swiftpm`：full-test.log，仅一次。
3. 显式TYPING_PIANO_SIGN_IDENTITY=-、TYPING_PIANO_BUILD_ROOT指向上述独立candidate-0.2.9，运行Code/Scripts/build.sh：build.log。
4. 直接调用候选Contents/MacOS/TypingPianoProbe的`--self-check`、`--menu-smoke`、`--transparency-snapshot <本目录绝对路径>/previews`。分别产生对应JSON/stderr；未运行候选GUI、window-smoke、旧7图入口或open/lsregister。
5. codesign --verify --strict、ZIP CRC及内含二进制哈希匹配、Info.plist版本、90冻结源文件和153保护文件逐项比较：verification.json、codesign.log。不要重建覆盖已冻结候选。

## 测试证据
环境：macOS27.2 (26B123)、arm64、Apple Swift6.4，见environment.json。macOS14是编译目标，不是跨系统认证。
- PASS：5个新增针对性测试，旧/无效偏好兼容、真实NSSlider action及禁用状态、64键alpha端点、减少透明度恢复、100%材质全像素透明、独立标签/浮音、held输入及音频mock状态与其他偏好保存保持。第一轮RED为未实现API；第一次实现后仅细字形抗锯齿峰值断言过严，改为验证可见且不超过指定alpha后通过，没有以生产渲染改动掩盖失败。
- PASS：完整146项，143通过、3 CandidateBankTests按既有opt-in要求跳过、0失败；height、保存失败/退出取消、自定义映射、浮音、Dock策略、离线音频等已有回归覆盖见full-test.log。系统后端为mock，AppKit窗口测试是测试进程临时窗口，不是候选GUI实测。
- PASS：64键每个档位的面中心alpha一致，0→1，15→0.85098，50→0.50196（8位像素量化），100→0；100%无标签/浮音时整个材质图所有像素alpha=0。系统覆盖四档均为1且保存值不变。
- PASS：已查看3图；100%图仅保留深/浅灰键名与浮音，无底座、高光、边框、阴影残留。浮音区域在0/100%材质下逐像素相同（针对性测试）。
- PASS：构建、CLI self-check/menu-smoke、3图报告、strict ad-hoc签名、ZIP CRC/内含二进制、版本0.2.9/12、源冻结和153保护文件完整性。

## 已知限制
NOT RUN：真实菜单拖拽和菜单文字最终视觉、真实系统减少透明度切换、0.2.9真实全局输入/听音/Dock实景、TCC续接、固定身份签名安装与发布。离屏背景为三色合成，不能代替真实桌面合成。构建原有--build-system native弃用提示保留；未扩展范围处理。

## 请求主对话处理
接收上述冻结源/候选；按既有固定身份流程重新签名并比较0.2.8 designated requirement，封存ad-hoc后安装续验。代码侧不操作运行App、用户偏好/TCC或GitHub。

## 下一步建议
1. 主独立验收及固定签名/旧DR比较。
2. 封存临时候选后原路径安装，检查真实菜单/减少透明度恢复、输入听音和TCC续接。
3. 主按授权提交并发布，校验下载包。
