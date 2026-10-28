# U-001B 原生适配清单

依据PM-002与ADR-015，联调初值为1000×56pt主体＋48pt效果留白、18pt单音符♪；非最终用户审稿结论。接受基线9270936286de49892881b0898c2f915558deb10e。开始执行时HEAD为4237186（后续派发记录），未切分支。U-001候选quiet-ivory-u001.0.3冻结，本轮不复制渲染程序，不修改其182项产物或生产Code。

## 文件入口与字段归属

- `reference.json`：三宽度每键的静止/按下矩形、主符号和侧标的文字原点/墨迹范围、颜色、浮动锚点、关键帧、18张原生参考PNG及来源SHA-256。是对照数据，不是替代keymap的运行时映射。
- `theme-field-policy.json`：冻结theme全部372个叶字段逐项分类，无隐式漏项；jsonPointer指向原theme。它是适配说明，不是新增统一契约。
- `capture-request.json`：建议由代码线提供的原生截图/运行证据清单。
- `visual-acceptance.json`：必须修复与可微调项，所有原生结果初始为awaiting。
- `build_reference.py`：只读冻结文件并生成上面两份数据与核对证据；不会编译/运行App、申请权限、输出声音或写Dock。

| 字段组 | 处理方式 |
|---|---|
| schemaVersion/themeVersion/sourceMapping/artifactState | 加载时核对版本、映射hash与候选状态；本轮PM接收允许联调，不把design_proposal改ready |
| geometry、labels、motion | 运行样式与状态参数；保留单位。用户偏好覆盖首次默认，而非每次加载强制恢复默认 |
| candidateParameters.palette、blackShadow | 名称虽含candidate，当前联调绘制应使用这里的实际配色/阴影参数 |
| assets | 路径/hash/大小、SVG母版/切片、PNG倍率/模板标识；仅在初始化预热，不在按键回调读磁盘 |
| menuIcon、volumeControl | 菜单适配参数，由代码线绑定偏好与App总线；主题加载不能改变系统音量 |
| dockAutoHide | 产品控制约定；默认是首次期望值，真实系统值/确认/失败/恢复由系统适配器处理，本轮禁止现场写入 |
| notes/heightScope/fontStrategy/runtimeImplemented等 | 设计说明或历史元数据；不是实际系统能力/成功状态 |
| blackHeightRatio、rest/depressedKeyBottomPt | 冗余一致性检查：32/50=0.64、2+50=52、52+2=54。不能算成0.64×56 |
| residualGlowMs | 备用参数；residualGlowEnabled=false，不能因此关闭独立的小音符 |
| easingFormula字符串 | 说明用；实现明确数学函数，禁止把主题字符串当代码执行 |

未知/缺失关键参数须给可定位诊断，不静默退化为缺标签或无音符。读取快照坐标时保持Double精度，仅在最终像素绘制阶段处理backing scale。

## 坐标与图层

reference坐标原点为琴键主体左上，y向下，单位pt。整体画布范围[0,-48,W,104]，映射到普通左上画布时所有y加48。AppKit未翻转视图中，矩形转换为 y_native=104−(y_ref+48+h)；文字基线/字形还需遵守CoreText朝向，不能整体翻转后再次错误翻转文字。可采用明确的flipped绘制容器统一坐标。

令S=(W−4)/38。白键i：x=2+iS+0.35、y=2、w=S−0.7、h=50。黑键之前有n个白键：x=2+nS−0.59S/2、w=0.59S、y=2、h=32。MIDI33…96：38白26黑，首A#1为截断边界的单黑键，其后为正常2/3组。顶部功能键与Esc不加入；fn保留MIDI34、fn标签，捕获仍未测。

图层顺序：底座→白键及其文字→黑键及其文字→小音符。白键下沉2pt/黑键1.5pt，全部文字跟随所属键父层变换；48pt区域透明，不缩短琴键以腾出效果区。全104pt浮层均须非激活/鼠标穿透；按需试听窗口的命中测试与桌面浮层分别管理。透明性截图可检查，穿透/焦点行为必须真实指针证据，不能凭截图通过。

## SVG适配或原生等价绘制

建议直接复用几何/颜色进行轻量路径绘制，避免增加SVG运行依赖；等价绘制无须重新产出设计资产。若加载SVG，先确认现有解码器支持渐变、clip和阴影，不能假设NSImage能完整解析所有SVG滤镜。

