# U-027 预览入口

本批采用用户v0.2新映射，按主对话暂定默认；旧表可切回的生产菜单由C-027实现。本目录只做设计输出。

- [三宽总览](previews/overview@1x.png)：三行均以各自实际逻辑尺寸绘制，查看器可能缩放。
- [当前1512pt屏幕：1496pt琴键主体](previews/piano-1496-rest@1x.png)：112pt本体。
- [100ms关键帧](previews/floating-1496-normal-100ms@2x.png) / [450ms关键帧](previews/floating-1496-normal-450ms@2x.png) / [900ms清空](previews/floating-1496-normal-900ms@2x.png)。透明图像总高208pt。
- [单次漂浮短预览](previews/floating-1496-once.gif)：24pt音符900ms生命周期，容器920ms含20ms空白末帧；不循环。键面180ms离散回位仅示意，不代表45/100ms按压动画已验证。
- [规范](SPEC.md)、[参数](parameters.json)、[显式ID对照](id-translation.json)、[原生坐标](qa/layouts.json)、[验证结果](qa/validation.json)、[完整轨迹包络](qa/continuous-lifecycle.json)。

previews含36张主体图（3宽×3状态×标签开关×1x/2x）及42张漂浮关键帧（3宽×普通4帧/减少动态3帧×1x/2x）。宽度1264/1496/1904对应屏幕1280/1512/1920、左右8pt。整条PNG/GIF仅审稿，运行时应分别绘制键面、标签和音符。

在项目根重现（仅写本目录、不启动App）：

```sh
python3 Design/UI/U-027/tools/prepare.py
cat Design/UI/U-027/tools/drawing.swift.inc Design/UI/U-027/tools/render-tail.swift.inc > Design/UI/U-027/tools/render.swift
swift Design/UI/U-027/tools/render.swift /Users/wuming/Desktop/键盘钢琴
python3 Design/UI/U-027/tools/validate.py
```

macOS AppKit/CoreText + Pillow；系统字体仅运行时引用。未验证产品的鼠标穿透/焦点/显示开关修复、真实定时器或硬件输入；这些由代码线和主对话补证。
