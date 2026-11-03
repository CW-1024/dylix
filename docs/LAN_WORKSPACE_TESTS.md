# Dylix Remote 当前发布验证

当前发布：**1.0.7（160）**。本次完整重跑422项检查及两种IPA包校验，详情见[Build160发布测试](BUILD160_TESTS.md)。下方按构建号保留开发阶段历史，不代表当前仍使用TLS或早期文件传输大小限制。当前协议见[API文档](LAN_WORKSPACE_API.md)。

---

## Build 154 · HTTP 与后台共享音频（2026-11-03）

本节为当前构建结果；下方149–153的TLS记录属于历史版本。

- 主App和分享扩展：iOS26.0 SDK，arm64，最低iOS15；ActivityKit扩展仍由Xcode16.2 / iOS18.2 SDK构建，最低16.2。插件编译默认SDK仍16.4。两个IPA均核对Mach-O SDK/minOS、版本154、资源、GPL、默认SDK和风味差异。
- `python3 tests/AIAudioBackgroundRun.py`：54项。含AI/Remote幂等owner、双向释放隔离、关闭/恢复全局音频、最后owner释放、中断、解码错误、有限重试。
- `python3 tests/AIBackgroundRun.py`：87项既有AI后台生命周期检查。
- `python3 tests/RemoteCoreRun.py`：61项核心检查，另有历史TLS工具OpenSSL检查（该工具仍保留，当前Remote不配置TLS）。
- `node tests/RemoteIntegration.mjs`：81项，iOS18.3.1模拟器中的真实Network.framework HTTP服务。覆盖HttpOnly/SameSite cookie、配对/撤权、CSRF、Host/Origin、离线gzip与慢速读取、项目/文件、HTTP WebDAV、锁屏保护通知423、实际App切换。实际音频管理器验证AI结束后Remote继续持有，音频禁用后可暂停、前台恢复授权。
- `python3 tests/RemoteBrowser.py`：61项，Chrome156，直接访问模拟器HTTP。Monaco真实保存、源码着色、文件预览/下载、AI模型/流式UI（确定性本地提供商测试夹具）、备用编辑器和重试。
- `python3 tests/RemoteHTTPBrowser.py`：62项。使用仅本机测试relay将浏览器`http://dylix.test:随机端口`请求转发至真实模拟器服务，仅适配Host与同源Origin；未模拟API响应。Chrome未设置证书跳过或强制安全源标志，明确验证`isSecureContext=false`且无navigator.clipboard，再运行完整浏览器检查。此项验证普通HTTP网页能力，不宣称真实Wi-Fi吞吐或第三方挂载验收。
- 前台常亮回归见本次交付的awake日志。模拟器测试控制代码仅参与simulator编译，两个设备IPA中核对不存在回归参数/控制文件标记。

边界：未在真机验收长时间锁屏、电话/音乐中断、所有iOS15设备、所有WebDAV客户端。HTTP不加密授权码、会话令牌与源码。音频辅助遵循全局设置及系统中断，App强制退出或系统挂起仍会断开；受保护文件锁定时保持423。迁移后旧Secure cookie需重新配对。

# Dylix Remote · Build 153 验证记录

日期：2026-11-03，1.0.6（153）。移除用户界面的证书/指纹单元格及复制/导出操作，保留HTTPS证书内部生命周期。原生设置分组只有一项后台状态；网页配对、设置及WebDAV权限弹窗同步清理手动核对指纹提示。

- 模拟器构建、运行成功；通过Simulator实际可访问性树确认「后台状态」分组直接接「已授权设备」，无TLS证书单元格。截图remote-settings153.png。
- RemoteIntegration.mjs继续验证TLS1.2/1.3、证书有效性、配对授权与WebDAV等84项；完整日志随交付。
- 两种IPA主程序及分享扩展使用SDK26/min15，ActivityKit组件SDK18.2/min16.2；包内版本153、资源和发布/开源差异核对。插件默认SDK16.4不变。

本轮未修改编辑器/文件管理实现，其专项浏览器结果沿用Build152基线，未计作本轮重跑。浏览器自身的自签名证书提示由浏览器信任策略决定，此改动移除应用内管理入口。

---

# Dylix Remote · Build 152 验证记录

日期：2026-11-03，1.0.6（152），本地交付，未更新GitHub。

