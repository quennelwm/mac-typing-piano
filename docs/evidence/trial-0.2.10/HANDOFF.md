# 交接：C-033／程序实现对话
## 结论
已完成待主验收。0.2.10/build13，同时落实CR-010紧凑菜单和CR-011纯黑有光泽黑键。任务给定基线b74f560f97c64ead47e64fc510c01b7c8e92d371；不作Git操作。93项源码/依赖文件冻结。完整测试一次：150项，147通过、3既有条件跳过、0失败。当前已安装0.2.9保护文件未变。

## 实际产物
- 独立ad-hoc候选：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.10/打字钢琴试用.app`
- ZIP：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.10/打字钢琴试用.zip`
- 二进制SHA256：`a95146a73d2ef5784a77827bca3bf53c33bef2acfa7f3f7ecd6ad331c374397d`
- ZIP SHA256：`8171537a872c3e5c28973cc115e4fc6c6d4d42daf319025cf0387574c025eab5`
- source-hashes.json SHA256：`212add602c1fee7c2ea32d29e5b25783a5a0c0028e134f512ea3ad7a70be6fc7`
- delivery.json、verification.json、source-hashes.json；菜单对照menu-comparison.json，原生尺寸/树/文字边界previews/report.json。
- 两张预览：previews/menu-layout.png（原生slider视图离屏重建，非系统菜单截图），previews/black-opaque-detail.png（生产PianoView局部）。未复制before源码树，未执行候选GUI。

## 变更范围
仅Code及本证据目录。相对0.2.9冻结清单的源码变化：
- Code/IMPLEMENTATION.md
- Code/README.md
- Code/Scripts/build.sh
- Code/Sources/PianoMac/CompactMenuEvidence.swift
- Code/Sources/PianoMac/PianoView.swift
- Code/Sources/PianoMac/ProbeController.swift
- Code/Sources/PianoMac/ProbeMenu.swift
- Code/Sources/PianoMac/QuietIvoryProvenance.swift
- Code/Sources/PianoProbe/main.swift
- Code/Tests/PianoMacTests/CompactMenuTests.swift
- Code/Tests/PianoMacTests/GlossyBlackTests.swift
- Code/Tests/PianoMacTests/KeymapEditorTests.swift
- Code/Tests/PianoMacTests/MenuIntegrationTests.swift
- Code/Tests/PianoMacTests/StartupEntryTests.swift

菜单保留NSStatusItem.menu/原生NSMenu系统跟踪，不增加鼠标监听、模拟面板或新的权限种类。三滑块统一166×50pt两行视图，正文13pt、标题96pt/数值44pt，100%/180%完整；最终NSMenu尺寸另外测量，不能把166pt当菜单宽。

根层运行/声音/外观/设置帮助分组，系统声音与Dock归系统子菜单，启动/下载/测试归帮助。配置读取错误、设置保存失败和减少透明度用短状态，全文tooltip保留。根menu delegate才执行打开/关闭回调，关闭补存沿用旧管线；未改偏好格式、保存机制、映射、音频或Dock逻辑。

打开菜单只读输入监控预检。未授权的显式“输入监控授权…”点击，暂停当前无授权会话、显示既有说明窗口并直接复用handleStartup(.primary)，不要求第二次按钮点击。已授权直接打开系统输入监控页，不主动pause/panic或重启监听。原安全输入、授权续接/取消状态机保持；系统请求/页面打开依赖可注入，测试均替换为计数函数，没有真实TCC请求。原本窗口试弹失焦保护保持，不能把全局会话不暂停测试扩大成所有场景保证。

CR-011仅改变黑键底色与局部高光：主面#000000，减少透明度退路相同；0.7pt窄边缘高光，按压降低局部高光强度，位移/遮罩/命中沿用。白键、黑#414B55/.84及白#969FA9/.86标签、材质统一透明层、浮音均保持。U-031原始配方文件仍按原哈希保留用于溯源，CR-011覆盖已在元数据标识u031.1+cr011。

