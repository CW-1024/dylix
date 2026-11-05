---
name: Hook 模板
description: 新增或定位方法Hook、原调用与初始化顺序时按需读取。
---

先确认类、实例/类方法、selector、参数与返回类型。保持方法ABI一致，不猜对象类型。最小模板：%hook TARGET_CLASS
- (void)TARGET_METHOD { %orig; }
%end。多参数%orig按原签名传参。%ctor中只初始化必要分组，避免无证据添加启动行为。先原样%orig测试，再逐项增加逻辑。
