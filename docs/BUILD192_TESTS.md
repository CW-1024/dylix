# Build 192 — DEB 兼容性修复

问题：https://github.com/yangokok886/dylix/issues/2

## 根因与修改

旧 DEB 使用合法但消费端兼容性不足的未压缩 `control.tar` / `data.tar`。TrollFools 的导入器只寻找压缩的数据成员，因此拒绝旧包。改为 `control.tar.gz` / `data.tar.gz`，使用 App 已链接的系统 libarchive，不增加 App 依赖。

旧 tar 只记录文件。现在按父目录先于文件的顺序补齐唯一目录条目，包含 `.bundle` 自身；目录使用 type 5，名称不附加可选的末尾斜线，以兼容 TrollFools 按 `.bundle` 后缀识别资源的实现。补充目录与文件冲突拒绝，保留路径、符号链接、资源大小等原有检查。

RootHide 原生方案保留 `iphoneos-arm64e`、`Library/...` 路径及既有链接设置。不自动添加转换包特有的 `.roothidepatch`、pkgmirror 或固定 jbroot 路径。

## 验证与复现

- `python3 tests/DebCompatibilityRun.py`：编译真实 DebPackage.m 和 arm64 Mach-O 夹具，检查三种方案、gzip、目录顺序、权限、control、资源字节、Unicode/长路径、非法路径、符号链接、目录与文件冲突；安装 dpkg 时额外检查 info、contents、extract。
- `python3 scripts/build.py --simulator` 后运行 `python3 tests/DebCompatibilityIOSRun.py`：由模拟器 App 内嵌 Clang/LLD 实际构建 rootful/rootless/roothide 包并检查产物。
- `swift run --package-path tests/DebConsumerReader DebReader <rootful.deb> <rootless.deb> <roothide.deb>`：测试专用解析器，使用与 TrollFools 相同版本的 ArArchiveKit 0.3.0、SWCompression 4.8.6、BitByteData 2.0.4，要求读到 dylib、bundle 根目录及资源。这些依赖不进入 App 构建。
- AI 工具回归套件：348 项检查通过。

宿主打包、消费端依赖解析及模拟器实际编译均通过。真机 TrollFools 导入、目标 App 注入及 RootHide 实际安装仍需对应设备验证；此记录不将归档检查等同于真机安装通过。

## 上游核对

仅核对格式和行为，未复制上游 App 实现。

- TrollFools：https://github.com/Lessica/TrollFools ，核对版本 `c5c87b859a9ee34d215548377273eddd34a7c7f6`，`InjectorV3+Preprocess.swift`。
- RootHide Theos：https://github.com/roothide/theos ，核对版本 `3ac89c984ec652fd16bcd91b33ae16de45ce76fa`。
- RootHide Bootstrap：https://github.com/roothide/Bootstrap ，核对版本 `053072440b88c9533c43df8cdcceb693d7a78ba4`。
