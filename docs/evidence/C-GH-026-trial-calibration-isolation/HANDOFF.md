# 交接：C-GH-026／历史校准输出隔离

## 结论
已完成待主对话验收。真实写入`C-002T/audio-calibration/calibration.json`及WAV的是`TrialBankTests.testTrialBankCalibrationCoverageAndLifecycle`；`TrialGainTests`的两项测试没有证据输出，未作修改。

## 实际产物与范围
仅修改`Code/Tests/PianoAudioTests/TrialBankTests.swift`及新增本目录证据。固定历史路径替换为系统临时目录下的随机UUID子目录，独占创建，XCTest teardown负责删除；删除失败会令测试失败。默认继续执行全部原有音频校准断言，没有新增skip，没有改音频数值检查或生产实现。无需配置环境变量，也没有新增允许覆盖任意历史路径的输出选项。

本次按主对话已恢复后的实际文件重新建立保护快照；没有替主对话再次恢复或修改任何历史证据。上次CandidateBankTests修复保持原样。未操作Git、运行中的App、真实监听/输出或系统设置，未重建/重签发布候选。

## 复现方法
在仓库根目录执行：

```sh
env -u TYPING_PIANO_EVIDENCE_DIR swift test --build-system native --package-path Code --scratch-path "$HOME/Library/Caches/typing-piano-verification/c-gh026-fixture" --filter 'TrialBankTests|TrialGainTests|CandidateBankTests'
```

## 测试证据
macOS 27.2 (26B123)、arm64、Apple Swift 6.4。见[tests.log](tests.log)、[verification.json](verification.json)、[test-change.diff](test-change.diff)。

- 选中6项：TrialBankTests 1项及TrialGainTests 2项实际通过，CandidateBankTests 3项按此前设计明确跳过；总计0失败。未将skip算作音库验证通过。
- 校准输出90行测量，最大峰值0.69976664；offline手动渲染，没有硬件播放。
- JSON/WAV写入日志所列独立临时目录；测试结束后外部检查确认目录已删除。
- 3829个受保护文件SHA256逐一与本轮开始时相同，包括生产源码/脚本、C-001B、C-002T历史校准、冻结0.2.6证据/候选目录及固定安装App。
- 对Code/Tests静态检查，未发现其他硬编码历史证据输出；CandidateBankTests保留显式新快照运行机制及冻结目录拒写保护。

## 已知限制与主对话处理
仅重跑相关6项，没有再次运行整个无过滤套件；主对话报告的89项独立回归与本次验证分开。临时JSON/WAV在正常测试teardown后删除，仅日志保留；若测试进程被强杀，临时目录可能遗留，但不会写回历史证据。

主对话可审阅这次追加的test-only差异，并与此前CandidateBankTests修复一起纳入源码提交。冻结0.2.6源码清单保持原样，不重写历史哈希，也不重建发布App。
