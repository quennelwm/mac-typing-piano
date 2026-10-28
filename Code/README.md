# 打字钢琴试用 0.2.6

当前版本为 **0.2.6 / build9**，Bundle ID 为 `local.typingpiano.trial`。默认使用全64音Steinway B试用音库，原生Quiet Ivory琴键、独立灰标签和700ms上升♪。Fn保留，顶部整排（包括Esc）排除。对外下载入口见[仓库根说明](../README.md)。

现成冻结包是 **Apple Silicon（arm64）** 构建，不是Universal包。源码以macOS14为编译目标，但实际仅在本机macOS27.2 arm64、Swift6.4验证；macOS14、其他系统版本和Intel源码构建均未完成兼容验收。包使用本地ad-hoc签名，未做Developer ID签名或公证，下载后的系统安全提示处理见根说明。

## 用户开始

1. 先将App放到固定目录，再打开并授权。偏好写入用户Application Support；Dock恢复票据仍在App同级，安装目录需允许当前用户写入。不要来回移动已授权的App或同时运行旧副本。
2. 启动卡主按钮会显示“授权并开始”或“开始打字钢琴”。首次未授权时，点击后在系统设置亲自允许；同一进程从设置返回、预检通过时会继续这一次持续会话，不必再点第二个开始按钮。
3. 如果系统要求退出重开，会保留待办提示，但**重开后必须主动点击主按钮继续**。持久化取消/消费可能失败，旧标记绝不作为跨进程自动启动许可。普通重开、激活或已暂停状态不会自行开始；取消本次开始、关闭待授权启动卡或暂停都会撤销本进程续接。
4. 尚未授权时，可用“本窗口试弹（无需权限）”；失焦或关闭本地测试窗口会停止。安全输入或音频失败分别提示原因，失败后不会循环弹权限或自动重试。
5. ♪菜单显示运行/暂停原因，提供“打开启动窗口…”、暂停、声音、App音量、画面和标签；“下载新版…”仅打开GitHub Releases，由用户下载并正常退出后替换App。退出按钮只退出。测试子菜单的60秒模式会自动停止，持续全局会话关闭控制台仍可运行。

**升级后的旧授权可能失效。** ad-hoc重建或重签会改变代码身份；相同Bundle ID、同一路径、系统条目仍显示开启，都不能保证新包已获授权。本机从旧签名升级时，单纯关闭再打开开关未刷新旧记录：需先退出App，在“隐私与安全性 → 输入监控”移除失效的旧条目，再添加最终路径的新App，由用户允许并重开。只处理本App的条目，不重置整个权限数据库。CLI的preflight结果不代替GUI建立全局监听及实按验证。

同Bundle重复启动会激活已有实例并退出新启动自身，不终止其他软件。旧 `local.typingpiano.probe` 探针不在此控制范围，应自行正常退出。

## 音量与音库

新偏好默认50%，完整音库对应mixer0.375；最大100%为0.75，sampler增益+12dB。已有偏好会继续加载。0%清尾并抑制新音，不停止输入/动画；调高不重播旧音。完整音库覆盖MIDI33—96；64音velocity127和弦的既有离线峰值约0.699767（约3.10dB余量），不代表所有设备、演奏序列或长期听感均已验证。Float32片段和90组测量见 [音频校准证据](../docs/evidence/C-002T/audio-calibration/)。

测试子菜单还保留原创合成64音和Kawai10音/Steinway11音候选。部分候选缺音保持无声；换库会停止旧监听和声音，需重新开始。当前完整音库为单层mono16试用资源，音色仍可调整。

## Dock与边界

GUI启动会默认启用**系统原生Dock自动隐藏**，不再使用模拟开关。关闭前提示与钢琴重叠风险；取消不写入。App仅恢复本会话拥有且仍可核对的改动：若启动时系统已为true，不会退出后恢复成更早的false；发现外部不同值时不覆盖。未决/崩溃恢复票据须明确处理。

原生后端通过 `dlsym` 检测HIServices的 `CoreDockGetAutoHideEnabled` / `CoreDockSetAutoHideEnabled`，只操作autohide。它们是**私有SPI**，本机实测即时生效不构成其他macOS版本的兼容保证。缺失、无效读回或写后核对失败会明确报错，可用菜单“系统Dock设置…”直接调整；没有defaults-only假成功、Dock重启、Apple Events或新增权限的自动回退。

钢琴自动使用目标屏幕完整宽度减16pt，左右各留8pt、底缘贴屏幕，高度保持104pt（56pt琴键＋48pt效果区）。默认仍选内置屏优先的一条钢琴，不跟随鼠标跨屏跳，日常不再选900/1000/1100宽度。

Dock显隐依据已配对验证的Dock专属layer20窗口及 `onScreenOnly` 成员关系，不用鼠标靠边热区代替。实际出现时260ms淡出；隐藏稳定120ms后360ms淡入，减少动态为80ms。短暂未知保持当前状态，连续未知2秒后恢复可见并保留未知诊断。隐藏只影响视觉，输入和声音继续；恢复当前按压状态，不补播旧音符。

当前菜单请求16pt槽宽、16×16pt模板画布，使用18pt的♪字形按实际墨迹边界缩放居中，内缩1pt。本版真实菜单显示与点击尚待验收。此前0.2.4在本机已现场验证：实际20pt菜单按钮、1512pt屏幕上的1496×104浮层、原生Dock开关及淡变、本窗口试听、重新授权后的普通全局输入和琴声。真实Fn/Caps/双侧修饰的完整矩阵、中文/快捷键、声学延迟、设备切换、全屏/多屏组合和长时稳定性仍未全部验收。

