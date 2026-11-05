# 压缩包工程导入

打开项目 → 从 ZIP / 压缩包导入 → 选择文件。

在手机本地解压、识别工程和复制到工作目录。单工程直接打开，多个带工程标记的目录进入选择列表。保留源码目录、头文件、资源、control、plist、Makefile 和现有 MobileCompiler.json。不会启动 make 或执行压缩包里的脚本。

主要格式：ZIP / ZIP64、7z、RAR / RAR5、TAR、TAR.GZ / TGZ、TAR.BZ2 / TBZ2、TAR.XZ / TXZ，以及单文件 gzip / bzip2 / xz / lzma。密码 ZIP 支持输入密码，具体加密/压缩方法以设备系统 libarchive 的能力为准。分卷压缩包与部分加密 RAR / 7z 不在本版保证范围内。

识别优先级：MobileCompiler.json、control / Makefile 与源码目录；普通源码包去掉公共外层目录后生成配置。已有配置不覆盖，只在缺少 sources 时补充递归扫描的源码列表。扫描的源码类型为 .xm / .m / .mm / .c / .cpp。已有编译器能力限制仍适用，导入不代表所有桌面 Theos / Xcode 工程均可直接构建。

0.4.19 的 Makefile 导入支持单个 TWEAK_NAME / LIBRARY_NAME、变量及嵌套变量名、= / := / ?= / +=、本地 include、ifeq / ifneq / ifdef / ifndef 和 else if 链；SCHEME 按 rootless 解析。支持 wildcard、addprefix、addsuffix、filter、filter-out、sort、strip、patsubst、subst。源列表明确时按 Makefile 选择，避免混入旧生成的 .mm。shell、任意配方和安装命令不执行；源列表含尚未支持的表达式时明确报错，复杂工程使用 MobileCompiler.json 明确配置。

导入框架、库、-D / -I / -include / -W / -w / -O、ARC 开关、C/C++ 标准及 Logos generator；部分额外链接参数仅识别 -l 和 -framework，其他参数需核对。生成配置写有 importNotes。已有 MobileCompiler.json 保持优先，升级不会覆盖旧配置；要重新识别 Makefile，可从原始压缩包重新导入。

Logos 支持 .x（Objective-C）与 .xm（Objective-C++）。每个源码生成独立 logos-NNN.m / .mm，编译时保留原源码所在目录的头文件搜索路径；report.json 记录原文件到中间文件的对应关系，日志保留各中间文件的编译命令。

解压使用流式读写，界面显示实际条目数和已解压字节，可取消。失败清理临时文件；源压缩包不修改。上限为 100000 条目、单文件 1 GiB、总解压 4 GiB。拒绝越界路径、符号链接/硬链接、特殊文件和重名文件，忽略 __MACOSX、.DS_Store、AppleDouble 元数据。

验证：`tests/ArchiveImportCLI.m` 调用与 App 相同的实现，`tests/test_archive_import.py` 在 macOS 上验证解压、密码、工程识别和异常输入，不启动 iOS 模拟器。最终 iPhone 文件提供商交接与界面仍需真机验收。
