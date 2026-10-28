# Mac 打字钢琴｜四对话开发包 v1.0

这是给吴铭与四个独立开发对话使用的规划和交接包，不是已完成的软件。

## 最快开始

将整个目录放入专用项目文件夹。先打开主对话，提供 `prompts/01_Main_Conversation.md` 和主文档；由主对话建立任务卡后，分别将 `02_Code_Conversation.md`、`03_Audio_Conversation.md`、`04_UI_Conversation.md` 提供给三个执行对话。

有共享仓库时按文件和提交交接；没有时上传文档并转发HANDOFF摘要。四个对话不会仅因文件存在就自动互相通信。

## 文件索引

| 路径 | 用途 |
|---|---|
| Mac_Typing_Piano_Development_v1.0.docx | 19页排版阅读版主文档 |
| docs/00_Master_Development.md | 完整背景、目标、需求、技术、资源、协作、阶段与验收 |
| docs/01_Interface_Contract.md | 输入/音符/标签/音频/UI之间的统一契约 |
| docs/02_Acceptance.md | 逐项验收表，初始全部未测试 |
| docs/03_Task_Board.md | 首轮到发布的任务与依赖 |
| docs/04_Decision_Log.md | 用户要求、工程建议、开放决策 |
| docs/05_Keymap_Reference.md | 全部64键的可读映射与灰色标签 |
| prompts/ | 四份可直接粘贴的独立启动说明 |
| contracts/ | 映射、UI参数、音频清单和JSON Schema |
| templates/ | 任务卡和交接报告模板 |
| AGENTS.md | 简短项目规则与文档索引 |

## 本版关键点

64音位（38白26黑）与MacBook下方五排对应；修饰键、空格发声；每个琴键自身底部默认有灰色实体按键标签，黑键也有；音效与UI资源独立制作，代码对话统一集成，主对话审批验收。

## 证据边界

已做的是文档与JSON契约/映射的静态核对，未做Mac实机输入/Dock/音频测试。映射是联调初稿，不是已经试听批准的最终映射。音效与UI清单是模板/设计参数，不包含实际采样或正式贴图。不要将template改成ready而不真正产出并验证文件。
