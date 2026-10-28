# CR-001 同步记录

日期：2026-10-28。任务：落实用户菜单入口/标签选项/系统Dock自动隐藏需求，不是宣称功能完成。

- 直接用户澄清确认系统Dock自身自动隐藏；未通过工具写系统设置。
- 三次send_message_to_thread分别发给既有代码、UI、音效对话，均返回对应threadId无错误。
- 后续wait_threads确认三路仍运行；UI最新进度明确正在补独立预览、菜单示意及标签开关。代码正在排查测试构建，音效继续小样核查。不能据此认为所有增量代码已完成。
- 主文档、ADR-010、AGENTS、README、四启动说明、接口语义、三任务卡、PM-002与验收同步。原始DOCX保留历史快照并已在README标明。
- UI Schema仅增加visibleByDefault语义描述，不改结构/版本；映射/音域/音频格式无变更。
- 执行 `python3 docs/validation/validate_baseline.py`：Schema、64键映射、颜色、音名、标签和侧别均通过。执行 `git diff --check`：通过。
- 新增U-07/U-08/D-06/D-07全部仍未测试；需后续正式App证据，不以文档/预览代替。
