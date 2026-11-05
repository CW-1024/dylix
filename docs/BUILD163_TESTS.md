# Build163 测试与验收边界

日期：2026-11-04。版本1.0.7（163）。主App/分享扩展使用iOS26.0 SDK，最低iOS15；Activity桥接及widget沿用18.2 SDK和16.2最低版本。内嵌插件默认SDK16.4未变。

## 已执行并通过

- `tests/AgentExtensionsRun.py`：112项。原8个服务顺序/ID保留，新增Kimi/xAI官方模型端点及Chat请求；五项能力unknown；现有思考档位；四份技能按需正文/同名内容保留/越界拒绝；记忆读写/指纹冲突；本地摘要与最近8轮；MCP只读分类/stdio拒绝；检查点哈希/恢复/输入变化失效（含隐藏目录头文件）。
- `tests/provider_v4Run.py`：100项，0失败。原Chat/Responses/Anthropic/Gemini wire payload、DeepSeek/通义思考参数、图像/工具探测、流式协议和连接隔离回归。
- `tests/AgentRuntimeRun.py`：实际AIRuntime注入夹具，确认缩短请求上下文后完整公开聊天历史仍保留，连续请求没有重复历史前缀。
- `tests/AgentIOSRegression.m`：iOS18.3.1模拟器27项，0失败。真实模拟器钥匙串读写；20个并发过期请求共用一次刷新；退出与延迟刷新竞态；拒绝跨服务商或改端口令牌转送；HTTP MCP真实initialize/initialized/list/call；逐项授权/禁用写工具/写参数拒绝；重新导入撤销缓存与会话授权；SSE在服务保持连接时及时完成；临时WKWebView提取JS生成正文和链接、动态表单禁用；队列串行、取消排队、运行中取消及完成状态持久化。
- 内嵌Clang/LLD实际示例项目构建成功。第二次构建复用1个校验成功的目标文件，重新链接及打包；4条命令全部成功。报告记录`reusedCheckpoint`，不是以UI文字推断成功。
- 既有人设持久化/内置库与实际runtime注入回归通过；developer prompt测试52项、原项目/Git工具测试302项、静态网页工具测试51项通过；长工具循环及7项导航生命周期保护通过。
- 原生UI实查：11项服务菜单含Kimi、xAI、自定义正式入口；通用Agent页面、文本技能与独立模块入口使用原生样式。Kimi官方Base URL确认；没有填写真实密钥或发送真实模型请求。
- 两种SDK26设备构建通过。IPA清单另记录Mach-O SDK/最低系统/架构/UUID、资源逐字节一致、版本号与测试夹具排除、反馈/TG版本差异、文件SHA-256。
- 默认developer prompt、binary_inspect、原TFAIToolbox、两处审批实现、原Personas/Builtins.json：两种版本均与修改前6项SHA-256一致。没有数据清空/重置迁移。

## 夹具的准确含义

OAuth刷新/退出测试使用真实模拟器钥匙串，但HTTP返回由测试子类提供，未进行真实账户登录或远端吊销。MCP使用本机Python标准库HTTP服务，SSE响应后保留连接；属于真实HTTP传输测试，不等同于所有第三方服务器兼容认证。浏览器使用动态JS测试页面，并在模拟器测试内临时允许该127.0.0.1夹具地址；正式包保持原公开网页URL检查。队列用短执行器验证状态机，另用真实内嵌编译器验证编译与检查点，二者分别记录。

模拟器测试入口、URL校验替身、测试Keychain凭据与夹具页面代码均不进入设备IPA。没有使用用户真实模型密钥。

## 仍需真实账户/真机验收

- Kimi/xAI API key连接、真实官方模型发现及会话切换。已验证端点/请求/解析及模型选择路径，真实调用权限、额度、网络连通性需账号侧验证。
- Google iOS OAuth客户端需绑定自己的App Bundle ID，实际ASWebAuthenticationSession同意、回跳、过期刷新及远端吊销需真实账号验证。
- OpenRouter官方PKCE返回API key，不提供此流程的refresh/revoke接口；App退出清除本机，远端key须用户在官网撤销。这一项不冒充自动吊销成功。
- iOS15、iOS26/27真机前后台/锁屏、音频中断、系统回收、LiveActivity显示和通知点入，需安装后验证。模拟器不证明永久后台运行。
- 原生会话真实跨服务商切换后的长历史/图像/工具兼容性、第三方MCP服务以及真实JS网站仍需各自验证。失败应保留原连接并显示错误，不静默换模型。
- 长会话采用本地按角色截取记录与最近8轮上下文，并非语义模型摘要；完整聊天历史保留，摘要不自动上传。

## 复现命令

```sh
python3 tests/AgentExtensionsRun.py
python3 tests/AgentRuntimeRun.py
python3 tests/provider_v4Run.py
python3 tests/PersonaRun.py
python3 tests/PersonaBuiltinsRun.py
python3 tests/PersonaRuntimeRun.py
python3 tests/AIRuntimeBudgetRun.py
python3 scripts/test_developer_prompt.py
python3 tests/AIWebToolsRun.py
python3 tests/AgentHTTPFixture.py
# 另一终端构建并安装模拟器App，启动参数 --agent163-tests
python3 scripts/build.py --simulator
# 构建真机：显式提供iPhoneOS26.0.sdk路径；按BUILDING.md准备原有依赖
python3 scripts/build.py --sdk-root /absolute/path/iPhoneOS26.0.sdk
```

Git工具回归需要`build/git-macos/libgit2.a`；本次使用已构建的发布工作树libgit2，原工具/权限源代码哈希一致。详细日志、27项JSON与两次实际构建报告保存在交付目录tests/下，保护文件摘要见protected-after.json。
