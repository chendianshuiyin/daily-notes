# 阶段四：历史与回顾 (History & Review)

## 目标
实现数据的检索与展示，支持列表浏览、搜索和筛选。

## 任务列表

### 1. 历史页 (HistoryPage) UI
- [ ] **搜索栏 (SearchBar)**
    - 顶部吸附
    - 输入框 `TextField`: hintText "搜索内容或标签..."
- [ ] **筛选 Chips**
    - `Wrap` + `ChoiceChip`
    - 预设: "全部", "已同步", "未同步"
    - 动态标签: 从数据库聚合 Top 5 常用标签 (可选)
- [ ] **记录列表**
    - `ListView.builder`
    - **分组展示**: 按月份或日期分组 (Optional, e.g., "2023年10月")
    - **列表项 Card**:
        - 左侧: 日期 (e.g., "12日")
        - 中间: Title (截取前20字), Tags
        - 右侧: Sync Status Icon

### 2. 搜索与过滤逻辑
- [ ] **Isar 复杂查询**
    - 全文搜索: `.titleContains(query) or .contentContains(query)`
    - 标签过滤: `.tagsElementEqualTo(tag)`
    - 组合查询: 搜索词 + 标签 必须同时满足
- [ ] **分页加载 (Pagination)**
    - 既然是本地数据库，Isar 速度很快，初始加载 Limit 20-50 条
    - 滚动到底部加载更多 (Offset, Limit)

### 3. 查看详情
- [ ] **点击跳转**
    - 点击列表项 -> 跳转 `/editor` (只读模式 或 直接编辑模式)
    - 能够从详情页返回并保持列表位置
