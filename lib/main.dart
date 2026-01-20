import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'presentation/routers/app_router.dart';

void main() {
  runApp(const DailyNotesApp());
}

/// Daily Notes 应用主入口
class DailyNotesApp extends StatelessWidget {
  const DailyNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Daily Notes',
      debugShowCheckedModeBanner: false,

      // 主题配置
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // 路由配置
      routerConfig: AppRouter.router,
    );
  }
}
