---
trigger: model_decision
description: 适用于实现状态管理方案（ValueNotifier, Provider 等）、配置导航路由（GoRouter）、管理日志系统及运行代码生成任务时。
---

# 04. 开发功能：状态管理、路由与日志

本节包含了状态管理方案、导航路由、日志记录以及代码生成的相关规范。

## 状态管理 (State Management)

*   **内置方案:** 偏好 Flutter 内置的状态管理方案。除非明确要求，否则不要使用第三方包。
*   **Streams:** 使用 `Streams` 和 `StreamBuilder` 处理一系列异步事件。
*   **Futures:** 使用 `Futures` 和 `FutureBuilder` 处理单次异步操作。
*   **ValueNotifier:** 对于涉及单个值的简单本地状态，使用 `ValueNotifier` 与 `ValueListenableBuilder`。

```dart
// 定义状态
final ValueNotifier<int> _counter = ValueNotifier<int>(0);

// 监听并重建
ValueListenableBuilder<int>(
  valueListenable: _counter,
  builder: (context, value, child) {
    return Text('Count: $value');
  },
);
```

*   **ChangeNotifier:** 对于更复杂或在多个 Widget 间共享的状态，使用 `ChangeNotifier`。
*   **ListenableBuilder:** 使用 `ListenableBuilder` 监听来自 `ChangeNotifier` 或其他 `Listenable` 的变化。
*   **MVVM:** 当需要更健壮的方案时，使用 MVVM 模式构建应用。
*   **依赖注入:** 使用简单的手动构造函数依赖注入，使类的依赖关系在 API 中显式化。
*   **Provider:** 如果明确要求手动构造函数注入之外的方案，可以使用 `provider` 使 Service、Repository 或复杂状态对象在 UI 层可用。

## 路由 (Routing)

*   **GoRouter:** 使用 `go_router` 包进行声明式导航、深层链接和 Web 支持。
*   **GoRouter 设置:** 使用 `pub` 工具添加依赖，并配置路由。

```dart
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'details/:id',
          builder: (context, state) {
            final String id = state.pathParameters['id']!;
            return DetailScreen(id: id);
          },
        ),
      ],
    ),
  ],
);

// 在 MaterialApp 中应用
MaterialApp.router(
  routerConfig: _router,
);
```

*   **认证重定向:** 配置 `go_router` 的 `redirect` 属性处理认证流程。
*   **Navigator:** 对于不需要深层链接的短促屏幕（如对话框），使用内置的 `Navigator`。

## 日志记录 (Logging)

*   **结构化日志:** 使用 `dart:developer` 中的 `log` 函数进行集成到 Dart DevTools 的结构化日志记录。
*   **logging 包:** 在代码质量规范中也提到了偏好使用 `logging` 包替代 `print`。

```dart
import 'dart:developer' as developer;

developer.log('User logged in successfully.');

try { /* ... */ } catch (e, s) {
  developer.log(
    'Failed to fetch data',
    name: 'myapp.network',
    level: 1000, // SEVERE
    error: e,
    stackTrace: s,
  );
}
```

## 代码生成 (Code Generation)

*   **Build Runner:** 确保在 `pubspec.yaml` 中将 `build_runner` 列为 `dev_dependency`。
*   **生成任务:** 对所有代码生成任务（如 `json_serializable`）使用 `build_runner`。
*   **运行命令:**
    ```shell
    dart run build_runner build --delete-conflicting-outputs
    ```