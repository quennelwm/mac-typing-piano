# A-001 来源清单

取得日期：2026-10-28，Asia/Shanghai。两个候选均为 VCSL 发布的实际钢琴采样；未从商业软件提取音频，未下载 Salamander 或第三个候选。

## 可追溯版本与许可

- 上游：[sgossner/VCSL](https://github.com/sgossner/VCSL)。固定提交 `c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e`，提交日期 2026-01-14。
- 发布者/作者归属：Versilian Studios LLC；仓库维护者 Sam Gossner。没有把 Git 提交作者推定为每个录音的演奏者；具体录音人员未在本轮文件里另行证实。
- 许可：该提交的 [LICENSE](https://github.com/sgossner/VCSL/blob/c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e/LICENSE) 为 CC0-1.0；同提交 README 明确把许可用于声音素材和软件/媒体使用。已保存原文并随每候选复制，适用范围来自素材仓库本身，不是套用播放代码的许可。
- 原许可 SHA-256：`a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`。
- 原 README SHA-256：`6f7214a188f106c917d6503748485413c3e47cf56bce69f82beb9d16aa0894a9`。
- [官方 VCSL Keys 页面](https://versilian-studios.com/vcsl-keys/)另有 CC0 和这两类钢琴说明；本轮下载的是上述固定 Git 提交的 WAV，**不是**网页列出的整套 680 MB SFZ/FLAC 包。
- [CC0 说明](https://creativecommons.org/publicdomain/zero/1.0/)允许复制、修改和再分发；项目仍保存来源、许可和修改记录，且不暗示品牌或作者为本项目背书。正式发布接收由主对话处理。

## 两个候选

| 候选 | 固定提交中的目录 | 本轮有效根音 | 原格式 | 来源特征/限制 |
|---|---|---|---|---|
| VCSL Kawai | Chordophones/Zithers/Grand Piano, Kawai/Sustains | 33、42、60、96 | 44.1 kHz/16-bit/stereo | 目录自带 `Legacy.txt`，正文为 `LEGACY!`；不是最终音源推荐。源音名需按实测八度解释。 |
| VCSL Steinway B | Chordophones/Zithers/Grand Piano, Steinway B/NoSus | 34、42、60、96 | 44.1 kHz/24-bit/stereo | `NORMALIZED.txt` 明示 sustain/NoSus 已归一化；需力度曲线恢复动态。这里只用 vl2 单层，保留原说明。 |

`source_evidence/download-ledger.json` 是逐文件权威记录，包含不可变原 URL、目录、Git blob SHA-1、期望/实际长度、SHA-256 和本地相对路径。所有原始 WAV 完整下载，未把网络截断片段当作完整采样。下载账本同时保留八度诊断的额外 Kawai 文件；它们不计入候选有效覆盖。

本轮原始 WAV 和两份上游说明合计 **42,424,357 bytes（40.459 MiB）**。加上小型仓库树、提交、LICENSE、README 等文本证据仍低于 80 MiB；没有下载完整库或安装依赖。后续完整层的体积估算在 `proposed-zones.json`，尚未授权下载。

## 修改、署名与保留

原文件在各候选 `originals/` 原样保留。派生样本经过重采样、受控长度/尾部淡出、每候选公共增益；试听还有小范围移调、固定事件、释放包络及总线衰减。详见 `processing_recipe.md` 和 `qa_metrics.json`。

建议关于页文字（最终包接收后再集成）：

> Piano samples: Versilian Community Sample Library, Versilian Studios LLC, CC0 1.0. Selected and processed for Typing Piano. Source commit c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e.

原许可保存在每候选 `licenses/VCSL-CC0.txt`，README 保存在 `licenses/VCSL-README.md`。本轮只在 Design/Audio 内保存许可，不写正式 Resources 或项目根 Licenses。
