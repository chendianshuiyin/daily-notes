# 阶段二：核心数据层与首页 (Core Data & Home)

## 目标
实现本地数据库能够跑通 CRUD，完成首页的统计展示（热力图、统计卡片）和每日详情列表逻辑。

## 任务列表

### 1. 数据库模型 (Isar Schema)
- [ ] **定义 `Note`实体**
    - `id` (Id): 自增主键
    - `uuid` (String, Unique): 同步用
    - `content` (String): 纯文本预览
    - `rawJson` (String): Quill Delta 数据
    - `tags` (List<String>)
    - `createdAt` (DateTime)
    - `targetDate` (DateTime): 索引，用于按天查询
    - `syncStatus` (Enum): Synced, Dirty
- [ ] **生成代码**
    - 运行 `flutter pub run build_runner build` 生成 `note.g.dart`

### 2. 数据仓库层 (Repository)
- [ ] **定义 `NotesRepository` 接口** (可选，若不做严格层级可跳过)
- [ ] **实现 `LocalNotesDataSource`**
    - `init()`: 打开 Isar 实例
    - `saveNote(Note note)`: 插入或更新
    - `getNotesByDate(DateTime date)`: 查询指定日期的记录
    - `getAllNotes()`: 获取所有（用于热力图统计，需优化查询，只查日期字段）
    - `deleteNote(int id)`: 标记删除或物理删除
- [ ] **实现 `NoteProvider` / `HomeViewModel`**
    - 封装数据层调用，提供 UI 状态 (State)

### 3. 首页 (HomePage) UI 实现
- [ ] **整体布局**
    - 使用 `CustomScrollView` (Slivers) 以支持复杂滚动效果
    - 顶部 `SliverAppBar` (显示 "每日记录")
- [ ] **统计卡片 (Stats Cards)**
    - [ ] **布局**: Row -> 2 Cards (Total Notes, Streak)
    - [ ] **逻辑**: 计算数据库中总记录数；计算连续打卡天数（算法：从昨天/今天倒推连续存在的 targetDate）
- [ ] **日历热力图 (Calendar Heatmap)**
    - [ ] **组件集成**: 引入 `flutter_heatmap_calendar`
    - [ ] **数据映射**: 将 Isar 查询结果 List<Note> 转换为 Map<DateTime, int> (Dataset)
    - [ ] **交互**: 点击某天 -> 更新下方详情列表的 `selectedDate`
- [ ] **每日详情列表 (Daily List)**
    - [ ] **UI**: 时间轴风格 (Timeline)
    - [ ] **列表项**: 显示时间 (HH:mm), 内容摘要, 标签 Chips
    - [ ] **逻辑**: 监听 `selectedDate` 变化，实时刷新列表
    - [ ] **空状态**: 当日无记录时显示引导创作的 UI 插画
