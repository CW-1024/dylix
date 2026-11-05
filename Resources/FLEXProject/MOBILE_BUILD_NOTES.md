# FLEX 手机编译适配说明

原始目录：/Users/xuegao/彩虹编译/FLEX（未修改）。

- 依据原 Makefile 的排除规则选择 288 个源码，排除已有构建产物。
- 工程配置 MobileCompiler.json 显式列出源码、头文件目录、宏、前置头文件、系统框架与库。
- 本轮生成 ARM64 / iOS15+ 动态库，不沿用原 Makefile 的 iOS9 最低版本。
- 源码唯一适配：x/filza/UCFilzaTool.m 增加 #import <mach/mach.h>，为 task_info 及相关类型提供声明。
- 用户项目没有目标过滤 plist；control 的架构字段也不符合本工具当前 Rootless 打包契约，因此本次仅生成 dylib，package=false，保留原 control 供参考。
- 使用 dynamic_lookup 的链接结果还需目标运行环境核验；构建成功不代表全部调试功能已在目标进程验收。
- 手机验证：导入源码 → 载入 FLEX 编译测试工程 → 运行，保持 App 前台。预期 report.json sourceCount=288，289 条命令 exit=0，success=true。
