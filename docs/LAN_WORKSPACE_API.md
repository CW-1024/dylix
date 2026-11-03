# Dylix Remote API · 1.0.7 / Build 160

schema 1，Dylix1.0.7（160），服务运行在iPhone/iPad。默认关闭，工作台端口8787、WebDAV8788；停服后可设1024–65535，仅私有Wi-Fi IPv4。HTTP / HTTP1.1，局域网明文传输；不使用TLS证书。没有Bonjour、WebSocket或匿名Shell。网页、Monaco在App bundle内，无公网CDN。

## 首次信任与配对

1. 手机开启服务，访问显示的 `http://IP:端口`。二维码仅包含此URL。
2. 使用可信的同一局域网。HTTP没有证书信任步骤；浏览器可能仍标记“不安全”。
3. `POST /api/v1/pair`，Content-Type application/json、Origin完全匹配，body `{"name":"我的电脑","code":"授权码","workspace":true}`。正确码直接200，data为 `state:approved, deviceID`，不再等待手机确认。
4. 响应 `Set-Cookie: DylixRemoteSession=…; HttpOnly; SameSite=Strict; Path=/; Max-Age=2592000`。令牌不出现在JSON、URL或localStorage。服务器持久化其SHA256。
5. 随机8位码五分钟有效、成功保存授权后一次消费；固定6–12位ASCII数字存手机钥匙串、长期有效、可重复配不同设备，每台独立令牌。持码者撤权后仍可重配，需换码阻断。换码不自动撤销已授权设备。

`workspace`须为JSON布尔/NSNumber；缺省仅overview:read。勾选workspace获得手机项目范围的工作区能力，具体写入、构建、Git和AI工具仍确认。旧 `/api/v1/pair/result`兼容处理保留，但当前配对不创建pending申请，客户端无需调用。

## 公开路由

- GET/HEAD `/`、`/remote.js`、`/remote.css`、bundle允许的`/monaco/*`。不拼接用户URL到Documents。
- GET `/health`：服务名、schema、state，无设备/项目详情。
- POST `/api/v1/pair`：上文身份引导，失败按peer每分钟5次、全局20次限速。

响应 `{schema:1,data:…}` 或 `{schema:1,error:{code,message}}`；配对兼容响应含error:null。工作区任务错误也可能在data.error或job.state:failed，客户端必须检查HTTP和任务状态。

## 已认证路由

- GET `/api/v1/status`：data包含真实设备名、system/systemVersion、version/build、theme、SDK列表、默认SDK/minimumOS、buildRunning、foreground、protectedDataAvailable、capabilities和phase。session含id/name/csrf/permission/projectID/readOnly，排除令牌。概况由主线程每3秒生成快照，网页每5秒刷新。
- GET `/api/v1/events`：最多200条受控事件、Unix秒时间，不含密码或文件正文。
- POST `/api/v1/logout`，body `{}`：撤销本设备并清除cookie。
- POST `/api/v1/workspace`：workspace权限，body `{action,projectID,arguments}`，返回data任务对象。以项目UUID授权，不接受绝对目录。
- POST `/api/v1/jobs/get`：`{id}`，返回本设备任务。
- POST `/api/v1/jobs/confirm`：`{id,nonce,accepted}`，一次性nonce、120秒有效；拒绝取消。
- POST `/api/v1/jobs/cancel`：`{id}`，协作取消；当前编译阶段可返回cancelRequested而非立即终止。
- GET `/api/v1/download/<id>`：本设备专属、五分钟下载引用，文件管理下载无固定大小上限（Build157起），以分块方式发送。

所有变更必须同时有同源Origin与 `X-Dylix-CSRF`，从status.session.csrf获取。workspace读操作也通过POST调度，同样需要CSRF。仅workspace权限可访问工作区、jobs与downloads，DAV令牌不适用于工作台。

## 工作区任务

