# U-028 自定义键位 · u028.2

按CR-007与主审阅：新表唯一默认，旧表菜单删除；选音高即交换窗口内单层草稿，切换实体键保留全部编辑，最后一次保存。没有“继续调整”或“应用”按钮。U-027保持历史原样。

- [交换草稿预览](previews/swap.png)：G从C4改为F3、A同时改为C4，尚未生效。
- [恢复默认草稿](previews/restore.png)：当前仍为自定义，保存后才恢复新表。
- [窗口与状态规范](SPEC.md) / [选项与示例](reference.json) / [验证结果](validation.json)。

窗口560×440pt，静态图1120×880px。全部累计差异在预览列表滚动，不增加复杂主界面。写入失败保留草稿，取消/关闭不改运行映射。

复现（项目根；只写U-028，不启动App）：

```sh
python3 Design/UI/U-028/tools/build_reference.py
swift Design/UI/U-028/tools/render.swift /Users/wuming/Desktop/键盘钢琴/Design/UI/U-028
```

CoreText静态图与交换算术不等于原生控件、配置持久化、无障碍或真实音频/输入回归。生产实现与故障恢复由C-028负责。
