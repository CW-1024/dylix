# Dylix Remote 架构与实施方案

## 1.0.7（160）当前实现摘要 · 2026-11-03

本文保留Build148起的事前架构分析与阶段演进记录。当前使用HTTP工作台与独立HTTP WebDAV，默认关闭；授权码直连，设备独立授权。已接通现有项目、文件、编辑、构建、Git、AI、分析与任务入口；网页及Monaco离线打包。自动保存默认开启但保留首次写入授权；文件传输无固定大小上限；导航/文件栏可调整并支持全屏。Remote与AI共用按使用方计数的音频辅助和前台常亮管理。后文TLS及“未来阶段”段落为历史方案，实际接口与验证范围以[最新API](LAN_WORKSPACE_API.md)、[Build160测试](BUILD160_TESTS.md)和[发布摘要](RELEASE_1.0.7.md)为准。

基线：1.0.6（147），2026-11-02。本文件在 Remote 业务代码编写前建立。阶段一能力已扩展为真实项目工作区：项目浏览/编辑、构建任务、Git、AI、二进制分析与 WebDAV 均通过现有手机端业务入口执行。尚未支持的协议细节仍在 API 文档中明确标注，不返回虚构数据。

## 当前架构与真实入口

App 使用 Objective-C / UIKit，无 App 级 Web 前端框架。scripts/build.py 显式列出编译单元，资源目录复制进 IPA；主程序最低 iOS 15。主入口为 App/main.m 的 AppDelegate，TMCStudioRoot 在 Studio.m 创建项目、AI、设置三个 tab。

项目并无第二套数据库：Documents/Projects 存放创建的项目，Documents/Imported-* 为导入项目；MobileCompiler.json 配合 control、过滤 plist 和 Makefile 组成工程元数据。Studio.m 的 TFAIInternalProjects 提供已存在项目的 UUID、名称和内部 root，StudioHome.reloadProjects 复用文件系统及 StudioRecent。对外只使用 UUID，不返回沙盒绝对路径。未来将目录枚举、模板创建/导入和回收站操作从 UI 中逐项提取成共享服务；不重建项目数据库。

编辑器为 StudioEditor。ProjectSafety.m 的 TMCWriteDocument 使用 NSFileCoordinator 和 expected NSData 检查，冲突返回 409；这是手机和浏览器并发编辑的复用基础。未来保存必须同时持有 Git 写租约、验证源文件指纹、建立备份，再调用该接口；不能用裸 NSData 写文件替代。项目拷贝可复用 TMCCopyProject。ProjectTrash.m 与 StudioHome 已有 7 天回收站。

编译入口 CompilerController.runProof（main.m），直接进程内调用 Clang cc1 和 ld64.lld，经 TMCBuildRunning 保护单个构建。后台 worker 执行编译、Logos、SDK 解压、打包；主线程更新 console、完成回调。CompilerController.importedProject / lastBuild / buildCompletion 连接 UI。构建记录在 Documents/Build-*，含报告、命令、provenance、symbols.json 和 .studio-cache-owner.json。SDKResources、OutputNaming、DebPackage、RuntimeDiagnostics、SymbolProcessing.inc 均为真实服务。未来先提取可观察的构建 coordinator 再暴露远程调用；现有 native/AI 构建共用同一把资源锁。当前无安全取消正在执行的任意 cc1 的公共 API，阶段三需要补齐协作取消检查点；不得把隐藏页面或关掉 HTTP 请求当作取消构建。

Git 通过 TMCGitService（libgit2），所有同步 Git 操作在其共享 serial queue；TMCGitLease 协调读写。GitAutomation 保存后/构建后存档。凭据在 Keychain，远程只接收已清洗的 remote 信息。TFAIActionRegistry 和 TFAIGitConflicts 提供操作目录、state_token / fingerprint 校验和确认。Remote 未来使用相同服务和确认策略；push、pull、checkout、删除分支等仍需复核。