任务字段：id/action/projectID/state/startedAt；完成附finishedAt/result，失败附error；待确认附confirmation/nonce/expiresAt。state为running、awaiting_confirmation、completed、failed、cancelled。tasks仅返回本设备任务摘要，排除嵌套result；详情用jobs/get。

操作目录以DXRemoteWorkspace.m为准：

- 项目：projects、create_project（name/template）、import_project（inputID/name）、project_delete、export_project。
- 文件：tree、read、save、mkdir、new_file、upload、delete_file、move、copy、search、download、extract、backups、backup_read、restore；path相对项目根，保存带sha256，冲突保留双方内容，修改先备份。
- 上传：input_chunk分块输入，绑定设备、inputID与限额；分析/项目导入只使用本设备暂存引用。
- 构建与配置：config、settings、build、builds、artifact_download；设备执行，SDK选择16.4/26.0，保留现有任务锁与报告判断。
- Git：git_status、git_diff、git_history、git_branches、git_*白名单；复用libgit2与写租约，涉及修改、同步、分支切换需确认。没有匿名远程命令。
- AI：ai_sessions、ai_connections、ai_send等既有runtime桥接；连接凭据留手机，浏览器轮询任务增量状态，不是新模型代理。真实模型流式与并发原生会话仍须专项验证。
- 分析：analyze、classdump，复用设备解析器与REipa；输入不执行。任务取消遵循NSProgress。

编辑文本上限1MiB、文件树2000项、暂存输入无固定总字节上限（Build157起）、单次分析32MiB；有具体错误即显示，不用示例数据代替。以上为已接入入口，跨功能端到端覆盖见测试记录。

## WebDAV over HTTP

手机选择单一内部项目并指定只读/读写，开启独立HTTP端口。Basic用户名dylix，随机256bit密码24小时有效，手机可撤销；更换共享设置重发凭据并使旧凭据失效。不要把浏览器cookie用于DAV。

支持OPTIONS、PROPFIND（Depth0/1）、GET/HEAD、PUT、MKCOL、MOVE、COPY、DELETE、LOCK/UNLOCK（Depth0、600秒）。写入8MiB、读取32MiB；ETag/If-Match拒绝旧版本覆盖，锁拒绝冲突写，覆盖/删除先备份；不共享整个沙盒。拒绝跨origin Destination与路径穿越、非空目录整体COPY/MOVE/DELETE。该实现是明确范围的DAV子集，尚未通过Finder/Windows各客户端完整互操作验收；iOS Files原生连接服务器为SMB，使用支持WebDAV的客户端。

## 生命周期与边界

进入后台先请求有限传输宽限；已有AI音频实际播放时观察其状态，Remote不另开永久静音播放。宽限耗尽且无音频时暂停HTTP/DAV，保留授权与期望状态，返回前台恢复原cookie/凭据。手动停止清除期望状态，重启App默认不开启。Wi-Fi地址变化停止并要求重开。锁屏willBecomeUnavailable即置锁：status仍可查看，其余业务API和DAV返回423，解锁后恢复。系统实际挂起时连接也会中断。

状态stopped/starting/running/failed/suspended；native lifecycle foreground/background_grace/background_audio/background_system/suspended。后台许可被系统拒绝时如实显示由系统决定，不声称永久可用。

401身份/撤权；403权限、Origin/CSRF、配对；404未开放；405方法；409文件冲突（可能在job.error）；412 DAV版本冲突；413大小；415格式；423受保护数据或写锁；429配对限速；431头部超限；503监听/存储故障。

header16KiB、普通body8KiB、workspaceJSON2MiB、DAV PUT8MiB；最多16连接，请求读取10秒，响应传输120秒，一次响应关闭。拒绝重复头、Transfer-Encoding、Expect、Upgrade与管线。所有请求Host严格匹配IP端口，有Origin必须同源。授权上限32设备，在线表示30秒内认证活动。服务日志不含密钥、cookie、授权码或body。HTTP不加密授权码、会话令牌、源码或操作内容；模型服务的连接另行建立。


## Build 150 AI 选择参数

