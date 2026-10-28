# 0.2.1授权流程修复交接

**包和签名已冻结，不再覆盖。** 最终固定App：`/Users/wuming/Library/Caches/local.typingpiano.trial/打字钢琴试用.app`，version0.2.1/build4，bundleID local.typingpiano.trial。二进制SHA-256 `3e90c772f6590658377d94f2c7436677de9c44d3f3b15eb0dd6528492e4eaeae`；ZIP SHA-256 `f551974878c64b06860bffa41c3eddebb95ea6b19567a0480f6ca81fd2697dab`。0.2.0归档保留为Caches/local.typingpiano.trial/Reviewed-0.2.0.zip。

主对话已实机确认：0.2.0全局开始因缺输入监控授权在input.start抛错，尚未进入audio.enable，故保持静音。不能将其写成已证实的音库/增益故障。

## 用户操作

1. 从上述固定路径打开，确认标题0.2.1，点击“授权输入监控”。只有这个点击才调用CGRequestListenEventAccess并打开Privacy_ListenEvent设置；用户亲自允许，代码对话没有代申请/批准。
2. 回App点击“重新检查并开始”；每次重新查询。若系统要求退出或仍不能建立监听，点退出并从同一路径重开。
3. 尚未授权也可点击“本窗口试弹（无需权限）”，打开本地琴键、启动本窗口持续输入及所选声音。只在明确点击后启声；本地失焦/关闭/暂停/退出清理。

## 实时诊断入口（仅主对话决定何时操作）

控制台显示实时聚合状态，可明确导出JSON：有效事件数、noteOn请求/接受数、引擎运行/采样器加载状态、源与gain/volume、当前输出AudioUnit设备ID/名称、本App主混音器tap回调/帧数/峰值/最新回调时间。tap不读取麦克风或其他App，不存PCM或键序列；峰值非零证明自身混音器有数字输出，不能证明声学播放。帧数是回调累计帧数，不是逐帧非零计数，须结合peak判断。

可选独立短诊断（会发声；代码对话未运行）：

```sh
'/Users/wuming/Library/Caches/local.typingpiano.trial/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe' --live-audio-smoke 5 > '/Users/wuming/Desktop/键盘钢琴/docs/evidence/C-002T/0.2.1/live-audio-smoke.json'
```

此入口播放固定60/64/67，不启键盘监控，结束清理；主对话应先停止冲突的试听会话。查看engineRunning、currentOutputDeviceName、outputTapFrameCount、outputTapPeak和cleanupEngineRunning。它跟随实际系统设备，不切换输出、不改系统音量或Dock。主对话设备证据显示QuennelAPP是蓝牙（blue），不是虚拟路由；不能将设备类型猜测当无声原因。

## 验证与未测

31项无窗口测试通过，加9项实际离线采样器回归通过；release构建和只读strict签名验证通过。source/core/audio mock与纯buffer计量测试没有启动GUI、真实监听或硬件声音。未执行live CLI、权限申请或设置打开，实际授权、按钮布局、实时输出及Cmd+Q仍交主对话/用户验收。菜单退出新增q等效键，但不能把静态属性写成快捷键现场成功。

同时修复音频配置通知对象未隔离的问题：只接受当前引擎通知，忽略旧/无关对象；这是源码确认的缺口，不宣称其已被观察为本次硬件根因。原.75最大mixer/+12dB增益没有再上调。

证据：headless-tests.log、offline-audio-regression.log、build.log、signature-readonly.log、frozen-delivery.json。主对话已开始授权安排；任何后续修复只改源码或其他输出路径，不能覆盖本包破坏正在进行的授权。
