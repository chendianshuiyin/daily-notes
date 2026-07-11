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
class DailyNotesApp extends StatefulWidget {
  const DailyNotesApp({super.key, this.noteRepository, this.aiProvider});

  final NoteRepository? noteRepository;
  final AiProvider? aiProvider;

  @override
  State<DailyNotesApp> createState() => _DailyNotesAppState();
}

class _DailyNotesAppState extends State<DailyNotesApp> {
  final _router = AppRouter.createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              NoteProvider(repository: widget.noteRepository)..loadNotes(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppSettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => WebDavProvider()..load()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = widget.aiProvider ?? AiProvider();
            if (widget.aiProvider == null) {
              provider.load();
            }
            return provider;
          },
        ),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp.router(
            title: 'Daily Notes',
            debugShowCheckedModeBanner: false,

            // 主题配置
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,

            // 路由配置
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
