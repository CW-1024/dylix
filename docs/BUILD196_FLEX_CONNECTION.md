# Build196：FLEX 跨设备连接诊断

Dylix 1.0.8 / Build196，配套 FLEX 可见版本保持 1.0.0。此次修改位于实际注入插件的连接模块，Dylix 安装包内置插件同步更新；已注入旧插件的目标 App 需要更新插件并重新启动 / 注入，仅更新手机 Dylix 不会替换 iPad 中正在运行的旧代码。

## 已确认的问题

用户截图中的提示来自插件的 TCP `connect()` 失败分支。旧实现直接关闭 socket，并把所有错误覆盖为“无法连接 Dylix；请确认手机已开启局域网远程服务”。该阶段尚未发送配对请求，因此不能据此认定授权码错误，也不能判断究竟是连接被拒绝、网络路由不通或系统访问策略拒绝。

旧实现只设置发送 / 接收超时，没有真正限制阻塞式 connect；读取失败未保留 errno，部分响应可能被误判成 JSON 错误；错误分支在发现 JSON 不是对象后仍按字典下标读取，错误端口返回数组时可能触发异常。

未发现 iPhone → iPad 场景被业务层禁止。Dylix 监听指定 Wi-Fi IPv4 地址，接受局域网私有地址客户端并保留原有连接数量、认证、CSRF 与权限检查。此次没有放宽服务器访问范围或改变授权流程。

## 改动

- 新增 Foundation 实现 `FLEXDylixConnection.h/.m`，供真实聊天请求调用。保留现有 HTTP、IPv4、实际端口、Cookie、CSRF、GET / POST 和40MiB响应限制，不使用宿主 URLSession / ATS 路径。
- 非阻塞 socket + poll + 单调时钟截止时间，连接、发送、接收各阶段最多8秒；EINTR重试，清理前保存 errno。
- 区分 connect、send、read、HTTP、响应头、JSON 与响应不完整。Content-Length 接收完整即结束，不继续等待对端关闭；异常、重复冲突长度及不支持的传输编码拒绝解析。
- HTTP 保留状态码 / 错误域。配对码无效、授权过期、请求过频、设备上限、工作区权限、CSRF、设备锁定等只映射已知服务端错误码，不把任意服务器响应正文展示或复制到诊断。
- 错误弹窗增加“复制诊断”；连接设置增加“上次连接诊断”。自动恢复与心跳失败保留诊断和配置，心跳不循环弹窗打扰。
- 诊断包含当次实际目标、固定接口、阶段、POSIX / HTTP、时间、宿主标识 / 版本、系统版本及宿主是否包含本地网络用途说明。用途说明存在不等于已授权，缺失也不单独判定失败原因。
- 不记录或复制授权码、Cookie、访问令牌、CSRF、请求正文、响应正文和聊天内容。诊断只在内存保留，由用户主动复制，不自动上传。

FLEX 本轮修改源码（连接模块、调用方与打包签名）保存于 [源码快照](patches/build196-flex-connection-sources.zip)，应用于维护中的 FLEX 工程；不是完整独立 FLEX 工程。打包阶段给最终 dylib 加 ad-hoc 签名，验证 DEB 内 dylib 与单独分享的文件一致。

## 给该用户的排查顺序

1. 手机 Dylix 确认 HTTP 服务运行中，重新复制当前完整访问地址；iPad 使用该地址，不使用 WebDAV 端口。
2. 在同一台 iPad 的 Safari 打开这个地址。Safari 也打不开，优先比较两端 Wi-Fi、手机服务状态、VPN 的局域网绕行和路由器访客 / AP 隔离。截图有 VPN 标识，但这只是线索，未证明是 VPN 故障。
3. Safari 能打开而插件不行，检查 **iPad 上被注入的目标 App** 的本地网络权限 / 系统策略，而不只是 iPhone 上 Dylix 的权限。不同 App 的访问状态不能用 Safari 的结果代替。
4. 更新 iPad 插件后重试，失败时点击“复制诊断”回传。根据阶段和 errno / HTTP 再确定具体修复，不靠统一提示猜测。

苹果官方资料：TN3179 *Understanding local network privacy*，说明到本地网络的出站 TCP 及 BSD Sockets 同样受本地网络隐私检查约束。参考 URL：

https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy

本轮读取了 Apple 文档 JSON 原文；没有通过修改目标 App 的 Info.plist、绕过权限或改变 VPN 设置来掩盖问题。

## 测试

- `tests/FlexConnectionRun.py --flex /path/to/maintained/FLEX`：122项。真实生产 socket 连接本地 TCP fixture；覆盖分片、认证头、Cookie、Content-Length、连接拒绝、真实 connect 超时、响应超时、错误授权码、401 /403 /404 /423 /429 /503 /302、JSON数组 /null /HTML、截断及诊断脱敏。
- `tests/FlexAgentUISmokeRun.py --flex /path/to/maintained/FLEX --device <simulator> --persistence --diagnostics`：118项。生产聊天 / Runtime 在真实 UIKit 中运行，HTTP 与无关 FLEX 服务为 fixture；覆盖既有手势、会话、模型路由、覆盖安装配置保留、错误弹窗、诊断入口和实际端口显示。模拟器目视检查诊断弹窗。
- `tests/RemoteCoreRun.py`：61项服务端基础测试及 OpenSSL 证书解析回归通过。
- FLEX arm64 rootless dylib / deb、Dylix 模拟器和设备 IPA 编译及资源哈希检查见 `BUILD196_TESTS.json`。

**未验证：**没有这位用户的 iPhone / iPad 实机、宿主权限和 VPN 配置，未复现其具体跨设备失败，不把诊断完善宣称为已解决该用户网络根因。旧iOS真机、实际路由隔离与VPN环境仍需新版诊断反馈。
