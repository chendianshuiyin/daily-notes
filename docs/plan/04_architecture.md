# 技术架构设计

## 1. 架构模式

本项目采用 **Clean Architecture (整洁架构)** 的简化版，结合 **MVVM (Model-View-ViewModel)** 模式，以确保代码的可维护性、可测试性和由于业务逻辑与UI的分离。

### 分层结构

1.  **Presentation Layer (表现层)**
    *   **UI (Widgets)**: 负责页面的渲染和用户交互。
    *   **ViewModel (ChangeNotifier/Provider)**: 负责持有页面状态，处理UI逻辑，调用领域层 UseCase 或 Repository。
2.  **Domain Layer (领域层)** (可选，对于 MVP 规模可适当合并到 Data 层)
    *   **Models (Entities)**: 核心数据模型（如 `DailyNote`, `Tag`）。
    *   **Repositories Interfaces**: 数据仓库接口定义。
3.  **Data Layer (数据层)**
    *   **Repositories Implementation**: 接口的实现，负责协调本地数据和云端数据。
    *   **Local Data Source**: 本地数据库操作 (SQLite/Isar)。
    *   **Remote Data Source**: WebDAV 客户端操作。

## 2. 状态管理

使用 **Provider** 进行依赖注入和状态管理。
*   简单直观，官方推荐。
*   配合 `ChangeNotifier` 实现数据驱动UI更新。

## 3. 技术选型

| 类别 | 库/插件 | 说明 |
| :--- | :--- | :--- |
| **基础框架** | Flutter | SDK 3.10+ |
| **路由管理** | go_router | 声明式路由，支持深度链接 |
| **状态管理** | provider | 轻量级状态管理 |
| **本地存储** | isar | 高性能 NoSQL 数据库，类型安全，查询语法友好（替代 sqflite） |
| **键值存储** | shared_preferences | 存储简单的配置项（如主题设置、同步开关） |
| **网络同步** | webdav_client | 处理 WebDAV 协议通信 |
| **富文本编辑** | flutter_quill | 强大的富文本编辑器支持 |
| **图表绘制** | fl_chart / flutter_heatmap_calendar | 绘制统计图和热力图 |
| **工具类** | intl | 日期格式化、多语言支持 |

## 4. 目录结构规划

```
lib/
├── core/                   # 核心通用代码
│   ├── constants/          # 常量 (颜色、API地址)
│   ├── theme/              # 主题定义
│   ├── utils/              # 工具函数 (日期处理、UUID)
│   └── widgets/            # 全局通用组件
├── data/                   # 数据层
│   ├── datasources/        # 数据源 (Local/Remote)
│   ├── models/             # 数据模型 (JSON/DB 映射)
│   └── repositories/       # 仓库实现
├── domain/                 # 领域层 (实体业务逻辑)
│   ├── entities/           # 纯净实体
│   └── repositories/       # 仓库接口
├── presentation/           # 表现层
│   ├── providers/          # 状态管理 Provider
│   ├── routers/            # 路由配置
│   └── pages/              # 页面
│       ├── home/           # 统计总结页
│       ├── editor/         # 今日记录页
│       ├── history/        # 历史记录页
│       └── settings/       # 设置页
└── main.dart               # 入口文件
```

## 5. 关键技术点

### 5.1 离线优先 (Offline First)
应用始终从本地数据库读取数据进行展示。任何增删改操作先写入本地数据库，成功后标记为 `unsynced`，然后在后台异步触发同步任务。

### 5.2 日历热力图逻辑
*   数据源聚合：从数据库查询过去 365 天的所有记录。
*   映射逻辑：
    *   0 条: Level 0
    *   1 条: Level 1
    *   2-3 条: Level 2
    *   4-5 条: Level 3
    *   >5 条: Level 4
