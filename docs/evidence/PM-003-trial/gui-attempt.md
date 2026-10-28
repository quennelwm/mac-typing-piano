# 实际启动检查

主对话通过CUA按完整Caches路径启动C-001C App；进程及CUA库存显示isRunning=true。CUA读取菜单两次超时；按bundleID选取有旧Code/build同ID冲突，按显示名未解析。未执行菜单点击/监听/发声/Dock动作，不能声明真实GUI菜单已通过。程序化self-check/menu-smoke独立通过，证据同目录。检查后只终止本次启动且仍默认停止的PID32686，避免后台旧版妨碍新包。
