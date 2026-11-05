---
name: deb 打包
description: 检查rootful/rootless/RootHide布局、control、filter和产物时按需读取。
---

以项目配置和现有打包器为准。核对Package、Version、Architecture和依赖，CPU slice与包架构字段分别记录。检查deb内安装路径、filter目标与dylib实际UUID/SHA-256。rootless路径与其他布局分别校验；不要靠文件大小判断版本。写配置与构建仍走现有审批。
