# 统一接口契约 v1.0

本文件定义并行工作的接缝，不是已实现的 Swift API。代码对话可用 Codable／结构体映射，但不能无通知改变语义。修改结构须提交 ADR；小参数调整也要更新资源版本。

## 1. 标识与单位

PhysicalKeyID 使用 `keyA`、`commandLeft` 等稳定英文 ID。音符唯一标识是 MIDI 整数 33—96；音名 C4＝60。图形尺寸是逻辑点 pt，位图另标 scale 与像素尺寸。动画时间是 ms，音频时间使用明确的秒或毫秒字段，禁止同字段混用。

所有事件 timestamp 使用同一单调时钟的相对时间，不使用系统日历时间安排音符释放。时间字段仅用于内存调度或合成测试，不持久化真实按键时间序列。

## 2. 输入、音符与画面

NormalizedKeyEvent 必需项：eventID、physicalKeyID、phase（down/up/pulse）、monotonicTime、captureCapability。监听层过滤系统自动重复；不发送 Unicode 文本。

NoteEvent 必需项：pressID、physicalKeyID、midiNote、velocity、phase（down/release/panic）、mappingVersion。down 建立 pressID；release 只能释放该次击发，panic 清空所有有效 pressID、尾音和延迟任务。

KeyVisualState 按 MIDI 保存 activePressIDs、pressed、animationGeneration。标签来自当前 KeyMapping，不能依赖音频引擎回调猜按下状态。声学尾音可能长于按键状态；pressed=false 时仍可有 residualGlow，但不能一直下沉。

同音重击必须写出底层策略：抽象 pressID 不代表 AVAudioUnitSampler 本身支持按任意 voice ID 释放。P0 可采用同音新击发替代旧音／旧尾音，按音源实际行为验收。未来多对一映射需引用计数或明确声部管理；不得由一个键的 up 误释放另一个仍按住的键。

## 3. 状态重置契约

输入中断、锁屏、睡眠、权限丢失、音频重建、映射切换：先禁止新事件，递增事件代次，清空 pressed 与任务，停止所有声部／尾音，再进入恢复。只有可靠的新输入可以重新击发。UI 重新显示不补播历史动画。

仅隐藏浮层不触发 panic；关闭声音、暂停全部或进入安全阻断则触发。关闭视觉只影响 UI。两个开关都关闭时可停止监听，但重新开启任一个功能前必须真实检查权限。

## 4. 映射文件

`keymap.schema.json` 约束字段结构；`keymap.ansi64.v0.1.json` 是联调初稿。

额外语义校验（JSON Schema 不能独自保证）：
- physicalKeyID 唯一且等于已列出的64键集合；每排数量是14/14/13/12/11。
- MIDI 唯一且集合恰好为33…96；颜色由 MIDI%12 推出，与字段一致。
- 音名符合 C4=60；标签非空；左右键有不同 labelParts；没有顶部键。
- captureStatus 不是设计推测：初始 unverified，实测后才写 full/pulseOnly/unavailable。
- source schemaVersion 与运行时支持版本不一致时拒绝静默加载，并给出错误。

## 5. 音效 Manifest

`audio.manifest.template.json` 故意没有实际路径；状态 template 不可作为生产资源。ready 至少满足覆盖64音、真实文件、来源许可、处理配方、QA与哈希。

SF2／DLS 的 instrument 对象需要 bankFile、program、bankMSB、bankLSB；这些值以最终音色库实测为准，不能默认一个库的 program 适用于另一个。所有路径相对音源包根目录，不允许 `..`、绝对路径或 URL 作为运行时资源路径。

WAV 集合需要 zones：sampleFile、rootMIDI、lowMIDI、highMIDI、velocityMin、velocityMax、gainDB、releaseMs、loop 信息；选择此格式意味着已批准相应采样配置或引擎能力。原始 WAV 文件不是“自动会正确映射”的乐器。若无循环，不伪造 loop 点；如有，必须验证接缝。

