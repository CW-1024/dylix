# Build 194：工具上下文治理与测试记录

日期：2026-11-05。版本：Dylix 1.0.8 / Build 194，FLEX 插件仍为 1.0.0。

## 问题与已确认的根因

用户报告 1.0.7 某会话工具占用 877K tokens，其中 propose_patch ×30 占 734K。尚未取得该会话导出及服务商 usage，不能声称已经复现这两个精确数字，也不能判断该统计指单次窗口还是多轮累计输入。

已检查公开 1.0.7 Build160（d985b0e6）的 TFAIToolbox.m 及当前 Build193：propose_patch 的返回已经是 proposal_id、路径、字节数、hash 等摘要，完整差异留在本机。因此不能简单归因成“提案工具返回了整份文件”。

真正存在的问题：

1. assistant.tool_calls.arguments 中的 before / after / 文件正文一直原样保留，每轮又随完整历史发送。工具参数也是模型输入上下文，不能只统计 role=tool。
2. 单个结果上限 512 KiB、会话 JSON 上限 8 MiB 都是字节防线，不是 token 预算；许多低于单条上限的结果仍会累积。
3. 旧裁剪只在发送用户消息前运行，依赖项目记忆开关和至少 8 次用户发言；一条任务内连续几十轮工具调用无法触发。
4. 把服务商历次输入 tokens 相加是累计用量，不能直接当作某一时刻的模型窗口占用。

## 参考项目与取舍

本次只参考设计，Objective-C 实现为新写代码，没有复制 Swift / Python 片段或新增依赖。

