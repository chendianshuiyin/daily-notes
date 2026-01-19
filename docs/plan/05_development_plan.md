# 开发计划

## 阶段一：基础设施搭建 (预计 2 天)
**目标**：完成项目初始化，打通路由和基础UI框架。
- [ ] Initialize Flutter Project & Git Repo.
- [ ] Setup `go_router`, `provider`, `isar`.
- [ ] Configure `ThemeData` (Light/Dark) based on Design.
- [ ] Create Basic Layout (Scaffold, AppBar, BottomNavigationBar if needed - though design seems to rely on separate pages).

## 阶段二：核心数据层与首页 (预计 3 天)
**目标**：实现本地数据库操作，完成首页统计展示。
- [ ] Implement `Note` Isar Collection.
- [ ] Create `NotesRepository` (CRUD).
- [ ] Implement `HomePage`:
    - [ ] Calendar Heatmap (mock data first, then real data).
    - [ ] Stats Cards logic.
    - [ ] Daily Detail List logic.

## 阶段三：记录功能实现 (预计 3 天)
**目标**：完成核心写作体验。
- [ ] Implement `EditorPage`:
    - [ ] Integrate `flutter_quill` or simpler `TextField` first.
    - [ ] Toolbar implementation (Bold, Time insert).
    - [ ] Date Picker logic.
    - [ ] Save functionality (Write to DB).

## 阶段四：历史与回顾 (预计 2 天)
**目标**：实现数据的检索与展示。
- [ ] Implement `HistoryPage`:
    - [ ] Infinite Scroll List (Pagination).
    - [ ] Search Bar logic (Isar filter).
    - [ ] Filter Chips UI & Logic.

## 阶段五：设置与同步 (预计 3 天)
**目标**：完成 WebDAV 同步链路。
- [ ] Implement `SettingsPage`.
- [ ] Integrate `webdav_client`.
- [ ] Implement Sync Service (Background worker / Foreground trigger).
- [ ] Conflict resolution logic (Simple Overwrite).

## 阶段六：优化与测试 (预计 2 天)
**目标**：提升稳定性和体验。
- [ ] Bug Fixes.
- [ ] Performance Tuning (List rendering).
- [ ] App Icon & Splash Screen.
- [ ] Release APK.
