# Build197：余额自动识别与硅基流动查询诊断

版本1.0.8 / Build197，FLEX仍为1.0.0 / Build196。没有修改模型调用、用量计数、人设、技能、记忆、项目文件或鉴权存储。

## 硅基流动HTTP410的核查结果

用户提供的 `https://api.siliconflow.cn` 与 `https://api.siliconflow.cn/v1` 都应查询 **GET https://api.siliconflow.cn/v1/user/info**。旧版和Codex-X都使用此地址，不能通过给Base URL增删`/v1`来解决这个HTTP410。

2026-11-05读取硅基流动官方 `siliconcloud/openapi.yaml`：GET `/user/info`，服务器前缀`https://api.siliconflow.cn/v1`，余额字段`data.totalBalance`，成功码20000。未提供密钥的线上访问返回HTTP401及API码30014，而非410；这只证明未授权请求的表现，不证明该用户的密钥、账户权限、网络或网关能成功查询。

本轮没有索取或使用用户密钥，没有复现其带有效Key的HTTP410，也不将接口已废弃、密钥权限或网络网关中的任一项当作确定根因。未添加未经证实的备用官方地址，不把密钥转交其他站点。

已修复另一个响应兼容问题：官方OpenAPI未将顶层`status`标记为必填；现在硅基流动成功码20000且有合法`totalBalance`时允许缺少该字段，显式false / 错误类型 / 错误成功码仍拒绝。这个JSON解析修复不等于修复HTTP410。

## 自动识别方式

以前自动只覆盖官方服务，中转站要手选Sub2API；现在默认自动覆盖两类：

1. 官方域名、受支持API前缀、HTTPS443匹配后，使用固定的官方余额接口。
2. 其他兼容站点仅请求**用户保存的当前API同源**`/v1/usage`。保留路径前缀；支持Base URL填写完整`/chat/completions`、`/responses`、`/messages`或`/models`时先移除接口后缀。

保留“不查询”开关及原Sub2API选项；旧连接不需重新保存或重新填接口。HTTP仍须遵守连接已有明确授权，OAuth不向API-Key余额接口发送token，已知但不支持余额的官方服务不当中转站探测，不跟随重定向、不携带Cookie、响应限制64KiB。

识别到的余额必须通过对应响应结构校验。Sub2API只接受有效的`unrestricted`账户钱包，不把套餐、rate limit或未说明语义的quota字段当金额；零余额有效，单位未报告时不猜币种。404 /405 /410 /501以及不支持的钱包结构明确标记不可查询。未知余额不显示为0。

## 与Codex-X对照、接口范围

本轮重新读取Codex-X `main` 的 `apps/desktop/src-tauri/src/provider_balance.rs`，其适配范围也是以下五类，并不是能够从任意OpenAI兼容站点自动推导余额接口：

- DeepSeek：GET `https://api.deepseek.com/user/balance`，`balance_infos[].total_balance`，保留服务商报告的CNY / USD。
- 硅基流动国内：GET `https://api.siliconflow.cn/v1/user/info`，`data.totalBalance`，CNY。
- Kimi国内：GET `https://api.moonshot.cn/v1/users/me/balance`，`data.available_balance`，CNY。
- OpenRouter：GET `https://openrouter.ai/api/v1/key`，优先显示`data.limit_remaining`为Key剩余额度；只有明确返回null的不限额Key才查询`/api/v1/credits`，账户钱包为`total_credits - total_usage`。权限不足如实显示失败。
- 其他站点：当前API同源Sub2API `/v1/usage`，读取`balance`，缺失或null时兼容`remaining`，不能用另一个非零字段覆盖真实零。

OpenAI、Anthropic、Gemini、xAI、通义千问等没有在本模块中获得可验证的统一账户钱包API，不虚构支持；国际Moonshot / SiliconFlow也不擅自套用国内币种。模型列表接口`/models`不能提供或推算余额。Codex-X的自动识别同样是域名 / 路径匹配加响应校验；本轮Objective-C独立实现，未复制Rust代码，无新依赖。

## 诊断入口

余额与额度页面每个已请求连接右侧增加信息按钮，显示实际GET地址、适配器、HTTP状态、可识别的数字API码与网络错误码，支持复制详情。不保存 / 复制密钥、响应正文、服务器任意错误文本、Cookie或token。旧余额刷新失败仍保留且标记过期；成功刷新清除旧错误与“不支持”标记。失败缓存一分钟，成功缓存五分钟，并发同连接查询合并。

该用户更新后可点余额右侧信息按钮、复制详情；特别是HTTP410对应的**实际请求地址和API错误码**可帮助区分服务商 / 网关表现。没有可验证证据时不通过重复请求、切换模型或更换服务商来掩盖错误。

## 测试与边界

- `tests/BalanceRun.py`：91项适配 / 数值 / 错误检查；真实URLSession连接本机HTTP服务器，另检查自动识别、完整Responses地址、HTTP410 /404、套餐拒绝、失败后恢复、缓存、single-flight、重定向拒绝与响应大小限制。
- `tests/provider_v4Run.py`：100项通过，验证现有协议、模型发现及请求行为。
- `tests/UsageRun.py`：28项通过，验证统计计数未改变。
- 模拟器`--ai-chat93-test --balance197-fixture`：8项生产UIKit与真实协议校验检查，包含410诊断入口、实际地址、API码和脱敏；样例明确标记非真实账户。测试分支只编入模拟器。
- Dylix最低iOS15模拟器和arm64设备编译、IPA结构、资源哈希及签名见`BUILD197_TESTS.json`。

线上有效Key余额仍待真实账号验收；本轮没有执行收费模型请求，没有将fixture中的HTTP410当作用户问题已复现。此版本交付的是自动识别、响应兼容和可定位的失败详情，无法仅凭当前证据保证该用户HTTP410已消失。

来源：

- https://github.com/yynxxxxx/Codex-X/blob/main/apps/desktop/src-tauri/src/provider_balance.rs
- https://github.com/siliconflow/siliconcloud/blob/main/openapi.yaml
- https://api-docs.deepseek.com/api/get-user-balance
- https://platform.moonshot.cn/docs/api/balance
- https://openrouter.ai/docs/api/api-reference/api-keys/get-current-key
