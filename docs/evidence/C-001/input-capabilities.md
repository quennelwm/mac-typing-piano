# C-001 64键捕获能力表

映射 ansi64-draft.0.1。SDK常量可解析与真实硬件捕获是两个不同结论。下列全部 **未测试**；本轮未启动全局监听或模拟系统按键。测试员须在明确测试窗口逐键实按，按步骤在结果列填能力和证据，不能将该表初始值写回契约 captureStatus。

| ID | SDK候选 | MIDI | 计划语义 | 真实捕获 | 证据 |
|---|---|---:|---|---|---|
| grave | kVK_ANSI_Grave | 54 | ordinary | 未测试 | 无 |
| digit1 | kVK_ANSI_1 | 56 | ordinary | 未测试 | 无 |
| digit2 | kVK_ANSI_2 | 58 | ordinary | 未测试 | 无 |
| digit3 | kVK_ANSI_3 | 61 | ordinary | 未测试 | 无 |
| digit4 | kVK_ANSI_4 | 63 | ordinary | 未测试 | 无 |
| digit5 | kVK_ANSI_5 | 66 | ordinary | 未测试 | 无 |
| digit6 | kVK_ANSI_6 | 68 | ordinary | 未测试 | 无 |
| digit7 | kVK_ANSI_7 | 70 | ordinary | 未测试 | 无 |
| digit8 | kVK_ANSI_8 | 73 | ordinary | 未测试 | 无 |
| digit9 | kVK_ANSI_9 | 75 | ordinary | 未测试 | 无 |
| digit0 | kVK_ANSI_0 | 78 | ordinary | 未测试 | 无 |
| minus | kVK_ANSI_Minus | 80 | ordinary | 未测试 | 无 |
| equal | kVK_ANSI_Equal | 82 | ordinary | 未测试 | 无 |
| delete | kVK_Delete | 85 | ordinary | 未测试 | 无 |
| tab | kVK_Tab | 49 | ordinary | 未测试 | 无 |
| keyQ | kVK_ANSI_Q | 81 | ordinary | 未测试 | 无 |
| keyW | kVK_ANSI_W | 83 | ordinary | 未测试 | 无 |
| keyE | kVK_ANSI_E | 65 | ordinary | 未测试 | 无 |
| keyR | kVK_ANSI_R | 84 | ordinary | 未测试 | 无 |
| keyT | kVK_ANSI_T | 86 | ordinary | 未测试 | 无 |
| keyY | kVK_ANSI_Y | 88 | ordinary | 未测试 | 无 |
| keyU | kVK_ANSI_U | 71 | ordinary | 未测试 | 无 |
| keyI | kVK_ANSI_I | 64 | ordinary | 未测试 | 无 |
| keyO | kVK_ANSI_O | 69 | ordinary | 未测试 | 无 |
| keyP | kVK_ANSI_P | 89 | ordinary | 未测试 | 无 |
| bracketLeft | kVK_ANSI_LeftBracket | 33 | ordinary | 未测试 | 无 |
| bracketRight | kVK_ANSI_RightBracket | 35 | ordinary | 未测试 | 无 |
| backslash | kVK_ANSI_Backslash | 36 | ordinary | 未测试 | 无 |
| capsLock | kVK_CapsLock | 51 | toggleCandidate | 未测试 | 无 |
| keyA | kVK_ANSI_A | 55 | ordinary | 未测试 | 无 |
| keyS | kVK_ANSI_S | 52 | ordinary | 未测试 | 无 |
| keyD | kVK_ANSI_D | 50 | ordinary | 未测试 | 无 |
| keyF | kVK_ANSI_F | 48 | ordinary | 未测试 | 无 |
| keyG | kVK_ANSI_G | 59 | ordinary | 未测试 | 无 |
| keyH | kVK_ANSI_H | 62 | ordinary | 未测试 | 无 |
| keyJ | kVK_ANSI_J | 74 | ordinary | 未测试 | 无 |
| keyK | kVK_ANSI_K | 76 | ordinary | 未测试 | 无 |
| keyL | kVK_ANSI_L | 77 | ordinary | 未测试 | 无 |
| semicolon | kVK_ANSI_Semicolon | 38 | ordinary | 未测试 | 无 |
| quote | kVK_ANSI_Quote | 91 | ordinary | 未测试 | 无 |
| return | kVK_Return | 72 | ordinary | 未测试 | 无 |
| shiftLeft | kVK_Shift | 53 | modifier | 未测试 | 无 |
| keyZ | kVK_ANSI_Z | 40 | ordinary | 未测试 | 无 |
| keyX | kVK_ANSI_X | 41 | ordinary | 未测试 | 无 |
| keyC | kVK_ANSI_C | 43 | ordinary | 未测试 | 无 |
| keyV | kVK_ANSI_V | 45 | ordinary | 未测试 | 无 |
| keyB | kVK_ANSI_B | 47 | ordinary | 未测试 | 无 |
| keyN | kVK_ANSI_N | 57 | ordinary | 未测试 | 无 |
| keyM | kVK_ANSI_M | 79 | ordinary | 未测试 | 无 |
| comma | kVK_ANSI_Comma | 93 | ordinary | 未测试 | 无 |
| period | kVK_ANSI_Period | 95 | ordinary | 未测试 | 无 |
| slash | kVK_ANSI_Slash | 96 | ordinary | 未测试 | 无 |
| shiftRight | kVK_RightShift | 67 | modifier | 未测试 | 无 |
| fn | kVK_Function | 34 | modifier | 未测试 | 无 |
| controlLeft | kVK_Control | 37 | modifier | 未测试 | 无 |
| optionLeft | kVK_Option | 39 | modifier | 未测试 | 无 |
| commandLeft | kVK_Command | 42 | modifier | 未测试 | 无 |
| space | kVK_Space | 60 | ordinary | 未测试 | 无 |
| commandRight | kVK_RightCommand | 44 | modifier | 未测试 | 无 |
| optionRight | kVK_RightOption | 46 | modifier | 未测试 | 无 |
| arrowLeft | kVK_LeftArrow | 87 | ordinary | 未测试 | 无 |
| arrowDown | kVK_DownArrow | 90 | ordinary | 未测试 | 无 |
| arrowUp | kVK_UpArrow | 92 | ordinary | 未测试 | 无 |
| arrowRight | kVK_RightArrow | 94 | ordinary | 未测试 | 无 |

步骤：构建并由用户打开测试App → 检查权限只读状态 → 如已自行授予输入监控，点击“观察60秒” → 一次只测试一键按/松，观察瞬时图示与聚合数 → 停止。每键记录 full/pulseOnly/unavailable 及重复次数，不记录业务文本或逐键时间序列。

Fn：保留音位，flagsChanged + secondaryFn 仅为候选，不能补造事件。Caps Lock：仅候选短脉冲，锁定状态不代表持续手指按压。侧键：使用 IOLLEvent.h 中设备侧位；缺位时不得用总 Shift/Command/Option 位冒充。

组合手测：左Shift→右Shift→松左→松右（Option/Command同样）；Command保持+C/V；中文拼音/选词/删除；A长按>10s和自动重复；内置/外接分开。顶部键只在用户判断安全时测试，不自动触发电源/TouchID。