文件记录包含 path、sha256、byteSize、role。Source/License 记录包含原始URL、作者、版本／提交、licenseID、许可文件、修改说明。QA包含加载方式、覆盖检查、端点音频、连续半音、短按／长按、多音与重击结果。资源包完整性与许可通过是两个不同检查。

## 6. UI Theme 与资源

`ui.theme.example.json` 是设计参数，尚无图形资源。正式 theme 的 assets 应包含：id、path、sha256、format、pixelWidth、pixelHeight、scale、contentRectPt、capInsetsPt、anchor、state、transparency、licenseRef。矢量则给 viewBox／设计坐标；不存在的字段写明不适用，不伪造像素尺寸。

每个琴键标签独立绘制，位置为 each_key_own_bottom；visibleByDefault=true 只定义首次默认，运行时 showKeyLabels 用户偏好可关闭；bakeIntoTexture=false；followKeyTransform=true。theme 不允许重新定义 physicalKey→MIDI 关系，只控制样式。

字母、数字直接显示；左右修饰键主符号＋独立 L/R 角标；完整名称放在设置预览的可访问说明。黑键标签不得落到白键下缘。字体缺字、裁剪和色彩对比度必须在真实字号检查。

白键几何按38个均分槽位生成；黑键按实际 MIDI 邻接关系定位，不按26个黑键等间距排一条。绘制和点击测试（仅设置预览）共用几何，避免试听点中一个键却亮另一个。

## 7. 模块接口建议

InputService: startObservation()/stopObservation()；KeyStateReducer: consume(event)/reset(reason)；MappingProvider: mapping(for:keyID)；AudioService: prepare(pack)/noteOn(event)/noteOff(event)/panic()/setGain(value)；OverlayPresenter: apply(snapshot)/setVisibility(reasonSet)；AssetValidator: validate(manifest)。

这些是能力名称而非要求逐字照抄的生产函数签名。主线程边界、错误返回和并发隔离由代码对话提交设计，但不得把错误吞掉或让 UI 直接调系统输入监听。

## 8. 必须自动检查的静态项

所有JSON可解析；schema验证；64键双射；音域与颜色一致；标签非空与左右可分；resource状态不冒充ready；引用文件存在、大小和hash一致；路径在资源根下；主题不得静默覆盖用户标签偏好；用户主动关闭合法；正式audio不可缺许可和覆盖。

空assets数组属于未完成，不是“用代码生成好了”；程序化矢量方案可在manifest中明确 `format=procedural` 与实现版本，但仍需可复现、预览及审稿证据。

## 9. CR-001 菜单与用户偏好

主入口为原生菜单栏下拉/子菜单，不做复杂主界面。`showKeyLabels: Bool = true`只改变独立文字层，关闭时不清理activePressIDs、不停止动画或音频，重新开启读取当前映射。标签开启时原位置/颜色/随键规则完整保留。

`autoHideSystemDock: Bool = true`代表用户期望的系统自动隐藏，与DockAvoidance独立。关闭经过风险提醒及确认；取消无写入，确认才请求关闭。系统读回状态和期望值分开，失败/未知不可作为已应用显示。原值、应用拥有的改动和外部变化需可区分，正常退出恢复策略见CR-001。

当前只新增运行时偏好语义，现有资产字段结构与schemaVersion不变；后续若增加结构由主对话另行版本化。详细交互与本轮不写系统设置的边界见 `changes/CR-001-menu-options.md`。

## 10. CR-002 击键小音符

渲染层从统一NoteEvent.down按pressID生成一次浮动音符，保留独立instanceID、midiNote、单调开始时间及可视代次。release不再次生成、不截断实例；系统重复过滤沿用输入层。隐藏/暂停/安全重置清理全部实例，恢复不补播。标签关闭/声音关闭均不等同于隐藏浮层，小音符独立于音频尾音/residualGlow。

themeVersion classic-draft.0.2在既有motion对象增加可选floatingNote配置，未改变schemaVersion或键映射。参数默认700ms、最大1000ms、12pt、上移24pt、上方48pt透明留白；旧主题缺字段按CR-002默认。留白不能缩放琴键本体或扩大鼠标拦截范围。具体配置和验收见 `changes/CR-002-floating-note.md`。
