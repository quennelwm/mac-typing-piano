# 来源与授权边界

## Original design

U-001 的琴键几何、键面 SVG、预览脚本、配色、动效与菜单示意均在本任务中依据项目需求新制，未提取商业 App 的图形、音乐、系统 Dock 图标或壁纸。图形组件不包含标签；合成 PNG/GIF/SVG 只作审稿预览。

无第三方图形素材需要署名。项目所有者可在本项目内审稿和集成这些新制文件；本轮没有替项目选择对外开源/再许可条款，也没有把待批准资源登记为 ready。正式发布许可和登记由主对话在 U-002/发布阶段确认。

## 字体

由本机 AppKit/CoreText 读取系统字体并绘制。系统字体文件没有打包或复制。主字体 .SFNS-Medium；Return 与空格标签的具体回退及字号记录在 qa/layouts.json。小音符使用系统字体的 U+266A `♪`。不能将本机字形可用性推导为所有 macOS/字体版本兼容。

## 工具

使用已有的系统 Swift/AppKit/CoreText、Python 3 标准库、Node.js 和已安装的 Pillow。没有安装新依赖、下载素材、调用云端生成服务。Pillow 只用于生成审稿 GIF 和读取原生 PNG 做像素检查，不是产品运行时依赖。

## 数据

唯一映射来源为项目 contracts/keymap.ansi64.v0.1.json（只读）。qa/layouts.json 与 preview-data.js 是可重建的派生产物，不是第二份人工维护的映射。合成事件仅用固定示例；未收集真实按键序列。
