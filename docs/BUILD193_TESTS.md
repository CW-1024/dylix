# Build193 — RootHide 原生链接与签名

## 范围与已确认问题

Build192 仅修复 DEB 压缩成员与目录记录，不能据此宣布 RootHide 真机安装/运行兼容。本轮针对用户提供的 QXCapturePlus_1.0.1_iphoneos-arm64e.deb 继续核对。

样包 SHA-256：`37096d1f9a1a080c084e0f7efe7a4ef0c947c5555eef00fa93f7f2eae474f638`。它的 Debian Architecture 为 iphoneos-arm64e，主 dylib 的实际 CPU 是 arm64。包中存在 rootless-compat(>=0.9)、pkgmirror 原副本及 AutoPatches 的 .roothidepatch 符号链接，符合官方 Patcher 的 AutoPatches 转换路线。没有复制、修改或分发该插件正文。

包架构标签和 Mach-O CPU 属于不同层次：iphoneos-arm / iphoneos-arm64 / iphoneos-arm64e 在这里分别区分 rootful / rootless / RootHide 的包安装生态，不能用来推断 dylib 的 arm64 / arm64e CPU 切片；更不能通过改字段或 Mach-O subtype 来转换 ABI。App Store 目标通常使用 arm64；真正 arm64e 涉及 ABI，Dylix 继续拒绝内嵌 LLD 无法正确输出的 arm64e，不伪造切片。

## 修复

- 隐根方案优先使用专属 Substrate 链接描述：`@loader_path/.jbroot/usr/lib/libsubstrate.dylib`，同时支持 CydiaSubstrate framework 和 -lsubstrate。
- 隐根链接加入 `-adhoc_codesign`，确保发布裁剪重链接后的最终库仍有 ad-hoc 签名。此签名不是证书签名，不改变设备安装权限。
- 单方案和多方案均由同一函数配置链接参数；切回普通方案移除隐根专属搜索目录及签名参数。
- 打包前检查主库的 Mach-O 结构、原生 install_name、签名记录及残留 /var/jb / 通用 Substrate 路径，失败时明确停止。此结构检查不是对所有第三方资源、硬编码路径或设备兼容性的认证。
- 继续使用官方原生 RootHide 路线，不凭空添加转换器专用的镜像与 AutoPatches 标记，不盲目加入 rootless-compat 依赖。

## 测试

1. 模拟器 App 内实际 Clang/LLD：多方案发布自动裁剪、单隐根保留符号、-lsubstrate 别名三组，共5个产物通过；验证实际依赖、包字段与 CPU 层次，隐根最终 dylib 均通过 codesign --verify --strict。
2. PackageLinkingTests.m：参数幂等性、方案隔离、真实有效产物、旧输出/截断记录/残留路径拒绝通过。
3. 使用 RootHide Sileo 原始 ControlFileParserFast.c 编译独立测试；样包、Build192 夹具和 Build193 夹具的 dpkg-deb --field 输出均被识别。上游解析实现仅测试时从外部 checkout 编译，不复制进 App 或仓库。
4. AI 工具套件348项通过；IPA 已构建，ZIP和主程序/扩展版本及签名结构另行校验。

复现：`python3 tests/RootHideCompatibilityIOSRun.py`；`python3 tests/SileoControlCompatibilityRun.py /path/to/Sileo-roothide sample.deb native.deb`。PackageLinkingTests.m 用 macOS Foundation 编译，传入本轮 native-signed.dylib 和旧版 dylib。

## 尚未确认

上述差异是已复现的链接/签名缺口，不能直接证明它们就是用户 Sileo 安装报错的原因。Build192 夹具已能被宿主 dpkg 及上游 Sileo 控制解析器读取，仍需用户实际失败包与安装错误原文，区分架构选择、依赖求解、维护脚本和 RootHide 设备 dpkg 行为。没有真机 Sileo/APT 安装或目标 App 加载通过的结论。

## 官方依据

- https://theos.dev/docs/Rootless ：包安装方案、arm64e ABI 与非系统 App 的区别。
- https://github.com/roothide/Developer ：原生包方案及 .jbroot 依赖路径，核对 c53cc199f1bab7d7ea2fd70f0a14e215b1f3461b。
- https://github.com/roothide/lib/blob/master/iphone/roothide/CydiaSubstrate.framework/CydiaSubstrate.tbd ：Substrate 原生 install_name。Dylix 的专属描述由既有 stub 更改路径生成，没有引入新库实现。
- https://github.com/roothide/RootHidePatcher/blob/main/patch.sh ：AutoPatches 转换、签名、镜像与依赖；核对 80c16e08da33fecd27c0ff35777f37afd171868b。
- https://github.com/roothide/Sileo-roothide ：rawFields、控制解析和包架构检查；核对 065fb49969c872a90494689de82894c341396350。
