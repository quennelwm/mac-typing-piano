# PERF-034 窗口查询只读探针

结论：自然隐藏状态下，两条窄查询候选都有CPU/wall收益；目前没有可见状态/过渡证据，不能证明完整等价。保留为下一性能版本研究，不改0.2.11冻结工程或当前运行状态。纯Swift方案成本略高于ID列表，但无需C桥和双阶段快照，值得优先验证其显示态语义。

## 接口核对

先读本机 Xcode macOS SDK 的 CoreGraphics/CGWindow.h 和 CoreFoundation/CFArray.h，摘录见 `sdk-header-excerpts.txt`。Apple文档：[CGWindowListCreate](https://developer.apple.com/documentation/coregraphics/cgwindowlistcreate)、[kCGWindowIsOnscreen](https://developer.apple.com/documentation/coregraphics/kcgwindowisonscreen)。CGWindow.h 明确 `CGWindowListCreate` 返回CGWindowID值数组且标记 `CF_SWIFT_UNAVAILABLE`；字典接口与ID列表不能混用CFNumber假设。`kCGWindowIsOnscreen` 缺省表示offscreen，nil列表与空列表有不同含义。

ID候选用小C桥调用公开C API。全列表中的元素保持opaque token，不转NSNumber、不unsafeBitCast、不把token当指针解引用。用CFArrayGetValueAtIndex取token，CFArrayCreate以NULL callbacks装成单元素数组，再由官方CreateDescriptionFromArray确认该token对应目标Dock ID。后续用CFArrayContainsValue检查onscreen列表，命中才取单窗口描述并在Swift验证PID/layer/bounds/alpha；未命中为hidden。内存由CFRelease/CF_RETURNS_RETAINED管理。

首次直接用including选项构造singleton得到0元素；初版合并前置检查退出，未生成性能数据（`initial-attempt.txt`）。拆分检查后确认不是无Dock候选，是reference count=0（`reference-including-unknown.json`）。改为从all-ID列表取得、用字典验证的opaque token，不推测内部存储。

## 方法与数据

macOS27.2(26B123)/arm64，编译器版本见environment.json。目标沿现有逻辑：内建显示器、唯一全屏bounds/layer20 Dock窗口，Dock PID1339/window49，orientation bottom。没有模拟鼠标、发键、App启停或设置写入。编译及测量产物只在本目录。其他进程窗口标题/内容未记录。

第二轮于2026-10-29 17:47:10–17:47:43 +08运行100/200次成对查询；每次切换候选顺序，轮间100ms等待，CPU/wall只计查询调用、不计等待。CPU使用CLOCK_PROCESS_CPUTIME_ID，wall使用systemUptime。结果为本机非受控观察，包含WindowServer其他负载影响。

| 轮数 | 查询 | CPU均值 ms | CPU p95 ms | wall均值 ms | wall p95 ms |
|---|---|---:|---:|---:|---:|
| 100 | 全屏字典→筛目标 | 0.695 | 1.197 | 2.751 | 6.606 |
| 100 | ID列表→命中才取目标描述 | 0.152 | 0.249 | 1.153 | 4.804 |
| 100 | 单窗口字典（空数组→hidden候选规则） | 0.214 | 0.475 | 1.470 | 4.964 |
| 200 | 全屏字典→筛目标 | 0.582 | 1.209 | 2.152 | 5.545 |
| 200 | ID列表→命中才取目标描述 | 0.121 | 0.257 | 0.851 | 4.036 |
| 200 | 单窗口字典（空数组→hidden候选规则） | 0.160 | 0.424 | 1.106 | 4.551 |

第二轮300/300状态均为hidden/hidden，两候选都0不一致。相对本轮全字典查询，ID方案CPU均值减少78.1%/79.2%；单窗口方案减少69.2%/72.5%。这是单次API路径开销减少，不是整个App CPU减少同样百分比。按10次/秒简单换算，只约减少0.42–0.54个单核CPU百分点；未计周期重发现和其他App工作，不能承诺常驻总CPU达到某值。

首轮17:44:38–17:45:11，ID方案100/200次CPU均值0.109/0.140ms，对照0.590/0.724ms，状态同样300/300 hidden一致。原始结果保存在 `strict-including-result.json`。首轮纯Swift实现要求一条可验证字典，在hidden时返回unknown，故出现300次不一致；这暴露候选空数组规则缺失，而非证明API失效。第二轮显式区分nil→unknown、空数组→hidden；该空数组规则只在自然隐藏态验证。

`including-diagnostic.json`确认：同一隐藏窗口在all字典查询中存在，alpha=1、isOnscreen缺省；including-only返回空数组，onScreenOnly也无该窗口。因此不能只看alpha判断显示，也不能要求隐藏时必有单字典来读取isOnscreen。

## 验证边界与建议

- **hidden：PASS（当前主机/底部Dock/目标屏幕）**。ID方案两轮共600次与对照一致；修正空数组规则后的纯Swift方案300次一致。
- **visible、显隐过渡、侧边Dock、多屏切换、Dock重启/ID复用：UNKNOWN**，没有自然采到，不请求或制造用户动作。
- ID方案的命中→description热路径在本窗口没有运行，因为全部hidden。缓存singleton的初始化确实取得并验证过目标字典，但不能以此冒充visible性能/正确性。
- ID方案是两次IPC快照：membership后Dock可能变化，跟踪验证只能防身份/几何错误，不能使两个查询原子化。任何同状态观察都不能证明过渡一致。
- opaque-token查找初始化本轮CPU8.560ms/wall46.066ms（首轮10.169/38.862ms），未计入热路径。若每2秒重做，会吃掉大部分CPU节省；若未来使用C桥必须按Dock PID+windowID+屏幕绑定有限缓存，身份变更失效，不为追求基准削弱校验。
- `.optionIncludingWindow`单查询在本次更简单且更快于全字典。建议下一版本优先继续其自然visible/过渡观察，验证返回目标id、PID/layer/bounds、isOnscreen和alpha；nil维持unknown，异常字段不能静默当有效visible。未获这部分证据前，不改生产观察逻辑。
- 若后续显示态收益不足或语义不一致，明确保持原查询；不为benchmark改变实际Dock显隐行为。

源码、对象/可执行探针、哈希和命令分别见 `main.swift`、`QueryBridge.c/.h`、`environment.json`。首轮源码及环境另保留strict-including版本。没有运行测试、修改Code或当前发布包。
