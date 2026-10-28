# C-GH-026＋CR-005／0.2.6候选交接（CODE）

状态：实现及代码侧验证完成，待主对话复核、最终签名副本与GUI验收。2026-10-28。**本候选现已冻结，不再重建/重签；主对话可复制到独立路径进行最终Apple Development签名，另记发布哈希。**

## 实际产物

- App：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.6/打字钢琴试用.app`
- ZIP：`/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.6/打字钢琴试用.zip`
- Version0.2.6 / build9 / `local.typingpiano.trial` / arm64。
- Binary SHA-256：`a933d990c14b907f764a8bbb7530481968e4ccb74b780bcbccf8085a6fc07286`
- ZIP SHA-256：`5cd4234250c85e5d1dc9dfc33265d11e30b82768fae526d444f437f35f44e8b8`
- 当前为ad-hoc签名；没有使用用户开发证书，没有输出证书邮箱/私钥，没有Developer ID或公证声明。
- [delivery.json](delivery.json)、[source-hashes.json](source-hashes.json)、[changes.diff](changes.diff)、[changed-files.json](changed-files.json)绑定本次产物和增量。修改17个Code文件及本证据目录；未修改根README、需求/ADR、Design资源或Git。

## 最终行为

### 授权与重开

启动卡只有一个主操作“授权并开始”/“开始打字钢琴”，另有本地试弹、取消待办及准确的“退出App”。只有显式主按钮路径可调用CGRequestListenEventAccess，先保存本次待授权意图；同进程返回App时，必须满足预检已通过或已观察到系统设置真正激活后返回，且请求不在进行中，才消费一次。NSAppleScript提示音功能与输入授权入口独立。

请求中的嵌套激活不消费意图；如果返回已在请求过程中发生，请求结束后还会检查当前前台状态补接。没有timer轮询弹权限或背景启动。预检未通过、取消、安全输入与音频失败分别提示，失败后不循环开始。

**采纳P2审查后的保守调整：跨进程保存的是待办提醒，重开后必须再次点击主按钮。** 消费/安全输入/取消都先撤销内存续接，再清持久标记；磁盘清理失败后，后续激活绝不重新开始。即使磁盘残留true，新进程也没有自动续接资格。已有三个清理失败回归覆盖消费、安全输入和取消及随后存储恢复/进程重开。不能把本版说明为“任何情况下重启后自动继续”。

菜单“打开启动窗口…”、Finder reopen回调和重复启动通知都能重新显示入口；重复实例通知按现有PID定向，仅显示窗口，不直接启动输入或请求权限。菜单显示当前运行/暂停原因。普通激活/已暂停状态不会开始。“下载新版…”只打开`https://github.com/quennelwm/mac-typing-piano/releases`，没有下载器、执行器或自动安装器。

### 用户数据与签名

音量/标签迁至`~/Library/Application Support/local.typingpiano.trial/probe-preferences.json`。已有目标优先；没有目标时只读取**当前App旁**的旧偏好一次，缺失则保存默认值，原文件不修改。损坏数据报错，不静默覆盖。授权意图保存在同目录`authorization-start.json`，不含输入记录，不表示登录自动启动。Dock恢复票据仍使用当前App旁原路径，不迁移或接管旧副本数据。

因此第一次GUI验收应先明确最终安装路径及其旁边正确的旧偏好；若先打开空候选目录，会按缺失规则写默认值，之后这些新目标数据具有优先权。本次CODE没有启动候选GUI或进行真实用户目录迁移，迁移测试只使用临时目录。

构建脚本支持调用方提供`TYPING_PIANO_SIGN_IDENTITY`，缺省`-`；没有硬编码身份，也不把签名错误中的证书详情写入公共日志。本次明确传`-`构建。主对话此前报告的0.2.4/0.2.5开发签名DR一致属于其独立试验；0.2.6最终副本仍须由主签名、strict核验、记录DR/发布哈希及实测授权。开发签名不等于Developer ID公证。

### 静音系统提示音

