# U-001B 反馈增补交接（2026-10-28）

范围：只新增 `Design/UI/integration/responsive-dock-feedback/` 及本交接；不改Code、契约、系统设置或冻结候选，不启动App。来源为主对话转交的用户截图及本轮明确反馈。参数属可用于下一候选的UI建议，不是假称正式接口或实测已通过。

交付：

- `Design/UI/integration/responsive-dock-feedback/SPEC.md`：菜单栏20pt固定槽＋18pt单♪；屏幕左右8pt，宽度连续适配；实际Dock显隐触发及生命周期规则。
- `Design/UI/integration/responsive-dock-feedback/reference.json`：1280/1512/1920pt屏幕对应1264/1496/1904pt钢琴，192键坐标/标签及参数、来源哈希。文字墨迹由旧基准平移，未冒充新原生测量。
- `Design/UI/integration/responsive-dock-feedback/validation.json`：192键/每宽38白26黑、映射及标签边界通过；182份冻结原件哈希不变。

供代码线直接使用：

1. 保留一个♪和18pt模板图像，固定20pt状态项槽，无文字/空格/箭头；不要为压空白缩小字形。截图不能单独测定槽宽或承诺系统相邻项间距。
2. 默认自动适配，去掉900/1000/1100日常宽度选择；W=screenWidth−16，S=(W−4)/38。既有56+48pt、字体、键压位移不随宽度缩放；新宽度不是新的映射。
3. 目标屏幕底部中央Dock实际可见→260ms淡出；实际完整隐藏稳定120ms→360ms淡入。鼠标靠底边或离开均不替代Dock状态。反向从当前alpha开始，时长按剩余透明度距离折算，generation防旧回调；减少动态为80/80ms线性透明度过渡。
4. Dock出现立即清空音符和视觉动画，退场键面快照淡出；输入/音频继续。恢复先放当前有效pressed状态，仅对恢复淡入后的新down生成音符；安全重置优先，绝不补播。未知Dock状态保持最后确认策略，不偷用鼠标代理；首次未知保持可见且注明未验证。

实际识别来源、首次显隐、反转、菜单/拖拽、键盘呼出、屏幕切换、20pt槽清晰度和原生三屏宽图由代码线验证；如识别需要额外权限或做不到，应回报主对话，不在UI侧扩权限。本轮不要求另做素材包、不阻塞可运行候选。

主对话同步事项：最新反馈覆盖原主文档的固定宽度/底边热区预判，若需更新ADR、契约或任务编号由主对话处理。旧UI_SPEC/MOTION_SPEC与U-001B基准作为历史冻结证据保留，以本增补指导下一候选。


## 0.2.4 主对话实机回传核对（2026-10-28）

已读取并核对 `docs/evidence/PM-004-dock-adaptive/live-fade-summary.json` 和 `gui-runtime-024.json`，本条仅补文档，不重新生成图像/规范，不修改冻结源码或包。

- 菜单栏实际状态按钮宽度20pt，与建议一致。
- 主对话报告目标屏宽1512pt；窗口记录1496×104pt、X=8、Y=878，符合左右8pt和56+48pt布局。
- 同一windowID3456在Dock隐藏前alpha=1；Dock显示阶段有3个中间alpha采样，最终不在屏幕/窗口列表；Dock隐藏后有13个中间alpha采样，最终在屏幕且alpha=1。支持本机原生窗口确实淡出并恢复，已超出此前纯离屏证据范围。记录中的alpha=-1伴随present=false，是缺席标记，不是负透明度。
- 运行快照时间2026-10-28T10:34:39Z（上海18:34:39）：dockVisibility=hidden，来源为Dock PID/window、onScreenOnly、bottom；overlayAlpha=1，sessionEnabled=true，engineRunning=true，samplerLoaded=true；App音量保留0.8444062499999997。
- 主对话报告显隐过程音频引擎保持运行；所给运行JSON证实采样时引擎运行，本摘要本身不是完整连续音频记录或声学证明。该快照inputMode=local、globalInputPermission=false、acousticProof=false，不宣称全局后台输入已验收，也不沿用此前0.2.1的权限状态。

本批接收范围：20pt实际槽宽、1512pt屏宽布局和一次真实Dock显隐淡变/恢复。260/360ms精确时长、快速反转、减少动态、所有屏宽/多屏和隐藏期间状态组合不由汇总采样单独宣告通过。此前“新规范尚未装入0.2.1”的说明只对应当时运行实例；主对话已确认0.2.4实装，UI侧不再追加改动延误候选。

证据SHA256：

- live-fade-summary.json：`e0744d354c4d0f18d4f25cb2efda4315f39ddaead12082f483ebb760c51a7199`。
- gui-runtime-024.json：`8aa0e5490ebfa0cc29019c4f4ff90dc44faeac64414acf115cebfe500e8fd869`。