白键母版32×50、黑键19×32，圆角各1/1.2pt；顶部0.5pt细高光，底沿白2.5pt/黑2pt。垂直渐变、底沿色取palette；高光白#FFFFFF/黑#58595C。底座外框#353638圆角3pt，内框[1,1,W−2,53]、#71716E圆角2pt。这些静态细节来自被冻结的components SVG及native_render.swift，而非任意补色。

face切片top/left/right=1.5、bottom=3pt；base各3pt。优先参数绘制以保留圆角/底沿，禁止对整条琴图或文字整体拉伸。阴影不做九宫格：rest offset[0,1]、blur1.5、alpha0.3；pressed [0,.5]/.5/.18，局部于黑键。滤镜实现差异可微调，但不能使标签低于4.5:1或吞字。

图标用18pt单音符♪模板，1x/2x为同一逻辑NSImage的不同表示，设置isTemplate=true交系统着色；16pt为对照候选。可访问名称“打字钢琴”，不随打字闪烁。4张模板路径/hash已在原theme列出，勿用高音谱号替换。

## 文字锚点

运行时文字仍来自KeyMapping.labelParts。白主字10pt、黑9.5pt、侧标6.5pt、medium，白#595959/黑#CDCDCD。原生系统字体及必要回退，不硬编码私有PostScript字体名、不分发字体文件。reference中的字体名仅说明参考机器实际回退。

设主字形墨迹bounds为B（相对CoreText基线，y向上），矩形R使用参考坐标：

- mainX=R.midX−B.midX+(有侧标 ? −0.6 : 0)。
- mainBaselineY=R.maxY−bottomInset+B.minY；bottomInset白4/黑3pt。
- 主墨迹顶部mainTop=mainBaselineY−B.maxY。
- 侧标墨迹右缘=R.maxX−1.1pt，sideX=右缘−sideBounds.maxX。
- 侧标墨迹底=mainTop−0.6（黑键），mainTop+2（白键）；sideBaselineY=侧标底+sideBounds.minY。

白Shift侧标采用较低位置是修复后的必须保留条件：不可把黑键角标位置套给白键，否则邻黑键按下会降低对比度。字体回退导致的0.5pt以上墨迹差异需审阅，但只要语义、无遮挡、自身底部与对比度满足，不以字体名不同单独判失败。

showKeyLabels默认true、可保存开关；关闭只隐藏文字层，不重建映射、不释放琴键、不停音、不关小音符。snapshot要分别提供标签开/关证据，不能仅提交带字位图。

## 700ms音符及降动效

每个有效新pressID一枚♪12pt，起点墨迹底位于本键静止顶部上方4pt，x为键中心；与标签和音频尾音独立。t=elapsed/700，rise=24×(1−(1−t)^3)，opacity=min(1,elapsed/60,(700−elapsed)/400)，elapsed≥700销毁。#626C66、白色1.25pt光晕；48pt空间包含字形与光晕。

0/100/350/700ms机器期望在reference.floatingFrames。0ms实例已创建但alpha=0；700ms应无实例，不只透明后留在集合。减少动态：200ms原位淡出、rise=0，不明显位移。

长按重复不增生；松开不截断音符；快速重击分别销毁旧/新实例；隐藏/关闭钢琴/暂停/阻断立即清理，隐藏期间不排队，恢复不补播。无实例时停止帧刷新。琴键45ms按下、100ms回弹、45ms最短视觉脉冲；真实up不延迟，旧回弹不能覆盖新generation。

## 菜单与验证权限

菜单内水平音量0—100%，拖动时保持菜单可用；只控制App总线，声音关闭后拖动不暗开声音，0%不停止视觉。无复杂主界面、触控板专属手势。Dock提醒原文/按钮按CR-001，不把静态提醒当写入/读回通过。本轮仅适配与对照，不自动启动全局监听、硬件输出或系统Dock修改。

## 后续快照对照

当前未收到主对话转交的C-001C原生快照，因此不直接读取并假认其他工作中的截图已获验收。代码提交截图、诊断元数据和合成脚本后由主对话转交；按visual-acceptance.json记录差异。必须修复项退回，材质等软差异列建议；确需更改设计原件时提供差异及版本提案，先由主对话安排。完成本轮文件后停止等待，不轮询空转。
