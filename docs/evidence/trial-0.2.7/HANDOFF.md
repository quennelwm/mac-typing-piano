# 交接：C-027＋C-028／0.2.7 build10

## 结论
已完成待主对话接收，生产源码与contract已冻结，最终候选和验证哈希已落盘。新表为唯一出厂默认，旧表仅保留历史contract，不列为运行时选项。此次未替换现用0.2.4或冻结0.2.6，未做Git操作、申请权限或改系统设置。主对话负责最终开发签名、实际安装和GUI实按验收。

## 实际变更
- 钢琴主体112pt，白/黑键面100/64pt，独立透明区96pt，总高208pt；宽度仍随目标屏幕减16pt。音符24pt、900ms，上移48pt、向右漂4pt；减少动态保持200ms原地淡出，空闲动画计时器停止。
- 静态显示与声音/输入暂停分离。显示前先观察Dock；普通暂停保留显示意图但清理按键和效果，安全输入、锁屏、睡眠、会话失活各自阻断。恢复一个原因不会清除其他原因，也不会自动开始输入/声音。Dock可见时让位，持续unknown2秒后恢复并说明未知状态。
- 新映射由64个DOM ID显式转成原实体ID，原SDK键码、事件语义、标签和力度保持，音高逐项对应附件；G=C4，核心20音覆盖F3—C5。新contract符合既有schema，旧表字节不变。
- ♪菜单只提供“自定义键位…”和当前默认/自定义状态。560×440原生窗口仅一份草稿，选音高立即交换草稿中两个键，全部累计差异可滚动查看。切换实体键保留草稿；取消/关闭不保存，恢复默认也需保存。
- 配置在用户Application Support的custom-keymap.json；版本、全部实体ID和MIDI33—96双射均校验。先原子保存，再同批应用音高和标签；写失败保留当前运行映射和草稿。损坏配置原文保留并提示回退新默认，显式修复保存前另存原始损坏字节。
- 保存清理旧声部、按键、延迟释放、浮动音符及旧输入代次，保持运行/暂停、声音开关、音量和显示意图。输入捕获层即时维护瞬时held集合，在丢弃旧队列时返回捕获快照：已捕获但未投递的up不再导致误吞下一次down；真正仍按住的键等待up后再击发。没有重新建立监听器、请求权限或持久化输入序列。

## 失败先行与原因

1. 原toggleOverlay入口、refresh、dockTick和updatePanelOpacity都把暂停与可见性绑定。未启动时尝试显示，原生面板alpha仍0。准确复现见overlay-red-corrected.log；早期overlay-red.log包含CGFloat转型不当，不能单独作为根因证据，后续已修正断言并在原控制器上重跑。
2. 原尺寸/音符/新映射缺失由features-red.log证明；新几何、原生标签、字体墨迹含光晕、900ms消失、减少动态与计时器停止均进入回归。
3. 自定义文件此前不加载，已保存G→F3后仍发C4，见custom-red.log；模型、真实文件、原生窗口动作和控制器现在分别覆盖。
4. 独立review指出释放队列竞态。queued-release-red-corrected.log使用旧的归约held策略，真实Dispatch主队列投递完成后仍误吞新down；新InputEventQueue捕获快照修复通过。早期queued-release-red.log/首次green日志使用不足以保证主队列执行的RunLoop等待，最终测试改为XCTestExpectation确认投递，不能将早期日志当最终结果。
5. 独立阻断原因集合覆盖lock＋sleep→wake仍不显示，再解除lock但secureInput仍不显示；只有全部解除才恢复静态画面。

## 产物与复现

独立构建位置：~/Library/Caches/local.typingpiano.trial/candidate-0.2.7/打字钢琴试用.app，ZIP同目录。最终路径和哈希见delivery.json；完整源码清单见source-hashes.json，修改摘要见changes.diff。

仓库根构建：

```sh
TYPING_PIANO_BUILD_ROOT="$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.7" TYPING_PIANO_SIGN_IDENTITY=- bash Code/Scripts/build.sh
env -u TYPING_PIANO_EVIDENCE_DIR swift test --build-system native --package-path Code --scratch-path "$HOME/Library/Caches/typing-piano-verification/c027"
```

默认全套中CandidateBankTests明确skip3项，另在新candidate-bank-run目录预检并实际重跑；TrialBankTests只写独立临时目录并清理。预检复用既有prepare_fixture_without_git.py，仅省略信息性Git HEAD查询，不改变输入哈希校验。

## 最终验证

- 完整套件130项：127项通过、3项CandidateBankTests显式跳过、0失败（full-tests-final.log）；随后独立新快照执行这3项，3项通过、0失败（candidate-tests.log）。因此本次130个不同测试均实际通过，不能把初始skip算作通过。
- 候选音库Kawai/Steinway分别191/193项数值检查通过；预检绑定36项输入，汇总和unchanged通过。只做offline渲染。
- 36张三宽度生产琴键图、228帧动画、4张实际原生编辑控件图检查通过；末次编辑截图因主屏backingScale为1而输出560×440，先前2x为1120×880，逻辑尺寸一致。
- 源清单80个文件哈希复核，112个受保护文件字节未变；包括旧contract、现用固定App、0.2.6 App/ZIP及其冻结证据。旧表没有打入新候选资源。
- 独立arm64 App为0.2.7/build10，ad-hoc strict签名通过，ZIP完整性及内含可执行文件哈希与App一致。
- 生产可执行文件SHA256：`f8394ae4997e3124f856eb30ff680801dbf26b8cd70f577612167ad7b02dea0d`
- ZIP SHA256：`74fb579fece7a2c92927b1fde628dc6eed3aef58faeeacd67e14ea0b9486ce4e`
- 源清单SHA256：`36122adb450b0a3e6139f387f57a72b22e2ee8aaf25f7ec0c34a56760e68b589`

最终机器可读结果：final-verification.json、delivery.json、source-hashes.json。verify_delivery.py可在本机对同一未改动候选复核。构建/源码已冻结；之后若主对话对副本开发签名，签后binary/ZIP哈希应由主独立记录，不能沿用这里的ad-hoc值。

## 生产渲染与限制

piano/为生产PianoView在1264/1496/1904pt、1x/2x、标签开关及静止/单键/多键场景的36张图；animation/为同一渲染器的真实时序帧，frames.json记录含光晕的墨迹边界。editor/为真正NSWindow/NSPopUpButton/NSTableView产生的四种设置状态，显式合成windowBackgroundColor以方便查看；属于生产控件离屏渲染，不是屏幕截图，保存回调在此诊断入口中仅用内存模拟。真实磁盘失败另由自动化测试核验。

window-smoke验证原生面板可见、非主/非关键窗口、全画布鼠标穿透、前台PID不变。dock-readonly只读取当时Dock状态，没有写设置。这些均不代替真实用户输入、完整锁屏/唤醒通知顺序、多屏/全屏/Dock组合或声学验收。

本轮只用ad-hoc签名，没有Developer ID/公证或更新权限自动延续保证。Swift工具链的--build-system native弃用提示保留。实际包安装、固定开发签名和现用实例切换由主对话执行。
