# 阶段五：设置与同步 (Settings & Sync)

## 目标
完成应用配置管理，并打通基于 WebDAV 的多端同步链路。

## 任务列表

### 1. 设置页 (SettingsPage) UI
- [ ] **分组布局**
    - 虽然简单，但建议用 Section 分隔: "同步", "外观", "数据", "关于"
- [ ] **同步设置**
    - Server URL (`TextField`)
    - Username (`TextField`)
    - Password (`TextField`, obscureText)
    - "立即同步" 按钮 (`ElevatedButton`)
    - 显示 "上次同步时间: yyyy-MM-dd HH:mm"
- [ ] **外观设置**
    - 主题模式切换 (`SegmentedButton`: System/Light/Dark)
- [ ] **关于**
    - 显示 Version Number (`package_info_plus`)

### 2. WebDAV 客户端集成
- [ ] **封装 `WebDavService`**
    - `init(url, user, pass)`: 建立连接
    - `testConnection()`: 验证配置有效性
    - `uploadFile(path, content)`
    - `downloadFile(path)`
    - `listFiles(path)`

### 3. 同步业务逻辑 (SyncEngine)
- [ ] **触发机制**
    - 手动触发: 点击 "立即同步"
    - 自动触发 (Foreground): App 启动时, 或保存 Note 后延迟 5秒
- [ ] **上传流程 (Push)**
    - 查询 Isar 中 `syncStatus == Dirty` 的记录
    - 按日期分组，合并成 JSON 数组 (Day Level Granularity)
    - 上传至 `/DailyNotes/data/YYYY-MM/YYYY-MM-DD.json`
    - 上传成功 -> 更新本地记录状态为 `Synced`
- [ ] **下载流程 (Pull)**
    - 遍历远程目录 (需优化，不要每次都全量遍历) -> 检查 `metadata.json` 或文件修改时间
    - 对比差异 -> 下载变更的 JSON
    - 解析 JSON -> 写入 Isar
    - **冲突处理**: 简单粗暴，Server 覆盖 Local (或由 Isar 里的 `updatedAt` 决定，但在多端场景需谨慎) -> *建议采用 "Last Write Wins" 并记录日志*

### 4. 敏感数据处理
- [ ] **密码存储**
    - 使用 `flutter_secure_storage` (如果需要更高安全性) 或简单的 SharedPrefs (MVP)
    - *注意: 计划书中只提到 SharedPrefs，MVP 阶段可暂用，但需注意安全性*
