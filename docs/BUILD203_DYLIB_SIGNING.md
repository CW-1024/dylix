# Build 203：插件产物签名修复

版本：1.0.9 / 203；日期：2026-11-05。

## 原因与改动

原先 `TMCPackageLinkArguments` 仅为 RootHide 加入 `-adhoc_codesign`，并在普通 rootless/rootful 分支删除该参数，导致这些环境缺少统一的签名保证。当前全部链接及发布裁剪重链接保留 ad-hoc 签名，独立 dylib 也执行同样流程。RootHide 的专用依赖路径与 ABI 检查保持不变。

新增 `App/DylibSignature.h`，验证最终 ARM64 Mach-O 的加载命令、唯一签名命令、SuperBlob/CodeDirectory 边界、SHA-256 代码覆盖范围及逐页哈希。校验在发布裁剪之后、独立产物成功导出之前，以及每个变体进入 deb 打包之前执行；失败删除该动态库并停止本次产物成功流程。deb 使用刚校验的同一份 NSData，不额外修改其中的 dylib。结构化 report 记录 signatureVerified，每个成功进入打包流程的变体也记录该字段。

签名由内嵌 LLD 生成，无第三方依赖、不需要开发者证书或安装后的 postinst 补签。裁剪实际通过 LLD 的 `-S` 重链接实现，所以新签名覆盖裁剪后的内容；完整调试副本保留原始有效签名。

## 测试

- `python3 tests/DylibSignatureRun.py`：生产校验函数的正负样例，包括未签名、截断、内容篡改、签名表损坏及越界；签名参数跨方案一致性与幂等性。
- `python3 scripts/build.py --simulator`。
- `python3 tests/RootHideCompatibilityIOSRun.py`：在模拟器中的 App 内运行真实嵌入式 Clang/LLD，构建 rootless/rootful/roothide 的发布和调试包、RootHide 库别名包，以及独立发布/调试 dylib。解包 deb，用主机 `codesign --verify --strict` 验证原样输出，不用主机工具补签；另验证导出的 dylib 和调试副本。可用时用 dpkg-deb 检查包元数据。
- `python3 tests/test_release_symbols.py`：实际 LLD 发布裁剪及 Objective-C/C++ 异常处理回归；移除对插件测试产物的主机补签，直接验证内嵌链接器生成的签名。测试运行器自身签名与插件产物无关。
- 私有与开源源码分别编译设备安装包，检查 ZIP、主 App/扩展版本与签名、FLEX manifest，以及各自的人设资源保持不变。

## 参考实现与边界

结构对照了 theos/theos 的 `makefiles/instance/rules.mk`（构建、裁剪后签名），以及 opa334/Dopamine 的 2.x 分支 `BaseBin/dyldhook/src/lv_bypass.c` 与 `BaseBin/launchdhook/src/jbserver/jbdomain_systemwide.c`（加载时签名与 CDHash 信任处理）。本次没有复制这些项目的实现。

本校验针对 Dylix 自己生成的 thin ARM64、SHA-256 ad-hoc dylib，不是任意第三方签名验证器，不等同于设备 trustcache/宿主兼容验证。未取得本次用户失败的 rootless deb，也未在 Dopamine 真机注入 QXCapturePlus；原项目需要在本版本重新构建后再测，旧 deb 不会自动修复。未改变已有人设、工具审批或项目文件。
