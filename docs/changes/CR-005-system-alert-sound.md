# CR-005：可选静音系统提示音

用户确认琴声恢复，但没有输入框时系统警告声与琴声叠加，要求在菜单提供关闭选项（2026-10-28）。

菜单项为“静音系统提示音”，默认不主动改变当前系统设置。用户开启时说明：这是macOS系统提示音音量，会影响其他遵守该音量的系统警告；钢琴及媒体输出音量不改变。不能拦截或吞掉键盘事件，也不能修改系统总静音。

实现以Apple公开Standard Additions的`get volume settings`和`set volume alert volume`为候选，仅指定alert参数；不使用System Events、不申请无关权限。资料：[Apple命令文档](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html)、[Mac提示音设置](https://support.apple.com/en-in/guide/mac-help/mchlp2207/mac)。资料支持接口含义，不能代替当前macOS实测。

开启前读取和记录原提示音量，设为0后核对；失败时不显示成功。关闭或正常退出只恢复本会话拥有且仍为所写值的改动，外部修改不覆盖。原本已经为0时不凭空恢复成某个非零音量。保留“系统声音设置…”入口；异常退出的恢复策略和未验证边界需在交接明确，不悄悄接管旧副本票据。

验收：菜单状态、取消零写入、只有alert值改变、关闭/退出恢复、外部变化保护、写入失败、初始已静音；mock测试与真实系统滑块/听感核对分别记录。新包最终冻结后再公开发布，当前已授权运行包保持。
