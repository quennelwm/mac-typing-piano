# PM-027 独立验收记录

基线8cf809a，主对话PM-027，2026-10-29。用户明确新表唯一默认并新增自定义，以CR-007覆盖早期保留旧预设的假设。C-029窗口层级回归已关闭，最终包已通过独立测试及打包校验。

## 接收范围
- U-027：目视三宽overview，独立逐项核对64音高/标签、112pt主体以及182份旧素材哈希，见ui-independent-review.json。生产琴键主体112、透明效果区96，总208pt。
- U-028：目视swap.png及生产editor-swap-draft.png；独立校验8文件manifest，接收单层草稿、交换双方、保存/取消/恢复默认。生产图为实际控件离屏渲染，不冒充桌面菜单操作。
- C-027/C-028：新表为唯一出厂默认，64键/音域不变；自定义先保存再应用、占用音高两键交换；配置错误保留原件并提示。应用时保持运行/暂停/声音/音量/显示意图，清理旧队列和动画。

## 代码审查与回归
只读复核助手review_027未修改文件或执行写入测试。
1. 早期旧预设切换强制暂停：旧菜单已删除，自定义保存保留运行状态，回归通过。
2. 锁屏/睡眠/会话共用布尔：已改独立原因集合，单一恢复不解除其他阻断。
3. 保存时已捕获但未送达的up导致下一次新down被吞：改用捕获端InputEventQueue按住快照，丢弃旧队列时覆盖ignoredUntilRelease。down已送达→up排队→保存→排空→新down回归通过。早期RunLoop测试日志不作为最终证据，使用corrected红/绿回归。
4. 主最后发现普通窗口遮挡风险：生产ProbePanel原为normal层，isVisible不代表未被遮挡；C-029单独修复并补真实WindowServer顺序验证。通过前不发布。

主独立执行 `swift test --build-system native --package-path Code --scratch-path <独立缓存>/swiftpm`：130项，127通过、3条件跳过、0失败，见full-tests.log和independent-tests.json。代码交付的3项离线音库测试另在新证据目录实际通过。测试前后源文件一致，并检查源文件修改时间早于测试日志创建；见tested-sources.json。C-029后的最终增量另记，不能把本次结果直接外推为后续二进制测试。

## 原生GUI与输出
主通过CUA在已安装0.2.7前一候选实际操作：本窗口A/G试弹收到4事件、2/2 NoteOn，音频输出tap峰值0.021709453；暂停后input=stopped、engine=false。点击隐藏/显示，WindowServer中1496×208浮层由alpha0且不在onscreen变为alpha1且在onscreen，状态栏按钮实际16pt；迁移的音量1和标签开启保持。

证据live-ui-pre-c029.json仅保留本App聚合字段和本App窗口元数据，不含输入文字或按键历史。Dock初始真实可见时状态为“等待Dock隐藏”；原生自动隐藏开启，收回后恢复显示。该证据属于C-029前候选，尚不证明最终浮动层跨应用实测。

## 签名、安装与权限
旧0.2.4正常退出并备份原App，原SHA256为6edd694ea26998ffb0015c1301b4042ed5a22c4fa594611eee102dcb41222202。首次签名0.2.7严格验证通过，DR与公开0.2.6逐字节相同；记录pre-c029-final-signature.json、pre-c029-installed.json。尚无Developer ID和公证。

初次安装后输入监控preflight=false；未改TCC。旧ad-hoc版本的许可不能冒充新固定签名包已获授权。主的本窗口合成输入只证明局部路径和引擎输出，不证明真实全局键盘或声学听感。最终重新构建仍沿用同一固定签名、安装路径，待用户亲自授权后复核。

## 未测边界
实际菜单栏打开自定义窗口及完整手动保存流程、真实TCC弹窗层级、Fn/Caps/左右修饰全量实按、多屏/侧Dock/全屏/Spaces/Stage Manager组合、其他macOS、真实声学延迟及最终音色未由本轮全部验证。实际安全会话系统通知不等于注入状态回归。历史0.2.4通过不替代最终新包实测。

## C-029最终接收与发布候选

只读最终复核无阻塞，82个冻结文件逐项一致。主独立重跑最终131项：128通过、3条件跳过、0失败，源文件在测试期间未变，见final-tests.log、final-independent-tests.json及final-tested-sources.json。真实重叠窗口A→B→A排序、modal代理优先和前台不变通过；早期green.log失败保留但不计入通过。

最终开发签名及安装二进制SHA256为aa73ef762225ba3e5d54d358cc5235274b3d247542a871b7be4e77032c254ec5，DR与0.2.6相同。ZIP共43文件全文件哈希往返一致、CRC和解压后strict签名通过，见package.json、final-signature.json、installed.json。原0.2.4和前一0.2.7候选分别备份，没有修改TCC。

最终App本窗口合成输入受理，并在400ms按住测试测得音频tap峰值0.028249156，随后按失焦规则停止。短瞬时合成按键曾被受理但tap峰值为0，未据此宣称声学输出；使用有时长按键后才取得正输出。final-live-diagnostic.json记录选择显示之前的实际聚合状态：新映射、音量1、16pt菜单、输入权限false。GUI显示后的真实浮动层/另一应用前台状态见final-live-windows.json、final-other-app-foreground.json；这不外推所有跨应用遮挡组合。

## 用户授权与真实实按闭环

用户自行移除了旧输入监控条目，主在系统添加窗口选中固定路径最终App，用户亲自点击添加并允许。最终App只读preflight=true。系统“重开”曾误启动同Bundle ID的ad-hoc候选，主从实际进程路径识别并正常退出，注销该候选LaunchServices登记、重新登记固定安装包，未重签或改TCC。重新打开正确App显示“开始打字钢琴”，主点击进入持续后台模式。用户在普通输入框实按A/G，明确回复“能听到琴声”。见user-physical-confirmed.json。此时仅一份正确安装路径进程运行；不将这两键实按外推至Fn/Caps/左右修饰或跨版本升级保留权限。

## 固定签名发布检查与提交

C-030接收：13项真实签名工具测试通过。主独立verify-only确认最终公开包通过，并确认ad-hoc候选被拒。临时候选GUI已正常退出，其.app原字节封存为.app.retired，原ZIP保留，见candidate-retired.json；正式App保持运行与签名不变。以后使用Code/Scripts/release_sign.py明确身份、校验上一公开包DR，缺身份或不一致即失败，无ad-hoc回退。真实跨版本TCC继承仍未测。

Git按功能、发布工具、文档/证据拆分提交。明确路径git add后检查git diff --cached及--check，生产源码与冻结hash一致。Design/UI/U-027/tools/drawing.swift.inc冻结生成文件末尾有额外空行，保留交付hash；证据中的原始diff/log空白保留，不回写历史测试日志。功能提交使用core.whitespace=-blank-at-eof仅放过该已知EOF空行，其他源代码空白检查通过。