- RemoteCoreRun.py：61项及OpenSSL检查通过。
- RemoteIntegration.mjs：84项通过，新增gzip解压与原脚本逐字节一致、传输大小低于40%、gzip;q=0返回原资源、备用高亮资源可用、客户端延迟11秒读取仍收到完整3.6MB响应。保留TLS/配对/授权/文稿路径/WebDAV/生命周期检查。
- RemoteBrowser.py：60项通过。Chrome156连接真实iOS18.3.1模拟器HTTPS服务，含真实文件预览、每个项目ZIP导出、列表/网格切换、名称搜索及空结果、排序；真实Monaco读写、token类别、AI模型与流式阅读；主动阻断editor.main.js后，备用编辑器实际源码、语法token、行号、清晰错误路径、保存与恢复原文；解除阻断后点击重试恢复完整Monaco并保留当前文件。无pageerror，无公网资源请求。
- 截图实际查看：sandbox-browser152.png、editor-dark152.png、editor-fallback152.png；另拍摄文稿根目录列表/网格深色截图。备用编辑器截图有明确资源故障提示，因为这是主动断开主编辑器资源的回归场景。
- 追加真实应用PNG加载、0B/1.5KB/2MB/3GB格式、编辑器文件树大小显示；主动中断status请求后侧栏显示中断，恢复网络请求后显示已连接。
- 文件浏览维持Documents范围和既有权限，未扩大至私有Library；文件写入仍需确认和版本校验。highlight.js复用原有BSD-3-Clause依赖，许可证随包保留。
- 两种IPA核对版本1.0.6/build152、主程序与分享扩展SDK26/min15/arm64、内置默认SDK16.4和可选26、HTML/JS/CSS/高亮资源和许可证、gzip解压内容、发布版与开源版反馈/TG区别，以及设备产物无模拟器控制入口。ActivityKit组件沿用Xcode16.2的Swift SDK18.2/min16.2。

本轮205项断言只覆盖列出的路径。Windows Edge、真实慢Wi-Fi和iOS15/26真机仍需安装后复测；已确认旧服务存在10秒无条件关闭连接逻辑，并在新版测试延迟读取通过，但用户截图没有网络日志，尚未证明此次截图一定由该超时触发。

---

# Dylix Remote · Build 151 验证记录

日期：2026-11-03，版本1.0.6（151）。本地交付，未发布GitHub。

- RemoteCoreRun.py：61项核心检查及OpenSSL验证通过。
- RemoteIntegration.mjs：77项通过，新增未选择项目时的文稿目录列表、测试文件隐藏、路径穿越/绝对路径/私有目录拒绝检查。
- RemoteBrowser.py：46项通过，Chrome156连接真实iOS18.3.1模拟器HTTPS服务。验证每个项目均有导出入口、实际ZIP下载；清空顶部项目后目录仍可访问；文件夹进入/返回、实际文本预览；反复切换编辑器/文件管理；读取多种文件、真实保存和恢复；主动阻断Monaco资源后仍展示实际源码。保留原有语法颜色、模型档位、AI流式阅读和移动布局回归。无JS pageerror，无公网资源请求。
- 文件浏览范围为Documents用户文稿（项目、构建、导入等），不暴露Library私有配置；预览UTF-8文本上限1MB、下载上限128MB。在线编辑仍使用现有项目接口和文件版本校验。
- 双版本主程序和分享扩展SDK26.0、arm64、最低iOS15；ActivityKit组件沿用Xcode16.2自带Swift SDK18.2/min16.2。内置插件默认SDK16.4/min15不变。包内版本、资源、许可证与发布版反馈/TG差异逐项核对。

截图：sandbox-browser151.png、editor-fallback151.png。完整日志随交付。上述是模拟器和Chrome验证，用户设备/Edge实际表现仍需安装后复测。Build150的其他模块测试记录为历史基线，未计为本轮重新执行。

---

# Dylix Remote · Build 150 验证记录

日期：2026-11-03，版本1.0.6（150）。本地开发交付，未推送 GitHub 或发布 Release。

## 本轮结果

