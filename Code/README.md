# 打字钢琴试用 0.2.11

当前版本为 **0.2.11 / build14**，Bundle ID 为 `local.typingpiano.trial`。默认使用全64音Steinway B试用音库，程序化水晶琴键、独立浅/深灰弱标签和24pt、950ms轻漂浮♪。Fn保留，顶部整排（包括Esc）排除。对外下载入口见[仓库根说明](../README.md)。

♪控制面板采用瞬态NSPopover，图标切换/外部自动关闭/Esc与滑块交互需安装实测。四条单行滑块控制归一化高度、透明度、App音量与系统提醒音量（仅显式拖动后防抖写入，正常退出按会话核验原值恢复）；运行勾选与独立浮音、按键声音开关分别保存。键位编辑点音位后按实体键，保存才应用，编辑窗口可见期间禁止启动演奏。系统设置可选顶层/底层。旧版说明仅保留追溯：原生菜单曾采用紧凑分组和两行滑块，音量/高度/透明度留在主层；系统声音与Dock移到“系统选项”，启动窗口/下载/测试移到“帮助与测试”。“输入监控授权…”在主层：展开菜单只读检测；未授权时显式点击直接进入既有授权并开始流程，已授权只打开系统页，不主动停止运行。菜单沿用系统跟踪，真实重复点击/外部点击和拖动需安装后验收。错误用短状态显示，完整说明在tooltip中。

黑键在0%透明度时主体为#000000，只有局部窄边缘光泽；按压仍有位移及局部高光反馈。白键、标签及独立透明度规则保持。系统减少透明度也使用相同黑底。

当前候选为 **Apple Silicon（arm64）** 构建，不是Universal包。源码以macOS14为编译目标，但实际仅在本机macOS27.2 arm64、Swift6.4验证；macOS14、其他系统版本和Intel源码构建均未完成兼容验收。本地构建默认ad-hoc，公开包采用固定Apple Development身份；未做Developer ID签名或公证，下载后的系统安全提示处理见根说明。

## 用户开始

1. 先将App放到固定目录，再打开并授权。偏好写入用户Application Support；Dock恢复票据仍在App同级，安装目录需允许当前用户写入。不要来回移动已授权的App或同时运行旧副本。
2. 启动卡主按钮会显示“授权并开始”或“开始打字钢琴”。首次未授权时，点击后在系统设置亲自允许；同一进程从设置返回、预检通过时会继续这一次持续会话，不必再点第二个开始按钮。
3. 如果系统要求退出重开，会保留待办提示，但**重开后必须主动点击主按钮继续**。持久化取消/消费可能失败，旧标记绝不作为跨进程自动启动许可。普通重开、激活或已暂停状态不会自行开始；取消本次开始、关闭待授权启动卡或暂停都会撤销本进程续接。
4. 尚未授权时，可用“本窗口试弹（无需权限）”；失焦或关闭本地测试窗口会停止。安全输入或音频失败分别提示原因，失败后不会循环弹权限或自动重试。
5. ♪菜单显示运行/暂停原因，提供“打开启动窗口…”、暂停、声音、App音量、画面和标签；“下载新版…”仅打开GitHub Releases，由用户下载并正常退出后替换App。退出按钮只退出。测试子菜单的60秒模式会自动停止，持续全局会话关闭控制台仍可运行。

**升级后的旧授权可能失效。** ad-hoc重建或重签会改变代码身份；相同Bundle ID、同一路径、系统条目仍显示开启，都不能保证新包已获授权。本机从旧签名升级时，单纯关闭再打开开关未刷新旧记录：需先退出App，在“隐私与安全性 → 输入监控”移除失效的旧条目，再添加最终路径的新App，由用户允许并重开。只处理本App的条目，不重置整个权限数据库。CLI的preflight结果不代替GUI建立全局监听及实按验证。

