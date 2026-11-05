# FLEX 1.0.18 / Dylix 1.0.7 build186

日期：2026-11-05。

## 本次修复

- FLEX 聊天页只保留一个本会话总授权入口，敏感读取与现场控制共用授权。删除原来两档各 30 分钟的逻辑。
- 授权以配对设备、项目、真实 AI 会话 ID 为边界，无倒计时或过期时间。收起、重开同一会话继续有效；新会话不继承。支持主动撤销，撤销设备、退出或停止 Remote 服务时清除。
- 首次 FLEX 敏感/控制工具请求未授权时，只请求一次会话总授权；授权后，Dylix runtime 和 FLEX 执行端均检查同一个会话授权，不再出现两层逐次确认。
- 新会话在首次发送或首次授权前创建真实 ID；桥接命令携带 sessionID，拒绝复用其他会话的授权。
- 项目写入、构建、Git 等原有审批流程保持独立；工具范围和参数校验未放宽。
- FLEX 保存原始 modelID，选择、历史恢复、重开聊天、实际 ai_send 均传递连接 ID 与原始模型 ID。运行中的请求不允许界面误切模型，过期的异步模型菜单结果不能覆盖新会话选择。

## 模型问题根因

TFAIAvailableModels 会把同一连接展开成多条模型，连接 ID 相同而 model 不同。原 FLEX 只保存展示文字 modelName，并且 ai_send 仅发送 connectionID，遗漏 model；Remote 在无 model 条件下取第一个匹配连接，因此用户选其他模型后仍使用默认模型。服务端已经支持精确模型选择，本次修复客户端字段丢失和恢复路径，并验证失效模型不会静默回退。

## 已运行验证

1. 生产 FLEX Chat / Runtime / TouchDriver 的 UIKit 模拟器测试：74 项，0 失败。
   - 实际调用 sendTapped，拦截请求验证同一连接从 gpt-6-sol 切到 gpt-6.1-sol 后 model 字段改变。
   - 会话、项目与原始模型 ID 保留；运行中禁止误切；授权查询后不出现第二个逐次确认窗口；其他会话命令不能复用授权。
   - 原有收起/恢复、触摸、输入、滚动边界、停止与过期回调回归仍通过。
2. 真正运行 Dylix 模拟器 Remote HTTP 服务的集成测试通过。
   - ai_create 创建会话；查询、单次总授权、幂等授权、新会话隔离、撤销通过。
   - 本地 HTTP 模型回显服务实际收到同一连接下两个不同 model；会话持久化 modelID 正确；已移除模型报错且未发起替代模型请求。
   - 生产 runtime 实际处理模型返回的 flex_sensitive_read(defaults_get) 与 flex_control(set_network_recording) 两次调用，只产生一次总授权；两条命令与结果走真实 HTTP 桥接，命令 sessionID 正确。
   - 配对、心跳、伪造回复拒绝、16 KiB 回复传输与退出通过。
3. 工具注册表运行时测试：13 项通过。
4. 原生 DXFlexBridge 回归通过。
5. FLEX arm64 rootless dylib / deb 编译通过；Dylix 模拟器和 iOS 26 SDK 设备构建通过，设备版最低 iOS 15。

## 验证边界

UI 测试的 HTTP 为 fixture；Remote 集成使用真实本地 HTTP 模型回显与 FLEX 应答 fixture，不使用用户密钥，不声称已验证第三方服务商的真实模型推理结果。本次未在红果目标 App 真机注入，需安装配套新 IPA 与新插件后验收实际设备表现。模拟器专用夹具不编入设备版。

## 主要修改位置

- FLEX/FLEXDylixChatViewController.m、FLEX/Makefile。
- App/Remote/DXRemoteWorkspace.m、DXFlexBridge.m、DXFlexPluginInfo.m。
- tests/FlexAgentUISmoke.m、RemoteFlexIntegration.py、RemoteSimulatorRegression.inc。
- Resources/FLEXPlugin/manifest.json 及新版插件包、scripts/build.py。

## 使用

更新 Dylix build186 与 FLEX 1.0.18；打开同一 Remote 项目与会话，点击权限并允许一次“授权本会话全部 FLEX 工具”。之后该会话的 FLEX 操作不再分别授权。选择其他模型后，从下一条消息使用所选模型；正在运行的请求先完成或停止再切换。新会话重新授权，原项目与历史不清除。
