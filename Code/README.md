# 打字钢琴试用 0.2.0

默认使用全64音Steinway B试用音库；Quiet Ivory原生琴键、独立灰标签和700ms上升♪。Fn保留，顶部整排排除。当前为本地试用，不是发布版。

## 用户开始

打开 `/Users/wuming/Library/Caches/local.typingpiano.trial/打字钢琴试用.app`。中文启动卡默认停止，点击“开始打字钢琴”才启动持续全局观察、声音和画面。缺输入监控权限时按提示自行授权并重开；程序不代改权限。点击开始后可回到其他App打字，♪菜单提供暂停、声音、音量、画面、标签和退出。关闭控制台不结束持续会话；暂停或退出才完全停止。测试子菜单仍提供60秒模式与其他音库。

新bundleID为 `local.typingpiano.trial`，版本0.2.0/build3；与旧探针不同，权限也可能需要单独授予。主对话维护的项目“试用版”入口和Reviewed-C001C快照不由本代码任务覆盖。

## 音量与音库

默认50%对应mixer0.375，最大100%为0.75，真实完整音库sampler增益+12dB。0%清尾、抑制新音，但不停止输入/动画；调高不重播旧音。全64音实载，极端64音velocity127和弦在单/双声道离线峰值约0.699767（约3.10dB余量）；这是测得序列，不保证所有设备/长期使用听感。Float32代表片段及90组测量见 `../docs/evidence/C-002T/audio-calibration/`，没有把旧低电平PCM16放大冒充修复。

测试子菜单保留原创合成64音和Kawai10音/Steinway11音候选。部分候选缺音保持无声；换库先停止旧监听/声音/状态，重新开始才恢复。正式音色尚未冻结，当前完整音库为单层mono16试用资源。

## Dock与边界

默认Dock模拟。真实系统开关只从用户明确确认的主动测试入口执行；固定defaults只处理autohide，不重启Dock。关闭前提醒、取消零写入；读回成功不等于视觉生效。外部修改受保护，退出按所有权恢复，未决/崩溃恢复须明确处理。普通鼠标点击不再永久隐藏钢琴；已知Dock区域/活动仍让位，释放并离开400ms后恢复。键盘呼出Dock、全屏/多屏/菜单等仍待现场验证。

偏好与恢复票据暂放App旁Caches联调路径，可能被系统清理；正式持久目录及安装策略留后续。真实Fn/Caps/双侧修饰、中文/快捷键、声学延迟、蓝牙/设备切换和长时听感未代用户验收。开发验证没有开启真实监听/硬件播放或改系统Dock。

## 开发复现

项目根目录执行；需要现有Python jsonschema、macOS音频框架，无新依赖安装：

```sh
export TYPING_PIANO_BUILD_ROOT="$HOME/Library/Caches/local.typingpiano.trial"
export TYPING_PIANO_EVIDENCE_DIR="$PWD/docs/evidence/C-002T/candidate-regression"
python3 Code/Scripts/verify_candidate_banks.py preflight
swift test --build-system native --package-path Code --scratch-path "$TYPING_PIANO_BUILD_ROOT/swiftpm"
python3 Code/Scripts/verify_candidate_banks.py summarize
python3 docs/evidence/C-001B/test_evidence_binding.py
bash Code/Scripts/build.sh
"$TYPING_PIANO_BUILD_ROOT/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe" --self-check
"$TYPING_PIANO_BUILD_ROOT/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe" --menu-smoke
```

源码/资源变更后必须重新预检并渲染，不只汇总旧报告。构建验证冻结资源哈希；完整试用bank/参数/许可/来源记录打入AudioTrial，原始和处理中间WAV保留项目内，runtime-bundle-inventory.json列出实际打包文件。仅本地ad-hoc签名和ZIP，不用发布证书或公证。native兼容后端的弃用警告保留。开发环境macOS27.2/arm64、Swift6.4；macOS14只是编译目标，其他系统/Intel未测。Git仍由主对话管理。
