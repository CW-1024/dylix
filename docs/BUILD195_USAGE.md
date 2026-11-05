# Build195：用量统计与服务商余额

版本：1.0.8 / Build195。FLEX 版本保持 1.0.0。最低系统仍为 iOS15。

## 使用入口

- **AI 模型与连接 → 用量统计**：今天、近7个自然日、近30个自然日、全部、自定义起止日期；按日、会话、模型、连接分组。点击分组查看每次请求明细。
- **会话菜单 → 本会话用量统计**：限定当前项目与会话。
- **AI 模型与连接 → 服务商余额**：账户钱包 / Key 剩余额度、更新时间、刷新失败提示；支持接口的连接在服务连接列表也显示余额。
- **编辑连接 → 用量与余额**：查询余额，选择官方识别 / 不查询 / Sub2API 钱包，以及“请求流式用量”开关。

## 实际用量的口径

一次用户提问可能调用模型很多轮。每个实际模型请求使用独立 UUID；同一次流式响应的累计用量更新同一条记录，不将每个 usage 帧相加。停止、报错、输出达到上限时，已经返回的真实用量仍保留。请求中断但未返回 usage 时标记未报告，不按文本长度猜测计费用量。

- Chat / Responses：输入、输出、缓存读取、思考 tokens；兼容 DeepSeek 的缓存命中 / 未命中字段。
- Anthropic：输入 = 普通输入 + 缓存读取 + 缓存创建；message_start 和 message_delta 合并。缓存写入单独展示。
- Gemini：输入包含 prompt 与 tool-use prompt；输出包含候选正文与思考。若提供 totalTokenCount，优先保留服务商的总量。
- 缓存读取通常是输入的子集，思考是输出的子集，不再重复加到总量。无法获得某项数据时显示“未报告”，明确报告的 0 则显示 0。
- 缓存命中率 = 同时报告输入与缓存读取的请求中，缓存读取之和 / 输入之和。加权统计，不平均各请求百分比；界面显示报告覆盖次数。
- 缓存数量的单位是 **tokens**，不是手机磁盘字节，也不是服务商缓存池容量；现有接口无法提供后两者，不伪造这些数值。
- 只覆盖本版本起由 Dylix AI 会话发出的模型请求，包括 Remote / FLEX 发起并由同一 Runtime 执行的会话。能力测试、模型发现、余额查询不混入会话统计。
- 升级前没有逐请求用量记录的历史无法准确回填。此前保存的单次上下文诊断仍可在“上下文用量”查看，与累计消耗分开。

日期按设备当前时区划分自然日，结束日期包含当日。请求归属发起日期；模型和连接名称记录发起时快照，不随后续切换而改变。

## 持久化与数据流

`AIRuntime` 创建请求 → `TFAIStreamDecoder` 输出原始 usage → `TFAIUsageStore` 归一化并更新 → 本地原子 JSON 文件 → 原生 UIKit 汇总页。

记录位于 Application Support / Dylix / AIUsage-v1，按请求写入小文件，串行队列处理。重启可读，未结束的旧记录视为中断；损坏记录跳过并提示。仅保存请求 UUID、项目 / 会话 ID、时间、连接 / 模型标识、计数和完成状态，不存正文、工具内容、API Key、访问地址或 OAuth Token。统计不会自动上传。

Chat 流默认请求 `stream_options.include_usage`。旧中转若拒绝此参数，可在该连接关闭“请求流式用量”。不通过自动重发模型请求来探测兼容性，避免额外计费。

## 余额适配

- DeepSeek：官方 `/user/balance`，按返回币种显示，可保留负余额和零。
- SiliconFlow 国内：官方 `/v1/user/info` 的 totalBalance。
- Moonshot 国内：官方 `/v1/users/me/balance` 的 available_balance。
- OpenRouter：先查询 `/api/v1/key` 的 Key 剩余额度；不限额 Key 才尝试 `/api/v1/credits` 的账户总充值减总使用。接口权限不足时显示错误。
- Sub2API：**手动选择后**查询当前 Base URL 同源的 `/v1/usage`；保留路径前缀。仅接受有效、unrestricted 钱包响应，拒绝将套餐 / 限流 / quota 等不同语义当钱包余额；单位不报告时不猜币种。
- 其他服务、没有官方余额文档的站点及 OAuth 连接显示不支持查询。没有统一的“OpenAI 兼容钱包 API”，不会向无关域名发送密钥。