`ai_connections` 返回 `connections: [{id,name,model,efforts:[{id,name}]}]`，另有 `defaultID/defaultModel`。每个 connection ID 可以有多条模型记录；按 id＋model 选择。仅含已在手机保存的模型，不包含 API Key、baseURL 或任意连接配置。

`ai_send.arguments` 支持 `sessionID?`, `text`, `connectionID?`, `model?`, `reasoningEffort`（默认 auto）, `mode`（ask/develop）。字段必须为字符串；模型不存在/档位不受支持时失败，不静默换模型。使用同一 TFAIAvailableModels 与 TFAIValidatedReasoningEffort。选择只影响下一轮，不修改手机默认连接。会话保存 connectionID/modelID/reasoningEffort，重新打开恢复选项。

任务快照 `events` 仍最多80项，增加递增 `sequence` / `eventSequence` 以防滚动缓冲导致漏事件或重复显示。`reasoning` 最多128000字符，为服务已提供的 analysis_summary 累计；text 仍最多512000字符。网页按sequence增量消费工具状态。停止生成使用既有 `/api/v1/jobs/cancel`，原生 runtime 停止并保存检查点。

## Build 151 文稿浏览

` sandbox_list `、` sandbox_read `、` sandbox_download ` 不要求 projectID；arguments.path 为 Documents 相对路径，列表根目录使用空字符串。列表返回 entries（name/path/folder/bytes/modified）。仅公开用户文稿，隐藏远程测试数据、私有配置与点目录；路径穿越和符号链接仍经统一安全路径校验。文本预览沿用1MB/UTF-8限制，下载自Build157起无固定大小上限。目录列表最多4000项。编辑器继续通过项目接口执行版本校验保存，文稿浏览不扩大写权限。

## 后台保持（154）

Remote在进入后台时获取独立音频owner，前台或全部监听停止/失败后释放。AI与Remote共享播放器，互不释放对方owner，遵循全局音频开关。中断恢复时重启暂停的监听；音频不可用且系统宽限结束后标记暂停，前台恢复且保留授权。系统挂起、强制退出与受保护文件锁定仍受iOS管理。HTTP迁移后旧Secure cookie需重新配对一次。

## Build 156 · 文稿目录上传

- `sandbox_upload_probe {path}`：复用文稿目录路径范围检查，返回exists、sha256、bytes。禁止隐藏配置、凭据、符号链接及特殊文件；目录须已存在。
- `input_chunk {inputID?, offset, name, data}`：512KiB每块，自Build157起每个输入与总暂存均无固定字节上限，最多8个同时输入。零字节文件以offset0和空base64创建输入。
- `sandbox_upload {path,inputID,sha256}`：请求一次性确认（新增/覆盖标题区分），原文件sha256必须与probe一致；写操作使用Git写入lease并检查目标项目构建状态。覆盖前保存完整字节备份与路径元数据，随后原子写入。上传内容只保存，不执行。取消保留原文件；前端finally调用input_discard。
- `input_discard {inputID}`：只清理当前设备的临时输入；撤权与停服也清理。
- 不依赖顶部项目选择，目标固定为点击上传时所在目录。多文件依次上传、分别确认、显示进度与每项结果，成功后刷新当前文件夹。
- 二进制dylib/deb/ipa仅为文件管理扩展了允许的文件后缀，AI工具路径策略保持原有范围；下载自Build157起无固定大小上限。

## Build 157 · 取代156的文件传输大小规则

文件管理不设置单文件上传大小、下载大小或临时输入合计字节上限。仍保留512KiB请求块和同时8个临时输入，这是请求/并发资源控制而非文件总大小限制。offset为平台可准确表示的非负整数，顺序校验不变。实际写入失败返回存储错误，不将磁盘写入异常显示为成功。

下载响应交由Network.framework读取已打开普通文件，256KiB一块、前一块发送完成再读取下一块。Content-Length为64bit。HEAD不读取文件内容，取消/停服释放文件句柄。120秒仅衡量无发送进展；正常长传输不断重置空闲计时器。下载链接仍限定设备身份及有效期，已开始的传输不按文件大小中断。