同Bundle重复启动会激活已有实例并退出新启动自身，不终止其他软件。旧 `local.typingpiano.probe` 探针不在此控制范围，应自行正常退出。

“显示钢琴”与音频/输入启动独立：尚未开始或暂停时也可显示静态琴键，不会申请权限或开启声音。Dock可见时让位，安全输入、锁屏/睡眠时隐藏，并在菜单说明等待原因；恢复画面不会恢复已暂停的声音或监听。未保存自定义时使用新演奏键位（G=C4）；旧映射仅保留历史contract，不再提供运行时选择。

## 高度与水晶外观

♪菜单“钢琴高度”滑块为50%—180%，100%主体112pt；上方144pt透明留白固定，总高200—345.6pt。宽度仍自动适屏、底边固定。拖动实时预览，整数百分比持久化，250ms空闲后保存；关闭菜单及退出前补存。旧偏好缺高度或字段非数值时使用100%，有限越界钳制，其余偏好保留。

缩放只重算键面、按压位移和命中轮廓，文字字号不变；不重启输入/声音，不清空按住键，不改变音量或自定义映射。保存失败保留内存设置并在菜单提示“设置尚未保存”；退出前仍失败时可取消退出重试，或明确仍然退出。取消不会先停声音或恢复本次拥有的系统提示音设置。

♪菜单“琴键透明度”滑块为0%—100%，默认15%，实时更新、按整数百分比保存，与高度共用250ms防抖及菜单关闭/退出补存。0%材质不透明，100%键面、底座、边缘、高光和投影全消失；标签和浮音不受此设置影响，Dock仍控制整个窗口淡变。系统“减少透明度”开启时覆盖为实色并禁用滑块，菜单显示原因；原设置保留，系统选项关闭后恢复。旧偏好缺失或无效值默认15%，有限越界钳制。

材质按U-031配色逐键绘制：薄透明底座，白键乳白、黑键纯黑主体及局部窄高光，白浅灰/黑深灰标签。白键会扣除已按压黑键轮廓，避免透明黑键下叠满白色。减少透明度时仅键面实色，透明留白不填实；减少动态时音符原地200ms淡出。正常♪为950ms、上升100pt、横漂最多8pt，字形与halo在左右边界内收束。效果参考Liquid Glass，不使用系统原生折射，不读取桌面或申请屏幕录制权限。

本版少量离屏预览可用候选可执行文件的`--crystal-snapshot <新目录>`生成7张图及9组布局/72条轨迹指标；它不会打开App GUI、监听键盘或输出声音。白/暗/彩色为合成背景，不能代替实际桌面效果验收。

## 自定义键位

从♪菜单打开“自定义键位…”。实体键和音高下拉框只列出现有64键与A1—C7（MIDI33—96），C4为中央C。选择音高立即在草稿交换占用该音高的两个键；累计列表列出保存后的全部变化。可连续修改，取消/关闭全部丢弃；“恢复新表默认”也需保存才生效。

保存先校验并原子写入`~/Library/Application Support/local.typingpiano.trial/custom-keymap.json`，成功后同时替换标签与声音映射。保存清理旧声部、按键/动画和旧输入队列，保留运行/暂停、声音开关、音量和显示意图，不重新申请权限。捕获层记录的松键状态用于切换边界，避免已排队的释放被丢弃后误吞下一次按下。保存失败保留当前运行映射及可重试草稿。

缺少配置使用新表默认；损坏/不兼容配置保留原文件、明确提示并回退新默认，之后显式保存修复时备份原始损坏内容。旧映射不打入运行包，不提供旧表预设入口。此配置只有用户选定的键位设置，不记录真实输入序列。

## 音量与音库

新偏好默认50%，完整音库对应mixer0.375；最大100%为0.75，sampler增益+12dB。已有偏好会继续加载。0%清尾并抑制新音，不停止输入/动画；调高不重播旧音。完整音库覆盖MIDI33—96；64音velocity127和弦的既有离线峰值约0.699767（约3.10dB余量），不代表所有设备、演奏序列或长期听感均已验证。Float32片段和90组测量见 [音频校准证据](../docs/evidence/C-002T/audio-calibration/)。