余额服务在原生侧读取现有钥匙串密钥；不复制密钥到设置、网页、统计文件或日志。官方余额固定 HTTPS 目标，中转遵守连接现有 HTTP 授权。所有重定向均拒绝，禁用 Cookie 与磁盘缓存，限制查询响应为64KiB，设置连接超时。成功缓存5分钟，失败缓存1分钟，同一连接 / 地址 / 密钥 / User-Agent / 适配器的并发请求合并。编辑连接或密钥后不会复用不同作用域的余额。

金额先保留 JSON 原始十进制数字，再用 NSDecimalNumber / NSDecimal 运算；不经 double 显示钱数。刷新失败可保留上次结果，但明确标记过期和更新时间。不支持 / 查询失败不能显示成余额0。余额不参与模型切换，不改变已有审批。

## 参考与来源

只研究结构，Objective-C 实现独立编写；没有复制 Swift / Rust / TS 代码或预置人设文本，没有新增第三方依赖。

- Codex-X，MIT，研究快照 `1a0ae707c6efde28727c0e4448d53dc262720bad`：`apps/desktop/src/pages/UsageStatisticsPage.tsx`、`usageTypes.ts`、`src-tauri/src/usage.rs`、`provider_balance.rs`。参考逐请求归因、日期分组、余额适配 / 缓存 / 状态表达；Dylix 不采用其 Codex rollout 文件扫描器。
- https://github.com/yynxxxxx/Codex-X
- https://api-docs.deepseek.com/api/get-user-balance
- https://github.com/siliconflow/siliconcloud/blob/main/openapi.yaml
- https://platform.moonshot.cn/docs/api/balance
- https://ai.google.dev/api/generate-content#UsageMetadata
- OpenRouter / Sub2API 响应结构与 Codex-X 对应适配器交叉核对；本机访问 OpenRouter 文档被403拒绝，未将其列为已在线验证的账号接口。

## 验证记录与边界

- `tests/UsageRun.py`：28项，四协议计数、重复帧、缓存加权、真实零、缺失数据、重启、中断、损坏记录与目录边界。
- `tests/UsageRuntimeRun.py`：真实 Runtime 配合测试传输器，多轮请求只记一次、切换连接后归因、取消保留已报告用量。
- `tests/BalanceRun.py`：45项适配 / 金额 / 非法响应检查；真实 URLSession 连接本地 HTTP 测试服务，验证成功与失败缓存、刷新保留旧余额、响应上限、重定向拒绝、4个并发调用只发1次请求。只使用不可用的 fixture 密钥。
- `tests/AITransportNetwork.py`：119项，包含流式 usage 参数和显式关闭、Responses 未完成及 Anthropic 上限帧先保存用量。
- 既有回归：工具348项、工具注册174项、上下文投影58项；上下文 Runtime、人设 Runtime、Agent Runtime、构建任务预算 / 会话生命周期、注册表 Runtime 均通过。
- iOS18.3 模拟器原生统计页：12项，日期零点、7 / 30天、自定义区间、会话 / 模型 / 连接分组和会话隔离。浅色、深色与明细、日期选择、余额过期提示进行界面检查。
- iOS15最低目标的模拟器和arm64设备版编译、IPA结构与签名检查见交付测试JSON。

**尚未验证：**本轮没有使用用户真实密钥逐家请求线上钱包，也没有冒充真实线上消耗。官方接口的账号权限、非标准中转响应及真机上的交互仍需实际账号验收。统计样例只在显式模拟器测试启动参数下生成，正式启动没有模拟用量或余额。
