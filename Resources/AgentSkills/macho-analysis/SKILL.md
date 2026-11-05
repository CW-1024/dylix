---
name: Mach-O 分析
description: 检查Mach-O架构、依赖、UUID、符号与异常展开证据时按需读取。
---

使用现有binary_inspect只读能力，先确认实际加载UUID与产物SHA-256。检查LC_BUILD_VERSION、LC_LOAD_DYLIB、LC_RPATH、初始化节、__unwind_info、__eh_frame和符号表。区分strip前后差异，按镜像基址与帧偏移符号化。libunwind栈顶不等于首发故障；记录证据与未验证假设，保持对照源码和其他插件组合一致。
