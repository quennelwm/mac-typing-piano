# 交接：C-031／0.2.8 build11 高度滑块与水晶键面

## 结论
已完成待PM-031接收。生产源码已冻结，独立arm64候选构建和有限离屏验证完成。基线按任务卡8142d59；没有Git操作。C-031/CR-008/ADR-025与已批准U-031 u031.1为本次范围。

当前已授权0.2.7及公开签名包未改，未启动ad-hoc App GUI、安装替换、停止当前App或操作TCC/系统设置。测试中的AppKit临时窗口、模拟输入/声音、离线真实采样器与生产GUI验收分开记录。

## 实现与变更范围
- AppPreferences新增heightScale，默认1；缺字段、非数值回退1，有限越界钳制0.5—1.8，按整数百分比保存。volume/labels一并读写保留。未改自定义键位文件、映射契约或音源。
- ♪菜单真实NSSlider显示“钢琴高度”和百分比。实时更新主体几何，250ms空闲保存，关闭菜单/退出前补存。144pt留白独立，总高200/256/345.6pt，宽减16pt、底边固定。
- resize保留键按下/释放、动画pressID与鼠标释放归属、音频/输入模式、音量和自定义映射；字体不拉伸，按压位移随高度缩放。
- U-031水晶：逐键矢量alpha、薄透明底座、细边高光、轻边缘投影；白键可见面扣除已按压黑键的圆角路径。白浅灰#969FA9/0.86、黑深灰#414B55/0.84，独立文字层。
- 24pt♪，减速上升100pt/右漂最多8pt/950ms结束；减少动态原地200ms；字形与4pt halo按左右画布夹紧。减少透明度只使键面实色，留白仍透明，不修改系统辅助设置。
- 渲染、白键镂空和命中共用变换后的圆角路径，黑键优先；180%按住黑键后，新增2.7pt键面下沿点击不会误命中白键。
- 所有设置保存失败统一preferencesDirty、提示“设置尚未保存”；关闭菜单/退出重试。applicationShouldTerminate先保存，仍失败可取消或明确退出；取消前不会恢复系统提示音或清理运行状态，WillTerminate仅最终安全补存/清理。正常成功无新增弹窗。
- 构建默认candidate-0.2.8/build11，保护candidate-0.2.7等旧路径；资源加入已批准reference/recipe并固定reference SHA。C-030发布签名脚本保持原样，开发候选不冒充正式更新。

具体差异见changes.diff、changed-files.json；Code/README与IMPLEMENTATION更新当前参数。没有修改Design/主docs/历史证据。

## 验证与证据
环境见environment.json（本机macOS27.2/arm64、Swift6.4；macOS14仅编译目标）。

- **完整套件141项：138通过、3条件音库测试明确跳过、0失败**：full-tests-release-source.log。3项CandidateBankTests本次未重放；没有覆写旧音库证据。其余离线音频测试实际执行，临时校准目录自动清理。
- HeightPreferencesTests：旧JSON、坏类型/null、有限越界、NaN/Inf setter、round-trip及其他字段保留。
- HeightIntegrationTests：实际滑块action与百分比；运行/静音/暂停＋自定义映射下resize；按住G跨高度释放为原音；250ms保存、失败保留内存、退出补存、重开恢复；仅volume/labels失败也dirty；取消退出保持模拟输入/引擎/按住键及mock提示音0，不先恢复。
- CrystalRenderingTests：50/100/180%实际RGBA键面，rest/全按/实色退路；白面镂空不会在黑键下累积白色；透明区alpha0；按压边界/圆角命中。900/1000/1264/1496/1904宽、全部64音符与halo均在边界内。
- 原静态显示、floating层真实窗口排序、Dock模拟淡出、独立系统阻断、映射保存释放竞态继续回归。
- release候选仅执行self-check、menu-smoke、crystal-snapshot。`native/report.json`包含9布局/72轨迹采样；950ms清理，减少动态退路已清理，无裁剪。只输出7张PNG，不导出旧大量动画序列。
- 普通报告含标签；50%白键85%高度采样可能落到浅色文字，alpha最高0.97647仍小于1。纯键面无标签的独立测试均小于0.94；黑键中心小于0.94，证明没有旧白色底层。实色退路键面alpha1；头部透明。没有把含字样本误当纯材质采样。
- 已目视查看dark、color-pressed-475ms、180%生产图，标签/侧标及漂浮未见裁切；7图均核对像素尺寸。它们是程序化合成背景，不是桌面截图，也不是系统原生Liquid Glass折射。

早期height-red.log为新接口未实现的编译失败；height-green.log记录初次仅common-mode未按期落盘的失败，改为scheduledTimer并加入common-mode后通过。full-tests-before-review-fixes.log保留旧轨迹断言仍用900ms/48pt的失败；最终断言按950ms/100pt更新。编译期间发现重复ShouldTerminate声明，已合并到原提示音恢复路径，最后141项实际执行通过，不以这些中间日志计通过。

## 有限预览
- native/crystal-50.png、crystal-100.png、crystal-180.png：透明RGBA，2x；逻辑高200/256/345.6pt（像素高400/512/692）。
- native/crystal-white.png、crystal-dark.png：合成白/暗背景。
- native/crystal-color-pressed-475ms.png：合成彩色背景、三键按压及475ms♪。
- native/crystal-reduced-transparency.png：键面实色、透明留白。

## 复现
从仓库根目录运行，测试不使用真实输入/音频输出/系统偏好后端：
```sh
swift test --build-system native --package-path Code --scratch-path "$HOME/Library/Caches/local.typingpiano.trial/candidate-0.2.8/swiftpm"
```
候选可执行文件支持`--self-check`、`--menu-smoke`、`--crystal-snapshot <新目录>`。只直接调用这些明确分支，不用open、不双击、不注册LaunchServices，不运行普通GUI模式。最终包校验可复跑本目录verify_delivery.py；主签名/安装后旧包完整性检查自然不再代表未动的0.2.7，按阶段分别记录。

## 已知限制与请求主接收
本次没有实机菜单拖动、真实桌面透明效果/动态辅助开关、跨显示器/全屏、物理输入/声音或升级TCC保留结论。当前源码是macOS14+可用的手工矢量alpha，不声称原生Liquid Glass。低存在感标签按用户方向实现，不宣称4.5:1无障碍对比度。

主对话下一步：按source-hashes.json完成独立回归；使用固定身份对新副本签名并对0.2.7检查DR；封存ad-hoc候选后才更新固定安装路径并真实验收。不要把本次ad-hoc ZIP直接作为最终公开包，也不要沿用其哈希标记之后的已签名包。

## 最终冻结产物

- App：/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.8/打字钢琴试用.app
- ZIP：/Users/wuming/Library/Caches/local.typingpiano.trial/candidate-0.2.8/打字钢琴试用.zip
- binary SHA256：`f8cb2d89c3842cab6fbaa01c51b0a06b9387e3fe7e1e8a829bf5df9db95f43f2`
- ZIP SHA256：`7597e7ae3485974ced30887903ab4ebd45df1a40caedb007a3f296216a40d7be`
- source-hashes.json SHA256：`c81565ff0f063507f6caba771d962fc9f6c3c9c21c031a75efc1ea6fbbcc68b7`
- 88项源/配方清单复核，217个受保护文件字节未变；strict ad-hoc与ZIP CRC/内含二进制一致性通过；AudioTrial资源与已安装0.2.7逐文件一致。详见delivery.json。
