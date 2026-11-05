# 第三方组件与许可证

本清单与 App 内的 `Resources/ThirdPartyNotices/` 一同保留。各组件维持原版权；GPL 仅适用于本项目有权许可的原创部分。

- **LLVM** — Apache-2.0 with LLVM exceptions。https://github.com/llvm/llvm-project/tree/llvmorg-14.0.0；许可文本：[`llvm-LICENSE.txt`](Resources/ThirdPartyNotices/llvm-LICENSE.txt)。
- **Clang** — Apache-2.0 with LLVM exceptions。https://github.com/holzschu/llvm-project；许可文本：[`clang-LICENSE.txt`](Resources/ThirdPartyNotices/clang-LICENSE.txt)。
- **LLD** — Apache-2.0 with LLVM exceptions。https://github.com/holzschu/llvm-project；许可文本：[`lld-LICENSE.txt`](Resources/ThirdPartyNotices/lld-LICENSE.txt)。
- **ios_system** — BSD-3-Clause。https://github.com/holzschu/ios_system；许可文本：[`ios_system-LICENSE.txt`](Resources/ThirdPartyNotices/ios_system-LICENSE.txt)。
- **Perl 5.34.0** — Artistic 1.0 / GPL（见原文）。https://github.com/holzschu/perl5；许可文本：[`perl-artistic-LICENSE.txt`](Resources/ThirdPartyNotices/perl-artistic-LICENSE.txt)。
- **Perl GPL 文本** — GPL（Perl 双许可证选项）。https://github.com/holzschu/perl5；许可文本：[`perl-LICENSE.txt`](Resources/ThirdPartyNotices/perl-LICENSE.txt)。
- **Theos Logos** — GPL-3.0-or-later。https://github.com/theos/logos；许可文本：[`Logos-LICENSE.txt`](Resources/ThirdPartyNotices/Logos-LICENSE.txt)。
- **highlight.js** — BSD-3-Clause。https://github.com/highlightjs/highlight.js；许可文本：[`highlight.js-LICENSE.txt`](Resources/ThirdPartyNotices/highlight.js-LICENSE.txt)。
- **MBProgressHUD** — MIT。https://github.com/jdg/MBProgressHUD；许可文本：[`MBProgressHUD-LICENSE.txt`](Resources/ThirdPartyNotices/MBProgressHUD-LICENSE.txt)。
- **libarchive（系统组件）** — BSD 及文件级许可（见原文）。https://github.com/libarchive/libarchive；许可文本：[`libarchive-LICENSE.txt`](Resources/ThirdPartyNotices/libarchive-LICENSE.txt)。
- **libgit2 1.9.7** — GPL-2.0-only with linking exception。https://github.com/libgit2/libgit2/tree/v1.9.7；许可文本：[`libgit2-LICENSE.txt`](Resources/ThirdPartyNotices/libgit2-LICENSE.txt)。
- **diff2html 3.4.55** — MIT。https://github.com/rtfpessoa/diff2html/tree/3.4.55；许可文本：[`diff2html-MIT.txt`](Resources/ThirdPartyNotices/diff2html-MIT.txt)。
- **jsdiff（diff2html 内含）** — BSD-3-Clause。https://github.com/kpdecker/jsdiff/tree/7.0.0；许可文本：[`jsdiff-LICENSE.txt`](Resources/ThirdPartyNotices/jsdiff-LICENSE.txt)。
- **Hogan（diff2html 内含）** — Apache-2.0。https://github.com/twitter/hogan.js；许可文本：[`hogan-LICENSE.txt`](Resources/ThirdPartyNotices/hogan-LICENSE.txt)。
- **AI 模块与研究参考** — 独立原生实现 · 上游许可见说明。https://github.com/cline/cline；许可文本：[`AI-Research.txt`](Resources/ThirdPartyNotices/AI-Research.txt)。
- **REipa 0.1.0** — MIT。https://github.com/JRBusiness/REipa；许可文本：[`REipa-MIT.txt`](Resources/ThirdPartyNotices/REipa-MIT.txt)。
- **Rust standard library 1.99.1** — MIT / Apache-2.0（依赖归属见完整清单）。https://github.com/rust-lang/rust/tree/1.99.1；许可文本：[`Rust-LICENSE.txt`](Resources/ThirdPartyNotices/Rust-LICENSE.txt)。
- **thiserror 与 Rust 宏依赖** — MIT / Apache-2.0 / Unicode-3.0（见原文）。https://github.com/dtolnay/thiserror；许可文本：[`REipa-Rust-Dependencies.txt`](Resources/ThirdPartyNotices/REipa-Rust-Dependencies.txt)。
- **iOS tweak development 指南** — MIT。https://github.com/liamschwie/skills/tree/main/skills/ios-tweak-development；许可文本：[`ios-tweak-skills-LICENSE.txt`](Resources/ThirdPartyNotices/ios-tweak-skills-LICENSE.txt)。
- **Cydia Substrate compatibility header** — BSD-style (see header)。https://github.com/theos/headers；许可文本：[`CydiaSubstrate-header.txt`](Resources/ThirdPartyNotices/CydiaSubstrate-header.txt)。

