# U-034 最终复核：等待预览与源一致

2026-10-29。一次读取当前冻结清单97文件，全部SHA256一致；full-test-final日志158项、3skip、0fail。UI未运行App/测试。当前只能确认源码/已有日志，不能签收最终视觉。

## 尚需关闭

1. **预览来源未与冻结源对齐（待更新，不把旧图判成最终布局失败）**：当前binding-draft.png仍含实体键/目标音高下拉框及大表格；冻结KeymapEditor.swift为760×390pt，visible stack仅title/description/pianoScroll/hint/dirty/error/buttons，两种旧控件未加到主视图。请用最终候选重新出两图及report，记录绑定窗口逻辑尺寸。当前control-panel源码/报告为270×370pt，处于批准240—280pt范围，272是UI建议而非硬性阈值。
2. **P2：新绑键路径仍显示旧操作提示/内部ID**：KeymapEditor.update()无草稿时写“选择目标音高即可交换”，有草稿回退提示仍提“下表”；现在选择器/表格已不在视图。bindPhysicalKey摘要使用keyA等内部ID。请统一为“点一个琴键，再按电脑按键”、真实可读键标签的两向交换摘要；避免用户寻找已移除的控件。PRECHECK/EARLY_REVIEW已明确此项。

## 已核对的源码范围

- 运行/音符/声音独立控件与四单行slider，归一化高度旧1.32仅显示约63%；system alert单独路径。
- 首行勾选是paused反值；声音左右状态同步；浮音独立偏好。系统设置含层级二选一，top/bottom保存；bottom为desktopIconWindow+1，现场窗口关系仍未测。
- 黑键文字#68717A/.90，主字/角标共用；白#969FA9/.86。纯黑主体保留。需最终同源局部/绑键图确认文字。
- 瞬态popover显式toggle、Esc及关闭补存，旧故障触发机制仍UNKNOWN；真实重复/外部点击、拖动不关闭仍须主现场验收。
- 浮音950ms/100pt、减少动态200ms保留。render-paired-final为同进程离屏CPU基准，不是屏幕帧间隔；press-plus-floating缓存p95CPU约19.48ms，不能据此称实机卡顿已解决。

最终REVIEW/HANDOFF待同源预览及上述文案修正结果；当前不把158项通过外推为视觉/真实交互通过。不重复轮询中间图、不重跑测试。

## 已关闭
最新两图已与当前冻结源对齐；旧提示及内部ID已修正。本待办状态由REVIEW.md与review-evidence.json取代，保留此前记录作为过程证据。
