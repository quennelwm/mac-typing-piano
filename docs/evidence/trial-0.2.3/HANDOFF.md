# 0.2.3｜系统Dock与自适应钢琴候选交接

角色CODE；2026-10-28。完整本轮候选，包含0.2.2菜单栏与同Bundle防重基础；旧0.2.2仅保留历史阶段证据。**候选包/签名已冻结，0.2.1未覆盖。**

## 固定候选

- App：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.3/打字钢琴试用.app`
- ZIP：同目录`打字钢琴试用.zip`
- 版本0.2.3/build6；Bundle ID local.typingpiano.trial。
- Binary SHA-256：`3c75954a9811b6c36677375ba1d86a288514c45f18640aa6d7cfca47dcc25da3`
- ZIP SHA-256：`cab63477085144f01ac2ec6769c81591a53adf5eb6fbd0c40e5b0c0bce907e4e`
- 当前已授权0.2.1 Binary SHA-256仍为`3e90c772f6590658377d94f2c7436677de9c44d3f3b15eb0dd6528492e4eaeae`。

## 实装

- 菜单栏固定请求20pt，保留18pt单♪；日常移除900/1000/1100选择。运行诊断JSON新增requestedStatusItemWidthPt与actualStatusItemButtonWidthPt，后者来自真实statusItem.button.bounds。CLI菜单厚度22/request20仅是参数和API读值，不能宣称实际槽宽或系统图标总间距已缩2pt。
- 正常GUI入口直接注入DefaultsDockStorage和文件恢复票据，默认请求系统com.apple.dock autohide=true。单元测试默认仍注入模拟，无真实写入。启动原值true→请求true不写、不生成恢复票据；关闭有原冲突确认；本会话若改变true→false，退出仅在仍为本App最后写值时恢复true。外部改值保护、未知/失败票据和明确恢复入口保留。没有把用户本轮主动改动之前的false当原值。没有killall、合成快捷键或鼠标拦截。
- 保持原目标屏幕选择：默认内置屏优先，单条钢琴，不随鼠标跨屏跳。窗口用screen.frame，左右8pt、底缘贴屏幕底缘，W=屏宽−16，高104pt=56+48。屏幕参数变化重新布局；三目标屏宽1280/1512/1920对应1264/1496/1904pt，字号、键高、标签、映射不随宽放大。较窄屏几何不再被900下限清空，但其标签可读性未宣称已实测。
- 真实Dock判据来自PM同期配对：`docs/evidence/PM-004-dock-adaptive/paired-observation.json`及本目录600行dock-metadata-sequence.jsonl。相同Dock PID1339/window49/layer20、整屏bounds不变，onScreenOnly成员false→true→false；不能把该整屏bounds当Dock条带。生产实现只认Dock PID、layer20、与目标屏幕Quartz CGDisplayBounds匹配的唯一全屏窗口；不认其他Dock层/菜单/屏幕/模糊多窗口，使用原生orientation，缺键时使用本机UI已确认的原生bottom默认。左右Dock不触发此底部隐藏原因。bounds比较使用Quartz显示坐标，避免AppKit多屏Y方向混用。
- 目标窗口发现缓存2秒；普通0.12秒轮询只查一次onScreenOnly，不每tick扫两遍全集。用户关浮层/暂停/屏幕不可用时停止轮询；完全透明时无视觉动画计时，仅保留恢复所必需的Dock观察。
- Dock实际出现260ms淡出；实际隐藏稳定120ms后360ms淡入；smoothstep，反转从当前alpha按剩余距离缩时，generation防旧计时回调。减少动态80ms线性。高优先级安全/总暂停立即隐藏。未知短暂保持最后可信状态并取消隐藏确认；连续未知2秒后保守淡回可见、诊断仍unknown（PM明确补充，覆盖UI原“无限保持”建议）。
- Dock隐藏立即清浮动音符/独立键动画，冻结当时键面姿态淡出；输入与音频、按键ID继续。恢复时在不可见状态先放当前有效pressed快照，再允许新击发，无旧音符/按键动画补播。新增回归抓到并修复退场半途按键跳到完全按下的问题。
- 同Bundle实例策略沿用0.2.2：内核flock+旧同Bundle运行实例识别，只退出新启动自身，不杀其他进程；旧local.typingpiano.probe不受控制。

## 验证与边界

macOS27.2/arm64、Swift6.4。最终60项无窗口测试通过；包括真实临时文件锁、系统Dock命令mock/恢复保护、用户已开启baseline、fade/反转/未知超时、精确Dock窗口筛选、音画状态独立、原生字体/三新宽度键面和标签、退场快照与恢复无补播。

Release构建、strict签名、自检、无状态项安装的菜单smoke通过；36张原生离屏PNG（3宽×3状态×标签开关×1x/2x）与captures.json在native-snapshots。包内`--dock-visibility-snapshot`当前只读返回hidden，PID1339/window49/layer20，目标display1，琴宽1496。这是生产观察器的当前隐藏态核对；paired visible证据来自PM原探针，候选完整GUI淡变仍待PM实测。

没有启动正常GUI、真实监听/声音、写系统Dock或申请权限；没有动TCC数据库。测试/构建仅已有SwiftPM native backend弃用提示。实际按钮宽度/点击清晰度、鼠标与键盘Dock呼出、菜单/拖拽、快速反转、多屏、系统设置即时生效及退出恢复仍由主对话验收。defaults写入读回不等于Dock界面已即时响应；若系统未刷新，应报告，不能偷偷重启Dock。

## 升级与现场验收

1. 主对话正常退出当前0.2.1并保存完整旧包，保留用户已开启的Dock自动隐藏；不要覆盖运行中的App。候选普通启动遇到仍运行的0.2.1会主动退出，故不能在旧版运行时期待出现新图标。
2. 决定最终固定路径后复制完整签名候选，校验上述SHA和strict签名；不再次签名。建议继续根路径作为唯一日常入口，保留prefs文件，候选路径不再作为日常入口。
3. 新包不满足0.2.1旧DR（old-DR-comparison.txt），所以同Bundle/路径不保证授权继承。必要时由用户在新包“授权输入监控”流程亲自允许，再重新检查/按系统要求重启。不创建证书、不改/重置TCC。依据：[Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)。
4. 开始持续打字，验证全宽、声音。底边鼠标没有真正呼出Dock时钢琴应保持；真正Dock出现才淡出，隐藏才恢复。导出运行JSON查看dockVisibility/dockVisibilitySource/overlayAlpha/actualStatusItemButtonWidthPt；隐藏期间按键应仍响，恢复无旧音符。
5. 系统Dock开关关闭前应有冲突提示；测试关闭/开启时同时看系统设置与Dock真实行为，确认读回和视觉生效分别成立。退出只恢复本会话拥有的改动，外部不同值不覆盖。最后保持用户要求的自动隐藏true。

可独立只读核查，无需启动GUI：

```sh
'/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.3/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe' --dock-visibility-snapshot
```

本包现在冻结。任何后续改动必须另建候选，不能静默改变已供主对话替换/授权的签名字节。