AIContracts.h / AIV2Contracts.h 是 AI 的真实跨模块契约。TFAISessions 按 storageProjectID + session UUID 保存会话，summary 与活动时间独立，不能因打开浏览器重排。AIRuntime 负责消息、工具、确认和取消；TFAIToolbox.prepare 仅产生带指纹的提案，execute 再检查。TFAIRuntimePolicy（AIPolicy.h）控制当前会话的临时授权；模型连接 TFAIConnections.secret 读 Keychain，不返回浏览器。阶段四需要抽取会话显示无关的 run owner，把现有事件与 approval 回调桥接到已认证远程客户端，而非另建模型代理或绕过 UI 权限。

TFAISafePath / TFAIAllowedRelativePath / TFAIContainsSecret 是现有源码工具的路径与敏感信息边界。源码工具禁止读取产物和密钥，不能为 Remote 任意放宽：产物下载应另用构建记录授权并限制单一生成目录。附件 TFAIAttachmentStore 管理目录 opaque grant、security-scoped bookmark 与 ZIP 引用；外部目录每次用同一授权接口获取 scope 并在完成后释放，不凭绝对路径读取。TFAISessionResources 和 TFAISessionFiles 共用资源索引。

二进制分析入口 TFAIBinaryStage / TFAIBinaryExecute / TFAIBinaryParse；头文件导出 TFAIClassDumpFile、TFAIClassDumpZip，支持 NSProgress 取消、progress 回调，本机 Rust REipa 执行，不执行上传的二进制。阶段四通过任务适配器复用。

TFAIBackgroundCoordinator（TFAIBackground*）管理 AI 活动生命周期。Remote 使用独立、有限的 UIApplication 后台任务，已有 AI 音频实际播放时观察其状态；采用广播通知，不占用 AI coordinator 的唯一 changed 回调，也不为 Remote 单独启动循环音频。音频结束且宽限耗尽后暂停 listener；返回前台恢复期望开启的 HTTP/WebDAV，保留授权。手动停止会清除期望状态；Wi-Fi IP 改变则停止并要求重开，重新签发匹配 IP 的证书。锁屏 willBecomeUnavailable 通知立即置锁，独立于 UIApplication 属性延迟；状态查询可用，业务与 DAV 返回423。

## 线程与状态

- UIKit 和业务 bridge 的读取/确认：main queue。
- HTTP listener、parser、认证、设备会话、服务状态：Remote 专用 serial queue。
- phase 1 snapshot 由 main 生成白名单缓存，网络队列只读快照，不同步阻塞主线程。
- 未来文件/压缩/分析独立 bounded worker；Git 保持其既有 queue。
- 任何异步回调携带 server generation；停服、重启、撤权后旧回调不再提供数据。
- 每个 HTTP 请求有时间、头部和 body 上限；连接数上限；一次请求一次响应后关闭，不接收管线请求。
- 连接设备数量表示最近 30 秒有认证活动的授权设备数（不是 TCP 请求数），授权列表与在线数分开。

## 依赖与设计系统

已检查 README、CHANGELOG、docs/BUILDING、dependencies.lock.json、THIRD_PARTY_NOTICES。
现有 ios_system / LLVM14 / Logos / libgit2 / libarchive / REipa 不改许可证。第一阶段只使用系统 Foundation、Network、Security、UIKit、CoreImage；新增模块采用仓库 GPL-3.0-or-later，无新增第三方依赖。

评估：BSD sockets 需要自行处理监听与平台路径变更；大型 HTTP 框架会增加依赖；Network.framework 的 C API 在 iOS 12+ 可用，适配现有 Objective-C 与 iOS 15，选用 nw_listener / nw_connection。首期仅 HTTP/1.1，显式拒绝 WebSocket Upgrade；阶段三/四再添加认证事件传输（WebSocket 或 SSE），当前总览采用有限频率轮询。