测试子菜单还保留原创合成64音和Kawai10音/Steinway11音候选。部分候选缺音保持无声；换库会停止旧监听和声音，需重新开始。当前完整音库为单层mono16试用资源，音色仍可调整。

## Dock与边界

GUI启动会默认启用**系统原生Dock自动隐藏**，不再使用模拟开关。关闭前提示与钢琴重叠风险；取消不写入。App仅恢复本会话拥有且仍可核对的改动：若启动时系统已为true，不会退出后恢复成更早的false；发现外部不同值时不覆盖。未决/崩溃恢复票据须明确处理。

原生后端通过 `dlsym` 检测HIServices的 `CoreDockGetAutoHideEnabled` / `CoreDockSetAutoHideEnabled`，只操作autohide。它们是**私有SPI**，本机实测即时生效不构成其他macOS版本的兼容保证。缺失、无效读回或写后核对失败会明确报错，可用菜单“系统Dock设置…”直接调整；没有defaults-only假成功、Dock重启、Apple Events或新增权限的自动回退。

钢琴自动使用目标屏幕完整宽度减16pt，左右各留8pt、底缘贴屏幕，默认总高256pt（112pt琴键主体＋144pt透明效果区，白键面100pt、黑键面64pt）。默认仍选内置屏优先的一条钢琴，不跟随鼠标跨屏跳，日常不再选900/1000/1100宽度。

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
export TYPING_PIANO_BUILD_ROOT="$(mktemp -d "$HOME/Library/Caches/typing-piano-builds/candidate-0.2.11.XXXXXX")"
bash Code/Scripts/build.sh
codesign --verify --strict "$TYPING_PIANO_BUILD_ROOT/打字钢琴试用.app"
"$TYPING_PIANO_BUILD_ROOT/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe" --self-check
"$TYPING_PIANO_BUILD_ROOT/打字钢琴试用.app/Contents/MacOS/TypingPianoProbe" --menu-smoke
```

输出为该目录下的 `打字钢琴试用.app` 和同名ZIP；脚本验证冻结资源哈希，进行本地ad-hoc签名并检查签名。可通过 `TYPING_PIANO_SIGN_IDENTITY` 由调用方指定签名身份（缺省为 `-`）；脚本不硬编码证书，也不输出签名身份或证书错误详情。上述自检不启键盘监听或硬件声音，菜单smoke不安装真实状态项。**此构建入口不等于发布入口：同Bundle ID的ad-hoc候选不可直接作为正式更新，也不要双击、open或调用lsregister登记/启动。** 仅在下述发布签名校验通过后，由负责人将最终包放回固定安装路径再启动。

## 固定发布签名与升级

使用 [release_sign.py](Scripts/release_sign.py)，显式提供所选证书的40位SHA-1指纹（`--identity` 或 `TYPING_PIANO_RELEASE_IDENTITY`）。可在本机 `security find-identity -v -p codesigning` 查看并由发布负责人选定原发布身份；不能自动选第一项。指纹是精确身份选择器，不是私钥。证书、私钥和包含本机身份的配置不要提交到仓库。verify-only不需要私钥，签署新副本时必须在钥匙串中有该有效签名身份。

发布校验检查Info.plist和签名中的Bundle ID均为`local.typingpiano.trial`、非ad-hoc、证书指纹、deep/strict/全部架构签名，以及与显式指定上一公开包的designated requirement逐字一致。身份缺失、不可用或任一检查失败即非零退出；不换证书、不回退ad-hoc。上一公开包应来自可信发布归档，不能拿待发布包自身冒充升级基线。签名模式允许源候选为ad-hoc，但新副本必须通过全部发布校验。它是发布前检查工具，不会上传或创建Release。

```sh
# 三个路径和身份均由发布负责人显式配置，不使用仓库内的本机身份默认值。
python3 Code/Scripts/release_sign.py --verify-only \
  --app "$RELEASE_APP" --previous "$PREVIOUS_PUBLIC_APP" \
  --identity "$TYPING_PIANO_RELEASE_IDENTITY"

