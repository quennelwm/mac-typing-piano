# C-001 本地签名稳定性限制

已观察到Desktop文件提供器在生成.app根目录重新添加com.apple.FinderInfo。第一次build脚本的ad-hoc签名和strict验证可在当时通过，但稍后再次strict验证会报“resource fork, Finder information, or similar detritus not allowed”。这不是用户证书错误，也没有修改系统设置来规避。

当前措施仅作用于自己生成的Code/build/TypingPianoProbe.app：构建时清理扩展属性，最多3次签名/验证；随后使用ditto --norsrc --noextattr --noacl保存无扩展属性的TypingPianoProbe.zip。archive-verification.json逐文件核对ZIP与已生成App字节一致且没有AppleDouble条目。它不是公证/正式发布安装包，解压回Desktop仍可能重新出现同样属性。

signing-immediate.log为空且命令exit0表示清理后即时strict验证通过；executable-signature.log为空且exit0表示Mach-O自身签名通过。后续包目录元数据可能再次变化，因此不能将build.log瞬间成功描述为稳定安装/分发验证。self/menu/window/snapshot探针可执行结果有独立JSON，不以签名声明替代运行证据。

本问题留给PM-002选择正式构建输出/安装路径与签名策略；C-001不迁移用户目录、不关闭文件提供器、不修改用户权限或使用开发者证书。
