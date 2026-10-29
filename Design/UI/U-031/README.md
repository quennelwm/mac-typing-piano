# U-031 可调高度与轻透明水晶琴键

首批供代码接入：[reference.json](reference.json) / [材质配方](MATERIAL_RECIPE.md)。本批是程序化逐键矢量，不是系统原生Liquid Glass；不采集桌面。新默认映射及U-027/028不变。

## 有限预览

- [总览](previews/overview.png)：50/100/180%对应56/112/201.6pt真实主体，白浅灰/黑深灰标签。
- 三高度：[50%](previews/piano-1496-h50-rest@1x.png)、[100%](previews/piano-1496-h100-rest@1x.png)、[180%](previews/piano-1496-h180-rest@1x.png)。
- 模拟背景：[明](previews/background-light.png)、[暗](previews/background-dark.png)、[彩色](previews/background-color.png)。背景色确实透过单个键面，不是整窗降透明。
- 极值：[窄屏最矮](previews/piano-1264-h50-rest@1x.png)、[宽屏最高](previews/piano-1904-h180-rest@1x.png)、[50%边缘细节](previews/edge-detail-h50@2x.png)、[180%边缘细节](previews/edge-detail-h180@2x.png)。
- [475ms音符](previews/notes-normal-475ms.png)、[949ms](previews/notes-normal-949ms.png)、[950ms已结束](previews/notes-normal-950ms.png)；0ms及减少动态0/100/200ms文件同目录。
- [减少透明度退路](previews/reduced-transparency.png)。

## 复现与缓存

项目根执行以下命令；只做离屏设计渲染，不启动App或修改用户设置：

```sh
python3 Design/UI/U-031/tools/prepare_renderer.py
cat Design/UI/U-031/tools/drawing.swift.inc Design/UI/U-031/tools/render-tail.swift.inc > Design/UI/U-031/tools/render.swift
swift Design/UI/U-031/tools/render.swift /Users/wuming/Desktop/键盘钢琴
python3 Design/UI/U-031/tools/validate.py
```

可再生像素QA中间图默认输出`~/Library/Caches/local.typingpiano.ui/U-031/`，也可通过`TYPING_PIANO_UI_QA_CACHE`指定独立缓存；不纳入交付manifest。缓存不存在时先运行渲染命令即可重建。持久报告、布局、边界、alpha/对比度分组摘要在qa/。复跑不会把50张中间PNG写回交付目录。

真实菜单高度拖动/偏好保存、程序窗口层级/穿透、声音与输入保持、系统辅助功能联动和Dock行为由C-031及主对话验证；离屏素材不替代这些实机验收。
