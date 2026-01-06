---
trigger: model_decision
description: 适用于初始化项目、配置 AI 交互准则、设置 Flutter 项目标准结构或进行包管理时的指导。包含基础样式指南与分析修复工具的使用。
---

# 01. 通用原则与项目结构

本节涵盖了与 AI 交互的基本准则、项目结构、Flutter 样式指南以及包管理规范。

## 交互准则 (Interaction Guidelines)

*   **用户角色 (User Persona):** 假设用户熟悉编程概念，但可能对 Dart 不熟悉。
*   **解释说明 (Explanations):** 在生成代码时，为 Dart 特有的特性（如空安全、Future、Stream）提供解释。
*   **澄清 (Clarification):** 如果请求模糊，请询问预期的功能和目标平台（如命令行、Web、服务器）。
*   **依赖项 (Dependencies):** 当建议使用 `pub.dev` 的新依赖项时，解释其优势。
*   **格式化 (Formatting):** 使用 `dart_format` 工具确保一致的代码格式。
*   **修复 (Fixes):** 使用 `dart_fix` 工具自动修复常见的错误，并帮助代码符合配置的分析选项。
*   **分析 (Linting):** 使用 Dart Linter 和推荐的规则集来捕获常见问题。使用 `analyze_files` 工具运行 Linter。

## 项目结构 (Project Structure)

*   **标准结构:** 假设项目采用标准的 Flutter 项目结构，以 `lib/main.dart` 为主要的应用程序入口点。

## Flutter 样式指南 (Flutter Style Guide)

*   **SOLID 原则:** 在整个代码库中应用 SOLID 原则。
*   **简洁与声明式:** 编写简洁、现代、技术性的 Dart 代码。偏好函数式和声明式模式。
*   **组合优于继承:** 在构建复杂 Widget 和逻辑时，优先使用组合。
*   **不可变性:** 偏好不可变的数据结构。Widget（尤其是 `StatelessWidget`）应该是不可变的。
*   **状态管理:** 区分瞬态状态 (Ephemeral State) 和应用状态 (App State)。使用状态管理方案处理应用状态，以实现关注点分离。
*   **Widget 即 UI:** Flutter UI 中的一切都是 Widget。通过更小、可复用的 Widget 来构建复杂的 UI。
*   **导航:** 使用现代路由包，如 `auto_route` 或 `go_router`。详细示例请参阅[导航指南](./navigation.md)。

## 包管理 (Package Management)

*   **Pub 工具:** 如果可用，使用 `pub` 工具管理包。
*   **外部包:** 如果新功能需要外部包，使用 `pub_dev_search` 工具（如果可用）。否则，从 pub.dev 中确定最合适且稳定的包。
*   **添加依赖:** 如果可用，使用 `pub` 工具。否则，运行 `flutter pub add <package_name>`。
*   **添加开发依赖:** 如果可用，使用 `pub` 工具配合 `dev:<package name>`。否则，运行 `flutter pub add dev:<package_name>`。
*   **依赖覆盖:** 如果可用，使用 `pub` 工具配合 `override:<package name>:1.0.0`。否则，运行 `flutter pub add override:<package_name>:1.0.0`。
*   **移除依赖:** 如果可用，使用 `pub` 工具。否则，运行 `dart pub remove <package_name>`。