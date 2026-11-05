# Build201：主动整理旧上下文

版本：1.0.9 / Build201；FLEX 仍为 1.0.0 / Build196。日期：2026-11-05。

## 已确认问题

Build200 的工具批次折叠和普通 AI 长回复卸载仅在最终文本预算超限时继续。把保护上限从 256 KiB 调到 512 KiB 后，投影会保留接近 512 KiB 的旧内容。上限设置工作正常，但这不是降低输入消耗的策略。

用户截图显示 491.5 KiB 文本 JSON、服务商报告 162370 输入 tokens；没有取得完整会话，因此本次合成测试不能证明该真实会话的精确组成，也不能把字节降幅换算成真实 tokens 或费用降幅。

## 开源对比（仅参考结构，独立 Objective-C 实现）

1. OpenMinis：核对远端 HEAD 与本地源码均为 `1a71df0f381cefde80bf912b723de6f9831bc177`。`ContextPolicy.swift` 将触发水位、目标水位、最终边界分开，并考虑固定上下文成本；`ContextTrimPlanner` 按完整迭代做卸载、骨架化、旧步骤索引，保留最近轮次，操作发送副本而不是原始会话。`AIChatViewModel+Compaction.swift` 还会在压缩后处理保留尾部中的大结果。其稳定切点/缓存复用、模型语义摘要是更完整的架构，不在本轮整体移植。
   - https://github.com/OpenMinis/OpenMinis/blob/1a71df0f381cefde80bf912b723de6f9831bc177/src/ios/Agent/Chat/ContextPolicy.swift
   - https://github.com/OpenMinis/OpenMinis/blob/1a71df0f381cefde80bf912b723de6f9831bc177/src/ios/Agent/Chat/AIChatViewModel%2BCompaction.swift
2. Codex-X：核对远端 HEAD 与本地源码均为 `1a0ae707c6efde28727c0e4448d53dc262720bad`。`context_config.rs` 分开配置 `model_context_window` 与 `model_auto_compact_token_limit`，是面向 Codex 运行时的配置，不是可直接搬进 Dylix 的 iOS 压缩实现。没有照搬其 1M/900K 数字，也不据此宣称 Dylix 模型的官方窗口大小。
   - https://github.com/yynxxxxx/Codex-X/blob/1a0ae707c6efde28727c0e4448d53dc262720bad/apps/desktop/src-tauri/src/context_config.rs
3. nanoMuse：核对远端 HEAD 为 `8b32d43c946db2bbef6fae39c48a9fc608ebd8e9`，检查其仓库中的 Minis 衍生 ContextPolicy 与工具配对测试。它与 Minis 有共享实现来源，不能当作独立方案的第二份证据，也没有复制代码。
   - https://github.com/nano-muse/nanoMuse/tree/8b32d43c946db2bbef6fae39c48a9fc608ebd8e9

本次 GitHub API 树接口受未认证限流，改用公开 Git 远端 HEAD 和已有对应 checkout 核对；未使用用户 PAT/API Key。

## Dylix 变更

- 可整理旧历史采用独立 **64 KiB 目标**，不随用户的保护上限增大；这是旧消息 JSON 的保留目标，不是全部请求大小或 token 窗口。
- 旧的完整工具批次按时间转成紧凑事实记录：保留工具名、调用标识、原参数/结果引用，以及原文中明确给出的状态、错误、构建/提案标识等。所有摘录标记为不完整，不根据“无 error”推断成功，也不重放旧写操作。整条回执带卸载标记，不能作为项目源码重放。
- 最近两个完整工具批次保留；原有单个大结果预览规则仍适用。未完成调用、用户原文、system/人设、工具 schema 不为软目标删除；有原生 provider_items 或图片的批次不参与本次主动折叠。
- 旧普通长回复也参与独立目标；最近一条普通回复仅在硬上限超限时按原有回读方案精简。原始会话、工具执行参数、项目、审批、人设与记忆不修改。
- 旧 read_context 结果可在不再属于最近轮次后折叠为原始结果引用；最新回读页不会立即再次卸载。没有另建磁盘副本或引入反复读取同一卸载文件的机制。
- 使用原始非 system ordinal 生成 message:N 引用，删除工具结果行后仍能正确回读；所有本地记录保持原状。
- 更新统计：旧历史目标/保留量、主动折叠数、最近保留批次数，明确与最终保护上限分开。
- 用每条消息的序列化大小增量计算处理中的预算，避免为每个旧批次都重编码整份会话；结束时仍按最终完整投影计算统计。
- 设置说明改为“最终请求上限，旧历史提前整理”，默认 256 KiB 和用户已保存的自定义值均保留。

## 对照测试

同一份公开可复现的合成数据：128 次中等结果（95 FLEX、22 read_file、11 context）、多条 16 KiB 历史报告、22 KiB system 与 26 KiB 用户文本。保护上限 512 KiB。

- 原始文本 JSON：1001758 bytes。
- Build200 投影：517186 bytes（约 505.1 KiB）。
- Build201 投影：127740 bytes（约 124.7 KiB），较旧版发送副本减少约 75.3%。
- Build201 可整理旧历史：59463 bytes，低于独立 64 KiB 目标。
- 同一数据改成 16 MiB 保护上限，投影内容完全一致，不恢复成完整旧工具输出。

以上只说明该合成数据的序列化文本改进；不是用户真实会话或计费 tokens 的复现。基线源码为本地公共分支 Build200（`0e992eef`）。

## 验证与边界

`ContextProjectionRun.py`：103 项通过；生产 `AIRuntime` + fixture transport、40 轮/1200 次工具、后台/停止/导航生命周期回归和12项会话恢复检查通过。原生 UIKit 使用真实投影生成测试诊断，通过会话菜单打开弹窗，核对目标、上限、保留量与持久化。模拟器/设备构建、IPA、签名、版本及 fixture 排除检查见 BUILD201_TESTS.json。

本轮没有额外调用付费模型生成摘要，没有新增依赖，没有修改 developer prompt、binary_inspect 或写入审批。没有真实服务商计费请求或设备端用户会话验证。

64 KiB 是尽力目标：大量不可缩小的小记录、用户长输入、system/工具定义、原生签名数据或最近轮次仍可能使总量较大；最终按用户上限判断，超限不会强行丢弃这些数据。没有承诺任意长会话恒定大小、精确计费下降或缓存命中率。未来若加入持久化压缩切点或语义摘要，需要独立实现与验证，不能把这次事实预览冒充模型摘要。
