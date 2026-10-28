# CR-005公开接口核对与边界

2026-10-28，CODE只读研究与mock验证；没有执行真实提示音getter/setter或打开系统设置。

Apple [AppleScript Language Guide — Commands Reference](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html)明确列出`get volume settings`记录中的`alert volume`，范围0…100；`set volume`可以只指定alert volume，未指定的output volume/input volume/output muted保持不变。100表示相对当前输出音量的最大提示音量，不是单独设置媒体音量。

本机Apple提供的`/System/Library/ScriptingAdditions/StandardAdditions.osax/Contents/Resources/StandardAdditions.sdef`第570—578行和592—598行具有相同公开命令/参数定义。字典只读核对，没有复制或改动系统脚本组件。

[NSAppleScript.executeAndReturnError](https://developer.apple.com/documentation/foundation/nsapplescript/executeandreturnerror(_:))用于在当前进程执行脚本并接收错误。实现只提供固定读取脚本`return alert volume of (get volume settings)`和范围检查后的`set volume alert volume N`；不含tell System Events、其他目标应用、shell、defaults、output muted或媒体音量参数。代码不增加Automation用途描述、entitlement或权限请求入口。

据这些接口语义，当前进程Standard Additions路径预期不需要控制其他应用的Automation授权，但这不是本机运行时证据。NSAppleScript真正执行、系统拒绝/权限提示、硬件路由和提示声变化均由PM在最终签名副本通过UI测试。出现拒绝（包括-1743）明确报错，保留系统声音设置入口，不自动切换后端或新增权限。

状态机只保存本会话原值于内存；首次已为0零写入且不创造恢复值。操作后真实getter核对，关闭/正常退出前再次读取，外部不同值释放所有权不覆盖。写入后未能核对时不假报成功；未经验证的写入不自动恢复，需要系统设置检查。退出恢复失败可取消退出重试或明确选择仍然退出。

崩溃、强制退出和机器断电不保证恢复；下次启动不接管旧会话，不读写其他副本恢复票据，用户应在系统声音设置手动恢复。接口没有原子比较交换能力，外部同值写入、外部值改回0或检查与写入间的竞争不能被完整识别；不把值相同声称为绝对所有权证明。

mock测试涵盖默认/取消零写入、正常恢复、初始0、外部改变、写入被拒/忽略、写后报错但读回0、读取失败和恢复重试、写后未确认禁止自动恢复，以及后端只指定alert参数/非法读回/拒绝传播。它们不证明本机声音或权限行为。