原生主题 StudioTheme：0 跟随、1 石墨、2 纸感。Gold() 深色 RGB .93/.77/.52，浅色 .43/.31/.13；系统动态 label / secondarySystemBackground；系统字体、16pt 内容、22pt 面板圆角、16pt 栈间距。GlassSupport iOS26 原生材质 + 旧系统 material fallback。
Web tokens：石墨底 #141414 / 纸感 #f5f3ee、暖金 #edc485 / #6e4f21，system Apple/PingFang 字体、12/16/22 圆角、8pt 间距网格。用户明确要求延续原生字体，因此使用系统字体。图标采用本项目统一 inline SVG（自绘），不使用 emoji/CDN。动画只用于短淡入/状态，尊重 reduced-motion。Build149已离线打包Monaco0.52.2（MIT），保留完整许可和worker CSP。

## 新模块与边界

- App/Remote/DXRemoteHTTP.{h,m}：有界 HTTP 解析、Network listener、固定静态资源路由、请求/响应类型。
- App/Remote/DXRemoteAccess.{h,m}：安全随机数、随机/固定码直连配对、会话哈希、CSRF、失败限速、设备撤权、事件日志。
- App/Remote/DXRemoteService.{h,m}：main 业务 bridge、局域网 IPv4 选择、服务生命周期、真实设备快照与原生控制器工厂。
- App/Remote/DXRemoteSettings.m：UIKit 分组设置、启停、端口、IP、QR、复制地址、设备撤权、后台状态、日志。
- Resources/RemoteWeb/{index.html,remote.css,remote.js}：完全离线工作台、配对页、总览、设备信息与退出。通过Workspace bridge调用原生项目、构建、Git、AI与分析。
- tests/Remote*、docs/LAN_WORKSPACE_API.md、docs/LAN_WORKSPACE_TESTS.md：协议、自动检查与验证边界。

## 通信协议与安全设计（Build 154）

Network.framework提供局域网HTTP / HTTP1.1，工作台和WebDAV均使用明文HTTP。Remote不生成证书、不设置TLS identity。钥匙串仍保存固定配对码。HTTP保留所有原有业务能力，传输内容不加密，没有证书信任弹窗，但浏览器可能显示“不安全”。模型连接独立遵循已配置的提供商协议。

随机8位码五分钟有效，授权成功持久化后消费；固定6–12位数字存本机钥匙串，手动更换前有效，支持多设备。有效码直接200，无手机二次批准；配对时请求 workspace 或 overview:read。配对失败按peer每分钟5次、全局20次限速；最多32设备。固定码是长期凭据，撤销设备后持码者仍可重配，应同时换码。

会话通过 DylixRemoteSession，HttpOnly / SameSite=Strict / Path=/，30天有效；32字节随机令牌仅cookie传递，落盘只保存SHA256。变更同时校验Origin与CSRF。Host严格匹配实际IP端口，无wildcard CORS。静态资源来自bundle固定allowlist；模型Key、Git凭据、系统绝对路径不回传。日志不含code/token/body。

请求头16KiB；普通body8KiB，workspace JSON2MiB，DAV PUT8MiB；读取请求10秒、响应120秒、最多16连接，响应后关闭。拒绝重复header、Transfer-Encoding、管线、Upgrade。默认关闭，不自动公网映射，仅绑定私有Wi-Fi IPv4。iOS App退出或挂起期间不提供永久在线保证。

项目操作使用既有UUID、ProjectSafety、Git lease；修改前校验指纹并备份。工作区任务使用一次性nonce确认；任务中心只返回摘要，避免嵌套此前tasks结果。构建调用现有设备单运行入口，取消为协作请求；非协作操作已执行的部分不宣称回滚。AI复用会话/runtime/工具权限；WebDAV单项目独立24小时令牌，非全系统文件共享。业务接入和完整平台验收分开记录，见测试文档。

## 参考实现核查

