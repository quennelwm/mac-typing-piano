# C-033 implementation plan
角色：代码唯一生产实现。任务基线b74f560，沿用CR-010已批准NSMenu设计；不作Git操作/独立设计审批。

1. 在未修改生产代码时用CompactMenuTests测真实NSMenu.size（初始化及长状态）；保存menu-before.json，断言目标170—195pt产生RED。
2. ProbeMenu：共用两行slider行；系统/帮助子菜单；根短状态、完整tooltip；新增权限menu action和只读状态；仅根menu delegate触发打开/关闭回调。保留NSStatusItem.menu原生跟踪。
3. ProbeController：打开菜单只读预检；显式菜单动作已授权只打开系统页，未授权点击直接复用handleStartup(.primary)并显示现有说明窗口（主后续明确）。系统页打开闭包可注入测试，不新增权限请求路线，不改授权状态机。
4. 针对性测试：最终菜单宽、文字适配、三滑块target-action、根/子菜单回调、授权分支不改变held/audio/运行；调整既有测试的新菜单路径且保留原行为断言。
5. 离屏入口输出NSMenu.size及完整树、3个真实slider视图的合成布局预览（明确非系统菜单截图）；菜单真实点击留主验收。只少量预览。
6. 定向通过后一次最终完整回归，冻结源；独立0.2.10/build13 ad-hoc候选，仅CLI。核验源/旧安装保护hash、ZIP/签名，交HANDOFF/delivery。
