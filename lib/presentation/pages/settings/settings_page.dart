import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

/// Application settings and local data management.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _copyBackup(BuildContext context) async {
    final noteProvider = context.read<NoteProvider>();
    try {
      await Clipboard.setData(ClipboardData(text: noteProvider.createBackup()));
      if (!context.mounted) {
        return;
      }
      _showMessage(context, '已复制 ${noteProvider.notes.length} 条笔记的 JSON 备份');
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '复制备份失败，请重试');
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (!context.mounted) {
        return;
      }

      final source = clipboardData?.text?.trim() ?? '';
      if (source.isEmpty) {
        _showMessage(context, '剪贴板中没有可导入的备份');
        return;
      }

      final noteProvider = context.read<NoteProvider>();
      final backup = noteProvider.inspectBackup(source);
      if (backup.notes.isEmpty) {
        _showMessage(context, '备份中没有笔记');
        return;
      }

      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('恢复笔记备份？'),
          content: Text(
            '将导入 ${backup.notes.length} 条笔记。现有同 ID 笔记会被备份内容覆盖，其他笔记会保留。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('恢复'),
            ),
          ],
        ),
      );

      if (shouldRestore != true || !context.mounted) {
        return;
      }

      await noteProvider.restoreBackup(backup);
      if (context.mounted) {
        _showMessage(context, '已恢复 ${backup.notes.length} 条笔记');
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message.toString());
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '恢复备份失败，请检查内容后重试');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
      ),
      body: Consumer<AppSettingsProvider>(
        builder: (context, settings, child) {
          final noteCount = context.watch<NoteProvider>().notes.length;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 64),
                children: [
                  _SettingsIntro(noteCount: noteCount),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '外观',
                    children: [_ThemeModeItem(settings: settings)],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '数据管理',
                    children: [
                      _SettingsItem(
                        icon: Icons.copy_all_outlined,
                        title: '复制笔记备份',
                        subtitle: '将全部图文笔记复制为 JSON',
                        onTap: () => _copyBackup(context),
                      ),
                      _SettingsItem(
                        icon: Icons.settings_backup_restore_outlined,
                        title: '从剪贴板恢复',
                        subtitle: '合并备份，同 ID 内容将覆盖',
                        onTap: () => _restoreBackup(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SettingsSection(
                    title: '关于',
                    children: [
                      _SettingsItem(
                        icon: Icons.info_outlined,
                        title: '版本',
                        subtitle: '1.0.3',
                        showChevron: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({required this.noteCount});

  final int noteCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_outline,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地优先', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '$noteCount 条笔记保存在此设备，可随时导出备份。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置分区
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 设置项
class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showChevron = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: showChevron ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}

class _ThemeModeItem extends StatelessWidget {
  const _ThemeModeItem({required this.settings});

  final AppSettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('主题'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SegmentedButton<ThemeMode>(
          key: const ValueKey('themeModeSegmentedButton'),
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('系统'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('浅色'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('深色'),
            ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (selection) {
            settings.setThemeMode(selection.first);
          },
        ),
      ),
    );
  }
}
