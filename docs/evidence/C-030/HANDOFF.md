# 交接：C-030／固定发布签名检查

## 结论
已完成待主接收，脚本和Code文档已冻结。仅新增Code/Scripts/release_sign.py并更新Code/README.md；没有重建生产App、替换/停止运行实例、启动任何App GUI、修改TCC或注册LaunchServices。任务源为C-030和ADR-024，Git仍由主维护。

## 产物与入口
- `Code/Scripts/release_sign.py`：Python标准库＋macOS系统工具。签名身份必须由`--identity`或`TYPING_PIANO_RELEASE_IDENTITY`显式给定40位证书SHA-1；不在工程硬编码本机身份，不自动挑选证书。
- `--verify-only --app <包> --previous <上一公开包>`：检查Info.plist和签名Bundle ID、非ad-hoc、证书身份、codesign deep/strict/all-architectures、DR逐字一致。只向自动清理的系统临时目录导出公共证书以比对指纹，不导出私钥，不修改包。
- 不带verify-only时必须指定新`--output <尚不存在的.app>`：只复制源包到暂存目录、用显式身份签署，再验证DR，成功后输出新副本。原包始终只读。身份不可用、签名/校验失败不会回退ad-hoc。
- 不构建、不安装、不启动、不注册、不发布。输出复制若遇文件系统错误可能留下不完整目录，始终非零退出，负责人不得仅凭目录存在继续发布。
- Code文档明确：保持固定身份/Bundle ID/安装路径，不能直接发布或启动同Bundle ID的ad-hoc临时候选；候选宜封存ZIP，最终签名后由负责人放回固定路径。未改现有build.sh，开发默认ad-hoc与正式发布入口的用途已区分。

## 测试与证据
本机真实codesign、security、ditto运行；所有故障改动/签名只在TemporaryDirectory的受控副本上完成。未执行App二进制。

`tests-final.log`：13项通过、0失败：
1. 0.2.6公开包verify-only通过。
2. 0.2.7公开包相对0.2.6通过。
3. candidate-0.2.7 ad-hoc拒绝。
4. 缺少身份拒绝。
5. `-`身份拒绝。
6. 指定错误证书指纹拒绝。
7. ad-hoc基线拒绝。
8. 临时副本Bundle ID错误拒绝。
9. 临时副本资源封印损坏拒绝。
10. 同证书、strict有效但DR不同的临时副本拒绝。
11. ad-hoc源只签署新临时副本并通过校验，资源字节一致。
12. 已有输出路径拒绝，哨兵文件不被覆盖。
13. verify-only附带output拒绝。

`verify-public-026.json`、`verify-public-027.json`、`reject-adhoc.json`为实际只读调用的结构化结果。`protected-before.json`/`protected-after.json`核对1048个文件字节未变：生产源/资源/契约/Design、原build.sh、两版公开包、ad-hoc候选和固定安装App。核对发生在主对话封存候选前；后续主对话搬移候选不属于本任务改包。

早期`red.log`是codesign证书提取可选参数格式导致的测试准备失败，不是有效功能红测；已修正为`--extract-certificates=<prefix>`。中间日志另有临时DR测试表达式缺少`=`前缀的准备失败，最终13项均实际执行通过。保留这些失败记录，不计为功能通过。

## 冻结哈希
- release_sign.py SHA256：`7633e0e77b9be1fc3a9c32865ad7c52ba2dea4a74e9cf22dd16abc5d61bc9604`
- Code/README.md SHA256：`3a4795db2b141bd011375f97b5e3be0c2b727e8435c6c5ad6ac0b853437ea6f0`
- 机器清单：frozen-files.json、verification.json。未输出、保存或提交本机证书/私钥，日志中的本机指纹已脱敏。

## 限制与主对话接收
签名/DR检查不能证明macOS权限必然跨版本保留。真实TCC继承为NOT TESTED；输入监控由用户确认，运行路径及实按由主验收。本轮没有开发者ID签名/公证或跨Mac兼容结论。验证要求可信上一公开包；证书续期、身份迁移或DR改变需要单独处理，不能绕过检查。

候选读取和拒绝验证已经完成，不再依赖该临时.app；主可封存。后续主将这两个代码/文档文件随源码发布，无需为此重建已冻结0.2.7生产包。脚本没有上传GitHub或替换安装的行为。
