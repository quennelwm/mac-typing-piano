# 发布协作测试版

源码推送与可运行App发布是两个步骤。菜单“下载新版…”打开本仓库Releases；程序没有自动下载安装器。

1. 按`Code/README.md`在新的独立目录构建并运行对应测试。不要重建或重签已授权、正在使用的包。
2. 为公开候选使用同一Apple签名身份和Bundle ID，核对签名要求。通过`TYPING_PIANO_SIGN_IDENTITY`传入本机身份；证书、私钥、钥匙串文件和登录信息不得提交。源码默认ad-hoc构建不承诺延续其他构建的输入监控授权。
3. 当前Apple Development签名只是协作测试过渡。正式外部分发需要Developer ID Application与公证；参见[Apple说明](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。不要将开发证书检查通过等同公证或首次下载启动通过。
4. 更新版本号、下载指南和版本验收范围。将已签好的完整App与“开始测试.md”放入同一ZIP，保留UTF-8中文文件名及可执行位。只放App和指南，不加入个人偏好、授权待开始意图、Dock恢复票据或构建缓存。
5. 解压到新目录，核对所有App文件字节、strict签名、`--self-check`和`--menu-smoke`。为ZIP生成`SHA256SUMS.txt`，将版本/大小/哈希/验证范围记入该版本`artifacts.json`。
6. 提交审核后的源码、资源与说明，推送main。为对应提交创建版本tag，再创建GitHub prerelease并上传ZIP和校验文件。需使用正式Release资产，不只提供GitHub自动生成的Source code ZIP。
7. 检查远端提交与tag匹配，并在不使用GitHub登录凭据的情况下下载发布资产，核对SHA-256；成功后才把下载链接交给测试者。

本仓库首次公开协作发布沿用用户授权：公开完整项目，供协作测试。各版本的实机/权限/音色/兼容边界见交接和发布说明。统一开源许可证尚未选定；第三方资源原许可须随包保留。
