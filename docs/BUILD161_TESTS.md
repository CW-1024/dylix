# Build 161 人设 / 思维验证记录

日期：2026-11-04。版本 1.0.7，构建 161；开源版与发布版使用同一套 Persona 实现。

## 自动回归

- PersonaRun：31 项核心断言通过，另起进程 2 项持久化断言通过。覆盖初始为空/默认关闭、单项互斥与撤选、三种模式、Unicode 字节数、连续组装三次、嵌套/残缺旧标记清除、存储读写失败与重启恢复。
- PersonaRuntimeRun：使用真实 AIRuntime 与本地模拟 transport，三种模式各连续发送三次并输入陈旧 system 块；每次仅一个 Persona 块，预览文本与完整 system 的 UTF-8 字节数一致，tools 数组与关闭时一致。关闭后下一次发送恢复 developer 层，公共聊天记录不含 system 提示。
- AIRuntimeBudgetRun：40 轮单工具与 40 轮每批 30 工具完成，停止/空回复/后台终止原因保持正确；7 项导航生命周期静态回归通过。
- DeveloperPromptTests：52 项检查，0 失败。原 developer 提示正文保持原样。

运行命令见 PERSONA.md。未连接付费模型或发送测试正文到外部模型。

旧的同步 transport 夹具在模拟 1,200 次工具回调时耗尽默认主线程栈，测试 runner 改为大栈 worker 后通过；生产异步传输和工具定义未为此改变。
macOS 测试优先使用本机完整 CommandLineTools SDK，缺少时回退 xcrun 选中的 SDK。

## 模拟器交互

设备：iPhone 16 Pro Max，runtime 显示 iOS 18.3，实际版本 18.3.1（22D8075）。

1. 初次进入列表为空、总开关关闭。
2. 通过原生编辑页保存 Test A 和 Test B（仅测试夹具正文）。字节统计随输入更新。
3. 开启 A，再开启 B：A 关闭、B 显示生效。
4. 终止进程并安装最新 simulator 构建后重启：列表、总开关、B 生效状态均恢复。
5. 从真正的设置页 AI 分组点击「人设」成功进入。
6. 通过现有主题设置切换纸感浅色，列表、编辑、预览正常；深色列表亦检查。
7. 将 B 切为 replace，预览只包含标记与 9 B 正文，完整 system 为 65 B，未包含 developer 提示层。
8. 关闭当前项后显示未选择生效项；确认删除两份测试条目并关闭总开关，最终为空列表、默认关闭。

截图在 `docs/images/persona/`。测试数据仅保留于截图/测试源码，未内置至 App。

## 构建与范围

开源版、发布版设备构建完成；App 与分享扩展使用 iOS 26.0 SDK，最低 iOS 15.0。Activity Widget 沿用既有 SDK / 最低系统。
保留现有发布版反馈/TG及开源版差异。build161 安装包、SHA-256 与组件信息记录于交付目录 manifest.json。

未进行 iOS 15 真机或真实模型端到端验收；模拟器验证与编译结果不等同于真机验证。基础预览与动态项目上下文的差异在界面明确说明。
未修改 binary_inspect、工具定义、developer 提示文本或新增第三方依赖。
