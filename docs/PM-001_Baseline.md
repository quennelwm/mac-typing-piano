# PM-001 项目基线

日期：2026-10-28，Asia/Shanghai。执行：项目主对话。

## 来源与环境

- 项目根：`/Users/wuming/Desktop/键盘钢琴`。接收时为空，无已有程序；未新建重复项目。
- 来源：用户给定 ZIP 的 22 个文件，SHA-256 和逐文件摘要见 devkit-provenance.json；Markdown 为工作阅读版，DOCX 原样保存。
- 初始提交：`e0c65123dc321e20d9c0560240bca5261d188cd7`，本地 main，无远程发布。
- macOS 27.2（26B123），arm64；Xcode 27.1（27A9275），SDK 27.0，Swift 6.4。以上是执行命令所得环境，不能推导其他系统兼容。
- Xcode 路径：`/Applications/Xcode.app/Contents/Developer`。Python 可用 jsonschema。
- 原目录无 Git 仓库，已本地初始化；未配置用户提交身份，提交使用单次显式 Codex <codex@local.invalid>，未修改全局/本地身份配置。
- 原始主文档4行 Markdown 换行空格触发 diff --check 提示，作为原包内容保留；非代码错误。

## 本轮工程选择

- 采用已有三个对话和共同根目录，无需用户转发聊天。只通过已授权的 send_message_to_thread 实际派发；报告统一入文件。
- M0 采用严格目录归属：主=docs/任务/决策/契约；代码=Code；音效=Design/Audio；UI=Design/UI。M0路径互不重叠，Git写入由主对话串行执行。共享根不切分支、不stash/reset，不假称worktree隔离。进入M1前复核是否需要worktree。
- 已批准按 v1.0 启动三个探针/候选任务，尚未批准最终音色/视觉/平台支持矩阵，也未授权权限设置或发布。
- 64键映射维持 integration_draft，仅供联调；不修改 captureStatus。
- 标签默认常驻，文字分层，左右可分；56pt是v1.0建议初值，不再沿用旧稿“默认隐藏”建议。

## 静态证据

执行 `python3 docs/validation/validate_baseline.py`，报告 PM-001-static.json。JSON与Schema通过；64实体键/音高双射、每排14/14/13/12/11、MIDI33—96、38白26黑、音名与左右标签均通过。真实输入、音频、UI渲染均未测。

本轮文件不修改原始主文档/契约；任务卡是实施范围，不能把技术提案标成用户最终批准。
