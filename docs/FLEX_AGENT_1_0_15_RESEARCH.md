# FLEX AI 自主交互：1.0.15 / Dylix build 183

日期：2026-11-05。本文记录实际读过的上游源码、选择依据、实现范围和验证限制。

## 术语改为具体能力

此前的“第三方扩展”指 FLEX++ 在原版 FLEX 之外增加的 xx.h、反汇编、Filza、抓取、保护入口，不是要求用户另装某个通用扩展。

“自定义手势”指依赖 UIGestureRecognizer 的点击、双击、长按、滑动、拖动、双指缩放和旋转。只调用 UIButton 的 touchUpInside 不能覆盖它们。

## GitHub 源码研究

1. KIF：<https://github.com/kif-framework/KIF>
   - 固定提交 `357a70fe0ccfb8ae5097d6ac14d0f010b376787d`。
   - 阅读 `Sources/KIF/Additions/UITouch-KIFAdditions.m`、`UIEvent+KIFAdditions.m`、`Sources/KIF/Classes/IOHIDEvent+KIF.m` 和 UIView 事件投递代码。
   - 借鉴进程内 UITouch、IOHID、UIEvent 组合，以及 iOS 18+ SwiftUI 命中上下文适配。没有引入 KIF 框架、XCTest，也没有采用原始 UITouch ivar 写入。
2. Google EarlGrey：<https://github.com/google/EarlGrey>
   - 固定提交 `aea2d32233dc2cd2eff7906426944c8f287c0855`。
   - 阅读 `EarlGrey/Event/GREYTouchInjector.m` 和 UITouch 扩展，采用异步分帧触摸序列的思路。
3. Appium WebDriverAgent：<https://github.com/appium/appium-ios/tree/main/packages/webdriveragent>
   - 固定提交 `afeb9cd03af16c7f3cea23633c82d715642c4e58`。
   - 已核对原 `appium/WebDriverAgent` 迁移说明和新仓 README。其运行路线依赖 XCTest.framework，适合独立自动化测试服务，不能直接作为当前注入型 FLEX dylib 的内置依赖。没有复制其实现。

前两项以 Apache-2.0 许可提供；适配部分的来源、提交和修改说明在 FLEX 的 ThirdPartyNotices/NOTICE，许可证随 deb、Dylix App 和本次交付附带。

## 实际接入

- `FLEXDylixTouchDriver`：主线程、60Hz、1–2 指异步路径；运行时探测固定私有接口和符号；前台、窗口与坐标校验；失败和停止时尽力发送 Cancel，清理 timer/触摸状态。
- `gesture`：tap、double_tap、long_press、swipe、drag、pinch、rotate。操作前收起聊天并隐藏 FLEX 覆盖层。最长单次 3 秒，投递后必须重新读取页面或截图确认。
- `gesture_capabilities`：区分接口探测与实际投递验证。不可用时明确返回原因。
- `input_text`：当前目标 App 可见、非安全文本框；尊重原生 shouldChange 校验，文本不在工具结果里复述。UITextField 发送 editingChanged。
- `set_control_value`：UISwitch、UISlider、UISegmentedControl、UIStepper；检查原生范围并发送 valueChanged。
- `extension.headers`、`extension.disassembly`：使用现有 UCClassSearchViewController 工厂打开真实页面；支持内嵌 UITableView 的搜索、滚动和已审查列表导航。
- `class_header`：基于 UCClassDumpTool 读取运行时真实类头文件，支持按行分页。不是任意内存地址读取。
- `flex_ui_state`：增加可见页面文字摘要；头文件全文通过 class_header 分页，摘要不能当成全文。
- 插件上报 touchGestures 能力，Dylix 以绑定会话的快照决定是否下发 gesture schema。旧插件、断线或缺接口时不下发手势操作。
- 会话收起后保留同一连接、任务和轮询；悬浮条恢复聊天或立即停止。停止也取消正在投递的手势，并阻止旧授权回调执行。

## 保留的明确边界

Filza 的系统目录写入、抓取/注入二进制和“保护”这种直接改变宿主状态的入口，不伪装为普通只读导航。它们仍在目录中给出明确原因，沿用已有人工/暂存流程。对象检查器中的任意方法调用没有通过 select_row 放开。这不是“所有 FLEX 功能已经自动化”的声明。

没有声称可以操作其他进程、系统键盘或系统弹窗；触摸投递仅发生在当前注入宿主的目标窗口。自定义渲染视图、特殊手势竞争、SwiftUI、不同 iOS 版本仍需目标 App 真机验证。

`delivered=true` 只证明事件已投递，不能证明按钮业务成功；返回 requeryRequired 和 semanticSuccessUnverified，要求 AI 再观察结果。

## 验证

- 生产 FLEX Chat/Runtime/TouchDriver + UIKit 模拟器：56 项 / 0 失败。HTTP 和无关 FLEX 服务使用显式 fixture，不是模型端到端或目标 App 真机测试。
- 真实 UITap/UILongPress/UIPan/双击/UIPinch/UIRotation 识别器回调均观察到；没有直接调用这些 recognizer 的 action 冒充触摸。
- 验证了 UITextField / UITextView 输入与原生拒绝校验、editingChanged / didChange、开关/滑块/分段/步进器 valueChanged、安全文本框拒绝、隐藏祖先拒绝、越界与零半径拒绝、触摸取消、内嵌表格的扩展导航、分页及会话恢复。
- 真实 Network.framework HTTP 模拟器服务通过配对、心跳、命令/回复、伪造回复拒绝、权限授权/撤销和退出联测；没有把它等同目标 App 内实际注入。
- FLEX bridge 回归：新增五类 operation 转发、设备隔离、能力快照更新、旧插件默认不可用及非法能力类型校验。
- 工具注册表 174 项；实际 AIRuntime 注册表 13 项，包含新旧能力 schema 和断线隐藏；AI transport 103 项。
- 本轮没有目标 App 真机和真实模型闭环结果，不能记为已验证。

交付物的哈希、Mach-O UUID、IPA 版本与内置包一致性由同目录产物核验记录给出。
