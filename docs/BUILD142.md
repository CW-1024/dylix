# Dylix 1.0.5（142）

- 增加项目与全局 C++ 标准选择，默认使用 gnu++17，兼容 typeof 等 GNU 扩展。
- AI 通过 propose_build_settings 设置 cxxStandard；优先尊重 Makefile 显式 -std，构建返回实际生效配置。
- App 使用 iOS 26 SDK 打包；内嵌插件默认 SDK 16.4、最低 iOS 15。

详见 OutputNaming.m、Studio.m、TFAIToolbox.m 与相关回归测试。编译通过仍需真机运行验证。
