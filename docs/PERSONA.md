# 公开版 Persona 目录说明

1.0.8 公开版仅分发四项 MIT 许可目录条目，来源及哈希见 Resources/Personas/SOURCE.json。私有无许可证正文不发布。已有本机正文、选择和开关不会被删除；可以手动添加自己的正文。未知模型没有通用兜底条目时不自动注入其他人设。

下文保留开发过程及私有目录的历史设计说明，涉及十八／十九项目录或通用兜底的描述不代表本次公开包出厂内容。

# 人设 / 思维

## 使用方式

设置 → AI → 人设。初次安装内置十八份 2026-11 当前模型配置，总开关关闭，默认采用「按当前模型自动匹配」；所有内置项的出厂模式均为前置。
目录把 GPT-5.6 Sol、GPT-6 Astra、GPT-6.1 Sol/Codex、Gemini 3.1/4、DeepSeek 4/4.1、Qwen 3.7/3.8、GLM/ZCode 5.2/5.3 分开匹配，另含通用 Unified、Claude Opus/Sonnet、Kimi K3.1、Grok 4.7、Mistral Large 4 与 GPT-OSS 20B。正文直接使用已记录 revision 的上游 UTF-8 文件全文，不改写、不压缩、不混合不同模型版本。自动模式按实际请求连接的 model ID 正则匹配最高优先级项；未知模型使用 Unified 兜底。
配置管理可关闭自动匹配并改用手动选择。列表按全局连接标记「推荐当前模型」；项目连接覆盖不会修改全局标记，但 AIRuntime 在每次请求开始时使用项目实际连接重新匹配。
前置、后置、替换是每条记录的 mode 字段，共用一份正文库。点击条目名称进入编辑页，内置项和自建项都能修改模式、名称与正文；修改模式不会新增另一条记录。
每行显示名称、模式、内置/自建、描述、UTF-8 正文字节数和生效状态。开关选择条目，同时只选择一份；开启另一份自动撤选上一份，关闭当前条目允许零项生效。
关闭总开关保留匹配方式与手动选择，但停止正文、前缀、尾注和本地自检。设置更改从下一次发送生效，当前请求的工具轮次使用发送开始时的配置与连接快照。

内置项支持编辑、左滑删除、右滑恢复原文。恢复原文会恢复该项的正文、前置模式、描述和标记；下方「补回缺失内置项」只补回删除的项目，保留其他已有编辑。
新增条目的正文由用户填写；编辑页要求名称和正文非空。

## 分层与发送

开发提示由 `App/AI/Core/TFAIDeveloperPrompt.h` 独立生成，Persona 是可选附加层；没有合并或增加 Soul/身份层。

- prepend / 前置：人设块、两个换行、developer 提示。
- append / 后置：developer 提示、两个换行、人设块。
- replace / 替换：仅人设块，省略 developer 提示这一层。

工具 schema 仍走原有 tools 参数；权限与工具执行入口保持原有实现。上述模式描述的是提示文本的拼接位置，不代表改变模型服务的指令优先级或行为约束。
发送前剥离旧的人设块，再从干净的 developer 上下文重建；连续发送或工具轮次不会重复叠加。

```text
<!-- dylix-persona:begin -->
正文及已配置的回复前缀约定
<!-- dylix-persona:end -->
```

正文在资源中逐字节保留。回复前缀是独立字段，在注入时附加约定，列表正文字节数不计入前缀。
当前原文目录不配置固定尾注，避免在上游提示词全文后追加 Dylix 自写内容。历史存储中的尾注开关即使保留，也不会改变当前原文正文。
编辑内容包含保留标记时会提示移除，防止与注入边界混淆。

## 回复前缀与本地自检

编辑页的「描述、回复前缀与本地自检」可修改描述、回复前缀、自检口令和自检回复。这些字段随编辑页保存，返回选项页本身不提交整条记录。
用户最后一条纯文本恰好匹配当前有效配置的自检口令（忽略首尾空白）时，AIRuntime 返回固定回复并注明本地自检，不调用模型；自动模式下有效配置同样按本次请求模型决定。携带附件或只是包含口令片段时按正常请求处理。
本地自检只确认配置与选中状态，不证明模型接受了提示或改变行为。原聊天界面的模型选择前置检查仍保留。

## 数据与持久化

