# Crystal Piano Implementation Plan

主角色PM-031；用户已直接指定功能与视觉方向，按项目四对话规则执行。基线8142d59。

**Goal:** 交付可调高度、更高漂浮和轻透明水晶琴键的0.2.8试用版本。
**Architecture:** 代码维护唯一Swift/AppKit工程；UI交程序化逐键材质参数；主维护CR/验收/固定签名安装。保留全部音频与键位状态。
**Tech Stack:** Swift、AppKit/CoreGraphics/CoreText、既有AVAudioUnitSampler、Python签名检查。

- [x] 读取现状、用户需求及Apple材质参考；明确CR-008、角色/路径和参数。
- [ ] U-031先交材质参数，再交三高度/背景预览，由主目视接收。
- [ ] C-031先覆盖旧JSON读取、比例边界与保存、运行中resize不影响输入/音频，再实现AppPreferences/AdaptiveOverlay/Geometry/ProbeMenu/ProbeController。
- [ ] C-031接入U-031到PianoView，FloatingNotes改100pt/8pt/950ms，144pt独立留白；检查减少透明度和减少动态。
- [ ] 主复核源变化，复跑相关测试与全套，核对少量生产原生预览、标签边界和透明像素证据。
- [ ] C-031冻结候选，主使用release_sign.py签署新副本、对0.2.7验证DR，封存ad-hoc后以固定路径正常更新。
- [ ] 主验收菜单滑块/高度保存与真实运行权限；不反复重签、重置TCC或混用候选GUI。
- [ ] 更新文档、源码和可下载试用包，公开下载校验通过再报告。

验证边界：离屏图不等于桌面透明效果；同DR不等于实测TCC继承。新生产二进制和运行实测独立记载。设计/生产对比只留必要图片，避免再次产生大量重复公开资产。
