# FLEX 1.0.16 / Dylix 1.0.7 build 184

## 本轮变更

- 完整移除 DXAgentBubbleWindow、悬浮条、拖动、悬浮恢复和停止按钮。
- 手动收起聊天回到原生 FLEX 菜单。会话 controller / navigation 仍由 FLEXExplorerViewController.dylixNavigation 持有，连接、同一 sessionID、jobID、任务和轮询不暂停。
- 点击原菜单 Dylix AI 时重用同一聊天，并在 viewDidAppear 清除收起标志。AI 仍可用 restore_chat 恢复会话。
- AI 要操作目标 App 时，minimize_chat(surface=target) 仍隐藏 FLEX 覆盖层，不遮挡目标触摸；不创建任何替代悬浮窗。
- chat_status.minimized 使用独立状态；不再以悬浮窗是否存在判断。
- 更新发送给 AI 的操作说明：从原 FLEX 菜单返回；无 controlActions 或 hit_test 命中父容器时继续检查交互归属，不能草率写全局 UIButton Hook；测试不能因为其他项目通过而跳过。
- 会话内原有主动停止操作保留。收起本身不会调用停止、取消或断开。

## 用户反馈的真机证据（非本机独立复测）

用户提供红果短剧 com.phoenix.video 的 AI 调用记录：截图、真实 tap 从视频流进入剧场、识别继续播放按钮、临时隐藏与撤销、恢复聊天均报告成功。这是有价值的真机反馈，但本机未取得完整工具原始记录或录像，不把它扩展为所有功能已通过。

SSTabBarTextButton 被 activate_control 拒绝符合该接口只支持 UIButton 的约定；随后 gesture 完成导航，不能把首次拒绝说成点击成功。

继续播放按钮的 controlActions 为空，坐标命中父容器，提示实际交互归属可能在父层。仍需检查父视图/手势/控制器及稳定生命周期；只查通用 UIButton 的方法不能据此确定持久 Hook。

原反馈中的滚动未测、class_header 未调用、页面未回到起始视频流，应保留为未完成项。临时隐藏与撤销不是插件源码实现完成。

## 自动验证范围

生产聊天/运行时/触摸代码在真实 UIKit 模拟器运行，HTTP 与无关 FLEX 服务为 fixture。新增验证：没有独立悬浮窗 class；手动收起后原 FLEX 菜单仍可见；收起期间任务/轮询不暂停；通过保留的原生导航重新打开时会话/任务/timer 不变且 minimized=false。

原 FLEXExplorerViewController 的菜单入口已做源码核查；模拟器 fixture 复现它使用保留 UINavigationController 调用 presentTool 的路径，不把 fixture 当作实际注入红果短剧的 UI 测试。具体检查数及产物哈希见交付目录中的记录。
