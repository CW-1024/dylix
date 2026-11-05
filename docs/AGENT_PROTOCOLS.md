# Agent 扩展接口 · Build163

原TFAIToolbox schema、binary_inspect和审批入口未修改。以下是runtime的独立扩展目录。

- `agent_skill_read({id:string})`：精确ID来自清单，返回正文、readOnly=true、scriptsExecuted=false；只读、无脚本执行。
- `web_browse({url:string})`：仅在原联网工具开关开启时注册，返回title/url/text/links/readOnly/source；公开网页校验、临时WebKit、无自动登录/表单/下载。
- `mcp_<server-prefix>_<normalized-name>_<hash>({...})`：根据已发现schema映射原工具名，名称归一化并带摘要，兼容常见带点或长工具名；只注册用户允许且当前会话开启的只读工具。返回远端content/isError、source=remote-mcp-reference-data、localWritesPerformed=false。

HTTP MCP使用POST JSON-RPC2.0，协商2025-06-18 Streamable HTTP，逐次执行initialize、notifications/initialized、tools/list、tools/call。会话头存于内存，POST重定向被拒绝。JSON/SSE按匹配ID接收；SSE收到结果立即完成，不等待服务端关闭；累计响应最大8MB。

`TFAIRegistry`读取声明并提供provider/wireProtocol/模型族档位与实测能力标题；`TFAIOAuth`提供login/credential/logout。OAuth仅把临时访问凭据交给传输层构造官方请求头，连接JSON不含访问/刷新令牌。

`TFAIAgentContext`提供skills/metadata/readSkill/installSkills、memory/saveMemory、compact。saveMemory使用expected内容指纹拒绝冲突，原生UI复用Git写租约。compact只返回缩短的请求数组，完整公开历史由runtime单独保留。

`TFAIBuildQueue`提供enqueue/cancel/tasks。executor接收progress(stage,fraction)及done(result,error)，所有队列状态在主线程更新。队列复用StudioEditor构建、TFAIBackground、LiveActivity与本地通知；状态机为queued→running→completed/failed，取消为queued→cancelled或running→cancelling→cancelled。进程重启的未完成状态变为interrupted；原生确认新的构建后根据指纹复用检查点，不恢复旧审批。
