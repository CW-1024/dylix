# Dylix 1.0.7（160）发布验证 · 2026-11-03

## 发布范围

汇总Build148–159的最终Remote实现。Build160只同步主App、Share Extension、ActivityKit组件及配套framework为1.0.7 / 160，并更新README、CHANGELOG、API当前版本与发布说明。开发过程中的TLS、早期上传上限等被替换方案保留在历史记录中，不列为1.0.7当前特性。

GitHub发布开源源码及开源版未签名IPA；开源版不包含反馈接口或Telegram入口。带这些入口的发布版仅本地交付。两版均保留开源地址与GPL许可证。

## 本次实际重跑

- 核心HTTP/访问控制：61项通过；历史证书工具另通过OpenSSL签名、用途与SAN检查。当前Remote工作台使用HTTP，保留历史工具不表示开启TLS。
- 原生HTTP模拟器集成：94项通过，包括配对、设备授权、CSRF、Host/Origin、真实项目/文件、自动保存权限、HTTP WebDAV、锁屏文件保护与实际App切换。
- 音频生命周期：54项通过；AI后台生命周期与屏幕常亮：87项通过。
- 轻量编辑器差量历史：13项通过。
- Chrome156 + iOS18.3.1模拟器原生HTTP：113项真实浏览器检查通过，无页面脚本错误，无公网资源请求。覆盖新版本展示、默认自动保存、导航折叠、拖动缩放、窄屏/全屏、撤销重做、读写备份、冲突、上传下载、语法高亮和AI模型/流式显示。
- 上述六组共422项检查。浏览器AI供应商使用本地确定性夹具，不代表公网模型性能测试。

## 构建与包核对

两版主App及Share Extension均为arm64、SDK26.0、最低iOS15；ActivityKit组件沿用SDK18.2、最低iOS16.2。主App、Share Extension、ActivityKit组件和TFTaskActivity.framework的Info.plist版本均为1.0.7 / 160。内嵌插件SDK16.4与可选26.0保持不变。

核对：正式包无模拟器回归启动参数与控制文件标记；页面/脚本/样式及Monaco许可证和补丁说明与源码逐字节一致；gzip解压后编辑器内容匹配；GPL和第三方许可随包保存；两版反馈/TG入口差异符合预期。产物SHA-256、UUID与大小记录在本地交付manifest.json；GitHub附件另提供开源版SHA256SUMS。

## 运行边界

本次未进行Windows/Edge、iOS15真机、真实Wi-Fi长期传输或所有WebDAV挂载客户端验收。HTTP为局域网明文，服务默认关闭。后台连接仍受iOS挂起、音频中断及锁屏文件保护影响，不承诺永久运行。IPA未签名，安装前需按自己的设备与签名方式处理。
