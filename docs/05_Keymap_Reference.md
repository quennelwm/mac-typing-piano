# 64 键映射参考｜联调初稿

版本：ansi64-draft.0.1。用于联调，不代表最终音乐映射已由用户试听批准。音域、数量、黑白分类及唯一性已作静态校验；所有 Mac 事件捕获状态仍为 unverified。

唯一机器来源：`contracts/keymap.ansi64.v0.1.json`。代码、音效和 UI 都使用 MIDI 33—96；中央 C＝C4＝60。

## 初稿安排原则

字母、字母区标点、左右 Shift、Return、Space 分配到白键；数字排及其余控制键分配到黑键。Space 暂放 C4，左 Shift 暂放 F3，右 Shift 暂放 G4，Return 暂放 C5。字母区标点主要位于音域两端。其余逐键分配是确定性的联调方案，不声称已经达到最佳听感。

UI 的左右侧别要用独立小角标绘制，而不是把长英文键名压入黑键。`displayLabel` 便于检查，实际绘制优先使用 `labelParts`。

## 第 1 排

| 实体键 | 稳定 ID | MIDI／音名 | 黑白 | 底部标签 |
|---|---|---|---|---|
| 反引号 | grave | 54／F#3 | 黑 | 反引号 ` |
| 1 | digit1 | 56／G#3 | 黑 | 1 |
| 2 | digit2 | 58／A#3 | 黑 | 2 |
| 3 | digit3 | 61／C#4 | 黑 | 3 |
| 4 | digit4 | 63／D#4 | 黑 | 4 |
| 5 | digit5 | 66／F#4 | 黑 | 5 |
| 6 | digit6 | 68／G#4 | 黑 | 6 |
| 7 | digit7 | 70／A#4 | 黑 | 7 |
| 8 | digit8 | 73／C#5 | 黑 | 8 |
| 9 | digit9 | 75／D#5 | 黑 | 9 |
| 0 | digit0 | 78／F#5 | 黑 | 0 |
| 减号 | minus | 80／G#5 | 黑 | - |
| 等号 | equal | 82／A#5 | 黑 | = |
| Delete／向后删除 | delete | 85／C#6 | 黑 | ⌫ |

## 第 2 排

| 实体键 | 稳定 ID | MIDI／音名 | 黑白 | 底部标签 |
|---|---|---|---|---|
| Tab | tab | 49／C#3 | 黑 | ⇥ |
| Q | keyQ | 81／A5 | 白 | Q |
| W | keyW | 83／B5 | 白 | W |
| E | keyE | 65／F4 | 白 | E |
| R | keyR | 84／C6 | 白 | R |
| T | keyT | 86／D6 | 白 | T |
| Y | keyY | 88／E6 | 白 | Y |
| U | keyU | 71／B4 | 白 | U |
| I | keyI | 64／E4 | 白 | I |
| O | keyO | 69／A4 | 白 | O |
| P | keyP | 89／F6 | 白 | P |
| 左方括号 | bracketLeft | 33／A1 | 白 | [ |
| 右方括号 | bracketRight | 35／B1 | 白 | ] |
| 反斜杠 | backslash | 36／C2 | 白 | 反斜杠 |

## 第 3 排

| 实体键 | 稳定 ID | MIDI／音名 | 黑白 | 底部标签 |
|---|---|---|---|---|
| Caps Lock | capsLock | 51／D#3 | 黑 | ⇪ |
| A | keyA | 55／G3 | 白 | A |
| S | keyS | 52／E3 | 白 | S |
| D | keyD | 50／D3 | 白 | D |
| F | keyF | 48／C3 | 白 | F |
| G | keyG | 59／B3 | 白 | G |
| H | keyH | 62／D4 | 白 | H |
| J | keyJ | 74／D5 | 白 | J |
| K | keyK | 76／E5 | 白 | K |
| L | keyL | 77／F5 | 白 | L |
| 分号 | semicolon | 38／D2 | 白 | ; |
| 单引号 | quote | 91／G6 | 白 | ' |
| Return | return | 72／C5 | 白 | ↵ |

## 第 4 排

| 实体键 | 稳定 ID | MIDI／音名 | 黑白 | 底部标签 |
|---|---|---|---|---|
| 左 Shift | shiftLeft | 53／F3 | 白 | ⇧L |
| Z | keyZ | 40／E2 | 白 | Z |
| X | keyX | 41／F2 | 白 | X |
| C | keyC | 43／G2 | 白 | C |
| V | keyV | 45／A2 | 白 | V |
| B | keyB | 47／B2 | 白 | B |
| N | keyN | 57／A3 | 白 | N |
| M | keyM | 79／G5 | 白 | M |
| 逗号 | comma | 93／A6 | 白 | , |
| 句点 | period | 95／B6 | 白 | . |
| 斜杠 | slash | 96／C7 | 白 | / |
| 右 Shift | shiftRight | 67／G4 | 白 | ⇧R |

## 第 5 排

| 实体键 | 稳定 ID | MIDI／音名 | 黑白 | 底部标签 |
|---|---|---|---|---|
| Fn／地球键 | fn | 34／A#1 | 黑 | fn |
| 左 Control | controlLeft | 37／C#2 | 黑 | ⌃ |
| 左 Option | optionLeft | 39／D#2 | 黑 | ⌥L |
| 左 Command | commandLeft | 42／F#2 | 黑 | ⌘L |
| 空格 | space | 60／C4 | 白 | ␣ |
| 右 Command | commandRight | 44／G#2 | 黑 | ⌘R |
| 右 Option | optionRight | 46／A#2 | 黑 | ⌥R |
| 左方向 | arrowLeft | 87／D#6 | 黑 | ← |
| 下方向 | arrowDown | 90／F#6 | 黑 | ↓ |
| 上方向 | arrowUp | 92／G#6 | 黑 | ↑ |
| 右方向 | arrowRight | 94／A#6 | 黑 | → |

## SDK 与实测边界

sdkConstantCandidate 是供代码对话在本机 SDK 查验的符号名，不是已验证的数值键码表。尤其修饰键、Fn 与 Caps Lock，必须验证事件形态后决定捕获策略。不要仅按总 flags 值判断左右键。

任何音乐映射调整需更新 mappingVersion；修改后重新校验 64 个实体 ID、64 个独立 MIDI、38白26黑、标签非空，并让主对话批准。
