import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/repositories.dart';
import 'presentation/providers/providers.dart';
import 'presentation/routers/app_router.dart';

void main() {
  runApp(const DailyNotesApp());
}

/// Daily Notes 应用主入口
class DailyNotesApp extends StatelessWidget {
  const DailyNotesApp({super.key, this.noteRepository});

  final NoteRepository? noteRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NoteProvider(repository: noteRepository)..loadNotes(),
      child: MaterialApp.router(
        title: 'Daily Notes',
        debugShowCheckedModeBanner: false,

        // 主题配置
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,

        // 路由配置
        routerConfig: AppRouter.router,
      ),
    );
  }
}
