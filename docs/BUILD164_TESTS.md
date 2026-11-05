# Build164 验证记录

日期：2026-11-04。版本 1.0.7（164）。

## 新增测试

- `tests/ToolRegistryRun.py`：159 项通过。覆盖完整声明、A/B/C 默认值、独立模块开关、缺少真实编译资源、有效输入 ID 枚举、撤权、原始与当前 schema 交集、严格参数类型、C 人工确认/拒绝/重放/过期/开关撤销、目标替换、符号链接与日志分页、拒绝 C 写工具、审计及能力失效。
- `tests/ToolRegistryRuntimeRun.py`：10 项实际 AIRuntime 测试通过。覆盖有效 B 读取、发送后撤权、伪造 ID、C 逐次确认与取消、等待时关闭隔离档、项目记忆与技能开关。
- `tests/ToolRegistryIOSRegression.m`：iOS18.3.1 模拟器 25 项通过。检测实际嵌入编译器/LLD/SDK资源、真实目录授权/撤销、实际 Share 快照、运行时下发过滤、独立开关、本地记忆保留、浏览器执行端拒绝、Remote 敏感字段剔除、关闭队列后直接构建及并发拒绝。
- 原生设置页目视检查通过：A 五开关、B Remote 默认关闭、C 默认关闭、审计入口与精确目标登记；截图保存在交付目录。

测试过程中修正两处回归：普通文本快照的空 `binaryInputID` 不再误判为失效二进制；没有技能元数据时不再插入额外空 system 消息，人设原注入结果保持一致。

## 已有能力回归

- 通用 Agent：112 项通过；提供商与流式协议：100 项、0失败；原项目/Git工具：302 项通过；静态 Web 工具：51 项通过；developer prompt：52 项通过。
- 人设持久化、内置库（36项及新进程）与实际 runtime 注入回归通过；长工具循环、7项导航生命周期保护和会话上下文压缩/公开历史隔离测试通过。
- 再次执行 `AgentIOSRegression.m`：27 项、0失败。真实本地 HTTP MCP initialize/list/call、SSE持久连接、只读授权及写参数拒绝；临时 WKWebView 提取JS正文与禁用表单；队列串行/取消/持久化；模拟器钥匙串及OAuth刷新/退出夹具。
- 主 App 和 Share Extension 两种版本均使用 iOS26 SDK、最低 iOS15 编译成功。Activity 桥接和 widget 沿用 SDK18.2 / 最低16.2。内嵌插件默认SDK16.4保持原值。
- 两份 IPA 校验版本、arm64、SDK、最低系统、UUID、SHA-256、正式资源、许可证、发布/开源功能差异，并排除模拟器测试入口。
- 交付前校验发现公共源码同步覆盖了发布版的反馈和Telegram入口；已恢复发布版专用入口、图文反馈代码及原端点，重新编译发布包。模拟器确认关于分组依次为关于Dylix、反馈与建议、Telegram频道、项目开源地址、软件许可证；反馈多行页面已目视检查，本轮未向机器人发送测试消息。
- 默认 developer prompt、原工具箱、binary_inspect、附件存储、目录授权、两处审批策略及 Persona 内置库，两个工作树均与修改前8份SHA-256一致。未加入数据清空或重置迁移。

## 验收边界

Foundation 的 C 档测试使用本机临时精确目标；模拟器测试使用测试授权和短执行器。它们证明注册表、竞态检查及路径边界逻辑，不证明签名真机或越狱设备的外部路径权限。

签名真机 A 档、越狱真机手动登记与逐次原生确认、iOS15兼容运行、真实服务商/MCP服务器、锁屏后台、LiveActivity和通知仍需对应设备/账号验收。iOS SDK 编译通过不等同真机全部运行通过。C 档没有写操作，未宣称 C 写入快照验收。

OAuth测试使用模拟器钥匙串和HTTP响应夹具，没有使用用户真实账号。MCP使用本机Python标准库HTTP服务；JS浏览器使用动态测试页面。以上测试入口及夹具凭据均不进入设备IPA。详细账号和后台边界继续见 [Build163记录](BUILD163_TESTS.md)。

## 复现

```sh
python3 tests/ToolRegistryRun.py
python3 tests/ToolRegistryRuntimeRun.py
python3 tests/AgentRuntimeRun.py
python3 tests/AgentExtensionsRun.py
python3 tests/provider_v4Run.py
python3 tests/PersonaRun.py
python3 tests/PersonaBuiltinsRun.py
python3 tests/PersonaRuntimeRun.py
python3 tests/AIRuntimeBudgetRun.py
python3 scripts/test_developer_prompt.py
python3 tests/AIWebToolsRun.py
python3 scripts/build.py --simulator
# 安装模拟器App后，启动参数 --registry164-tests；结果在Documents/registry164-tests.json
python3 tests/AgentHTTPFixture.py
# HTTP夹具运行期间，启动参数 --agent163-tests；结果在Documents/agent163-tests.json
python3 scripts/build.py --sdk-root /absolute/path/iPhoneOS26.0.sdk
```

交付目录包含测试日志、两份模拟器JSON、保护文件摘要、截图、安装包清单及SHA256SUMS。安装包均为待重新签名IPA；本次没有上传GitHub。
