---
trigger: model_decision
description: 适用于设计应用架构、定义数据分层（MVC/MVVM）、实现 JSON 序列化以及规划 API 接口时。强调关注点分离与模块化设计。
---

# 03. 架构、数据与 API 设计

本节涵盖了 API 设计原则、应用架构方案、数据流向以及序列化规范。

## API 设计原则 (API Design Principles)

在构建可复用 API（如库）时，请遵循以下原则：

*   **考虑用户:** 从使用者的角度设计 API。API 应该是直观且易于正确使用的。
*   **文档至关重要:** 良好的文档是 API 设计的一部分。它应当清晰、简洁并提供示例。

## 应用程序架构 (Application Architecture)

*   **关注点分离:** 像 MVC/MVVM 一样实现关注点分离，明确 Model、View 和 ViewModel/Controller 的角色。
*   **逻辑分层:** 将项目组织为逻辑层：
    *   表现层 (Presentation): Widget, 屏幕。
    *   领域层 (Domain): 业务逻辑类。
    *   数据层 (Data): 模型类, API 客户端。
    *   核心层 (Core): 共享类, 工具, 扩展类型。
*   **基于功能的组织:** 对于大型项目，按功能组织代码。每个功能都有自己的表现层、领域层和数据层子文件夹。这提高了导航效率和可扩展性。

## 数据流 (Data Flow)

*   **数据结构:** 定义数据结构（类）来表示应用中使用的数据。
*   **数据抽象:** 使用 Repository/Service 抽象数据源（如 API 调用、数据库操作），以提高可测试性。

## 数据处理与序列化 (Data Handling & Serialization)

*   **JSON 序列化:** 使用 `json_serializable` 和 `json_annotation` 进行 JSON 数据的解析和编码。
*   **字段重命名:** 编码数据时，使用 `fieldRename: FieldRename.snake` 将 Dart 的 camelCase 字段转换为 snake_case 的 JSON 键。

```dart
// 在模型文件中
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class User {
  final String firstName;
  final String lastName;

  User({required this.firstName, required this.lastName});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```