`probe-preferences.json`（音量/标签）现在位于 `~/Library/Application Support/local.typingpiano.trial/`。已有目标文件优先；目标不存在时，只读取当前App旁的旧偏好一次，缺失则写入默认值，旧文件不修改。迁移后不再读取其他旧副本偏好。损坏文件会报错，不静默覆盖。`authorization-start.json`只保存一次授权待办状态，不记录输入，也不是开机启动开关。`dock-recovery.json`仍在当前App旁，不迁移、不接管其他副本票据。

升级应先正常退出，只替换完整App，保留用户偏好和待处理恢复票据，再核对授权。首次迁移请从最终安装路径打开，以读取该App旁正确的旧偏好；不要先运行另一个空候选目录导致默认值优先保存。Caches目录可能被系统清理。

## 可选静音系统提示音

“静音系统提示音”默认保持系统现状。用户开启并确认后，仅将macOS提示音音量设为0；它会影响所有遵守该音量的系统警告，不仅是无输入框的提示音。钢琴、媒体音量、系统总静音和键盘事件不变。系统原已静音时不产生恢复值，也不会猜测50%或100%。

后端在当前进程通过NSAppleScript执行公开Standard Additions的 `get volume settings` / `set volume alert volume`，不调用System Events，不用defaults读回代替设置生效。关闭/正常退出先核对当前值，仅恢复本会话仍拥有的原提示音量；外部不同值不覆盖。写入或核对失败显示未知/失败，正常退出恢复失败允许取消退出重试。菜单保留“系统声音设置…”入口。

原值仅保存在当前会话内存，**崩溃/强制退出不保证恢复**；下次启动不接管旧变化，需在系统声音设置手动调整。同值外部写入以及跨进程读写之间的竞态无法由该接口识别。额外Automation权限提示、真实系统音量/听感与其他系统版本尚待主对话验证；若系统拒绝，明确失败，不增加权限或切换私有接口。[Apple接口说明](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html)。

## 开发复现

需要macOS、提供Swift6.0或更新工具链的Xcode/Command Line Tools，以及Python3.9或更新版本。实际验证工具链为Swift6.4。构建脚本只用Python标准库；额外的 `verify_candidate_banks.py` 核验脚本才需要 `jsonschema`。构建依赖完整的 `Design/`、`contracts/`、`Code/Assets/` 和音频交接/manifest文件，不可只下载Code目录；manifest列出的源文件也须齐全。

在包含Code、Design、contracts的**仓库根目录**执行。以下每次创建独立候选目录，不依赖作者用户名或本机项目绝对路径，也不会覆盖正在使用的授权包：

```sh
mkdir -p "$HOME/Library/Caches/typing-piano-builds"
export TYPING_PIANO_BUILD_ROOT="$(mktemp -d "$HOME/Library/Caches/typing-piano-builds/candidate-0.2.6.XXXXXX")"
bash Code/Scripts/build.sh
codesign --verify --strict "$TYPING_PIANO_BUILD_ROOT/打字钢琴试用.app"
"$TYPING_PIANO_BUILD_ROOT/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe" --self-check
"$TYPING_PIANO_BUILD_ROOT/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe" --menu-smoke
```

输出为该目录下的 `打字钢琴试用.app` 和同名ZIP；脚本验证冻结资源哈希，进行本地ad-hoc签名并检查签名。可通过 `TYPING_PIANO_SIGN_IDENTITY` 由调用方指定签名身份（缺省为 `-`）；脚本不硬编码证书，也不输出签名身份或证书错误详情。不要将身份或私钥写入仓库；本轮CODE只使用ad-hoc，最终稳定开发签名由主对话在独立副本验证。上述自检不启键盘监听或硬件声音，菜单smoke不安装真实状态项。需要试用时再手动打开App；开始前留意其系统Dock默认开启行为。

未指定环境变量时，现有脚本默认输出到 `$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.6`。该默认目录重复构建会被更新，所以推荐上面的唯一目录命令。脚本明确拒绝输出到 `$HOME/Library/Caches/local.typingpiano.trial` 根目录，这是已有授权安装的保护规则，不是建议绕过的构建错误。已使用/授权的候选目录也不应再拿来构建。

可选的无窗口回归组（先完成上述构建环境变量设置）：

```sh
swift test --build-system native --package-path Code \
  --scratch-path "$TYPING_PIANO_BUILD_ROOT/tests-swiftpm" \
  --filter 'PianoCoreTests|NativeDockStorageTests|DockWindowVisibilityTests|AdaptiveOverlayTests|DockAdapterTests|SingleInstanceTests|RuntimeDiagnosticsTests|LocalTrialStartTests|AudioSelectionTests|MenuIntegrationTests|PianoMacTests.IntegrationTests|StartupEntryTests|AlertVolumeTests'
```

本版本上述回归组89项测试通过（0失败），验证记录见 [0.2.6交接](../docs/evidence/trial-0.2.6/HANDOFF.md)；系统Dock和提示音后端使用mock，不操作真实系统设置。无过滤的完整测试还包括窗口联调和会写音频证据的测试，不作为上述构建步骤的默认动作。`--build-system native` 在已验证工具链上会产生弃用提示，当前脚本仍使用它；其他工具链需自行验证，不能据编译目标宣称兼容。

完整音库、参数、许可与来源记录打入 `AudioTrial`，原始/中间WAV不打入App；`runtime-bundle-inventory.json`列出实际打包文件。资源与源码改变后应重新验证，不只汇总旧报告。当前实现与验收索引见 [IMPLEMENTATION.md](IMPLEMENTATION.md)。
