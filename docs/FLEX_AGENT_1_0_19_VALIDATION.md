# FLEX 1.0.19 / Dylix 1.0.7 build187

日期：2026-11-05。设备版使用 iPhoneOS 26.0 SDK，最低 iOS 15。

## 修复与增强

### 按钮所属关系与 Hook 取证

FLEX 的 object_info 对 UIView 新增 hookEvidence：视图父链、最近的 responder 控制器、类所属镜像、生命周期候选方法及其真正声明类、类型编码和继承状态。定位 signature 排除运行时地址，便于进出页面、刷新或复用后比较。

聊天上下文要求 AI 对目标按钮及业务父视图查询这些证据，结合 class_info / class_header，并在导航、复用后复查。最近 responder 控制器不是分配该按钮的所有者证明；方法声明也不等于执行轨迹。返回值明确标注 lifecycleExecutionObserved=false、stabilityVerified=false。本次没有新增动态追踪、任意方法调用或自动持久化 Hook。

### 打开聊天自动出现旧的选中代码

Studio 在恢复编辑器保存的选区后，openAIRecord 原先会自动把非空选区加入待发送附件。截图中的 Tweak.xm:361、8 字节、enum, no 来自这一流程，不是 FLEX 截图或构建产物。

移除打开聊天时自动附件的行为；改由附件菜单的“所选代码”显式添加，读取当前有效选区。不会删除用户既有待发送附件，历史已保存的误添加卡片可点击 × 移除一次。

### 远程工具记录和构建产物延迟

Remote 原先保存消息/checkpoint，却没有把运行时工具事件映射到原生 processRecords；会话资源索引依赖这些完成记录，已打开的会话文件页又持有旧快照。

- Remote 将 tool_call、tool_started、tool_progress、tool_result 映射到同一工具记录，重复结果幂等更新。
- 工具开始、结果立即持久化，并推进 remoteRevision；构建产物不再等到模型整轮回复结束才可索引。
- 会话存储通知原生聊天页、文件页刷新；手动刷新也会读取最新保存的远程版本。
- 旧原生页面保存时保留较新的远程消息/工具记录；远程 checkpoint 保存时保留原生草稿和显式附件。
- 同一会话已有远程运行任务时，原生发送入口保留草稿并提示任务仍在执行，避免启动冲突任务。

## 验证记录

1. FLEX 生产 Chat / Runtime / TouchDriver UIKit 模拟器测试：79 项，0 失败。包含自定义视图和控制器的声明类、signature、无伪造生命周期执行结论；既有模型、会话权限、收起/恢复、触摸及滚动回归。
2. 会话存储测试：35 项，0 失败。包含旧原生快照不能覆盖远程记录，远程更新保留用户草稿/附件。
3. 附件及资源索引测试：102 项，0 失败。包含重复工具结果幂等，以及模型回复结束前立即索引构建产物。
4. 实际 Dylix 模拟器 Studio→聊天→会话文件界面回归：7 项，0 失败。覆盖恢复的 8 字节选区不自动添加、显式所选代码菜单、已打开文件页立即收到产物、聊天记录刷新和远程同步不制造附件。
5. 生产 Remote HTTP 集成通过：真实本地 HTTP 模型回显、精确模型选择、无效模型拒绝、同一会话一次总授权、撤销/隔离、工具完成记录持久化、配对、心跳、16 KiB 回复、伪造回复拒绝及退出。
6. FLEX arm64 rootless dylib/deb、Dylix 模拟器及设备 IPA 构建通过。IPA 内置同版本插件，交付时核对 manifest SHA-256、deb 内 dylib 和独立 dylib 一致。

## 验证边界

模拟器 UI 回归使用本地夹具；Remote 集成使用本地 HTTP 模型回显和 FLEX 应答夹具，不使用用户密钥。构建产物即时刷新回归使用测试构建结果与真实文件。本轮未在红果真机重新注入，也未证明某个红果业务按钮的持久 Hook 已跨页面/复用稳定。模拟器专用测试夹具不编入设备版。

## 主要文件

- FLEX/FLEXDylixRuntime.m、FLEXDylixChatViewController.m、Makefile。
- App/Studio.m、App/AI/UI/TFAIAttachmentMenu.m。
- App/AI/Actions/TFAISessionResources.h/.m、App/Remote/DXRemoteWorkspace.m。
- App/AI/Sessions/TFAISessions.m、App/AI/UI/TFAIChat.m、TFAISessionFiles.m。
- tests/FlexAgentUISmoke.m、AIV2SessionsTests.m、AIAttachmentFilesTests.m、AIAttachmentFilesRun.py、FlexSessionSyncRegression.inc、RemoteFlexIntegration.py。
- App/main.m、scripts/build.py、Resources/FLEXPlugin/manifest.json 及 1.0.19 插件产物。

## 安装验收

配套更新 Dylix build187 与 FLEX 1.0.19。进入已有会话应不再自动添加旧代码；让 FLEX AI 构建时打开 Dylix 会话文件页，确认工具成功返回后即可看到产物。让 AI 对目标按钮读取 hookEvidence，再跨页面重进和复用验证定位条件。原有项目、人设、技能、记忆不清除。