- GCDWebServer/Core/GCDWebServer.m：_startBackgroundTask、_endBackgroundTask 采用有限后台时间，AutomaticallySuspendInBackground 默认开启。参考 https://github.com/swisspol/GCDWebServer 。
- OpenMinis/src/ios/Agent/Background/BackgroundKeepAliveManager.swift：活动任务计数、音频状态、中断与停止衔接。参考 https://github.com/OpenMinis/OpenMinis 。
- 仅借鉴生命周期；本轮没有复制第三方源文件，无新后台库依赖。已有离线Monaco许可证见THIRD_PARTY_NOTICES。

## 分阶段验收与修改范围

阶段一（本次）：文档先行；HTTP/配对/设备连接管理/设置/QR/总览/日志；编译模拟器与设备 App，真实请求验证认证、撤权、限速、解析边界、停服与端口冲突、离线资源与浏览器布局。修改 Studio 设置增加独立分组（不改旧 section 索引）、main AppDelegate 初始化 lifecycle、scripts/build.py 加源码和资源/框架/本地网络权限说明。两个发行目录保持业务代码一致。

阶段二：提取共享 ProjectService，使用 TFAIInternalProjects 与 ProjectSafety/既有导入；Monaco 离线资源、多 tab、expected hash 保存、备份/diff、项目搜索、流式上传下载、目录 grant 生命周期。先共享锁再远程写。
阶段三：提取 BuildCoordinator，保留单运行锁与主线程契约，实时事件、真实状态/诊断、协作取消、SDK 配置、GitService 与 lease、nonce 确认和报告授权下载。
阶段四：共享会话 owner / runtime 事件 / approval，断线不重复发消息；Binary/ClassDump adapters 和统一任务索引，真实取消与结果授权。
阶段五：独立端口 WebDAV（OPTIONS/PROPFIND/GET/HEAD/PUT/MKCOL/MOVE/COPY/DELETE/LOCK/UNLOCK 等按标准验证）；Finder/Windows/iOS Files 需分别实测。受限命令目录，复用 ios_system 已确认支持命令；备份/恢复和性能指标。标准支持范围按实际验证列出，不将普通 HTTP 接口标为 WebDAV。

每阶段：独立编译、回归、协议边界、iOS15 API 可用性检查；不合并未经验证的阶段。当前仅 phase1 可用模块纳入首页真实 capabilities。版本/发布由阶段验收后再处理。

## 实施与验证状态

Build 148 是初始HTTP/手机确认原型；Build 149以本节HTTPS/码直连/生命周期方案取代。各业务模块已接入，并不表示所有真机、浏览器和挂载客户端完成验收。原有分阶段清单保留为开发顺序；实际测试及尚待验证事项以 LAN_WORKSPACE_TESTS.md 为准。


## Build 150 · 编辑器、AI 会话与前台常亮（2026-11-03）

- 离线 Monaco 增加 Objective-C / Objective-C++、Logos 和 Makefile tokenizer，区分指令、类型、关键字、字符串、数字、注释与运算符；其他语言使用已随包分发的 Monaco providers。增加语言选择、字号、自动换行、可关闭标签、层级缩进文件树与收纳的文件操作。深浅主题同步到 Monaco。
- AI 模型目录复用 `TFAIAvailableModels()`，包含每个已保存连接的多个模型。浏览器只获得 id/name/model/合法思考选项；请求由手机验证并注入原生 `setNextConnection:`。思考档位按端点＋模型＋协议配置过滤，未开放任意请求 JSON 或未声明参数。
- 会话增加消息层次、用户气泡、处理摘要折叠、工具事件、代码语言栏/复制/语法颜色、列表与表格、模式/模型/思考选择、Enter 发送、停止生成与最新位置按钮。每250ms检查原生任务快照，已完成 Markdown 块保留 DOM，仅替换变化部分；向上阅读时停止自动跟随。不宣称 Web 和原生渲染性能完全相同。
- 新增 `TFScreenAwake`，以幂等 reason 集合统一管理 build / ai / remote。运行中的 HTTPS 或 DAV listener、所有 AI run、原有构建分别持有原因；结束、失败、取消、到期时释放，App 非活跃时恢复系统 idle timer，回前台按剩余原因恢复。没有增加 Remote 独立静音循环，也不拦截用户手动锁屏。
- WebDAV 改为原生 `pageSheet` 项目列表（iOS15 medium/large detents），显示项目名和选中标记。dismiss 完成后再展示权限 alert，避开 iOS26 action-sheet 锚定错误。主设置单元格显示项目名。

