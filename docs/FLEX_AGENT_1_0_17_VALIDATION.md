# FLEX 1.0.17 / Dylix 1.0.7 build 185：滚动结果语义

## 用户反馈

用户提供红果短剧剧场列表的 AI 运行记录：FQFeedListCollectionView 在顶部 contentOffset.y=-6，连续向上请求不再产生位移；向下 0.5 页后 y=403.666…，截图和卡片位置均变化；再向上回到 -6 并恢复聊天。该记录支持滚动在该宿主生效，但不是本机独立获取的原始工具日志，不能推广为所有 App 都通过。

## 修正

原 scroll_view / flex_scroll 无条件返回 scrolled=true，误把“执行了设置偏移请求”当成“实际位置改变”。

现在同步读取设置前后的实际 contentOffset：

- scrolled：请求轴实际移动超过 0.01 pt 才为 true。
- previousOffset / contentOffset：操作前后偏移，保留既有 contentOffset 字符串格式。
- delta：数值 x/y，便于判断真实位移。
- reachedBoundary：是否已在所请求方向的边界，考虑 adjustedContentInset；刚移动到边界时可以同时 scrolled=true / reachedBoundary=true。
- reason：moved、boundary 或 no_movement。到边界不属于工具错误。
- requeryRequired：仍为 true。实际业务效果需再次读取页面/截图，偏移改变不保证异步内容已完成加载。

仅约束请求轴，避免一次纵向滚动无意校正横向偏移，反之亦然。参数、授权、最大页数和目标范围保持原样。同步更新工具描述及 FLEX 会话操作说明。

## 验证

生产 FLEX Chat / Runtime / TouchDriver 在 UIKit 模拟器运行；HTTP 与无关 FLEX 服务为 fixture。

新增回归：目标 UIScrollView 的负顶部 inset、顶部无位移、向下实际位移、横滚保持纵轴、移动同时到达顶部；原生 FLEX UITableView 的顶部/底部重复请求均不再报假成功。既有无悬浮窗、菜单重开后同一会话持续运行、输入、触摸、头文件和撤销测试继续运行。

新包尚未在用户红果真机重新注入；本轮没有重新执行真实模型请求。最终检查数、产物 UUID 和哈希见交付目录的产物核验.json。
