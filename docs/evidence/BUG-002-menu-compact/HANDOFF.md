# BUG-002｜菜单栏紧凑化与同Bundle重复启动候选

角色CODE；2026-10-28。仅交付候选供主对话验收/替换，未升级正在使用的0.2.1。主对话已确认旧Reviewed-C001C由其正常退出，因此双图标不是0.2.1创建两个NSStatusItem。BUG-001已由用户确认有声音，现场音频证据位于docs/evidence/BUG-001-no-sound/live-audio-smoke.json；本次不改音频。

## 候选（已冻结）

- App：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.2/打字钢琴试用.app`
- ZIP：同目录`打字钢琴试用.zip`
- 版本0.2.2/build5；Bundle ID仍为local.typingpiano.trial。
- binary SHA-256：`2f60386b4a7bb6409720f56dfa1280f08b11ed76a2191b4361ea7000c29b99c1`
- ZIP SHA-256：`460cf6c0b5dfe5f17ce37e7df2a4ab2035f6deb59ffaf71781817f6ab4a9eca4`
- 已授权0.2.1 binary SHA-256仍为`3e90c772f6590658377d94f2c7436677de9c44d3f3b15eb0dd6528492e4eaeae`，未覆盖。

## 最小变更

1. ProbeMenu使用固定20pt槽宽，保留现有18×18pt template ♪，没有新增主UI。`--menu-smoke`读取本机实际NSStatusBar.thickness=22pt，因此原squareLength基准22pt → 请求20pt，减少2pt/约9.1%。这是请求槽宽比较，不是实际菜单栏截图/点击验收；系统排布后的视觉间距待主验收。
2. 正常GUI入口在创建ProbeController/NSStatusItem之前取得每用户flock，持有至App运行结束。重复启动只激活识别出的已有同Bundle App并退出本次进程，不终止任何其他进程。同Bundle且可执行文件为其Contents/MacOS/TypingPianoProbe才匹配，local.typingpiano.probe和其他软件不匹配。0.2.1无锁协议时通过运行App枚举让新版本退出；0.2.2+协议标记和内核锁处理并发新启动。
3. 锁位于~/Library/Application Support/local.typingpiano.trial/gui-instance.lock；只在正常GUI启动创建，退出/进程终止由内核释放持有的锁。保留空锁文件以保持inode稳定，拒绝符号链接、非普通文件或非当前用户所有者。测试只用了临时目录，代码对话没有创建真实GUI锁。
4. 自检、离线/显式音频诊断CLI不会创建菜单图标，保持独立；本次未运行会发声的CLI。构建默认输出candidate-0.2.2，且明确拒绝输出到冻结根路径，拒绝测试已通过。

边界：旧未升级程序无法被新程序反向约束；如果在新版本之后手动启动未带锁的旧版本，或先替换仍在运行App的磁盘文件，不能承诺防重。升级必须先退出旧版。按主最新要求，不做旧probe的跨App控制/forceTerminate，不添加旧版提示UI。

## 验证

macOS27.2/arm64、Swift6.4。新增4项真实文件锁/识别策略测试，覆盖锁竞争、释放与残留文件重用、拒绝符号链接、同Bundle与其他App边界、锁协议实例和旧实例选择。加既有core/audio选择/本地启动/诊断/menu回归共37项通过。初次red是新增API尚不存在的编译失败，保留test-red.log。Release构建成功；候选strict签名验证、自检与不安装statusItem的菜单smoke通过。只存在已有SwiftPM native backend弃用提示。

没有正常GUI启动、真实菜单栏图标安装、全局监听、硬件声音、系统设置修改、权限申请。实际槽宽、清晰度、点击、双击重复启动、切换/恢复以及新包TCC交主验收；不能将单元测试写成这些已实测。

## 签名与最小升级路径

只读codesign证据：0.2.1 DR为cdhash ef6156f4e1f2deb96add72f58c2628820749542d，0.2.2 DR为cdhash b838e35112c72d9291b0cfb06df430a30aad2dde。用旧DR实际校验新候选返回“code failed to satisfy specified code requirement(s)”。这证明新代码不满足旧DR；不是对TCC数据库内部状态的读取或断言。

Apple [TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)说明临时签名的身份要求绑定具体代码版本，隐私授权可能无法跨构建保留。相同Bundle ID/路径不足以保证授权继承。此处推断输入监控可能需要用户重新允许，实际以新包preflight/监听结果为准。没有创建证书、自定义弱身份要求、修改或重置TCC。

主对话最小升级步骤：
1. 用户/主对话正常退出0.2.1，确认该进程已退出；保存完整旧App/ZIP以便回滚，不删除现有偏好文件。
2. 先决定最终固定路径。建议验收后将候选完整签名App复制到现有根路径，复制后校验binary哈希和strict签名；不要重新签名，也不要边运行边替换。候选目录后续不能继续作为日常入口。
3. 从最终路径打开0.2.2；若输入权限未通过，使用现有“授权输入监控”，用户亲自允许，再“重新检查并开始”；系统要求时正常退出并重开同一路径。不要在候选路径提前授权后再搬移来假设授权可迁移。
4. 验证实际20pt图标的清晰度与点击，并重复启动/必要时open -n确认仍只有一个同Bundle App和一个音符。检查当前声音、暂停、退出；主决定是否显式执行实时音频诊断。
5. 若回滚，先退出0.2.2再恢复完整0.2.1签名包；即便恢复旧字节，也须重新检查授权状态，不承诺TCC记录未变。

证据：delivery.json、tests.log、build.log、menu-smoke.json、self-check.json、signing-comparison.json、frozen-path-guard.json。替换和用户授权均未由代码对话执行。
