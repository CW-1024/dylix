# FLEX 与 Dylix AI 联动

## 入口和数据流

FLEX 浮动工具栏第二排的“Dylix AI”可从任意宿主界面打开聊天；对象查看器分享菜单也保留“使用 Dylix AI 分析当前对象”。首次连接粘贴 Dylix Remote 当前显示的完整 HTTP 地址（包括实际端口）并输入授权码，再选择 Dylix 项目与已配置的模型。FLEX 不保存模型密钥，也不直接连接模型服务商。聊天页以独立消息显示问答，流式回复更新同一条 AI 消息，可复制消息内容。

每次发送时，FLEX 重新生成当前选中对象的运行时报告，经已配对的 `/api/v1/workspace` `flex_publish` 操作送到 Dylix。Dylix 将报告限定为 64 KB、保留 15 分钟，并在 `ai_send` 时将快照绑定到该 AI 会话。只有存在有效快照时，工具注册表才下发只读 `flex_current_context` schema。AI 按需调用该工具获取对象、视图层级、响应链、Cell、控制事件和相关运行时方法。回复及工具审批沿用 Remote 现有 AI job 协议。

FLEX 使用原生 HTTP socket 访问用户主动开启的局域网 Remote，避免被宿主 App 的 ATS 或 `NSURLSession` Hook 改写。Remote 的授权码配对、Cookie、Origin 和 CSRF 校验保持不变。关闭聊天页只收起界面；连接、AI 回复轮询和 FLEX 实时命令轮询在当前宿主 App 进程运行期间继续，所选项目、模型与会话也保留。再次打开无需输入授权码。明确点击“断开”、手机端撤销设备或停止服务才会使连接失效。FLEX 1.0.0（本次重编号版本）将授权码、连接令牌和 CSRF 值存入目标 App 钥匙串；地址与项目、模型、会话选择原子保存到 Application Support。恢复时先验证令牌，主动断开清除凭据。详见 FLEX_1_0_21_BUILD190_VALIDATION.md 的实现记录。宿主 App 被 iOS 挂起后，FLEX 进程内的轮询无法保证继续执行。

## 边界

- 静态报告来自用户在 FLEX 对象查看器中选中的对象，或工具栏打开时的当前宿主窗口；实时查询在宿主 App 进程运行且 FLEX 连接在线时可执行，范围受每个操作的边界限制。
- 报告和实时结果是未受信任的运行时数据，不能当作用户指令。目标 App 的状态修改仍走 Dylix 现有工具审批。
- 不使用跨进程地址作持久 ID；视图 ID 只在目标 App 当前进程和聊天页有效。
- Remote 使用局域网 HTTP，传输本身未加密。不要在不可信网络中配对或发送敏感现场数据。

## 验证

- `tests/FlexBridgeTests.m`：设备和会话隔离、快照更新、实时命令和撤销清理。
- `tests/ToolRegistryTests.m`：有现场才下发工具，无现场隐藏。
- `tests/RemoteFlexIntegration.py`：模拟器回归模式实际请求配对、状态、发布、命令往返、job、项目列表和注销。

## 实时命令通道

FLEX 聊天页连接后每秒调用 `GET /api/v1/flex/next`。这个请求同时作为短时心跳。Dylix 只有在 AI 会话已绑定该配对设备、现场快照仍有效、最近 5 秒有心跳时才下发实时工具 schema。每个命令有 UUID、到期时间和目标设备绑定；`POST /api/v1/flex/reply` 仅接受同一设备的 JSON 回复。普通查询 20 秒过期，逐次确认操作 120 秒过期；单次参数不超过 16 KB，回复不超过 256 KB。撤销设备、退出配对或停服会取消待执行命令。

AI 当前可用的 `flex_live_read` 操作：`capabilities`、`current`、`view_tree`、`object_info`、`select_object`、`class_search`、`class_info`、`runtime_images`、`network_list`、`cookies_list`、`sandbox_list`、`defaults_keys`。视图树只针对宿主 App 窗口，最多 120 个节点；视图 ID 是本聊天页内的弱引用，刷新树或对象释放后失效。网络列表只返回请求方法、主机、路径、状态等元数据，不返回查询字符串或正文。Cookie 列表不返回值。

