# C-034 closing investigation
已知现场：用户在0.2.10重复点击♪及外部点击均未关闭；属于FAIL，150项单测未覆盖真实tracking。
静态路径：NSStatusItem.menu直接绑定NSMenu，三个NSMenuItem.view承载连续NSSlider；无自定义鼠标钩子。menuWillOpen同步执行Standard Additions读取；运行时另有common-mode动画/诊断计时器。不存在显式关闭状态机，旧验证只检查构造及target-action。
限制：本任务不操作已安装App，未取得失败现场的主线程stack/事件序列；无法把同步读取或自定义view确认为唯一根因，精确运行时触发机制UNKNOWN。不能用原生绑定当通过。
修复选择：状态项按钮显式切换NSPopover(.transient)，无NSMenu根tracking；四滑条与胶囊开关在普通contentView中交互，系统项仍用原生子菜单。Esc在本App局部处理，关闭时统一补存。未新增全局鼠标监听/权限。
验证边界：程序化打开/关闭状态与控件回调可测；图标再次点击、外部点击和拖动必须主签名安装后实测。
