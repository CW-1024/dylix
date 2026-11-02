# ARM64 异常展开回归（2026-11-02）

Dylix 直接进入 Clang cc1，遗漏了 Darwin 驱动默认的非叶函数帧指针设置。
这会生成 DWARF fallback；内置 LLD 14 对此样例的 FDE/LSDA 链接错误。
同一个 Clang 14 对象用 Apple ld 链接后，FDE/LSDA 地址正确。
LLVM 14 上游 InputFiles.cpp 也有忽略 eh_frame SUBTRACTOR relocation 的路径，
它与本次对象的重定位形式吻合；尚未重编译/修补链接器确认具体源码行。

修正：编译命令添加 `-mframe-pointer=non-leaf`、`-funwind-tables=1`。
其中只添加 unwind-tables 的控制组仍失败，帧指针参数是已验证的关键变量。
保留 Objective-C/C++ 异常处理，未通过移除 catch 或删除展开表规避。

运行验证：arm64 iOS 18.3.1 模拟器，内置 Clang/LLD 14 生成的模拟器目标二进制。
原参数：ObjC KVC catch 路径 SIGSEGV（139），C++ throw/catch 路径 SIGABRT（134）。
修正参数：两条路径都返回 42；C++ 析构器执行。
执行 `python3 tests/test_embedded_unwind.py` 可重现正负对照。
负对照故意让独立辅助进程崩溃，不是 App 自身崩溃。

完整 AutoMessage 对照：归档源码与 provenance 的输入哈希全部匹配；使用用户提供的
6 个 Logos 生成文件和原编译/链接参数，仅替换本地路径并添加上述两项。
SDK 16.4，deployment 15.0，arm64；28 个对象成功链接。
修正产物无 eh_frame FDE，compact unwind 包含 2 个 personality 和 LSDA。
设备目标 dylib UUID：4C4C44E0-5555-3144-A1B3-E9F760583F15。

真机反馈：用户确认上述 UUID 的修正测试 dylib 注入抖音后不再闪退。
此结果来自用户反馈；修正后的手机端 Dylix 重新构建仍需同配置回归。
本次使用 x86_64 模拟器版工具框架，输出 arm64；设备版框架本身仍需真机回归。
补齐驱动参数解决了已复现路径，LLD 14 对其他 DWARF fallback 输入的处理仍待升级验证。
IPS usedImages.size 表示镜像映射范围，不能与磁盘文件大小直接比较。
发布版与开源版源码已同步参数修正，模拟器 App 正常构建入口也已验证生效。
构建版本更新为 1.0.5（143）。尚未推送远端仓库。