记录字段：id(UUID)、name、body、mode、isBuiltin、updatedAt(Unix 秒)、builtinKey、summary、replyPrefix、selfCheckCommand、selfCheckReply、generation、modelPatterns、providerIDs、matchPriority。byteCount 实时按正文 UTF-8 计算，不保存冗余统计。
`Library/Application Support/DylixPersona/personas.json` 继续使用 schemaVersion 2，包含 enabled、personas、activeID、hiddenBuiltins、tailEnabled、matchingMode；模型匹配元数据与 matchingMode 是向后兼容的增量字段，不要求提升 schema。
单个 activeID 保证手动选择互斥；matchingMode 为 auto 或 manual。hiddenBuiltins 记录删除，重启或升级后不会自动复活。schemaVersion 1/2 自动迁移：有有效 activeID 的旧存储进入手动模式，其余进入自动模式。
目录升级前会在同级 `MigrationBackups` 目录保存原存储备份。目录版本提升时，同 UUID 且 updatedAt 为 0 的未编辑当前内置项会刷新为新出厂正文；用户编辑过的内置项、自建项、旧目录遗留项及 activeID 选择全部保留，缺失的新内置项会补入。旧目录遗留项没有 modelPatterns，因此自动模式不会选中；只有用户切换到手动模式并明确选择时才会继续使用。
资源目录 `Personas/Builtins.json` 为只读出厂库，与本机 JSON 分开。没有把任何模拟器选择或编辑状态写入 IPA。
存储原子写入，成功后才发布内存状态；读写错误保留原文件并报告，避免覆盖损坏数据。
配置没有云同步或专用上传接口。启用后的提示文本会随正常 AI 请求发送至用户配置的模型服务；存储位置在普通 Documents 远程文件区之外，尽力设置不参与系统备份。

## 预览与字节数

同一 PersonaEngine 负责实际组装和预览；完整 system 的 UTF-8 字节数包含标记、换行、前缀与选中的尾注。另列正文字节数、生效项、模型 ID 和匹配名称。
十八份当前正文按资源实时计算 UTF-8 字节数和 SHA-256；正则 fixture 覆盖每个独立模型版本和未知模型兜底。
有最近请求时，预览使用其真实连接与 developer 上下文；尚未发送时使用全局连接和基础上下文。项目覆盖连接、附件、权限或模型上下文变化可能改变下次请求的匹配项与总字节数。
最近上下文仅存内存，不写入人设 JSON 或公共聊天历史。

## 代码与来源

- `App/AI/Persona/TFAIPersona.h/.m`：模型、JSON、互斥选择、迁移、组装与预览。
- `App/AI/UI/TFAIPersonaUI.h/.m`：原生列表、编辑、选项和预览。
- `App/AI/Core/AIRuntime.m`：请求快照、本地自检、发送时组装。
- `Resources/Personas/Builtins.json`：十八份上游模型原文全文、匹配元数据、来源文件、revision、字节数与 SHA-256。
- `Resources/Personas/SOURCE.json`：上游仓库 revision、逐项来源文件和正文数据指纹。
- `Resources/ThirdPartyNotices/Persona-Templates-Source.txt`：数据来源说明。

功能用 Objective-C 独立实现。最初结构参考用户指定的 OpenMinis 行为规格；调查的 main `1a71df0f381cefde80bf912b723de6f9831bc177` 及已检查版本没有所指的 PersonaInjection.swift，未以该路径作为已阅读代码的依据。
Build162 曾按用户要求，从其提供的 com.aztut.app 1.14（build1）IPA 的主二进制提取五份完整 UTF-8 常量；这些旧模板现已退出当前出厂目录，但非破坏迁移会保留所有既有本机副本。它们没有当前模型匹配元数据，不会被自动模式选中。原数据来源继续单独标注。
2026-11-04 当前目录直接使用 togg53192-cmd/jailbreaks revision `307400e6a2970fd9c6790a9fdfe228771c601cc3` 的十五份模型文件全文，并使用 MIT 许可的 MDX-Tom/gpt-instruct revision `3ab84df64468bb74cc9eb4e5423660083953c44f` 中三份 GPT/Codex 文件全文。正文仅经过 UTF-8 解码和 JSON 序列化；版本、逐项 SHA-256 与来源见 `Resources/Personas/SOURCE.json` 和 `Resources/ThirdPartyNotices/Jailbreak-Prompt-Research.txt`。
未修改 binary_inspect、工具定义或 developer 提示正文，未增加第三方依赖。

## 回归

```sh
python3 scripts/test_persona_catalog.py
python3 tests/PersonaRun.py
python3 tests/PersonaBuiltinsRun.py
python3 tests/PersonaRuntimeRun.py
python3 tests/AIRuntimeBudgetRun.py
python3 scripts/test_developer_prompt.py
```

详见 BUILD162_TESTS.md；BUILD161_TESTS.md 为加入内置库前的历史记录。