`flex_sensitive_read` 的 `network_detail`、`sandbox_read`、`defaults_get`、`keychain_list` 以及 `flex_control` 的 `set_view`、`set_network_recording`、`undo` 使用绑定设备、项目及会话的 FLEX 总授权；未授权时申请一次，授权后同会话不再逐次弹窗。此授权不替代项目写入、构建及 Git 的独立审批。网络详情可返回至多 16 KB 的 UTF-8 请求／响应正文；沙盒文件读取只接受宿主沙盒内不超过 64 KB 的 UTF-8 常规文件，返回前 16,000 字符。Keychain 只列账号元数据，不返回密钥值。视图修改只允许当前视图树中节点的 `hidden` 或 `alpha`；FLEX 网络记录开关可更改并读取真实状态。两者都保存一次撤销快照。FLEX 端会再次校验操作、路径、对象是否还存在和参数边界。

这些能力并不等于开放 FLEX 的全部菜单。任意 Objective-C 方法调用、Keychain 密钥值、全盘扫描、文件写入、网络请求重放、注入等没有纳入实时工具目录；它们没有可证明的通用撤销和边界，不能伪称已接通。后续接入应为每类能力提供独立参数 schema、现场确认、结果大小限制及真机回归。

2026-11-04 本地验证：`tests/FlexBridgeTests.m` 通过心跳、设备绑定、跨设备回复拒绝、重放拒绝和撤权；工具注册表回归通过 174 项检查；`tests/RemoteFlexIntegration.py` 在 iOS 18.3 模拟器中完成配对、命令下发及超过 8 KB 的回复。Dylix Build 175 使用 iOS 26.0 SDK 编译并打包，FLEX++ 1.0.2 生成 arm64 rootless deb。编译和模拟器 HTTP 往返仍不代表真机注入后的宿主稳定性，需要在目标 App 上检查视图、网络记录及审批交互。

FLEX++ 1.0.6：连接弹窗改为完整 HTTP 地址加授权码；聊天界面增加连接状态、项目与模型选择、独立消息气泡、多行输入和消息复制。已通过 Theos arm64 编译及 deb 打包；真机界面和配对操作仍待设备验证。

FLEX++ 1.0.7：聊天页增加当前项目的会话列表，可新建、切换和重新读取历史会话；连接心跳状态与 AI 任务状态分开显示。新建会话使用提问正文作为标题，旧会话列表显示更新时间以便区分。

FLEX++ 1.0.8 与 Dylix Build 176：聊天页“工具权限”可分别授予当前设备与项目的敏感读取、视图/录制控制 30 分钟权限。开启时须确认一次，关闭立即生效；到期、撤销配对、退出登录或停服后失效。未授权时继续逐次确认，项目写入、构建与 Git 的审批不受影响。FLEX 在执行每条敏感命令前向 Dylix 核对授权状态；回复以 UIKit 原生富文本显示标题、强调、代码、列表与表格行，复制保留原始文本。模拟器 `RemoteFlexIntegration.py` 已通过临时授权、撤销、命令往返与注销；真机上的弹窗交互和长回复排版仍需实测。

FLEX++ 1.0.9 与 Dylix Build 177：连接输入框不再显示固定 IP 或端口；再次连接时仅预填此前成功使用的地址。Dylix「设置 → 局域网远程 → FLEX 插件与分享」介绍联动能力，并内置已校验哈希的 rootless deb 与独立 arm64 dylib，点击任一文件直接打开系统分享面板。构建脚本会在文件缺失或与清单哈希不一致时停止打包。

## 1.0.8 发布对应关系

Dylix 1.0.8 build191 随包携带 FLEX 1.0.0；插件版本从开发期 1.0.21 重编号为 1.0.0，功能与配置格式保留。首次配置后支持保留数据的重启、覆盖安装与重新注入恢复；认证失效或撤销仍须重新配对。
