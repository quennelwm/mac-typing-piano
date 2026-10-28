# Typing Piano · C-001 M0 原生探针

仅限本地 M0 评审；真实钢琴资源、正式系统 Dock 控制、700ms 小音符绘制与完整常驻体验尚未接入。macOS 14 是候选编译目标，本轮只在 macOS 27.2 / arm64 / Swift 6.4 / SDK 27.0 验证。

## 构建和验证

在项目根执行：

```sh
python3 Code/Scripts/verify_candidate_banks.py preflight
swift test --build-system native --package-path Code
python3 Code/Scripts/verify_candidate_banks.py summarize
bash Code/Scripts/build.sh
Code/build/TypingPianoProbe.app/Contents/MacOS/TypingPianoProbe --self-check
Code/build/TypingPianoProbe.app/Contents/MacOS/TypingPianoProbe --menu-smoke
Code/build/TypingPianoProbe.app/Contents/MacOS/TypingPianoProbe --snapshot docs/evidence/C-001/previews
Code/build/TypingPianoProbe.app/Contents/MacOS/TypingPianoProbe --window-smoke
```

C-001B增加了两个真实钢琴候选的离线测试，默认应用仍使用合成占位。完整测试须先运行上述preflight，核对候选资源及测试源码；源码或候选发生变化后须重新preflight并重新测试，不能直接复用旧结果。该脚本使用当前已安装的Python `jsonschema`，不会安装依赖。只复跑C-001的35项原有测试可用 `swift test --build-system native --package-path Code --skip CandidateBankTests`。C-001B结果及复现细节见 `../docs/evidence/C-001B/README.md`。

测试只做合成事件/离线音频。`--window-smoke` 会显示250ms非激活面板后关闭，只验证属性和前台进程未变化，不代表实按/鼠标穿透/Dock实操通过。其他上述模式不会开始监听、硬件音频、权限请求或系统设置写入。

新 SwiftPM 默认 swiftbuild 在本 Desktop 文件提供器目录生成的 xctest 带 FinderInfo，导致签名失败。当前使用仍可工作的 native backend（已弃用警告保留），不改用户配置。build.sh 仅清理由本项目生成的 `Code/build/TypingPianoProbe.app` 扩展属性，做 ad-hoc 本地签名；不使用开发者证书，不公证或发布。`.build` 与 `build` 已在 Code/.gitignore 排除。

## 手动打开与停止

```sh
open Code/build/TypingPianoProbe.app
```

启动仅显示菜单栏单音符 **♪**，默认不监听、不发声、不打开主窗口。点击菜单可打开测试控制台、启用本窗口/全局60秒测试、暂停、开关声音/标签/浮层、调整本App音量或退出。关闭控制台会停止探针；从♪菜单“退出探针”终止进程。没有登录启动或自动后台监听。

- 先开启一次60秒测试，再在控制台用鼠标点琴键或按实体键；只有用户手动启用“声音”才建立硬件输出。资源在启用时一次性加载，按键回调不读文件。
- 全局模式仅在当前进程已获输入监控时尝试 listen-only tap；本轮不调用授权请求。没有授权时显示说明，可用本窗口测试，不增加辅助功能/屏幕录制/麦克风权限。工具进程预检true不等于用户双击启动的签名身份也已授权。
- 状态只保留瞬时按键集合和事件总数，未读取文字/剪贴板、未记录真实逐键历史，未注入/吞掉事件。失焦会暂停本窗口模式；全局模式继续。失效/睡眠/会话退出/安全输入阻断均清理；现场场景仍待测。
- 矩形浮层仅普通窗口层级，非激活、鼠标穿透，38白26黑。靠近边缘隐藏，离开恢复区400ms恢复；鼠标按住/拖拽或Dock前台后锁定隐藏，控制台点“解除保守隐藏”才恢复。Space/显示器变化保守隐藏，不承诺精确Dock状态或全屏支持。
- 仅隐藏浮层不停止声音；暂停/关声音清除声音尾音及任务。暂停后显示开关不会恢复会话。
- 所有黑白键底部标签来自 keymap，默认可见；菜单开关只改变文字，保存到本地探针偏好。黑键侧标采用独立上角标，避免900pt下越界。此为基础测试画面，未用正式UI资源。

## 音量与偏好（CR-001/003）

菜单内水平连续滑块0—100%，初始50%对应App gain0.08，最大100%对应0.16；不改系统音量/设备。0%会清除音频尾音并抑制采样器新击发，输入/画面继续；调高不补播旧音，也不会打开已关闭的“声音”开关。普通非零音量变更由AVAudioMixerNode应用，实时过渡/听感未测。

音量和标签保存为 App 同级 `probe-preferences.json`，本地构建为 `Code/build/probe-preferences.json`。启动只读；用户改动时原子保存。该文件无输入数据。M1再迁移为正式应用支持目录。坏偏好文件明确报错，不默默覆盖。

系统Dock自动隐藏只有纯逻辑模型、指定关闭警告和恢复方案，菜单明确标为“M1待接入”；没有执行写入/重启Dock。小音符模型支持700ms/减少动态200ms、pressID去重、重击独立、隐藏代次清理，不在M0面板假称完成上升效果。未添加任何触控板专属功能。

## 音源及测量边界

`Assets/placeholder-original.sf2` 是由 Scripts/generate_placeholder.py 可重复生成的原创合成占位，530,774bytes，非正式钢琴。固定program0/MSB121/LSB0。源波形、许可说明、manifest在Assets；所有正式音色选择留给PM评审。数字峰值不代表听力安全或主观音色验收；未证明64个内部声部、硬件无冲或真实延迟。

证据及逐项状态：`../docs/handoffs/C-001.md`、`../docs/evidence/C-001/acceptance.md`。共享仓库的Git操作由主对话处理，本代码对话未提交、切分支或修改他人文件。

补充：当前Desktop文件提供器可能在构建成功后重新添加.app FinderInfo，导致稍后的strict签名验证失败。脚本有最多3次生成包签名重试，并输出无扩展属性的 `Code/build/TypingPianoProbe.zip`；归档逐文件字节已核对，仍不是安装/分发认证。详见 `../docs/evidence/C-001/signing-stability.md`。本轮不通过修改文件提供器或迁移用户目录来掩盖此限制。
