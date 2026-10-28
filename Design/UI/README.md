# U-001 界面候选交付

候选 `quiet-ivory-u001.0.3`，含 CR-001 菜单/标签选项、CR-002 小音符及 CR-003 音量滑块/♪图标；等待 PM-002，不是正式App。

- `preview.html`：双击用本机浏览器打开的离线审稿页，可切宽度、标签、按压状态、小音符、短按/重击/隐藏/减少动态效果，以及菜单和Dock关闭提醒。没有后台输入、音频或系统设置写入。
- `previews/overview@2x.png`：三宽度×三状态总览。
- `previews/floating-single.gif` / `floating-multi.gif`：700ms单键/多键效果，一次播放，最后空帧；`floating-labels-off.gif`、`floating-reduced.gif`补开关/降动效。
- `previews/floating-keyframes@2x.png`：0/100/350/700ms。
- `previews/menu-and-warning@2x.png`：菜单和提醒设计示意。
- `components/`、`theme.candidate.json`：可组合矢量、样式参数和资源哈希，图形不含文字。
- `UI_SPEC.md`、`MOTION_SPEC.md`、`QA_REPORT.md`：设计/动效/证据与未测边界。
- `SOURCE_AND_LICENSE.md`：来源与系统字体声明。

## 复现

在项目根目录执行，均只读映射、写Design/UI（无安装/下载/系统偏好修改）：

```sh
swift Design/UI/tools/native_render.swift "$PWD"
python3 Design/UI/tools/build_preview.py
python3 Design/UI/tools/make_gifs.py
node Design/UI/tools/check_timeline.cjs
node Design/UI/tools/check_preview_logic.cjs
python3 Design/UI/tools/validate_ui.py
python3 Design/UI/tools/write_manifest.py
```

环境：macOS 27.2 arm64 / Swift 6.4 / Node 24.15.0 / Python 3.12，使用现有Pillow。原生图像和字体检查来自本机CoreText，不需要启动生产App或获得额外权限。

本次自动浏览器打开本地file协议被工具安全策略拒绝，因此HTML的真实浏览器布局、交互、可访问性和绘制计时未验证；事件逻辑在Node中以DOM桩检验，不替代浏览器验收。不要将该审稿页当作产品主窗口。
