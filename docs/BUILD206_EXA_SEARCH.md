# Dylix 1.0.9 · Build 206 — Exa 联网检索

1. AI → 联网检索新增 Exa API 密钥和搜索引擎选项；填写密钥后，将搜索引擎切换为 Exa。
2. 现有 web_search 返回真实标题、来源链接和正文摘录；本机、Remote 与 FLEX AI 复用同一设置。保留 DuckDuckGo、Brave 和 GitHub 原配置。
3. 每次最多 6 条结果，每条正文最多 1,800 UTF-8 字节，明确标注为摘录；认证、额度不足和限流独立报错，不静默切换搜索服务。
4. 密钥保存在本机钥匙串，只传给 Exa 官方固定 HTTPS 接口；认证请求禁止重定向。既有人设、项目及插件包未改动。

## 接口与数据流

- App 工具接口保持 `web_search({"query":"搜索词"})`，schema 不增加密钥参数。
- 配置键 `TFAI.Web.SearchProvider=exa`；钥匙串既有服务 `com.xuegao.tweakforge.web.v1` 下新增独立 `exa` 账户。API 密钥不进入 UserDefaults、模型上下文或日志。
- 请求 `POST https://api.exa.ai/search`，鉴权头 `x-api-key`，JSON：`query`、`type:auto`、`numResults:6`、`contents.text.maxCharacters:1800`。
- 响应规范化为 `query/provider/results/retrievedAt/truncated/note`。每条结果含 `title/url/snippet/content/excerpt/truncated`。标题限 300 字节，摘要限 320 字节，正文限 1,800 字节。只保留符合既有公开 HTTPS 链接规则的来源。
- Exa 内容可能已由服务端截取，因此始终标注 excerpt；truncated 表示本地进一步裁剪。需要继续核对时读取来源；web_read 仍为既有静态读取，不保证取得 JS 网页全文。
- 本期仅搜索和正文摘录，不接入 Answer、研究 Agent 或监控接口。选择 Exa 可能产生其账户用量；密钥保存不自动发测试请求。

## 参考与实现

依据官方 exa-labs/exa-py 的接口协议，提交 8ca7b446a18f3c6db52327c5544e868ca628d599，exa_py/api.py；本地 Objective-C 独立实现，未引入或复制 SDK。官方文档站在本环境返回 403，使用官方源码复核请求协议。

## 验证记录

- 真实 NSURLSession + NSURLProtocol 本地 fixture：77 项通过，覆盖原有 DuckDuckGo/Brave/GitHub、Exa POST/鉴权/UTF-8 限制/错误/取消/禁用/重定向。
- 工具注册表 174 项、上下文投影 121 项、token 格式 20 项通过。
- 私有版及开源版 iOS 设备目标编译通过；IPA 完整性、原有人设和 FLEX 资源哈希、App/扩展版本及 ad-hoc 代码签名检查通过。
- 未提供 Exa 密钥：未进行真实 Exa 账户请求，不将 fixture 当作真实在线成功；未做实机设置页点击及跨设备会话测试。
- 复验命令：python3 tests/AIWebToolsRun.py；python3 tests/ToolRegistryRun.py；python3 tests/ContextProjectionRun.py；python3 tests/UsageFormattingRun.py。
- 实测步骤：填写 Exa 密钥，切换 Exa，开启联网检索，让 AI 搜索一个明确问题，核对返回的来源链接；再分别通过 Remote/FLEX 会话发起搜索。错误密钥应返回认证错误，不能切到其他服务。