按CR-005新增可选菜单与系统声音设置入口。启动不读写提示音；用户打开菜单时读取，确认开启才写alert volume=0，不碰键盘事件、钢琴引擎、媒体音量或系统总静音。当前进程NSAppleScript调用固定Standard Additions命令，不tell System Events、不用defaults、不申请额外Automation权限或走私有接口。

本会话原值保存在内存；关闭/正常退出核对仍为本App写入且验证过的0才恢复。外部不同值放弃所有权，不覆盖；原来已为0时不虚构恢复成50/100。写/读回失败显示失败或混合状态，读回不明不能伪报成功。退出恢复失败可取消退出重试，或明确仍然退出。

**崩溃/强制退出不保证恢复；新进程不自动恢复或接管旧会话。** 用户须在系统声音设置手动调整。同值外部写入及检查/写入竞态无法完全识别。写后未核验成功时，保留原值说明但不做未经确认的自动恢复。接口、权限判断与mock边界详见[ALERT-VOLUME-DECISION.md](ALERT-VOLUME-DECISION.md)。

### 图标

16pt槽与16×16pt画布保持，18pt基础♪按实际墨迹缩放，inset由0.5增至1pt。生产ProbeMenu的离屏PNG在[icon-snapshots](icon-snapshots/)。1x外边最大alpha为21/255（约0.08235），2x为0；1x仍有少量抗锯齿触边，未宣称所有外边像素完全透明或真实菜单已通过视觉验收。

## 本次验证

环境：macOS27.2 (26B123)、arm64、Apple Swift6.4；macOS14仅为编译目标。

- [tests.log](tests.log)：**89项、0失败**。原有64组＋StartupFlow10、PreferencesMigration4、StartupEntry2、AlertVolume9；已有音频启动失败测试补充输入/声音错误分类检查。系统后端均mock，重开窗口测试注入展示回调，不开真实窗口/监听。
- [build.log](build.log)：release构建、资源manifest核对、本地ad-hoc签名、ZIP生成成功。只有原有SwiftPM native backend弃用提示。
- [self-check.json](self-check.json)：64键映射/主题/资源通过，无全局监听、权限请求、硬件声音或系统写入。
- [menu-smoke.json](menu-smoke.json)：原生菜单/连续音量回调通过，请求槽宽16pt，模板图标及1x/2x生产绘制离屏测量；未安装真实状态栏项目，也未执行提示音脚本。
- [signature-check.log](signature-check.log) strict通过；[zip-check.log](zip-check.log)归档完整性通过。
- `tests-red.log`、`gate-red.log`、`cleanup-red.log`、`alert-red.log`保留相关新增接口尚未实现时的失败编译证据；`alert-initial-compile-failure.log`保留首次新增文件缺少import的编译失败，已修复；`build-pre-alert.log`/`menu-smoke-pre-alert.json`属于加入CR-005前的中间验证，不是最终发布包证据。最终以本段上述日志和delivery为准。

复现命令见`Code/README.md`。请为复现另建独立输出目录，不重建冻结candidate-0.2.6；默认ad-hoc即可跑无窗口组。真实系统音量、权限或GUI不属于该组。

## 运行中安装保护与未测项

任务开始与结束固定安装均0.2.4/build7。包内42个文件逐一SHA-256完全一致，二进制仍为`6edd694ea26998ffb0015c1301b4042ed5a22c4fa594611eee102dcb41222202`。证据：[开始快照](protected-install-before.json)、[结束快照](protected-install-after.json)。没有覆盖、退出、启动或重签当前运行包；没有改权限、真实Dock/提示音/媒体音量，没有Git操作。

仍待主对话：最终开发签名和DR核验；GUI首次授权、系统设置返回及退出重开后主动继续；暂停/重开窗口与重复实例；安装路径迁移；16pt实际菜单和图标；真实提示音仅alert改变、取消、关闭/退出恢复、外部改动、初始0及是否有额外权限提示；钢琴实按/声音/Dock仍正常。若提示音路径请求额外权限或不可用，应停止此功能验收并使用系统声音设置，不扩大权限。

其他Mac/系统、Intel、多屏/全屏、完整物理键矩阵和长期稳定性继续保持未验收。主对话维护根文档、最终安装包与GitHub发布。
