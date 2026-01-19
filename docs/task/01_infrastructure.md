# 阶段一：基础设施搭建 (Infrastructure)

## 目标
完成项目初始化，打通路由和基础 UI 框架，确立代码规范与目录结构。

## 任务列表

### 1. 项目初始化
- [ ] **创建 Flutter 项目**
    - `flutter create daily_notes`
    - 设置 Android包名 (e.g., `com.example.dailynotes`)
    - 确认 Flutter SDK 版本 (3.10+)
- [ ] **版本控制**
    - `git init`
    - 配置 `.gitignore` (排除 `.dart_tool`, `build`, `.env` 等)
    - 提交初始 Commit

### 2. 依赖管理 (pubspec.yaml)
- [ ] **核心库**
    - `go_router`: 路由管理
    - `provider`: 状态管理
    - `intl`: 国际化与日期格式化
    - `uuid`: 生成唯一 ID
- [ ] **数据存储**
    - `isar`, `isar_flutter_libs`: 本地数据库
    - `path_provider`: 获取文件路径
    - `shared_preferences`: 轻量级配置存储
- [ ] **UI 组件**
    - `flutter_quill`: 富文本编辑器
    - `flutter_heatmap_calendar`: 热力图组件 (或 `fl_chart`)
    - `google_fonts`: 字体支持 (Manrope)
- [ ] **网络与同步**
    - `webdav_client`: WebDAV 客户端
- [ ] **开发工具**
    - `build_runner`: 代码生成
    - `isar_generator`: Isar 代码生成
    - `flutter_lints`: 代码规范

### 3. 项目结构搭建
- [ ] **创建目录层级** (Clean Architecture)
    ```text
    lib/
    ├── core/
    │   ├── constants/ (AppColors, ApiUrls)
    │   ├── theme/ (AppTheme)
    │   ├── utils/ (DateUtil, GuidUtil)
    │   └── widgets/ (Common Buttons, Dialogs)
    ├── data/
    │   ├── datasources/ (LocalDb, WebDavClient)
    │   ├── models/ (Isar Entities, Json Models)
    │   └── repositories/ (Repository Impl)
    ├── domain/ (Optional/Simplified)
    │   └── repositories/ (Repository Interfaces)
    ├── presentation/
    │   ├── providers/ (ChangeNotifiers)
    │   ├── routers/ (GoRouter Config)
    │   └── pages/
    │       ├── home/
    │       ├── editor/
    │       ├── history/
    │       └── settings/
    └── main.dart
    ```

### 4. 路由与导航配置
- [ ] **配置 GoRouter**
    - 定义路由表: `/`, `/editor`, `/history`, `/settings`
    - (可选) 配置 `ShellRoute` 实现底部导航栏 (`BottomNavigationBar`)，如果设计需要主要 Tab 切换。
- [ ] **创建占位页面**
    - `HomePage` (Placeholder)
    - `HistoryPage` (Placeholder)
    - `SettingsPage` (Placeholder)

### 5. 主题与全局样式
- [ ] **定义色彩系统**
    - Primary: `#135bec` (Blue)
    - Background: `#f6f6f8` (Light), `#101622` (Dark)
    - Surface: `#ffffff` (Light), `#1d2532` (Dark)
- [ ] **配置 ThemeData**
    - 实现 `AppTheme.lightTheme` 和 `AppTheme.darkTheme`
    - 配置 `TextTheme` (字体: Manrope/Noto Sans SC)
    - 配置 `InputDecorationTheme` (输入框默认样式)
    - 配置 `CardTheme` (圆角 12px/16px, 阴影)
