# FLEX 自主探索链路

## 工作方式

FLEX 插件运行在目标 App 进程内。Dylix Remote 只转发已配对设备的命令；AI 的工具 schema 只在 FLEX 心跳在线时出现。AI 可以从 `current`、`screen_elements` 和 `view_tree` 开始，不要求用户预先选中视图。`screen_elements` 每页最多返回 100 项，用 `nextOffset` 继续；窗口坐标可交给 `hit_test` 查找视图及其可交互父视图。`view_tree(id)` 可展开指定视图的子树。

已通过图片能力测试的模型可请求 `flex_sensitive_read(capture_screen)`。FLEX 仅绘制目标 App 的 UIWindow，压缩为不超过 120 KiB 的 JPEG；Dylix 校验格式和大小后，把它作为下一轮模型请求中的临时图片消息。工具结果和会话记录只保存尺寸、时间和投递状态，不保存 base64 图片。截图需要 FLEX 敏感读取授权，最短间隔 2 秒。若 UIKit 报告无法渲染则返回失败；受保护的视频图层也可能呈现空白，需和视图信息交叉核对。

经过 FLEX 控制授权后，`flex_control(activate_control)` 只激活当前窗口内可见、启用的 UIButton；`scroll_view` 只滚动当前窗口内的 UIScrollView，单次最多两页。操作可能改变目标 App 状态，AI 必须在操作后重新读取 `current`、`screen_elements` 或截图。现有 `set_view` 只是临时改视图属性，不能代替插件源码。Dylix 项目写入和构建仍由原有审批流程处理。

## 真机验收

1. 在 Dylix 中给所选模型完成“测试图片”，确认能力为“支持”；启动局域网远程，配对目标 App 中的 FLEX 1.0.17。
2. 不在 FLEX 中预选视图，要求 AI 描述当前页面并定位某个按钮。检查它是否调用 `screen_elements`、`capture_screen`、`hit_test` 或 `view_tree(id)`，并确认截图出现敏感读取授权。
3. 授权控制后要求 AI 进入一个无副作用的设置页、滚动并返回。核对每次操作后的重新观察；更换页面后旧视图 ID 应被拒绝。
4. 检查 Dylix 会话文件和工具结果没有 `imageBase64`；检查授权撤销、连接断开、无图片能力模型和受保护画面时的失败提示。

## 仍需设备验证的边界

`UIButton` 的 `touchUpInside` 并不等价于真实触摸序列。1.0.15 新增单独的真实触摸后端和非安全文本框输入，详见下文；这不等于可以控制系统键盘、系统弹窗或其他 App 进程。任意 Objective-C 方法调用及受保护图层仍不在可用范围。实际页面可截图内容和手势结果必须在目标设备上验证。

## 1.0.14：会话收起与原生 FLEX 页面（历史行为）

- `flex_live_read(tool_catalog)` 从 FLEXGlobalsEntry 工厂生成目录，包括真实名称、入口 ID、是否开放给 AI；用户注册项也列出，但不擅自执行其任意 action。
- `flex_live_read(chat_status)` 返回会话可见性、收起状态、心跳连接状态、任务状态和 sessionID。配置存在不等于心跳在线。
- `flex_control(minimize_chat, surface=target)` 等 UIKit 完成收起后隐藏 FLEX 窗口，露出目标 App；`surface=flex` 保留 FLEX 窗口。轮询、会话、消息、任务、运行时对象均继续复用，不断开、不暂停。
- `restore_chat` 恢复同一个聊天控制器；`open_tool(tool_id)` 收起聊天并通过真实原生工厂打开目录标为可用的页面。`navigate_back` / `dismiss_tool` 返回或关闭功能页。
- 独立非 key 小窗口展示 AI 状态，支持拖动、恢复会话、停止任务；其余屏幕仍由目标 App 接收触摸。聊天页发送按钮在运行期间变成“停止”。
- 停止先设置插件本地拒绝标记并增加任务代数，再请求 Dylix `/api/v1/jobs/cancel`。旧任务延迟返回的授权不能在新任务里执行；网络取消失败时明确提示，绝不声称远端已停止。
- `flex_sensitive_read(flex_ui_state)` 返回当前 FLEX 页面、可见元素、可见列表行及其真实 ID。`capture_screen(surface=flex)` 截取当前 FLEX 页，图片规则与目标截图一致。
- `set_search(query)` 调用当前页原生搜索栏；`flex_scroll(id,direction,pages)` 滚动该页面真实滚动视图；`select_row(id,section,row)` 只允许运行时/存活对象/实例列表导航，且 ID 必须仍对应当前可见单元格。对象检查器的方法调用行不开放。

窗口和 FLEX UI 控制继续复用 `flex_control` 授权，FLEX 页面读取复用敏感读取授权；已有 30 分钟授权可以免去每次确认。目录中未开放的项不会伪装成已支持。此版本并不等于已自动化 FLEX 所有第三方扩展。

## 1.0.15：手势、输入及 FLEX++ 扩展

- `gesture_capabilities` 探测当前系统固定触摸接口；插件上报能力快照，Dylix 只对可用的在线插件下发 gesture 操作。
- 收起至 target 后，`gesture` 支持点击、双击、长按、滑动、拖动、双指缩放和旋转。结果只确认事件投递，AI 必须重新观察实际页面。
- `input_text` 尊重原生文本校验；`set_control_value` 支持开关、滑块、分段控件和步进器，并触发原生 valueChanged。
- `extension.headers` / `extension.disassembly` 打开 xx.h 和反汇编；内嵌表格可搜索、滚动和选择已审查的导航行。`class_header` 按行读取运行时类头文件。
- 立即停止会取消正在执行的触摸；异常中断尽力发送 Cancel，避免遗留半个手势。
- 研究依据、具体未开放项和回归结果见 `FLEX_AGENT_1_0_15_RESEARCH.md`。

## 自动验证（当前版）

1.0.17 的 scroll_view / flex_scroll 以实际位移决定 scrolled，返回 previousOffset、contentOffset、数值 delta、reachedBoundary 与 reason。边界处没有移动应返回 scrolled=false / reason=boundary；不是操作失败，也不能冒充内容已变化。移动后仍须读取页面或截图。详见 FLEX_AGENT_1_0_17_VALIDATION.md。

1.0.16 已移除独立悬浮窗。手动收起回到原生 FLEX 菜单，会话、任务与轮询继续运行；点击菜单的 Dylix AI 返回原会话。AI 为触摸目标 App 调用 minimize_chat(surface=target) 时仍隐藏 FLEX 覆盖层，并可用 restore_chat 返回。没有新增暂停按钮，原会话内的停止操作仍可主动取消任务。chat_status.minimized 改为独立状态，不再依赖悬浮窗存在。

`tests/FlexAgentUISmokeRun.py --flex /path/to/FLEX --device booted` 在真实 iOS Simulator UIKit 中编译生产聊天控制器、运行时、Markdown 与地址处理代码。Dylix HTTP 与无关 FLEX 服务为测试替身，覆盖收起/恢复后轮询、同一会话与任务保留、目标 UIButton 激活、真实截图、原生工具页、搜索/列表导航、过期行 ID、滚动、立即停止及跨任务延迟授权隔离。它不能代替注入目标 App 的真机联调，也没有把测试替身当成实际模型请求。

`tests/FlexBridgeTests.m` 另外覆盖新增命令白名单、配对设备隔离、回复归属、超限回复、撤销与未注册操作拒绝。
