# 数据存储设计

## 1. 存储方案选择

考虑到应用需要存储富文本内容、标签以及进行复杂的日期查询，且追求高性能，我们选择 **Isar** 数据库。
*   **优点**：性能极快（比 SQLite 快），纯 Dart 编写（无 JNI 开销），ACID 事务支持，全文本搜索支持（利于历史记录搜索），Web 端支持友好。

## 2. 数据模型设计 (Schema)

### 2.1 Note (日记记录)

| 字段名 | 类型 | 索引 | 说明 |
| :--- | :--- | :--- | :--- |
| `id` | Id (AutoIncrement) | Primary | 本地主键 |
| `uuid` | String | Unique | 全局唯一ID，用于同步去重 |
| `content` | String | - | 记录内容（纯文本或 JSON 结构）|
| `rawJson` | String | - | 富文本 Delta 格式 JSON 字符串 |
| `tags` | List\<String\> | Index | 标签列表 |
| `createdAt` | DateTime | Index | 创建时间（用于排序和热力图） |
| `updatedAt` | DateTime | - | 最后更新时间 |
| `targetDate` | DateTime | Index | 记录所属日期（去除时分秒，用于按日查询） |
| `syncStatus` | Enum (0: Synced, 1: Dirty) | Index | 同步状态 |

### 2.2 AppConfig (应用配置)
使用 `Shared Preferences` 存储键值对。

| Key | Type | 说明 |
| :--- | :--- | :--- |
| `theme_mode` | int | 0: System, 1: Light, 2: Dark |
| `webdav_url` | String | WebDAV 服务器地址 |
| `webdav_user` | String | 用户名 |
| `webdav_pass` | String | 密码（需加密存储，建议用 flutter_secure_storage） |
| `last_sync_time` | int | 上次同步时间戳 |

## 3. WebDAV 同步策略

采用 **"以文件为中心的增量同步"** 策略。

### 3.1 远程目录结构
```
/DailyNotes/
    ├── data/
    │   ├── 2023-10/
    │   │   ├── 2023-10-01.json  # 存储当日所有记录
    │   │   ├── 2023-10-02.json
    │   │   └── ...
    │   └── ...
    └── metadata.json            # 记录设备变更时间戳等元数据
```

### 3.2 同步流程
1.  **上传 (Push)**:
    *   监听本地数据变化。
    *   当某日数据发生改变，将该日所有 `Note` 导出为 JSON 数组。
    *   覆盖上传至 WebDAV 对应路径 `YYYY-MM/YYYY-MM-DD.json`。
    *   上传成功后，更新本地记录的 `syncStatus` 为 `Synced`。

2.  **下载 (Pull)**:
    *   用户点击"同步"或应用启动时。
    *   对比本地与远程文件的修改时间（或 ETag）。
    *   如果远程文件更新，下载并解析 JSON。
    *   **冲突解决**：
        *   简单策略：最后写入为准 (Last Write Wins)。
        *   高级策略（二期）：合并两边的记录列表（基于 UUID 去重）。

### 3.3 数据隐私
*   一期：明文 JSON 存储。
*   二期：支持 AES 加密，用户在设置页输入密钥，上传前加密内容，下载后解密。