### 调研依据

- [Apple UIApplication.isIdleTimerDisabled](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled)：仅在持续显示内容时停用 idle timer，需求结束恢复。
- [react-native-keep-awake 原生 iOS 实现](https://github.com/corbt/react-native-keep-awake/blob/master/ios/KCKeepAwake.m)：在主线程调用 `setIdleTimerDisabled:YES/NO`。本项目直接使用 UIKit API，未引入 React Native 依赖或复制库实现。
- [OpenMinis TextFadeAnimator](https://github.com/OpenMinis/OpenMinis/blob/main/src/ios/Views/Chat/TextFadeAnimator.swift) 与 `BackgroundKeepAliveManager.swift`、`AIChatView.swift`：阅读其新增文本显现、生命周期及聊天组件处理。网页采用保留稳定块和滚动跟随控制，未将原生 CADisplayLink 方案生搬到浏览器，也未复制其代码。

### TLS 证书、指纹和授权码

HTTPS 的证书包含手机服务的公开身份/公钥，私钥保留手机钥匙串。TLS1.2/1.3加密浏览器与手机之间传输。当前为本机自签名证书，浏览器初次访问不会自动视为公共 CA 已认证。

SHA-256 指纹是公开证书的摘要；首次连接应比较手机显示的指纹与客户端所见证书指纹，确认是同一证书，防止连到冒充服务。指纹不是密码，也不代替证书信任校验。授权码另负责授予设备访问权限，彼此用途不同。IP变化重新签发或证书更新后须重新核对。手机到模型提供商的网络连接是另外一段链路。

## Build 152 文件浏览与编辑器加载

文件管理使用独立文稿浏览接口，前端目录搜索/排序、列表/网格切换及选中文件右侧预览，不扩大写权限。图标沿用自绘SVG，长文件名省略，完整路径保留在title。
Monaco保持离线主编辑器。服务端原始10秒计时器现仅约束请求读取；进入响应阶段后最多120秒传输，不再10秒无条件取消。构建脚本为Monaco JS/CSS生成确定性gzip资源，客户端声明gzip时发送压缩版本，Vary区分编码；原始资源仍可请求。3.6MB主脚本压至约932KB，解压与原始字节比对。
已有原生编辑器的highlight.js 11.11.1（BSD-3-Clause）复用于Web轻量编辑/预览，许可证随包保留。备用编辑器使用同字体、行高与padding的textarea/pre覆盖层，字符修改仍写入原有标签model，保存复用项目版本校验与确认。错误路径仅显示同源资源路径，过滤原始Event字符串；恢复网络后使用AMD loader reset重新加载，保留当前文件。

## Build 154 · HTTP 与共享后台音频

本节取代149–153中的HTTPS和仅观察AI音频设计。Remote进入后台时获取幂等remote owner，AI继续使用ai owner；一个owner结束不停止另一方。前台释放remote owner，停服、网络变化和全部监听失败时释放。全局禁用停止物理播放器并保留需求，重新启用恢复。中断/媒体服务恢复沿用已有重试，成功恢复音频时重启暂停的监听。没有永久运行保证；锁屏保护数据仍返回423。

HTTP cookie删除Secure与__Host前缀，保留HttpOnly、SameSite=Strict、CSRF、Host/Origin检查与授权范围。历史HTTPS cookie不再使用，需重新配对。浏览器复制功能增加非安全上下文回退。历史构建说明保留为记录，当前协议以本节和API文档为准。