## 复现方法
已执行，日志均在本目录；代码侧无需重复完整套件。
1. `swift test --build-system native --package-path Code --scratch-path /Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.10/swiftpm --filter 'CompactMenuTests|GlossyBlackTests|MenuIntegrationTests|StartupEntryTests|HeightIntegrationTests|TransparencyTests|KeymapEditorTests|CrystalRenderingTests'`：targeted-final.log。两个可选环境变量TYPING_PIANO_MENU_EVIDENCE、TYPING_PIANO_BLACK_EVIDENCE指定新JSON输出路径，不能指向旧证据。
2. 无filter的同一swift test命令：full-test.log，一次最终完整回归。源冻结前后无变动。
3. 显式TYPING_PIANO_SIGN_IDENTITY=-、TYPING_PIANO_BUILD_ROOT为独立candidate-0.2.10运行Code/Scripts/build.sh：build.log。不要覆盖冻结候选再构建。
4. 直接调用候选Contents/MacOS/TypingPianoProbe：`--self-check`、`--menu-smoke`、`--compact-menu-evidence <本证据绝对路径>/previews`。对应JSON/stderr已保存。未运行open、lsregister、候选正常GUI、window-smoke或旧钢琴大图入口。
5. strict codesign、ZIP CRC/内部二进制匹配、版本0.2.10/13、93项源冻结及153项保护文件比对：verification.json。installed实际版本仍0.2.9。

## 测试证据
环境：macOS27.2 (26B123)、arm64、Apple Swift6.4，environment.json。macOS14为编译目标，不能推及其他机器/系统。

| 项目 | 结果与证据 |
|---|---|
| 最终原生菜单宽 | PASS；初始化313→180pt；相同长状态输入352→181/184pt，常规运行181pt。初始根可见条目28→17；状态组合由28—29→18—19，含分隔线和自定义view。menu-before/after/comparison.json |
| 排版与回调 | PASS；文字fittingSize不超frame，三slider连续target-action/最大值，根开关回调一次，子菜单不重复触发；CompactMenuTests及既有回归 |
| 权限入口 | PASS（注入）；菜单开关只读预检无request/启动，未授权点击请求一次，已授权只开设置且held/audio/input不变，安全输入不发请求；不是实机TCC验收 |
| 黑键 | PASS；26键×9个主体点，0/50/100%×按压/释放×辅助覆盖共12组合，body RGB最大0，alpha为1/0.50196/0或系统覆盖1；局部高光可见。black-before/after.json |
| 白键保持 | PASS；12组合×38白键共456个RGBA采样前后完全相同；white-preservation.json |
| 标签/浮音/100%材质 | PASS；沿用并通过TransparencyTests，独立文字/浮音和100%全材质零残留 |
| 全套 | PASS；150项，147通过、3 CandidateBankTests按既有opt-in条件跳过、0失败。离线音频/临时AppKit窗口测试不等价于候选GUI实测 |
| 包与保护 | PASS；strict ad-hoc、ZIP CRC/内部二进制一致、版本和源/安装保护校验通过 |

菜单增宽定位证据width-diagnostic/width-columns：长文字叠加勾选、快捷键保留列使部分状态197pt；缩短状态文案后180—184pt，仍保留原生字体/勾选和166pt slider视图。RED记录分别证明旧宽度、权限未接入以及旧灰黑键不满足断言。

两张最终图均查看通过。菜单离屏重建使用实际native slider视图，以source-over合成；早期cache默认合成导致黑底、cell直接绘制未显示滑轨，已修正证据渲染，最终标题/百分比/轨道/拇指均可核对。它不是系统NSMenu弹出截图，不能用于声称真实跟踪已通过。预览使用合成100%音量/180%高度/100%透明度；黑键图使用0%透明度，未读取或改写用户当前偏好。

## 已知限制
NOT RUN：♪首次打开/再次点击关闭、外部点击关闭、原生拖动/子菜单跟踪；真实系统授权/取消/返回和TCC续接；新候选真实全局输入、听音、Dock实景。当前仅保留系统原生机制并验证构造/回调，实机交互需主安装后测。
NOT RUN：固定身份重签、安装、提交Git或发布。现有--build-system native弃用提示保留。用户偏好及正式0.2.9运行包未由代码侧更改。

## 请求主对话处理
接收冻结源与独立候选；按既有固定身份重签并比较0.2.9 designated requirement，封存ad-hoc候选后安装续验。旧安装保护校验截至verification.json生成时有效；主开始替换后本对话不再重查旧安装哈希。

## 下一步建议
1. 主独立回归/UI复核后固定签名并核对旧DR。
2. 封存候选、安装，验证真实菜单点击/拖动/授权分支、全局听音及偏好保留。
3. 主按授权提交发布并校验匿名下载。
