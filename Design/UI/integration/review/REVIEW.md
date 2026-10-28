# U-001B 对 C-001C 原生证据的差异审阅

结论：**给定静态画面通过；本次未发现新增的 UI 试用阻断缺陷。** 运行时首击、穿透/焦点、声音及系统行为仍由程序线与主协调验收；本结论不能替代实机试用。优先交付试用，不要求先做材质微调。

审阅取样时间（上海）：2026-10-28T15:57:21.765746+08:00。证据归档在本目录 `reviewed-evidence.zip`，防止后续更新覆盖本次审阅对象。

- 构建：C-001C；可执行文件 SHA256 `5903a94885faa73198e7721474d4bab75337a554213e6f16ac3e4826655a99d5`。
- captures.json SHA256 `4434e07d1626bbb85f4a3314c4866494c1ae3a39ee80d0bccdd2fa44cbe55973`。
- frames.json SHA256 `3668c5f30e453806f73e013b10637aa85dfc0be05d590f752bf1f908a5f7fc05`。
- 主题 SHA256 `1cd6ec885ff33d3cb071300c63b753604d29c5b4b28fbcdccf69812fff0220fb`；映射 SHA256 `147ad9041aa7514e70e80c94a476149f47944d36f74367825ae95bd69edf245b`，与 U-001B 基准一致。
- 该批标记为 production native offscreen RGBA rendering；hardwareInput / hardwareAudio / systemDockWrites 均为 false。没有把 `design_proposal` 状态擅自改成已验收。

## 已验证

1. 36 张正式登记静态图覆盖 900/1000/1100pt、rest/single/multi、标签开/关、1x/2x。裁出顶部48pt以下56pt主体，与冻结参考图 **36/36逐像素完全相同**（RGBA平均误差均0）。64键、标签、侧标、按压位置、材质无静态差异。未把目录中的旧版额外PNG算作新场景。
2. 原生64键诊断每图 MIDI33–96 齐全，缺字均0。静态局部墨迹和矩形与参考 rest 坐标误差0；按压最终位置由PNG一致性验证。
3. 152张常规音符帧含正常/减少动态、标签开/关。正常700ms、减少动态200ms时实例清零；位移/透明度相对模型最大误差分别为7.11e-15pt、2.36e-16。76对标签开关的透明效果区逐像素一致；覆盖的5音位音符未碰到透明区外沿。
4. 28张短击/重击合成帧：短击完成下沉和回弹，旧音符700ms消失；80ms重击形成独立实例，700ms仍保留新音符，780ms消失。可见状态与实例时间一致，未把离屏数据当成实际定时器证据。
5. 目视检查包含窄版1x标签、1000pt多键按压及100/350ms浮动音符，未观察到缺字、黑标签掉至白键底部或音符裁切。

## 非阻断说明与微调

- **诊断坐标说明需补充**：`actualNativeMetrics` 实际是未施加按压平移的局部 rest 坐标。直接与 held 坐标比较会出现最大2pt差异，但PNG中的按压坐标正确。建议程序线给字段补 `coordinateSpace=key-local-before-depression` 或另输出 transformed bounds；不应为消除此诊断差值去移动已正确的UI。
- `snapshot-ready.md` 的12张/148帧描述落后于本次manifest的36张/180帧。应以本报告绑定的manifest哈希为准；更新说明即可。
- 材质、字号和轮廓本轮不提出修改要求。1000pt为既定试用起点；真实屏幕读感反馈后再决定是否调整。

## 尚未覆盖，不能标记通过

启动首击音符正在由程序线修复，本批合成数据不能证明冷启动第一事件会触发真实绘制。所有动画 `timer=false`；还需运行时验证首次显示、实际持续时长、隐藏清空且不补播、全104pt区域鼠标穿透与焦点。菜单图标/滑块/Dock确认、声音独立性未在本批钢琴图中验证；Fn硬件捕获仍未验证。本批浮动音符仅覆盖5个音位，不宣称64音位全端点实测，也未补造全黑键按下的独立组合。

11项详细状态见 `visual-acceptance-review.json`，保留 partial / untested。原 `visual-acceptance.json` 不变。

## 复跑与证据边界

在项目根运行 `python3 Design/UI/integration/review/review_native.py` 与 `python3 Design/UI/integration/review/check_animation.py`。脚本优先读取已归档字节，不覆盖归档；前者同时检查原路径是否已变化。`comparison.json` 保存逐文件哈希、逐图结果和源变更列表，`animation-checks.json` 保存透明区边界及验证范围。后续构建如可执行文件或manifest哈希变化，应另行审阅其新增差异，不能套用本次结论。

本次只新增 integration/review 资料并增补交接，不改 Code、音频、契约、冻结主题/图像/原U-001B基准，不执行应用、实际键盘捕获或系统Dock设置。
