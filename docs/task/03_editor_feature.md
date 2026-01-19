# 阶段三：记录功能实现 (Editor)

## 目标
完成核心写作体验，支持富文本编辑、时间插入和记录保存。

## 任务列表

### 1. 编辑页 (EditorPage) 基础 UI
- [ ] **路由配置**
    - 支持带参数跳转: `/editor?date=2023-10-01` (补录模式) 或 `/editor?id=123` (编辑模式)
- [ ] **页面骨架**
    - `Scaffold`
    - `AppBar`: 显示 "新建记录" 或日期，右侧 "保存" 按钮
    - `Body`: 放置编辑器组件

### 2. 富文本编辑器集成
- [ ] **集成 `flutter_quill`**
    - 初始化 `QuillController`
    - 自定义 Toolbar (去除不需用的功能，保留加粗、列表等)
- [ ] **自定义工具栏功能**
    - **插入时间戳**: 添加一个 Icon，点击后在光标处插入当前时间 (e.g., "14:30 ")
    - **标签输入**: 独立的 Tag Input 组件，不在 Quill 内部，而在顶部或底部
- [ ] **字数统计**
    - 监听 controller 变化，实时显示字符数

### 3. 附加信息录入
- [ ] **日期选择**
    - 默认选中 `SelectedDate`
    - 点击日期可弹出 `showDatePicker` 修改日期 (补录)
- [ ] **标签系统**
    - `TextField` 用于输入 Tag
    - `Wrap` 显示已添加的 Tag Chips
    - 支持删除 Tag

### 4. 数据保存逻辑
- [ ] **保存操作**
    - 提取 Delta (Json) 和 PlainText
    - 构建 `Note` 对象
    - 调用 `NotesRepository.saveNote()`
    - 成功后：
        - 显示 `SnackBar` "保存成功"
        - 返回上一页 (pop) 或 重置编辑器 (如果支持连续输入)
- [ ] **自动保存 (可选)**
    - 使用 `Debounce` 监听内容变化，自动存草稿 (暂定 Phase 2，优先手动保存)
