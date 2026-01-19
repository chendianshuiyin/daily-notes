# 阶段六：优化与测试 (Polish & Test)

## 目标
提升应用稳定性、性能，并准备发布 release 版本。

## 任务列表

### 1. 性能优化
- [ ] **列表性能**
    - 检查 `HistoryPage` 长列表滚动帧率
    - 确保图片懒加载 (如果支持)
    - 优化 Isar 查询 (避免 N+1)
- [ ] **启动速度**
    - 异步初始化耗时操作 (Isar, WebDAV Test)
    - 使用 Flutter Splash Screen

### 2. UI 细节打磨
- [ ] **图标与启动页**
    - 设计并替换 `launcher_icon` (使用 `flutter_launcher_icons`)
    - 配置 Native Splash Screen (使用 `flutter_native_splash`)
- [ ] **空状态与错误页**
    - 统一的 `EmptyView` (无数据时)
    - 统一的 `ErrorView` (网络请求失败时)
- [ ] **动画效果**
    - 增加页面切换过渡
    - 增加按钮点击反馈

### 3. 测试
- [ ] **单元测试 (Unit Tests)**
    - 测试 `DateUtil` 逻辑
    - 测试 `HeatmapDataset` 生成算法
    - 测试 `WebDavService` Mock
- [ ] **集成测试 (Integration Tests)**
    - 模拟完整的 "写日记 -> 保存 -> 查看历史" 流程

### 4. 发布准备
- [ ] **Android 打包**
    - 配置 `key.properties` (签名)
    - 运行 `flutter build apk --release`
- [ ] **版本号管理**
    - 更新 `pubspec.yaml` version: `1.0.0+1`
