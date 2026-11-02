# Dylix 1.0.5（143）

- 修复本机 ARM64 构建中异常展开信息异常，导致部分插件注入后闪退的问题。
- 补齐直接调用 Clang cc1 时遗漏的 Darwin 帧指针与 unwind-tables 默认参数。
- 新增内嵌 Clang/LLD 的 Objective-C / Objective-C++ 异常捕获与析构清理运行回归。
- 修正测试 dylib 已获用户确认：注入抖音后不再闪退。手机端新版重编译仍待验证。
- 发布版与开源版均使用 iOS 26 SDK 打包 App；项目默认 SDK 保持 16.4。