覆盖探测和提交均使用64KiB增量SHA-256，避免CC_LONG全文件长度截断。备份、暂存复制由文件API执行，不把整个文件拼成NSData；复制后再次校验旧文件指纹，同目录替换。手机剩余存储、系统后台状态及网络断开仍会影响传输。预览/源码编辑/二进制分析的内容处理规则与文件传输大小独立，未扩大这些解析器的范围。


## Build 158 · 在线编辑器自动保存

- `editor_autosave {enabled: boolean}`：开启需一次浏览器确认，授权仅限当前配对设备、当前项目的`save`文本写入；关闭无需再次确认。默认关闭，服务停止及设备撤权清除授权。
- `editor_autosave_status {}`：返回当前设备/项目的`enabled`状态。
- `save {path, sha256, text, automatic: true}`：服务端验证自动保存授权；进入写队列后再次验证相同授权标识，防止关闭/撤权后队列继续使用旧授权。原有安全路径、项目构建/Git写租约、1MiB源码文本处理、凭据过滤、旧哈希校验和修改前备份仍适用。
- 浏览器按项目记忆开关偏好，默认关闭；服务重新启动或重新配对后重新确认授权。停止输入1.5秒后提交，IME组词期间延后，保存中输入安排下一批，路径/项目/模型绑定到保存发起时的标签。冲突/网络失败暂停该标签自动保存，保留未保存内容并提示手动处理。未保存时关闭浏览器触发离开提示；此草稿在内存中，不承诺崩溃后恢复。


## Build 159 · 可调整的在线编辑工作区

在线编辑器工具栏新增撤销/重做，只针对当前打开文件的编辑历史；灰色表示当前没有对应记录。完整编辑器使用Monaco原生编辑栈，轻量编辑器使用逐文件差量栈并恢复选择位置。连续普通输入适当合并，中文组词结束后记录为一次修改。Ctrl/Command+Z撤销，Ctrl+Y或Ctrl/Command+Shift+Z重做。

普通保存与自动保存只更新已保存版本指纹，不清除当前模型的撤销记录。开启自动保存后，撤销和重做会产生正常编辑事件，并按相同的延迟、授权、冲突校验与备份流程保存到手机。关闭文件、刷新页面或切换项目结束当前编辑历史；跨重新打开文件的恢复使用既有“备份与Diff”入口。撤销针对文本编辑，不撤销文件删除、Git、构建或其他任务。


Build159起，首次进入项目编辑器自动请求启用自动保存；手动关闭按浏览器/项目记忆。原生写入授权仍按配对设备/项目校验，首次启用及服务重启后需要确认，不改变服务端权限边界。默认开启只改变初始偏好，未确认前不自动写入。

布局偏好保存在浏览器本地，不改变项目文件：`DylixRemoteNavigationCollapsed`控制导航图标栏，`DylixRemoteTreeCollapsed`和`DylixRemoteTreeWidth`控制项目文件栏。文件栏最小140px，最大420px且为代码区保留约300px；拖动分隔线调整，方向键每次16px、Shift32px、Home/End到边界、双击恢复245px、Enter收起。手机宽度下文件栏作为浮层，不挤压代码。

“全屏编辑”采用工作区专注布局，Ctrl/Command+Alt+Enter切换，退出按钮或Esc恢复。编辑内容、选中文件、撤销记录和文件栏宽度保留；全屏仍显示实际连接状态。浏览器原生全屏权限不是前提，HTTP页面也可使用。工具栏按保存/历史/自动保存、语言/字号/查找/换行、文件栏/全屏/文件操作分组。

布局参考：VS Code/code-server的可折叠侧栏、可调整分区和专注编辑原则，Split.js的拖动分隔区交互。本实现使用原生Pointer Events、ResizeObserver和现有Monaco，未引入新前端依赖。