- `RemoteCoreRun.py`：61项；`RemoteIntegration.mjs`：72项，原有 TLS / 直接配对 / 文件及 WebDAV / 后台恢复检查通过。
- `RemoteBrowser.py`：35项，Chrome156.0.8078.79 + Playwright，连接真实 iOS18.3.1 模拟器 HTTPS 服务。真实 Monaco 读写/版本校验/恢复文件；tokenize断言Objective-C与Logos有独立token；语言切换实际model、主题跟随；AI模型列表与档位、代码高亮/表格、滚动稳定、停止生成、390px/1440px布局，无pageerror、无外网资源请求。
- AI使用 `RemoteChatFixture.py` 的本机18991端口确定性测试提供商，明确标记“本地回归回复”。浏览器 → 手机工作区API → 原生AIRuntime/TFAITransport → loopback provider → SSE → 手机任务 → 浏览器，验证实际请求model=gpt-5-fixture-alt / reasoning_effort=high。网页与手机业务接口未mock，未请求付费模型。测试专用模型配置测试后移除；控制指令仅编入模拟器。
- `RemoteAwakeRun.py`：7项真实UIKit检查，确认LAN启停、AI/build原因交叠、重复发布幂等、离开前台释放、回前台恢复。`AIBackgroundRun.py`：87项，额外8项把真实TFScreenAwake实现纳入平台fixture，覆盖AI begin/并发/完成/失败/到期与LAN原因共存。
- `AIToolsRun.py`302项、`AIBuildResultRun.py`5项、`AIAudioBackgroundRun.py`41项通过。本轮断言合计610项；数量只代表列出的断言。
- 真实模拟器中从设置表格点击“WebDAV项目”，确认原生底部列表显示；选择项目后列表关闭，再显示读取/读写权限alert；取消返回。截图 `webdav-project-sheet150.png`。
- 双版本主程序和分享扩展为arm64、SDK26.0、最低iOS15、1.0.6/build150；ActivityKit Swift组件仍由当前Xcode16.2工具链的SDK18.2构建、最低iOS16.2。内置插件默认SDK16.4/min15不变，26可选。公开许可证、网页/Monaco资源与IPA核对；发布版保留反馈/TG，开源版移除前两项；设备产物不含模拟器控制标记。

## 边界

此次运行平台为iOS18.3.1模拟器。iOS15/26真机首次网络授权、真实跨Wi-Fi客户端、用户手动锁屏、长时后台、浏览器证书信任、Finder/Windows挂载与高压并发仍需真机验证。模拟器通过不等于所有真机条件通过；前台防自动锁屏不等于永久后台运行。WebDAV列表使用iOS15起原生sheet，iOS26实际外观待真机检查。

## 重现

先构建/安装/启动模拟器，按顺序执行 `RemoteCoreRun.py`、`RemoteIntegration.mjs`、`RemoteBrowser.py`、`RemoteAwakeRun.py`。浏览器测试用SecureIntegration生成的项目fixture，日志与截图随交付保存。TLS浏览器测试仅在隔离headless实例中显式指定测试证书SPKI，不修改用户系统/浏览器信任库。详情、原有测试命令及边界见下方149记录。

---

# Dylix Remote · Build 149 验证记录

日期：2026-11-03，版本1.0.6（149）。本轮针对HTTPS、码直连和生命周期收尾；本地开发产物，未发布GitHub Release。主程序与分享扩展使用iOS26.0 SDK，最低iOS15；ActivityKit组件沿用当前Xcode的Swift SDK/最低16.2。内置插件编译默认SDK16.4、最低15.0保持不变。

## 本轮执行结果

- `python3 tests/RemoteCoreRun.py`：**61项通过**。真实Foundation/Network/Security基础实现，含HTTP解析边界、随机码消费、固定码复用、参数类型、存储失败、hash持久化、撤权与限速。另通过OpenSSL3证书解析、自签名校验、serverAuth用途、正确SAN接受/错误SAN拒绝。
- `node tests/RemoteIntegration.mjs`：**72项通过**。直接连接iOS18.3.1模拟器内Network.framework真实TLS listener，没有Mac代理或mock API。覆盖TLS1.2/1.3、显式信任本机证书、默认CA拒绝自签/错误IP拒绝、明文请求不提供API、离线资源与CSP、Host/Origin/CSRF、Secure __Host cookie与token不入JSON、码直连/无pending/随机码重放拒绝、手机倒计时实际变化、固定码钥匙串恢复/同IP证书保持、独立设备撤权；真实原生模板创建、ZIP分块暂存与导入、错误offset拒绝、任务摘要不递归。
- 同一72项中，WebDAV覆盖TLS1.2/1.3、Basic认证、只读拒写、重授权撤销旧凭据、PROPFIND、PUT/GET、ETag冲突、LOCK/UNLOCK、持锁写入、COPY的HTTPS Destination、DELETE、锁屏通知立即423/解锁恢复、后台暂停后原凭据恢复。仅是已列方法/路径的验证，未宣称完整RFC或各挂载客户端互操作通过。
- 同一集成套件实际通过simctl切换到系统设置、再返回App，宽限内服务保持。另由simulator本地控制调用生产相同expiration handler，验证宽限到期暂停HTTP/DAV、保留期望状态/授权、前台原cookie恢复。锁屏使用真实UIKit通知名确定性注入，非长时间真机锁屏。
- `python3 tests/RemoteBrowser.py`：**24项通过**。Chrome156.0.8078.79 / Python Playwright headless，连接上述实际模拟器。直接配对、不需手机批准；真实设备概况和workspace权限、HttpOnly、深浅主题、所有导航、离线Monaco读取真实手机文件，修改→确认→保存→再次确认恢复原文，390px与1440px无页面水平溢出，无JS pageerror、无外网请求。截图经查看：配对、总览、编辑器与手机布局。
- 现有工具回归：`AIToolsRun.py` **302项**、`AIBuildResultRun.py` **5项**、`AIAudioBackgroundRun.py` **41项**、`AIBackgroundRun.py` **79项**全部通过。工具测试使用发布工作区Mac libgit2 fixture；音频/后台为确定性平台fixture，并非真机音频后台时长保证。

