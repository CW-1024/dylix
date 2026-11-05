# 模型连接：User-Agent 与 HTTP

版本 1.0.7（165）。入口：设置 → AI → 模型连接 → 选择连接 → 传输与请求头。

## 自订 User-Agent

每个连接可以填写单行User-Agent。留空使用系统默认；最多512个可打印ASCII字符，换行、控制字符与非ASCII输入在保存和请求前被拒绝。设置用于该连接的模型列表发现、能力探测、对话及同源重定向。无需把User-Agent放进Base URL、模型名或API密钥。

它是普通客户端标识，不是鉴权凭据，也不保证服务商会接受请求。切换模型仍沿用该连接设置；按项目覆盖的连接选择规则保持原状。修改User-Agent或HTTP权限后清除旧能力探测结果，重新测试。

## HTTP API

Base URL 可填写HTTP。每条连接另有“允许此连接使用HTTP”开关，默认关闭；启用前提示请求、附件内容和API密钥按明文传输。地址可以先保存，开关关闭时实际请求会在网络前被阻止。关闭同时撤销旧版局域网HTTP授权，不修改地址。

HTTPS原有行为不变，OAuth连接继续要求HTTPS。App的ATS采用通用HTTP传输例外，以覆盖用户输入的任意HTTP主机；细粒度准入由模型传输代码按连接执行，ATS本身不是每连接授权机制。未关闭HTTPS证书校验。

同源比较采用实际协议、主机和有效端口：HTTP默认80、HTTPS默认443；跨域、跨协议、端口变化和改变请求方法的重定向被拒绝。HTTPS不会自动回落HTTP。远程网页只使用手机保存的连接，API密钥、OAuth token和User-Agent配置不返回网页。

Dylix Remote 的局域网HTTP服务与模型API连接是两条独立链路；打开其中一个不自动授权另一个。TLS保护网页/服务传输，User-Agent用于标识客户端，两者用途不同。

实现：`TFAIProtocol`、`TFAIConnections`、`TFAITransport`、`TFAISettings`及`build.py`中的ATS声明。测试见[Build165记录](BUILD165_TESTS.md)。
