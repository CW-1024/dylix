# Build165 修复与验证记录

日期：2026-11-04。版本：1.0.7（165）。本地交付，未推送 GitHub。

## 导入崩溃证据

用户提供的 `TheosMobileCompiler-2026-11-04-055347.ips` 实际运行版本为 1.0.7（160）。主镜像 UUID `535BA470-5198-3D59-811A-6C04F0B58D5E`，与保存的 build160 发布 IPA 一致。

主线程 `EXC_BAD_ACCESS / SIGSEGV`，地址 0；栈为 `objc_setAssociatedObject +88 → TFStudioImportReceived +168 → TFReceiveController tableView:didSelectRowAtIndexPath: 的 dismiss completion`。故障寄存器 x0 为 0。旧接收页仅取 `self.presentingViewController`；push 进入的接收历史页没有 presenter，子页面的 presenter 也可能归属外层导航容器。随后给空 host 绑定 importer 触发崩溃。这份日志支持页面归属错误，未发现证据指向编译器或项目源码。

修复遍历真实模态容器，分别处理 modal 和 pushed 页面；导入前保留有效导航锚点。Studio 导入入口增加空 host、非本地 URL 防护，导入器关联到稳定容器，阻止重复导入，并在成功后释放。原有压缩包检查、文件导入和路径安全策略保留。

## 新增验证

- `tests/Integration165IOSRegression.m`：13 项、0失败。实际 iOS 模拟器运行接收页 delegate 和生产导入器，完成弹窗源码、push 历史源码、ZIP 项目三条导入，检查编辑器内真实文件和 importer 释放；检查空 host / 非本地 URL 防护。另用真实 NSURLSession 验证 HTTP 官方兼容端点夹具的模型发现及对话 User-Agent。
- `tests/provider_v4Run.py`：125 项、0失败。新增 25 项覆盖 User-Agent 默认/标准化/非法字符、HTTP 默认拒绝/显式允许/撤销、OAuth HTTPS、真实 transport HTTP 请求与发现、80/443/自订端口同源重定向、UA 持久化及能力结果失效。原 100 项服务商协议回归全部通过。
- `tests/ToolRegistryRuntimeRun.py`：12 项实际运行时测试通过。新增 Remote 不下发 C 档 schema，已有 C schema 的远程调用同样被 preflight 拒绝；浏览器确认不替代手机隔离档确认。
- 人设页使用 Dylix 金色强调、纸感浅色/石墨深色，改为“运行状态 / 配置库 / 检查与管理”；配置选择按钮与总开关分离。模拟器目视检查两主题及新增编辑页，保留原 JSON、内置库、选中状态与注入引擎。

## 回归

- 分层工具注册表159项、Agent112项、Web工具51项、developer prompt52项通过。
- Persona 持久化、内置库、新进程恢复和真实 runtime 注入通过；长工具循环、导航生命周期及压缩历史隔离通过。
- Remote HTTP 原生服务集成94项通过，包括鉴权、路径、CSRF、上传/下载、项目/编辑/构建/Git/AI入口、WebDAV方法、撤权、锁屏保护和模拟器前后台生命周期。
- Remote 真实HTTP浏览器回归117项通过（Chrome 157）：模型切换、流式/思考、配置面板、无密钥元数据、五模块与隔离档边界、编辑保存/撤销重做/自动保存、上传/下载及本地资源。
- Agent模拟器27项和注册表模拟器25项、均0失败；重新覆盖OAuth钥匙串刷新/退出夹具、HTTP MCP、WKWebView JS正文及队列。
- 原生连接编辑页目视确认User-Agent入口和默认关闭的HTTP开关，未填写真实密钥或发送真实服务商请求。
- 主 App 与 Share Extension 使用 iOS26 SDK，最低 iOS15；Activity桥与widget沿用SDK18.2/最低16.2。内嵌插件默认 SDK16.4 保持原值。
- 两版本保留差异：发布版含反馈、Telegram、开源地址和GPL许可证；开源版含开源地址和GPL许可证。两包均排除模拟器回归入口。

## 传输与远程接入

见 [连接传输](CONNECTION_TRANSPORT.md) 与 [Remote Agent 衔接](REMOTE_AGENT_BRIDGE.md)。HTTP本身为明文；App ATS 传输层允许用户配置的 HTTP 域名，实际模型请求另外执行每连接默认关闭的 HTTP 授权。OAuth保留HTTPS规则，不跳过证书校验。

## 验收边界

以上证明本机编译、模拟器和本地回归服务器上的行为。用户设备的原始项目再次导入、iOS15真机、实际服务商对自订User-Agent的接受情况、Wi-Fi长时间后台/锁屏、真实OAuth账号、越狱精确目录权限仍需对应设备验收。未使用真实API密钥或向反馈机器人发送消息。
