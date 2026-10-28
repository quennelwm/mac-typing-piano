# 0.2.4最终候选交接（CODE）

2026-10-28。**包与签名已冻结，可供主对话正常退出旧版后替换/验收；代码对话不再覆盖该候选。** 当前已授权0.2.1仍未修改；0.2.2/0.2.3为历史中间候选，本轮应使用0.2.4。

## 包

- App：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.4/打字钢琴试用.app`
- ZIP：同目录`打字钢琴试用.zip`
- Version0.2.4 / build7 / bundleID local.typingpiano.trial
- Binary SHA-256：`6edd694ea26998ffb0015c1301b4042ed5a22c4fa594611eee102dcb41222202`
- ZIP SHA-256：`cddc86e138116a26f3be6c24a5d0dd7da7b761c9006d0ba3f61e605bb015f039`
- 已授权0.2.1二进制仍`3e90c772f6590658377d94f2c7436677de9c44d3f3b15eb0dd6528492e4eaeae`。
- root/probe-preferences.json只读SHA-256：`e2e805d42928f2a7ffe60b8e3b8fb7a7b1f4a1fbe1fdf78e05667d436933c9da`。构建不写入/打包用户偏好；升级保留这个文件，继续使用用户调整的音量，不将候选目录默认值覆盖过去。

## 本轮完整行为

保留0.2.3全部反馈实现：20pt请求槽/18pt♪、同Bundle新实例自退、screen.frame.width−16自动宽度/左右8pt/底缘贴屏幕/固定104pt高度、真实Dock专属layer20全屏窗口onScreenOnly判据、260ms淡出/隐藏稳定120ms后360ms淡入/80ms减少动态、反向连续与generation、连续unknown2秒后恢复可见、隐藏只影响视觉不影响声音/按键、退场姿态冻结与恢复不补播。详细参数/探针证据见`docs/evidence/trial-0.2.3/HANDOFF.md`，其中defaults-only后端段落由本版替换。

本版改为NativeDockStorage：动态解析HIServices仅CoreDockGetAutoHideEnabled和CoreDockSetAutoHideEnabled，UInt8 C Boolean ABI。生产GUI及恢复入口均使用该原生后端，不再通过defaults.write假装即时切换。原生getter提供实际baseline/读回，setter之后核对原生getter和固定autohide偏好读回；两者失败均明确报错。符号缺失、非法字节、忽略写入或偏好不匹配不会伪报成功；未知状态在菜单显示混合态，另有“系统Dock设置…”入口供用户直接调整。没有新增权限、Apple Events、键盘注入、killall、其他私有函数或外部依赖。

现有DockAdapter事务恢复保护保持：初始native=true且请求true时零写入；关闭仍先弹原冲突提示。自身改动才产生恢复票据，退出仅在仍为本App最后所写状态时恢复本会话原值。用户本轮系统设置改动后的true是原值，不存在恢复到更早false的理由；外部不同值不覆盖。若setter已改变原生状态但偏好核对失败，失败结果与恢复票据都保留，避免失去恢复所有权。

## 证据

- 主对话现场`docs/evidence/PM-004-dock-adaptive/core-dock-toggle.json`：原生get1→set0后Dock window49 onscreen→set1后消失，Dock PID1339未重启，最终defaults1。对照native-toggle-test.json证明defaults-only不即时生效。本机SDK也存在两个导出符号。
- CODE仅执行了只读getter/符号探针，coredock-readonly.jsonl为getter1；没有调用真实setter，未开正常GUI/监听/硬件声音、未申请权限、未写TCC或系统设置。
- 最终**64项无窗口测试通过**，新增4项后端mock覆盖双读回、不可用/非法/忽略写入、偏好失配后保留恢复票据、true baseline零写入；完整回归保留。只有已有SwiftPM native backend弃用提示。
- Release构建、strict签名、自检与无statusItem安装的菜单smoke通过。生产Dock观察器只读返回当前hidden，PID1339/window49/layer20，display1，琴宽1496。
- 原生离屏36张PNG沿用0.2.3；PianoView/Geometry/AdaptiveOverlay三个渲染布局源码SHA逐一比对未变，未把旧图冒充本版新截图。

## 私有SPI决策与限制

主明确批准此本地试用路线。它不是Apple公开稳定API，当前macOS27.2 arm64现场成功不证明macOS14或未来版本兼容；能力缺失明确降级到系统设置，不偷偷绕过。决策材料在`NATIVE-DOCK-DECISION.md`，供主线写正式ADR；代码线没有越权改ADR。实现独立，没有复制第三方程序。

## 主对话最小升级/验收

1. 在现有控制台正常退出0.2.1，确认进程退出；已有rollback-0.2.1保持。保留系统Dock自动隐藏true和root的probe-preferences.json。
2. 将本候选完整签名App复制到现有固定根路径，仅替换App；校验binary SHA和strict签名，不再重签。不要在旧进程仍运行时覆盖，也不要继续用多个候选目录作日常入口。
3. 新包DR不同，不满足0.2.1旧DR（old-DR-comparison.txt）。同Bundle/路径不能保证输入监控授权延续；按新UI由用户亲自授权/重新检查，系统需要时退出重开同一路径。无证书/TCC变更。Apple身份说明见[官方TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)。
4. 验证开始打字仍有声音、自动全宽、Dock真正出现才慢淡出/完整隐藏后淡入，快速反转及隐藏期间音画状态；鼠标只靠边不应触发。未知诊断连续2秒会回可见。
5. 实际点击系统Dock开关时验证即时效果、关闭提示、再开启与退出恢复；不要只看stored preference。可导出JSON核查actualStatusItemButtonWidthPt、dockVisibility、dockVisibilitySource、overlayAlpha。真实槽宽/点击、多屏、系统设置深链及完整GUI联动仍属PM验收，代码测试不能代替。

候选源码/包本轮冻结；后续修复另建版本，避免影响正在授权的签名字节。
