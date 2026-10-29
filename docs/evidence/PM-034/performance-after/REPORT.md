# PERF-034 0.2.11 安装后只读观察

2026-10-29 17:34:18.172–17:34:29.347 +08:00，唯一固定路径进程 PID 34381，0.2.11/build14，二进制 SHA256 `bb77fb34931168c171796a1f4a9e209288e30628e0a508b69dbcfd19854e61ef`。环境 macOS 27.2 (26B123)、arm64、16 GiB。未启动/暂停App、未发送按键、未更改运行状态或系统/用户设置；仅写本目录。没有收集逐键文本/历史。

## 同口径观察结果

命令与 baseline 相同：`top -l 6 -s 2 -pid <PID> -stats pid,command,cpu,mem,threads,time,state`，丢弃首个无效 CPU 样本；窗口前后运行同一 `ps -p <PID> -o pid=,etime=,time=,%cpu=,rss=,vsz=,stat=`；其后 `sample <PID> 2 -file ...`。原始命令、环境、时间、原始输出在同目录 JSON/txt。

| 指标 | 0.2.10 基线 | 0.2.11 本窗口 |
|---|---|---|
| 有效 CPU 样本 % | 2.1, 2.4, 6.5, 5.3, 4.7 | 4.6, 4.1, 4.5, 9.1, 2.3 |
| CPU 均值 % | 4.2 | 4.92 |
| top MEM | 158–189 M | 188–189 M |
| ps RSS KiB，前→后 | 107424→92080 | 201728→193920 |
| 线程数 | 10–14 | 10–12 |
| ps 累计 CPU，前→后 | 3:24.12→3:25.59 | 0:38.25→0:38.87 |
| sample physical footprint | 220.2 M | 189.4 M |
| sample 历史峰值 footprint | 237.2 M | 273.5 M |

两个窗口都是非受控观察，用户可能输入或操作菜单；0.2.11 的2秒栈确认系统选项子菜单在 tracking。不能把 CPU/RSS/footprint 差值归因于版本优化/回退，不能从瞬时峰值判断泄漏。top MEM、ps RSS、sample physical footprint 是不同指标，不能互换。ps 累计CPU区间包含初始采样，不与丢首样本后的均值强行匹配。

## 栈证据与下一步

- `sample-2s.txt:24` 主线程1032个样本均在 `ControlPanel.systemAction` 触发的原生系统选项 NSMenu tracking 调用树中；其中904个落在事件循环 Mach 等待路径。它不是1032个忙CPU样本，亦不证明菜单卡死/关闭失败。
- `sample-2s.txt:84` 有83个样本走 `dockTick → observeDock`，61个在 `.optionOnScreenOnly` 的 `CGWindowListCopyWindowInfo` 中；包含 WindowServer IPC 等待和解析。当前代码仍每0.1秒探测、每2秒重发现，仅变化才refresh。这个查询是本窗口可见的主要App工作，可作为下一轮受控优化目标：先分别计时发现/日常查询，评估降低稳定状态查询频率的CPU收益与Dock显隐延迟，不在本次采样中改动。
- `sample-2s.txt:739` 音频IO线程1032样本中的1024个等待信号量，只有少量转换/回调样本；本窗口没有证据证明音频计算是主要瓶颈，不支持为省CPU停音/删尾音。
- 本次没有 `PianoView` 绘制帧落入采样。缺少连续打字/滑条拖动的受控绘制负载，因此不能借此确认或否认离屏render基准的收益、实际帧率或流畅性。
- 真实菜单关闭、拖动、显示层级以及TCC继承属于其他验收；本采样没有操作或验证它们。

## 最终 AlertVolume 修复只读确认

`AlertVolume.swift:87` 的 `mute(confirmed:)` 仅在 `originalVolume == nil` 时记录读回值；已有第一次原值时不覆盖。结合 `setVolume` 相同保护，70→45→20→mute→restore仍以70为恢复目标。`ControlPanelTests.swift:18` 有mute后original仍为70的断言。本轮只读核对源码和断言，未跑测试、未改提醒音量。

冻结manifest SHA256 `873388910a57dc99eb302b8e2d28bcb04e95b6b6d7cc914db5aaeb8608c920a0`，97/97文件当前匹配；见 `source-observation.json`。
