# 服务商扩展与通用 Agent（Build163 实施记录）

## 现有入口与边界

- TFAIProtocolCatalog/TFAIEndpoint/TFAIRequestBody：服务目录、端点与四种协议；TFAITransport负责模型发现、分页、能力探测。
- TFAIConnections：钥匙串API密钥；原UserDefaults记录连接、全局默认及项目覆盖。
- TFAIChat/TFAIModels：会话选择连接/模型，runtime固定单次请求快照。
- AIRuntime：固定developer层、Persona组合、工具动态目录与审批；TFAIToolbox原有schema/权限保持原样。
- StudioEditor aiTool/build及CompilerController runProof：真实构建，Git租约保护项目，当前进程编译器串行。
- TFAIBackground/LiveActivity/Notifications：后台与完成提示，可供队列复用。
- 人设、旧技能/记忆、项目文件保留。现有人设库原样保留，本期不添加人设文本。

## 顺序与新增模块

1. Resources/AIProviders声明目录与模型族思考规则；兼容原8个id，新增kimi/xai/custom；testResults为能力证据。
2. TFAIOAuth：官方ASWebAuthenticationSession+PKCE；Google刷新单次化、钥匙串、退出吊销；OpenRouter官方授权换key不虚构refresh token。
3. 会话连接切换验证、服务商/模型/实测能力显示；失败保留旧连接。
4. 项目.dylix/skills元数据目录及按需只读正文；四份独立撰写插件开发技能，不执行脚本。
5. HTTP MCP初始化/工具发现/只读调用，按会话选择；写工具不进入扩展执行路径，仍需使用原工具和原审批。
6. 非持久WKWebView只读正文/链接提取；禁止Agent下载/表单/登录动作、持久Cookie保存和外部scheme。
7. 项目MEMORY.md用户编辑与本地长会话摘要；摘要只落本地，不自动发送给模型。
8. 全局构建队列，原构建入口执行、取消/检查点、后台/LiveActivity/通知及状态页。

## 保留与测试

新增资源/独立存储，不清空旧UserDefaults和用户目录。所有网络错误与OAuth诊断采用固定错误，令牌不进入连接字典或日志。
不改默认developer文本、binary_inspect、原工具定义与写项目/构建/Git审批。
测试覆盖兼容目录、端点、思考映射、能力unknown、OAuth刷新并发与退出竞态、路径穿越、技能按需、MCP只读筛选、浏览器JS、记忆持久化、构建串行/取消，随后SDK26构建两种发行版与模拟器检查。
真实API key和OAuth账户尚未提供，真实联网验收保留为用户端测试，夹具不冒充真实服务成功。

## 参考（结构参考，无Swift代码复制）

OpenMinis commit 1a71df0f381cefde80bf912b723de6f9831bc177：ProviderTypes、ThinkingLevelCatalog、OAuthRefreshSingleFlight、SkillStore、MCPStore、BrowserUseManager。
官方协议依据：OpenRouter OAuth PKCE；Google Gemini OAuth及OAuth2 native-app；xAI Models；MCP 2025-06-18 Streamable HTTP。详细来源在最终测试记录补齐。

## 实施状态

上述模块已接入真实App入口并完成模拟器/SDK26编译。复用路径与操作说明见AGENT_EXTENSIONS.md；验收证据、夹具边界及剩余人工验收见BUILD163_TESTS.md。新增文件集中在App/AI/Agent、Providers目录及Resources/AIProviders、AgentSkills；原审批、二进制分析和默认developer文件SHA-256保持一致。
