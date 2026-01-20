import 'package:flutter/material.dart';

/// 应用颜色常量
///
/// 定义应用程序的主色调、背景色、表面色和功能色
class AppColors {
  AppColors._();

  // ============ Primary Colors ============
  /// 主色调 - Blue
  static const Color primary = Color(0xFF135BEC);

  /// 主色调变体
  static const Color primaryLight = Color(0xFF5A8BF0);
  static const Color primaryDark = Color(0xFF0D42B8);

  // ============ Light Theme Colors ============
  /// 亮色主题背景色
  static const Color lightBackground = Color(0xFFF6F6F8);

  /// 亮色主题表面色
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// 亮色主题卡片色
  static const Color lightCard = Color(0xFFFFFFFF);

  // ============ Dark Theme Colors ============
  /// 暗色主题背景色
  static const Color darkBackground = Color(0xFF101622);

  /// 暗色主题表面色
  static const Color darkSurface = Color(0xFF1D2532);

  /// 暗色主题卡片色
  static const Color darkCard = Color(0xFF1D2532);

  // ============ Text Colors ============
  /// 亮色主题主要文字颜色
  static const Color lightTextPrimary = Color(0xFF1A1A1A);

  /// 亮色主题次要文字颜色
  static const Color lightTextSecondary = Color(0xFF6B7280);

  /// 暗色主题主要文字颜色
  static const Color darkTextPrimary = Color(0xFFF9FAFB);

  /// 暗色主题次要文字颜色
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // ============ Functional Colors ============
  /// 成功色
  static const Color success = Color(0xFF10B981);

  /// 警告色
  static const Color warning = Color(0xFFF59E0B);

  /// 错误色
  static const Color error = Color(0xFFEF4444);

  /// 信息色
  static const Color info = Color(0xFF3B82F6);

  // ============ Border Colors ============
  /// 亮色主题边框色
  static const Color lightBorder = Color(0xFFE5E7EB);

  /// 暗色主题边框色
  static const Color darkBorder = Color(0xFF374151);

  // ============ Heatmap Colors ============
  /// 热力图颜色梯度 (从浅到深)
  static const List<Color> heatmapGradient = [
    Color(0xFFEBEDF0),
    Color(0xFF9BE9A8),
    Color(0xFF40C463),
    Color(0xFF30A14E),
    Color(0xFF216E39),
  ];
}
