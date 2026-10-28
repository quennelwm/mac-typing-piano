# U-001B 原生联调对照

先读NATIVE_ADAPTER.md。reference.json含900/1000/1100pt的192个逐键坐标、文字锚点、静止/按下位置、配色、音符关键帧及来源hash；theme-field-policy.json逐项解释冻结theme的372个叶字段。

visual-acceptance.json用于差异分级，capture-request.json用于主对话转交原生证据。当前原生对照为awaiting，不代表原生渲染/穿透/权限/Dock/音频通过。

在项目根复现（只读前轮文件、只写本轮允许目录）：

```sh
python3 Design/UI/integration/build_reference.py
python3 Design/UI/integration/verify_reference.py
```

不要运行U-001旧生成器刷新delivery-manifest；原件冻结，新integration目录不应加入旧manifest。这里不包含第二套App/渲染器，不修改统一契约或生产Code。
