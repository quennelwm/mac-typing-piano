# C-GH-026：候选音库冻结fixture失配修复

2026-10-29。状态：原因确认、最小测试修复与独立离线验证完成。仅修改`Code/Tests/PianoAudioTests/CandidateBankTests.swift`，另新增本证据/专用fixture目录；不改生产源码、Code/Scripts、历史证据或现有App/ZIP。没有Git操作、硬件声音、监听、权限或系统设置操作。

## 确定原因

默认CandidateBankTests使用`docs/evidence/C-001B/input-verification.json`，这是一份绑定当时源码的冻结验收记录，不是持续更新的测试fixture。它登记36项输入，其中33项仍一致，3项已改变：

| 输入 | 冻结字节数 | 本次修复前字节数 | 原因/证据 |
|---|---:|---:|---|
| verify_candidate_banks.py | 11825 | 11901 | 后来增加TYPING_PIANO_EVIDENCE_DIR输出目录支持；在内存撤销该改动后，SHA精确恢复为旧清单值 |
| CandidateBankTests.swift | 23211 | 23331 | 同样增加可配置输出目录；在内存撤销后SHA精确恢复为旧值 |
| SamplerAudio.swift | 9002 | 11881 | 音频实现已经迭代；当前SHA与0.2.5、0.2.6冻结源码记录均一致，本次未改 |

当前三项修复前的SHA都已出现在0.2.5源码快照，故失配早于0.2.6，不是新增授权/提示音功能引起。验证循环按清单顺序首先检查到验证脚本不符，三个测试都因此失败；在新目录复制旧快照后独立复现了同样的3项失败，未碰历史目录。详见[root-cause.json](root-cause.json)、[reproduction.log](reproduction.log)。

另一个风险是原测试默认输出仍指向历史证据目录，两个候选测试捕获异常后也会在那里写失败报告。此次没有修订/恢复任何历史记录，只保护任务开始时的实际文件。

## 最小修复

- 无显式`TYPING_PIANO_EVIDENCE_DIR`时，这3项需要生成离线证据的测试明确XCTSkip并给出预检说明，不再默认访问或写入历史证据。**跳过不是测量通过。**
- 显式指定冻结C-001B目录或其子目录（含解析后符号链接）时拒绝执行。
- setUp先严格验证当前快照，再允许测试运行；缺失/过期快照直接失败，连失败报告也不写入目标目录。
- 原有哈希、音库、估计器、覆盖、尾音及数值断言均未放宽。没有静默重绑旧结果、自动覆盖旧清单或修改音频生产实现。

新增[prepare_fixture_without_git.py](prepare_fixture_without_git.py)只用于本次及后续独立重测：原样调用现有preflight全部schema/路径/资源/源码哈希检查，仅将信息字段headAtPreflight的Git查询替换为明确的NOT_QUERIED值，以遵守本对话不执行Git操作的边界；这一差异在fresh-run/preflight-invocation.json记录，不伪造提交号。Code/Scripts原文件没有修改。

## 验证结果

- 新建fresh-run快照：36项当前输入绑定成功。
- [fresh-tests.log](fresh-tests.log)：3项实际执行、0失败；Kawai191项、Steinway193项数值检查通过，音高估计校准通过；全程manual offline，无硬件播放。
- [summary.log](summary.log)和[unchanged.log](unchanged.log)：新结果汇总通过、36项输入哈希未变；WAV及结果仅写本目录[fresh-run](fresh-run/)。
- [default-skip.log](default-skip.log)：无配置时明确跳过3项、0失败，不将skip算作音库验证成功。
- [frozen-rejected.log](frozen-rejected.log)：旧目录被明确拒绝；[stale-rejected.log](stale-rejected.log)：旧快照仍严格失败，且原目标文件哈希不变。二者的非零退出是预期的保护验证。
- [verification.json](verification.json)：生产源码/脚本、C-001B历史目录、任务开始时固定安装及冻结0.2.6候选受保护文件哈希未变；0.2.6 App/ZIP与原delivery一致。

本轮没有重跑/宣称整个无过滤套件通过；主对话继续负责89组及其他GUI/发布验收。冻结trial-0.2.6/source-hashes.json中的测试源码哈希属于冻结时版本，保留原样；这次独立的测试文件改动以本交接和新fixture哈希为准，不会进入已冻结的候选可执行文件。

## 独立复现

在仓库根执行（新目录必须为空，输入/验证源码在一轮期间不要改动）：

```sh
export TYPING_PIANO_EVIDENCE_DIR="$(mktemp -d "$PWD/docs/evidence/candidate-bank-rerun.XXXXXX")"
trial_test_scratch="$(mktemp -d "$HOME/Library/Caches/typing-piano-test.XXXXXX")"
python3 docs/evidence/C-GH-026-candidate-fixture/prepare_fixture_without_git.py "$TYPING_PIANO_EVIDENCE_DIR"
swift test --build-system native --package-path Code --scratch-path "$trial_test_scratch" --filter CandidateBankTests
python3 Code/Scripts/verify_candidate_banks.py summarize
python3 Code/Scripts/verify_candidate_banks.py unchanged
```

需要macOS、Swift工具链和既有jsonschema。普通全套测试不提供环境变量时会跳过此离线证据组；若要将其纳入全套，应先按以上步骤为新目录完成preflight，再去掉`--filter`，并另行核对其他测试的写入/GUI行为。不要照历史C-001B README直接覆盖旧记录。

本轮对冻结0.2.6二进制无影响，仍为`a933d990c14b907f764a8bbb7530481968e4ccb74b780bcbccf8085a6fc07286`；主对话最终开发签名副本按其自己的发布记录核验。
