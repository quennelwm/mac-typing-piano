# Mac 打字钢琴

在其他应用打字时，键盘触发钢琴音色，屏幕底部显示与按键对应的钢琴。日常控制集中在菜单栏 **♪**，不需要一直打开主窗口。

**当前协作测试版：0.2.6。** [下载可运行的Mac试用包](https://github.com/quennelwm/mac-typing-piano/releases/tag/v0.2.6-trial) · [安装和测试说明](docs/testing/Download-and-Test.md) · [反馈问题](https://github.com/quennelwm/mac-typing-piano/issues)

现成包面向Apple Silicon Mac。编译目标macOS14+，实机已验证macOS27.2；其他系统仍待测试。下载发布页中的 `Mac-Typing-Piano-0.2.6-arm64.zip`，无需编译。首次启动需要由测试者允许App运行和输入监控，具体步骤见测试说明。这个版本尚未经过Apple公证。

## 功能

- MacBook下方五排的64键，顶部整排包括Esc不参与，Fn保留。
- 64音Steinway候选采样、多音与自然尾音；每次击键有约700ms上升♪动画。
- 钢琴自动适应屏幕宽度，每个琴键底部的电脑按键标签可开关。
- ♪菜单内的音量滑块只控制本App。声音、标签和钢琴显示独立控制；“下载新版…”打开GitHub发布页。
- 使用系统原生Dock自动隐藏；Dock出现时钢琴渐隐，Dock收回后渐现。
- 可选“静音系统提示音”，缓解无输入框时系统警告声叠加，媒体与琴声音量不变。
- 不保存输入文字或按键历史；安全输入期间暂停，不增加触控板专属功能。

## 项目内容

| 目录 | 内容 |
|---|---|
| [Code](Code/) | Swift原生App、构建脚本与测试 |
| [Design/Audio](Design/Audio/) | 音源候选、全64音试用资源、原始采样、处理脚本及许可 |
| [Design/UI](Design/UI/) | 可组合视觉资源、动效规范和适配参考 |
| [contracts](contracts/) | 64键映射和资源接口 |
| [docs](docs/) | 产品方案、任务、决策、交接与验收记录 |
| [prompts](prompts/) / [templates](templates/) | 四对话协作说明和交接模板 |
| [试用版](试用版/) | 原开发机入口和现场试用记录；其他测试者请使用上面的发布包 |

源码构建和测试见 [Code/README.md](Code/README.md)。本仓库保留现有项目文件与Git历史；历史证据中的本机绝对路径、设备名和版本描述属于当时环境，不是其他测试者的安装路径。原始开发文档为导入快照，当前要求以最新Markdown和决策记录为准；[原开发包索引](docs/Development-Package-Index.md)。

## 当前验证范围

0.2.6包含16pt菜单栏、同进程授权返回续接、重开后主动继续和持久偏好。菜单与回归检查见 [0.2.6交接](docs/evidence/trial-0.2.6/HANDOFF.md) 和 [独立发布复核](docs/evidence/PM-GH-026/REVIEW.md)。此前0.2.4已完成本机输入监控授权、普通真实按键与音频输出、自适应宽度、底部Dock实际淡出/淡入，用户确认听到琴声；证据和边界见 [PM-004](docs/reviews/PM-004.md)。0.2.6采用固定Apple开发证书签名；从旧ad-hoc版本升级仍需核对权限。两个不同构建的签名要求一致性已验证，但尚未等同跨版本真实授权验收。旧版实按结果不代替新包实按验收。

Fn/Caps/左右修饰键完整实按、多屏/侧边Dock、其他macOS版本、真实声学延迟和最终音色仍待协作测试。Dock原生适配使用隔离的私有SPI，能力不可用时引导系统设置；这是试用版，不等于正式发布或全平台兼容。

## 来源与许可

钢琴采样来自Versilian Studios VCSL，保留原CC0-1.0许可、固定来源版本及处理记录；见 [音源来源](Design/Audio/trial/A-002T/source_inventory.md)。UI资源在本项目制作，系统字体文件未打包，见 [UI来源说明](Design/UI/SOURCE_AND_LICENSE.md)。当前未为项目自有代码与设计选择统一的开源许可证；第三方资源仍按各自声明处理。