## 本地修改与归属

- REipa 固定上游 revision `b0d4759451ed20796892a059fa53d9dbb130af61`，包含本地边界检查/大镜像/增量导出修改；详情见 Vendor/REipa/README-TweakForge.md，源码完整保留。
- libgit2 完整来源及 COPYING 在 Vendor/libgit2；其 GPLv2 linking exception 不将 Dylix 主程序强制改为 GPLv2。
- Logos 的实际源码在 Resources/logos，使用 GPL-3.0-or-later。
- 原生 AI 交互研究参考不代表复制代码或链接其运行时，见 AI-Research.txt；另参考 OpenMinis（https://github.com/OpenMinis/OpenMinis）的流式呈现与生命周期设计，Dylix 使用自己的 UIKit 实现。
- 仓库中的 Apple SDK 16.4 / 26.0 与 Apple 系统 framework 保留 Apple 条款，不属于本项目 GPL 许可授权范围。
- 不分发用户项目、参考 macOS Perl 副本、设备日志、模型会话或用户附件。内置 FLEX 插件与随包示例另见下方许可和对应源码。

## 预编译工具链

Release 的工具链包包含 ios_system、LLVM/Clang/LLD、Perl 对应 xcframework 和许可证。来源、版本与包/文件摘要见 dependencies.lock.json；它不包含 Apple SDK。Apache/BSD/Artistic 等第三方组件继续适用原条款。

## Dylix Remote

原生服务、Web UI 与 SVG 图标为本项目原创实现，适用仓库 GPL-3.0-or-later；TLS使用Apple系统Network/Security，无第三方TLS库。

离线编辑器 **Monaco Editor 0.52.2**，Microsoft Corporation，MIT许可证。来源为npm官方包 https://registry.npmjs.org/monaco-editor/-/monaco-editor-0.52.2.tgz ，分发min/vs AMD资源，版本与来源记录于Resources/RemoteWeb/monaco/SOURCE.json。完整许可保留于该目录LICENSE及Resources/ThirdPartyNotices/monaco-editor-MIT.txt；无公网CDN。

Build152：远程工作台轻量编辑器与文件预览复用已列出的highlight.js 11.11.1离线构建，副本及BSD-3-Clause许可位于Resources/RemoteWeb/highlight.js和highlight-LICENSE。

- **已退休 Persona 模板数据** — 来源为 com.aztut.app 1.14（build 1）安装包。五份历史正文已退出当前出厂目录；非破坏迁移保留全部既有本机记录。原数据指纹见 `Resources/Personas/SOURCE.json`，来源说明见 [`Persona-Templates-Source.txt`](Resources/ThirdPartyNotices/Persona-Templates-Source.txt)。Objective-C 实现独立编写，未复制 Swift 代码。
- **公开 Persona 目录** — 仅包含 MDX-Tom/gpt-instruct 与 yynxxxxx/Codex-X 的四项 MIT 许可数据，逐项来源、revision 与 SHA-256 见 Resources/Personas/SOURCE.json；完整许可保留于 Resources/ThirdPartyNotices/GPT-Instruct-LICENSE.txt 和 Codex-X-LICENSE.txt。私有无许可目录正文不随本仓库或公开 IPA 分发。

## Build163 通用 Agent 结构参考

参考OpenMinis（GPL-3.0，commit `1a71df0f381cefde80bf912b723de6f9831bc177`）的ProviderTypes、ThinkingLevelCatalog、OAuthRefreshSingleFlight、SkillStore、MCPStore、BrowserUseManager目录分层与流程。新增实现为独立Objective-C代码，未复制Swift实现或提示词正文；四份插件开发技能为本项目新写文本，适用本仓库GPL-3.0-or-later。没有新增第三方依赖。协议资料与来源见docs/AGENT_EXTENSIONS.md。

## Build164 工具注册表结构参考

同一 OpenMinis revision 的 ToolDefinitions、ToolPreflight、FileTools、MemoryTools 仅用于研究定义、预检、条件下发与本地数据边界。分层注册表及隔离只读实现独立使用 Objective-C 编写，适用本仓库 GPL-3.0-or-later，未复制 Swift 片段；未引入 AzTuT ReverseTools 或其默认开启逻辑。未新增第三方依赖。实现与边界见 docs/TOOL_REGISTRY.md。

## FLEX 插件与现场工具

- FLEX 上游 https://github.com/FLEXTool/FLEX ，BSD-3-Clause，原文保留于 Resources/ThirdPartyNotices/FLEX-LICENSE.txt；FLEX++ 修改及 Dylix 桥接对应源码随 1.0.8 Release 的 FLEX-1.0.0-source.zip 提供。
- Capstone 相关许可保留于 Resources/ThirdPartyNotices/Capstone-LICENSE.txt，源文件头部声明继续保留。
- 进程内触摸适配的 KIF / EarlGrey 来源及 Apache-2.0 原文见 FLEXTouch-NOTICE 和 FLEXTouch-DylixTouch-APACHE-2.0.txt。