合计：Remote **157项**，现有回归 **427项**，共 **584项**，证书OpenSSL检查另计。测试源与完整日志随本地交付保存。数量仅表示已列断言，未列场景不据此推定通过。

## 重现

```sh
python3 scripts/build.py --simulator
xcrun simctl install booted build/simulator/TheosMobileCompiler.app
xcrun simctl launch booted com.xuegao.theosmobilecompiler --remote-test --remote-regression
python3 tests/RemoteCoreRun.py
node tests/RemoteIntegration.mjs
python3 tests/RemoteBrowser.py
```

如App已启动，先simctl terminate再launch。当前测试设备为Dylix iPhone16ProMax / iOS18.3.1，loopback工作台18787、DAV18788。测试账户/证书存单次隔离目录，固定码使用独立Keychain账号。RemoteIntegration.py是新版Node套件兼容入口，不再执行148的HTTP/pending协议。浏览器测试需先跑SecureIntegration，后者创建专用临时项目与fixture标识；不修改真实用户工程，不调用真实模型。

Node使用显式CA信任此自签叶证书并严格验证127.0.0.1 SAN；OpenSSL3独立验签。浏览器为隔离headless实例，仅以当前证书SPKI允许列表访问测试服务，不更改用户浏览器/系统信任库，不点击用户浏览器安全警告。此测试便利机制不属于App产品信任流程，客户端首次信任仍按手机证书指纹核对。系统Python/LibreSSL对自签非CA叶证书信任行为不同，故不使用其结果替代Node/OpenSSL验证。

截图输出默认/tmp/dylix-remote-evidence，REMOTE_EVIDENCE_DIR可覆盖；REMOTE_CHROME可指定Chrome执行文件。手机设置页为模拟器真实UIKit界面。

设备打包：

```sh
python3 scripts/build.py --sdk-root /绝对路径/iPhoneOS26.0.sdk
```

两个版本均独立构建、检查IPA内Info与Mach-O：主程序arm64、SDK26.0/min15.0、version1.0.6/build149；分享扩展同版本与SDK26.0；公开许可证、离线网页/Monaco许可与编译输出一致；设备二进制不含模拟器控制入口。发布版保留反馈、Telegram、开源地址和许可证，开源版去掉前两项。

## 尚待验证

- iOS15/26真机首次网络许可、跨设备Wi-Fi、长时间锁屏、来电/音频中断及系统资源压力；本轮不宣称永久后台在线。
- 实际Wi-Fi切换导致IP更新/证书轮换；本地证书与固定码在真实签名Keychain entitlement下的体验。
- 用户Safari/Edge/Firefox的自签证书首次信任步骤、Finder/Windows/DAV客户端挂载、大文件/慢网/并发连接。
- 真正模型流式、远程和手机同会话并发、真实远程构建与取消、Git远端push/pull、二进制大型输入、外部security-scope目录。现有入口已复用，仍需各自专项验收。

后台设计仅观察已有AI音频并请求有限系统时间，不为了LAN另开永久静音播放。真实锁屏时受保护文件暂时不可读，返回前台恢复与授权保留，不等于所有任务都在挂起期间执行。取消是协作请求，已经落盘/完成的操作不自动回滚。

## 证据与回滚

- [原生设置默认关闭](images/remote/native-https-settings149.png)
- [HTTPS总览](images/remote/overview-light.png)
- [实际手机文件的Monaco保存](images/remote/editor-https.png)
- [390px布局](images/remote/overview-mobile.png)

默认停止服务即可退出远程访问；停服保留设备授权，撤权应单独操作。固定码持有者可重新配对，需换码阻止。代码基线6779bde5，新增App/Remote、RemoteWeb、测试/docs，现有改动集中设置入口、Studio业务bridge、main生命周期、音频状态广播、打包资源与版本；无项目数据库迁移。回滚时只还原相关改动，保留用户工程和其他未提交修改。
