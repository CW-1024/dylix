# AI 与软件互通检查 · Build 138

## 接入方式

参考 OpenMinis 的 ConfigRegistry 统一注册思想，Dylix 的应用操作由 TFAIActionRegistry 定义，read_app_state 返回实际可用工具、可编辑设置、操作参数和附件限制。执行调用实际连接、Git、存储和会话服务；不是仅在提示词中宣称支持。实现为本项目代码，没有复制上游实现。

研究版本：OpenMinis 1a71df0f381cefde80bf912b723de6f9831bc177。重点阅读 src/ios/Shared/Config/ConfigRegistry.swift、src/ios/Agent/Chat/AIChatViewModel+Attachments.swift 和 src/ios/Shared/ExternalFileImporter.swift。

## 已接通的路径

- 应用外观、编辑字号、优化级别、SDK、最低系统、deb/dylib 开关、Rootful/Rootless/RootHide、产物命名、联网开关和音频辅助：read_app_state / set_app_settings。
- 已保存连接列表、选用连接、名称、模型、工具开关和已有思考参数覆写：app_action；当前会话模型/强度选择面板：open_model_controls。连接更改下轮生效。密钥及端点使用已有 AI 设置界面编辑。
- 项目列出、创建、克隆、绑定，以及源文件读取、搜索、目录创建、补丁、删除、配置提案、SDK 切换、构建、诊断、产物清理：原有项目工具。
- Git 偏好、初始化、分支创建/切换/删除和 HTTPS 远端：app_action；差异、历史、暂存、提交、下载更新、上传继续使用 Git 专项工具。
- 会话信息、重命名、置顶：app_action。工具执行后同步活跃页面状态，避免下一次持久化覆盖。
- 会话附件、生成结果、头文件、构建及项目目录：与页面共用 TFAISessionResourceIndex，list_session_files 返回不透明资源 ID、时间和消息来源；read_session_file 最多 120 行/16 KB。
- 存储统计、分类明细、所选缓存/旧临时/导出 ZIP/回收站清理：app_action；清理使用本机快照、所选 ID、文件指纹及原有清理服务；构建结果用 clean_builds。活跃附件、IPA、头文件需在原生存储界面审核。
- 设置、AI 设置、存储、会话文件：原生页面入口。模型、权限、附件选择：现有聊天控制界面，附件选择在当前任务结束后打开。权限面板由用户选择，不由模型给自己授权。
- 二进制和头文件工具仍由当前会话选择的真实输入注册；网络工具由开关及当前连接能力决定。没有输入时不会伪造可操作文件。

## iOS 15 空白问题

截图的输入框紧贴导航栏、下方为空，更符合键盘布局将消息列表压缩的表现；截图没有证明会话存储丢失。旧布局直接将 composer.bottom 绑定 keyboardLayoutGuide.top，新布局绑定 safeArea.bottom，通过本地键盘帧计算实际遮挡；后台与返回页面复位。停靠键盘只扣一次安全区，浮动、隐藏和零尺寸键盘不会压缩整个消息列表。

当前主机没有任何已安装 Simulator Runtime。已完成真实 arm64 编译和键盘几何回归，尚未在 iOS 15.0.1 / iPhone 13 Pro Max 上复现及确认修复；请以受影响设备复测为最终依据。

## 附件与 OpenMinis 比较

OpenMinis 所核对的 addFileAttachment 和 ExternalFileImporter 是先用安全作用域/协调器把文件复制到本机，再登记附件；这两条导入路径没有统一的 20 MB 检查。这不等于每个模型服务都支持无限附件，也不应把其云同步大小限制当成聊天附件上限。

Dylix 原来外部导入把目录、非普通文件、权限读取失败和超过20 MB合成同一句提示，并且外部24 MB批次与内部128 MB不一致。现统一校验并逐文件说明失败原因；成功的兄弟文件保留。文件夹只建立授权，不批量上传内容。

当前本机文本/原图单文件20 MB，deb/dylib检查输入64 MB，每批最多80项且原始总量128 MB；IPA继续走独立头文件工具。实际发送图片会缩放压缩到每张2 MB，发送总量4 MB。文本本机快照与目录授权只发送清单，通过工具按需读取，不把完整本机字节数计作请求体。

## 剩余边界与后续

本次没有宣称每一个页面按钮都已自动化。项目回收恢复/删除、仓库冲突解决、崩溃报告专用导入、通知系统授权和带密钥账号新增等仍使用现有原生页面或各自专项流程。界面入口可由 AI 打开，系统选择/确认结果必须由实际 UI 返回。继续扩展应进入同一注册表，并添加对应服务测试；不要让提示词代替不存在的执行入口。

构建使用 iOS26 SDK，内嵌插件默认仍 SDK16.4 / iOS15。构建环境缺少模拟器运行时和现成 Rust 工具链，本次复用未经修改的 classdump 静态库和 build136 图标资源；所有更改的 Objective-C 源文件重新编译。