- [OpenMinis](https://github.com/OpenMinis/OpenMinis)，本地核对提交 `1a71df0f381cefde80bf912b723de6f9831bc177`。
  - `src/ios/Agent/Chat/AIChatViewModel+Offloading.swift`：历史参数/结果卸载、回读、避免把占位符写回源码。
  - `AIChatViewModel+Compaction.swift`、`ContextPolicy.swift`、`AIChatViewModel+ContextUsage.swift`：每轮 dispatch 前预算检查、固定上下文与工具定义计入预算、全轮次边界、窗口和累计统计分开。
  - 没有照搬它的模型窗口阈值、文件系统路径或完整 tokenizer；Dylix 当前未可靠记录所有中转模型的官方窗口，不能猜测为 1M。
- [nanoMuse](https://github.com/nano-muse/nanoMuse)，核对提交 `8b32d43c946db2bbef6fae39c48a9fc608ebd8e9`。
  - `nanomuse/agent/context.py`：仅修改请求副本、不拆散工具交换、预算不足时有明确终止。
  - `nanomuse/llm/budget.py`：估算与服务商实际 usage 分开。
  - 用户只说 Muse，未确认具体仓库；这里只把可核实的 nanoMuse 当补充样本，不声称它就是用户所指项目。它的运行时架构也不同于 Dylix 的 iOS 本机构建。

## 本次实现

新增 `App/AI/Core/TFAIContextProjection.{h,m}`，在 AIRuntime 的每一轮请求前构建发送副本：

1. 本地完整消息、工具执行参数、审批提案、工具结果、恢复检查点保持原样。旧的可选本地摘要仍保存，但不再凭“保留最近8次用户发言”丢弃更早用户要求。
2. 对已完成且调用/结果完整配对的工具批次，历史参数内超过 1 KiB 的长字符串改为显式占位符，附原字节数、SHA-256 和原文引用。待执行、缺结果或部分完成的批次不修改。
3. 超过 16 KiB 的历史结果改为有标记的不完整预览，优先保留 error / success / state / proposal_id / build_id / path / hash / recovery / 分页游标等信息。没有把预览当作完整结果或成功结论。
4. 新增 A 档只读 `read_context`，仅从当前会话按 ref 回读已存原文，无文件路径访问、无执行、无跨会话扫描。每页最多 4096 UTF-16 单位，next_offset 续读，返回 hash 与原字节数；组合字符不拆分，非法/重复引用拒绝。仍走现有结果密钥过滤。
5. 模型若把历史占位符当作新工具参数提交，在 toolbox / 写入 / 审批执行前拒绝，要求回读原文及重新读取当前文件。
6. 应用文本 JSON 保护预算 256 KiB，包含工具定义、system、参数、结果和协议元信息。超过预算时按最旧顺序折叠完整工具批次为可回读收据，保留最近两个工具批次及全部 user / system 文本；不可安全缩减时暂停并保留完整记录。该预算不是官方模型窗口，不是精确 tokenizer，也不限制用户文件上传大小。
7. 图片 base64 不按“文本 bytes/2”硬算 tokens，原有图片/传输校验继续负责图片。粗估明确标为不含图片。协议 framing、JSON 转义和供应商分词会使实际请求计数与内部文本 JSON 不同。
8. Gemini 同时处理通用 tool_calls 和 native provider_items 内的 functionCall.args 副本，保留 native ID 和 thoughtSignature；Responses opaque reasoning 原样保留。协议配对回归覆盖四种编码，但不冒充真实服务端调用验证。
9. 当前连接未提供 read_context 时，不生成无法回读的占位符；普通小会话原样发送，过大则明确暂停。

会话菜单新增“上下文用量”：整理前/后 KiB、参数卸载次数、结果摘要次数、折叠批次数、工具参数/结果占用排行，以及服务商报告的本轮输入 tokens。没有 usage 时显示“未报告”，粗估单独显示，不伪装精确计数。

## 合成测量

固定 30 次 propose_patch，每次含约 48 KiB before 和 48 KiB after，返回值保持精简：

- 整理前内部文本 JSON：3,299,469 bytes。
- 整理后：25,219 bytes，减少 99.24%。
- 本地原文/执行参数保持完全一致，分页拼接后与原参数 JSON 逐字节一致。
- 按 1→30 轮逐步增长累计：整理前 51,152,910 bytes，整理后 401,835 bytes。

这些是可复现的合成字节测量，不是用户真实会话的 734K / 877K，不是实际账单 token，也不是所有项目固定能节省 99.24%。

## 测试

- `python3 tests/ContextProjectionRun.py`：58 检查，涵盖 30 大提案、历史大结果、单用户长工具循环、保留原文、完整配对、错误结果、原文分页、Unicode、未知及重复引用、部分完成批次、工具禁用、schema 成本、不可压缩预算、opaque reasoning。
- `python3 tests/ContextRuntimeRun.py`：真实 AIRuntime + 本地模拟 transport，30 次连续调用、记忆关闭时仍投影、旧会话在新 runtime 继续、原始执行参数及完整保存记录、占位符执行拦截、原文工具路由。
- `python3 tests/AIRuntimeBudgetRun.py`：原有 40 轮 / 1200 工具调用和导航、后台中断行为。
- `python3 tests/AITransportNetwork.py`：114 检查，含 Chat / Responses / Anthropic / Gemini 实际请求编码及本地 HTTP fixture，Gemini 双副本卸载、签名及 native ID 保留。
- `python3 tests/AIToolsRun.py`：348 检查，原有文件操作、补丁、审批、审计、越界保护。
- `python3 tests/ToolRegistryRun.py`、`ToolRegistryRuntimeRun.py`、`AgentRuntimeRun.py`、`PersonaRuntimeRun.py`：分层权限、历史保存、人设及模型切换回归。

模拟器 iOS18.3 实测会话菜单、首次无统计提示和带统计报告；原生 UI 事件接收、真实会话持久化 3 检查全部通过。UI 展示的 fixture tokens 为合成数值，不是真实服务商请求。

同步修正宿主测试夹具：共享 UIImage stub 只定义一次，补齐既有 FLEX bridge 链接；没有改变生产权限规则。

## 构建与范围

iOS 模拟器构建、iPhoneOS 构建通过；IPA ZIP.testzip、主 App 及两个扩展版本、codesign --verify --deep --strict 校验通过。主 App 最低 iOS15，Activity 扩展仍按原有设计最低 iOS16.2。产物 SHA-256 及版本信息见 BUILD194_VERIFICATION.json。

- 未使用用户 API Key，不产生真实模型请求或费用。
- 未修改默认 developer prompt 正文、人设正文、项目文件、FLEX 运行权限或 RootHide 打包方案。
- 完整原文仍保存在原会话，不额外向云端保存。
- 当前没有跨模型精确 BPE、基于可靠官方窗口的动态阈值、模型语义摘要或供应商原生 compact。本次不假称具备这些能力。长 user/system 文本自身超预算时会明确暂停，而非静默删掉用户要求。
- 真机上的模型服务响应、长时会话体验和实际用量仍需使用新版记录核对。
