# C-001C 第一批原生快照可审阅

2026-10-28；代码集成。使用生产 PianoView 的 AppKit/CoreText 离屏渲染，无真实输入、硬件声音或系统 Dock 写入。

- native-snapshots/: 900/1000/1100pt × 标签开关 × 1x/2x，共12张；总高104pt（48透明效果区＋56主体）。
- animation-frames/: 1000pt、普通/减少动态 × 标签开关、0—720ms每20ms，共148张生产绘制逐帧PNG；frames.json记录时间/数量/位移/透明度。
- 组件路径、渐变、底沿、阴影、字体墨迹定位忠实转写 Design/UI/tools/native_render.swift 与 UI_SPEC/MOTION_SPEC；文字来源仍为统一keymap。
- XCTest: 192个标签几何/缺字验证＋生命周期(700/200ms、重复、隐藏清理)已通过；尚未实际屏幕可读性/输入延迟验收。
- 首批快照用于UI差异复核；集成、Dock、音源与完整回归仍继续中。

## 第二批更新

已按U-001B补齐36张新命名rest/single/multi场景，详见native-snapshots/captures.json。包含actualNativeMetrics（实际几何、CoreText墨迹和回退字体）、主题/映射/可执行文件hash、OS、倍率、标签与合成按键场景。第一批12张旧命名rest图保留追溯，新批次以captures.json索引为准。

动画目录更新为180帧，补充精确350ms与短按/回弹中重击14帧×2场景；frames.json为当前索引。短按模型已修复（短up不跳到全按下），行为RED/GREEN和实际自动Timer到期/隐藏清理测试通过。
