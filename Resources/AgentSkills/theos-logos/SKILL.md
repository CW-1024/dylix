---
name: Theos / Logos 写法
description: 编写或检查Objective-C、Objective-C++和Logos语法时按需读取。
---

先读取项目Makefile、配置和相邻实现。%hook后写真实类名，%end闭合；只把合法Logos语法交给预处理器。%orig保留原调用的参数和返回类型。检查ARC、C++标准、SDK和最低系统版本，不假定完整Theos shell可用。修改前沿用项目审批，构建通过后仍需验证宿主运行。