# 只签署新副本；输出须为尚不存在的.app，父目录须已存在。
python3 Code/Scripts/release_sign.py \
  --app "$UNSIGNED_OR_CANDIDATE_APP" --previous "$PREVIOUS_PUBLIC_APP" \
  --identity "$TYPING_PIANO_RELEASE_IDENTITY" --output "$NEW_RELEASE_APP"
```

输入包始终只读；失败不会提交可通过校验的发布结果。复制收尾遇到文件系统错误时输出可能不完整，必须依据退出码停止发布，不能仅凭.app目录存在就继续。脚本不构建、不安装、不启动App、不调用LaunchServices注册或操作TCC。不要把默认构建的ad-hoc ZIP直接上传为正式更新，应从通过校验的最终签名副本重新打包并记录哈希。

同Bundle ID的临时副本会造成误启动风险：本机曾在添加权限后由系统重新打开ad-hoc候选，而非固定安装包。权限开关开启不代表当前进程来自正确路径。临时候选宜封存为ZIP并保留哈希；不要长期留下可误启动的同名.app。若将来需要并行GUI开发包，应另行设计独立身份/名称，当前生产包不因此改动。发布负责人需核对实际进程路径，并只在最终签名后启动固定安装位置的App。

每次更新二进制仍须重新签名；固定身份、Bundle ID、designated requirement和安装路径旨在保持身份连续性，但**不保证macOS永不提示授权**。0.2.6/0.2.7签名检查通过不等于真实跨版本TCC继承已经验证。首次从ad-hoc迁移、用户删除权限记录或系统策略变化仍可能需要用户确认。

未指定环境变量时，现有脚本默认输出到 `$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.11`。该默认目录重复构建会被更新，所以推荐上面的唯一目录命令。脚本明确拒绝输出到 `$HOME/Library/Caches/local.typingpiano.trial` 根目录，这是已有授权安装的保护规则，不是建议绕过的构建错误。已使用/授权的候选目录也不应再拿来构建。

可选的无窗口回归组（先完成上述构建环境变量设置）：

```sh
swift test --build-system native --package-path Code \
  --scratch-path "$TYPING_PIANO_BUILD_ROOT/tests-swiftpm" \
  --filter 'PianoCoreTests|NativeDockStorageTests|DockWindowVisibilityTests|AdaptiveOverlayTests|DockAdapterTests|SingleInstanceTests|RuntimeDiagnosticsTests|LocalTrialStartTests|AudioSelectionTests|MenuIntegrationTests|PianoMacTests.IntegrationTests|StartupEntryTests|AlertVolumeTests'
```

0.2.6的89项旧回归记录保留于 [历史交接](../docs/evidence/trial-0.2.6/HANDOFF.md)，不可代替本版验证；本版结果记录在 `docs/evidence/trial-0.2.11/`。系统Dock和提示音后端使用mock，不操作真实系统设置。无过滤完整测试包括真实AppKit窗口和离线音频：TrialBankTests写独立临时目录并清理；CandidateBankTests默认明确跳过3项，需显式新输出目录并预检才执行，不再覆写历史证据。`--build-system native` 在已验证工具链上会产生弃用提示，当前脚本仍使用它；其他工具链需自行验证，不能据编译目标宣称兼容。

完整音库、参数、许可与来源记录打入 `AudioTrial`，原始/中间WAV不打入App；`runtime-bundle-inventory.json`列出实际打包文件。资源与源码改变后应重新验证，不只汇总旧报告。当前实现与验收索引见 [IMPLEMENTATION.md](IMPLEMENTATION.md)。
