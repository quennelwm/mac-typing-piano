# vcsl-steinway-b／A-001B 候选 SF2 QA

状态 candidate，版本 a001b-sf2-mono.0.1。仅静态/字节校验，真实音源加载与听感未测试。

- bank: trial.sf2，2649954 bytes；SHA-256 `8261dac642441fcf78a5946e96f898119ebd609227590c8638f148dea5b7f359`。
- 四根音 [34, 42, 60, 96]；覆盖 [33, 34, 35, 41, 42, 43, 59, 60, 61, 95, 96]，共11个音位。
- 故意未覆盖 [36, 37, 38, 39, 40, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]，不是完整64音包。
- 声道/位深：48kHz/mono/16-bit，由已交A-001立体声24-bit数学降混和量化，有损。
- SF2 preset/bank=0/0；Apple program/MSB/LSB=0/121/0待实载验证。
- 无循环，未校音；releaseVolEnv=-1200 timecents（编码500ms）。实际释放持续时间、默认modulator行为未测。
- 源PCM变换及峰值/误差详见 instrument-parameters.json；来源与原许可见 source_records.json、licenses/。
- 独立RIFF/SF2检查及源PCM比对：scripts/test_sf2_contract.py；证据在 docs/evidence/A-001B。
- 清单/哈希/源文件保护/重复生成：scripts/verify_delivery.py；本报告不是运行时通过凭证。

下一环节由代码对话加载本包，对覆盖音位和未覆盖音位分别测试，并测短按/1s/5s、释放、同音重击、panic与峰值。不能将C-001占位bank的成功结果迁移到本bank。未进行扬声器/耳机播放、系统设置改动或完整音源选择。
