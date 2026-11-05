# FLEX 1.0.14 / Dylix 1.0.7 (182) 验证记录

日期：2026-11-05。Dylix device 构建 SDK：iPhoneOS26.0.sdk，最低系统 iOS 15.0。FLEX：arm64、rootless 包。

## 通过的检查

- Theos `make package`：成功。新增聊天与运行时代码实际参与编译、链接、签名和打包。
- Dylix device 与 simulator 构建：成功。保留原有 nullability 等编译警告，不把构建成功等同真机运行成功。
- `tests/FlexAgentUISmokeRun.py`：27 项、0 失败。生产聊天控制器与运行时代码在 iOS 18.3 Simulator 的真实 UIKit 中运行；Dylix HTTP 与无关 FLEX 服务使用测试替身。结果另存 `flex-agent-ui-results.json`。
- `tests/AITransportNetwork.py`：103 项、0 失败。
- `tests/ToolRegistryRun.py`：174 项通过。
- `tests/FlexBridgeTests.m`：通过。包括新增 11 个操作的白名单、配对设备隔离和回复往返。
- `tests/RemoteFlexIntegration.py`：在当前 simulator 构建的真实 Network.framework HTTP 服务上通过配对、心跳、命令/回复、伪造回复拒绝、现场发布、任务、临时权限授权/撤销、退出。新增各项 UI 命令的执行由前述 UIKit 测试覆盖，此 HTTP 测试未连接实际注入的 FLEX。
- deb 内的 dylib 与独立 dylib 字节一致；IPA 内置 deb / dylib 与 manifest、独立交付文件 SHA-256 一致。

## 产物

- `Dylix-1.0.7-build182-unsigned.ipa`：141195907 bytes；SHA-256 `3e4f3e10724b706263e8cd51f2f9d01abaeac360907e4f20e9436b5378e23706`。
- `FLEX++-1.0.14-arm64-rootless.dylib`：12878496 bytes；SHA-256 `34ceb26578813b4790bf4d39847aee1f74030cfffc9acd21c8726099a7a7422d`。
- `com.pxx917144686.flex_1.0.14_iphoneos-arm64.deb`：1712368 bytes；SHA-256 `62542d2f2afd6ff0af6b2cd6b955f196dc083393f8f90d02b181406c7002a0e9`。

交付副本目录：`/Users/xuegao/Downloads/Dylix-FLEX-1.0.14-build182/`。

## 验证边界

本次没有在用户实际目标 App 内注入新插件，也没有以实际模型请求验证决策质量。已验证工具实现与通信；不能据此声称任意宿主零闪退或全部第三方 FLEX 扩展均已自动化。工具目录会明确标示未开放项；凭据内容、任意方法调用、任意注入等既有边界保持不变。截图的模型输入还要求所选模型已通过图片能力探测。
