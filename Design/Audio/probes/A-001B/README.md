# A-001B／四根音 SF2 试验包

交付状态：candidate，待主对话转交代码做 Apple 采样器实载。没有最终音色选择，没有正式64音覆盖。

**代码读取入口：`trial-index.json`。所有 bankFile/manifestFile/parametersFile 均相对这个文件所在目录。**

| 候选 | bank文件 | 大小 | 编码音区 |
|---|---|---:|---|
| Kawai | vcsl-kawai/trial.sf2 | 2,668,204 bytes | 33–34、41–43、59–61、95–96 |
| Steinway B | vcsl-steinway-b/trial.sf2 | 2,649,954 bytes | 33–35、41–43、59–61、95–96 |

合计5,318,158 bytes（5.072 MiB），小于20 MiB任务预算。两者均48kHz/mono/PCM16，由既有A-001立体声PCM24有损降混得到。仅作格式验证，不替换原试听。

SF2内 preset0/bank0；Apple首次试载使用program0、bankMSB121、bankLSB0。这些数值已在bank中编码/登记，但尚未针对这两份bank实际加载，不能据C-001另一个占位bank成功就改为ready。

releaseVolEnv=-1200 timecents（500ms编码值），sampleModes=0，无循环、无额外混响/chorus。实际释放时长、力度/滤波默认调制、重击及panic需代码验证。具体参数及每个样本的源文件哈希见各候选instrument-parameters.json。

建议后续检查：覆盖区每音非零且音高正确；区间外无声；按50ms/1s/5s并释放；同音重击；多音峰值与panic。当前keyV对应MIDI45不在试验覆盖内，不应直接用完整应用的64键或A-001全部试听事件作为“每音都应响”的断言。

复现见 processing_recipe.md。结构校验、源PCM逐字节比对、12个损坏/越界反例、清单/hash/许可证与复现证据在 `docs/evidence/A-001B/`；源码只写本probes目录。A-001的56份既有文件保持原样。
