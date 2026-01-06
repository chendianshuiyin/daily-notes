---
trigger: model_decision
description: 适用于编写单元/Widget/集成测试、实施 UI 视觉设计（阴影、排版）、管理资源文件以及优化无障碍（A11Y）体验时。
---

# 05. 测试、设计与无障碍

本节涵盖了测试规范、视觉设计、资源管理以及无障碍适配。

## 测试 (Testing)

*   **运行测试:** 使用 `run_tests` 工具（如果可用），否则使用 `flutter test`。
*   **单元测试:** 对单元测试使用 `package:test`。
*   **Widget 测试:** 对 Widget 测试使用 `package:flutter_test`。
*   **集成测试:** 对集成测试使用 `package:integration_test`。
*   **断言:** 偏好使用 `package:checks` 以获得更具表现力的断言。

### 测试最佳实践
*   **约定:** 遵循 Arrange-Act-Assert (Given-When-Then) 模式。
*   **覆盖范围:** 旨在实现高测试覆盖率。
*   **Mock:** 偏好 Fake 或 Stub 胜过 Mock。如果必须，使用 `mockito` 或 `mocktail`。

## 视觉设计与主题 (Visual Design & Theming)

*   **UI 设计:** 构建遵循现代设计指南的美观直观的 UI。
*   **响应式:** 确保应用在移动端和 Web 端都能完美适配。
*   **导航提示:** 提供直观易用的导航栏或控件。
*   **排版:** 强调字体大小以辅助理解。
*   **背景:** 应用微弱的噪声纹理增加高级感。
*   **阴影:** 使用多层阴影营造深度感。
*   **交互元素:** 按钮、滑块等具有优雅颜色带来的“发光”效果。

### 主题 (Theming)
*   **集中化主题:** 定义集中化的 `ThemeData`。
*   **亮/暗模式:** 实现亮/暗主题支持。
*   **ColorScheme 生成:** 使用 `ColorScheme.fromSeed` 生成和谐配色。
*   **组件主题:** 使用 `appBarTheme` 等自定义特定组件。
*   **自定义字体:** 使用 `google_fonts` 包。

## 资源与图像 (Assets and Images)

*   **图像准则:** 确保图像相关、有意义且尺寸合适。提供占位图。
*   **资源声明:** 在 `pubspec.yaml` 中声明路径。
*   **加载方式:**
    *   本地：`Image.asset`
    *   网络：`Image.network`（务必包含 `loadingBuilder` 和 `errorBuilder`）
    *   缓存：使用 `cached_network_image`。

## 无障碍 (Accessibility / A11Y)

*   **颜色对比度:** 文本对比度至少 **4.5:1**。
*   **动态文本:** 确保 UI 在系统字体增大时仍可用。
*   **语义标签:** 使用 `Semantics` Widget 提供描述性标签。
*   **屏幕阅读器:** 定期使用 TalkBack (Android) 和 VoiceOver (iOS) 测试。