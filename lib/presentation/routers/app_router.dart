import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/home/home_page.dart';
import '../pages/editor/editor_page.dart';
import '../pages/history/history_page.dart';
import '../pages/settings/settings_page.dart';

/// 应用路由配置
///
/// 使用 GoRouter 管理应用的路由导航
class AppRouter {
  AppRouter._();

  /// 路由路径常量
  static const String home = '/';
  static const String editor = '/editor';
  static const String history = '/history';
  static const String settings = '/settings';

  /// 路由配置
  static final GoRouter router = GoRouter(
    initialLocation: home,
    debugLogDiagnostics: true,
    routes: [
      // 首页
      GoRoute(
        path: home,
        name: 'home',
        pageBuilder: (context, state) => const MaterialPage(child: HomePage()),
      ),
      // 编辑页面
      GoRoute(
        path: editor,
        name: 'editor',
        pageBuilder: (context, state) {
          // 获取传递的笔记 ID 参数
          final noteId = state.uri.queryParameters['noteId'];
          return MaterialPage(child: EditorPage(noteId: noteId));
        },
      ),
      // 历史页面
      GoRoute(
        path: history,
        name: 'history',
        pageBuilder: (context, state) =>
            const MaterialPage(child: HistoryPage()),
      ),
      // 设置页面
      GoRoute(
        path: settings,
        name: 'settings',
        pageBuilder: (context, state) =>
            const MaterialPage(child: SettingsPage()),
      ),
    ],
  );
}
