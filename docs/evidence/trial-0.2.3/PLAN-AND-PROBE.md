# 0.2.3后续候选：系统Dock、真实显隐、自动屏宽

代码角色。沿用0.2.2的20pt菜单及同Bundle防重复；0.2.2包只是已验证基础，不作为本轮完整最终交付。0.2.1保持冻结，不覆盖、不启动其他GUI；PM负责当前用户桌面和系统Dock操作。

已授权：真实com.apple.dock autohide，默认开启，关闭仍警告；当前系统由用户/PM改为true，不能恢复到该改动之前的false。禁止鼠标热区模拟真实Dock可见性，不拦截/模拟唤出Dock，不改TCC或自动申请新权限。

## 方案

1. GUI启动使用现有DefaultsDockStorage + DockAdapter，不再默认模拟。仅在本次会话确有已验证写入时保留恢复票据；启动读值true且请求true时不写、不记录false。退出只恢复本会话读到的原值，检测到外部不同值则不覆盖。单元测试继续注入模拟存储，不能触及真实Dock。默认启动绑定与用户选择通过PM现场验证。
2. 菜单保留原生自动隐藏开关和关闭冲突提示。defaults写入/读回只是偏好证据；需要PM确认Dock实际即时遵循。如果本机不即时刷新，报告这一限制，不偷偷killall或发快捷键，也不把读回标为UI已生效。
3. 钢琴浮层默认取当前目标屏幕screen.frame，左右各8pt，画布底缘贴屏幕底缘；1512pt屏幕为1496pt。移除日常900/1000/1100选择；尺寸/屏幕变化重新布局。预览测试窗口可继续固定1000pt。标签与64键几何按现有比例布局。
4. Dock可见性只采用可验证的Dock专属窗口元数据。当前PM隐藏态唯一Dock窗口49/layer20/alpha1为整屏，故不能将bounds等同Dock条带，也不能从可选字段缺失断定隐藏。先做隐藏/可见/再次隐藏成对采样，确认有稳定信号后才选算法。若公开元数据不足则unknown并保持钢琴可见，报告可能需要额外可访问性能力，先不申请。
5. 确认visible后视觉层260ms淡出、hidden稳定120ms后360ms淡入（减少动态80ms），仅变panel透明度/可见状态。音频/输入/coordinator.active不变；短暂未知保留最后可信状态，连续未知2秒后恢复可见且诊断仍unknown，不锁死隐藏。与安全暂停立即隐藏区分，快速反转从当前透明度继续，避免旧完成回调隐藏新画面。

## 只读探针

`Code/Scripts/probe-dock-visibility.swift`只采Dock-owned window的ID/bounds/layer/alpha/可选onscreen及onScreenOnly成员关系，不读取像素、其他App内容，不移动鼠标、不改设置、不申请权限。JSONL每行保留查询是否成功，absence不等于最终结论。

主对话可在自己控制Dock显隐时运行：

```sh
swift Code/Scripts/probe-dock-visibility.swift 100 0.1 > docs/evidence/trial-0.2.3/dock-metadata-sequence.jsonl
```

约10秒，建议先隐藏→鼠标让系统Dock真正出现→离开隐藏，并记录对应时间段。脚本无需启动试用App、无需麦克风/输入监听。具体显隐判定等待该对照证据；先实现不依赖此结论的原生偏好接入和自动屏宽。


后续证据/裁决：主对话提供同期600样本及paired-observation.json，已验证本机Dock PID1339/window49/layer20全屏窗口onScreenOnly成员关系false→true→false。本轮生产实现采用该限定判据；不再等待此本机配对证据。连续未知2秒保守恢复、底缘贴屏幕、固定104pt高度和具体时长以最终HANDOFF为准。
